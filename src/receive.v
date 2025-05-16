module receive (
    input clk,         // 27MHz clock
    input rx,          // UART RX from external device
    output tx,         // UART TX to external device
    output reg led15,  
    output reg led16,
    output reg led17,  
    output reg led18,
    output reg led19,
    output reg led20,


    output reg [7:0] data_out,     // Byte data output
    output reg data_valid,         // Data valid signal
    output reg image_start,        // Start of image signal
    output reg image_end,          // End of image signal
    output reg chunk_complete      // Chunk complete signal
);

    // Protocol control constants
    localparam START_IMAGE = 8'h01;     // SOH - Start of Heading
    localparam READY = 8'h06;           // ACK - Acknowledge
    localparam ACK = 8'h06;             // Same as READY
    localparam END_IMAGE = 8'h03;       // ETX - End of Text
    localparam IMAGE_RECEIVED = 8'h16;  // SYN - Synchronous Idle
    localparam CHUNK_SIZE = 10240;        // Chunk size in bytes

    // State machine states
    localparam IDLE = 4'd0;
    localparam RECEIVE_HEADER = 4'd1;
    localparam SEND_READY = 4'd2;
    localparam WAIT_TX_READY = 4'd3;
    localparam RECEIVE_CHUNK = 4'd4;
    localparam SEND_ACK = 4'd5;
    localparam RECEIVE_END = 4'd6;
    localparam SEND_COMPLETE = 4'd7;
    localparam IMAGE_DONE = 4'd8;
    localparam STARTUP = 4'd9;

    // UART control signals
    reg reset_n;
    reg tx_en;
    reg [2:0] waddr;
    reg [7:0] wdata;
    reg rx_en;
    reg [2:0] raddr;
    wire [7:0] rdata;
    wire rx_rdy_n;
    wire tx_rdy_n;

    // State machine registers
    reg [3:0] state;
    reg [3:0] next_state;
    reg [15:0] byte_counter;
    reg header_complete;
    reg [7:0] last_rx_byte;

    // Reset counter
    reg [7:0] reset_counter;
    reg startup_complete;  // Flag for communication between always blocks

    // LED control
    reg [7:0] blink_counter;
    reg [26:0] blink_timer; // For 75ms timing at 27MHz
    reg led_state;

    // Initialize registers
    initial begin
        reset_n = 1'b0;
        tx_en = 1'b0;
        rx_en = 1'b0;
        waddr = 3'd0;
        raddr = 3'd0;
        state = STARTUP;
        next_state = IDLE;
        byte_counter = 16'd0;
        header_complete = 1'b0;
        last_rx_byte = 8'h00;
        led15 = 1'b1;
        led16 = 1'b1;
        led17 = 1'b1;
        led18 = 1'b1;
        led19 = 1'b1;
        led20 = 1'b1;
        blink_counter = 8'd0;
        blink_timer = 27'd0;
        led_state = 1'b0;
        reset_counter = 8'd0;
        startup_complete = 1'b0;
    end

    // UART instance
    UART_MASTER_Top uart_master(
        .I_CLK(clk),              // Input clock (27MHz)
        .I_RESETN(reset_n),       // Reset signal (active low)
        .I_TX_EN(tx_en),          // Transmit enable
        .I_WADDR(waddr),          // Write address
        .I_WDATA(wdata),          // Write data
        .I_RX_EN(rx_en),          // Receive enable
        .I_RADDR(raddr),          // Read address
        .O_RDATA(rdata),          // Read data
        .SIN(rx),                 // Serial input (RX)
        .RxRDYn(rx_rdy_n),        // Receive ready (active low)
        .SOUT(tx),                // Serial output (TX)
        .TxRDYn(tx_rdy_n),        // Transmit ready (active low)
        .DDIS(),                  // Not used
        .INTR(),                  // Interrupt (not used)
        .DCDn(1'b1),              // Data Carrier Detect (tie high)
        .CTSn(1'b1),              // Clear To Send (tie high)
        .DSRn(1'b1),              // Data Set Ready (tie high)
        .RIn(1'b1),               // Ring Indicator (tie high)
        .DTRn(),                  // Data Terminal Ready (not used)
        .RTSn()                   // Request To Send (not used)
    );

    // Reset counter logic - synthesizable startup sequence
    // This always block only controls reset_n and startup_complete
    always @(posedge clk) begin
        if (reset_counter < 8'd100) begin
            reset_counter <= reset_counter + 1'b1;
            reset_n <= 1'b0; // Keep in reset
            startup_complete <= 1'b0;
        end else begin
            reset_n <= 1'b1; // Release reset
            startup_complete <= 1'b1; // Signal to the state machine that startup is complete
        end
    end

    // Main state machine - synchronous reset
    // This always block controls state and all other registers
    always @(posedge clk) begin
        // Default assignments
        rx_en <= 1'b1; // Always enable RX
        data_valid <= 1'b0; // Default to no valid data
        image_start <= 1'b0; // Default to no image start
        image_end <= 1'b0; // Default to no image end
        chunk_complete <= 1'b0; // Default to no chunk complete
        
        // State machine logic
        case (state)
            STARTUP: begin
                // Wait for the startup sequence to complete
                if (startup_complete) begin
                    state <= IDLE;
                end
                // During startup, ensure everything is in a known state
                tx_en <= 1'b0;
                led15 <= 1'b1;
                led16 <= 1'b1;
                led17 <= 1'b1;
            end
            
            IDLE: begin
                tx_en <= 1'b0;
                led15 <= 1'b1;
                led16 <= 1'b1;
                led17 <= 1'b1;
                
                if (~rx_rdy_n) begin // RX data available
                    raddr <= 3'd0; // Read from RHR (Receive Holding Register)
                    last_rx_byte <= rdata;
                    
                    if (rdata == START_IMAGE) begin
                        state <= RECEIVE_HEADER;
                        byte_counter <= 16'd0;
                        header_complete <= 1'b0;
                    end
                end
            end
            
            RECEIVE_HEADER: begin
                // Parse header: expecting size and checksum separated by comma
                if (~rx_rdy_n) begin
                    raddr <= 3'd0; // Read from RHR
                    last_rx_byte <= rdata;
                    
                    // Simple header parsing: just count bytes and look for end pattern
                    byte_counter <= byte_counter + 1'b1;
                    
                    // For simplicity, assume header is complete when we've received
                    // at least one char after a comma
                    if (header_complete == 1'b0 && last_rx_byte == 8'h2C) begin // Comma character
                        header_complete <= 1'b1;
                    end else if (header_complete == 1'b1) begin
                        // We've received at least one byte after comma, consider header complete
                        state <= SEND_READY;
                        image_start <= 1'b1; // Signal start of image
                    end
                    
                    // Safety check - if header is too long, reset
                    if (byte_counter >= 16'd64) begin
                        state <= IDLE;
                    end
                end
            end
            
            SEND_READY: begin
                if (~tx_rdy_n) begin // TX ready
                    tx_en <= 1'b1;
                    waddr <= 3'd0; // Write to THR (Transmit Holding Register)
                    wdata <= READY;
                    state <= WAIT_TX_READY;
                    next_state <= RECEIVE_CHUNK;
                    byte_counter <= 16'd0; // Reset byte counter for chunk
                end
            end
            
            WAIT_TX_READY: begin
                tx_en <= 1'b0; // One-shot TX enable
                if (~tx_rdy_n) begin // Wait until TX is ready again
                    state <= next_state;
                end
            end
            
            RECEIVE_CHUNK: begin
                if (~rx_rdy_n) begin // RX data available
                    raddr <= 3'd0; // Read from RHR
                    last_rx_byte <= rdata;
                    
                    // Check for END_IMAGE
                    if (rdata == END_IMAGE) begin
                        state <= SEND_COMPLETE;
                        image_end <= 1'b1; // Signal end of image
                    end else begin
                        // Process regular data byte
                        byte_counter <= byte_counter + 1'b1;
                        
                        // Output data to storing module
                        data_out <= rdata;
                        data_valid <= 1'b1;

                        // Check if chunk is complete (256 bytes)
                        if (byte_counter >= (CHUNK_SIZE - 1)) begin
                            state <= SEND_ACK;
                            chunk_complete <= 1'b1; // Signal chunk complete
                        end
                    end
                end
            end
            
            SEND_ACK: begin
                if (~tx_rdy_n) begin // TX ready
                    tx_en <= 1'b1;
                    waddr <= 3'd0; // Write to THR
                    wdata <= ACK;
                    state <= WAIT_TX_READY;
                    next_state <= RECEIVE_CHUNK;
                    byte_counter <= 16'd0; // Reset byte counter for next chunk
                end
            end
            
            SEND_COMPLETE: begin
                if (~tx_rdy_n) begin // TX ready
                    tx_en <= 1'b1;
                    waddr <= 3'd0; // Write to THR
                    wdata <= IMAGE_RECEIVED;
                    state <= WAIT_TX_READY;
                    next_state <= IMAGE_DONE;
                    blink_counter <= 8'd0;
                    blink_timer <= 27'd0;
                    led_state <= 1'b1; // Start with LEDs ON
                end
            end
            
            IMAGE_DONE: begin
                // LED blinking logic - blink 15-17 times with 75ms period
                // At 27MHz clock, 75ms is 2,025,000 cycles
                blink_timer <= blink_timer + 1'b1;
                
                // Toggle LEDs every 75ms
                if (blink_timer >= 27'd1350000) begin
                    blink_timer <= 27'd0;
                    led_state <= ~led_state;
                    
                    // Count completed blinks (OFF->ON transitions)
                    if (led_state == 1'b1) begin // Going from OFF to ON
                        blink_counter <= blink_counter + 1'b1;
                        
                        // After 17 complete blinks, return to IDLE
                        if (blink_counter >= 8'd2) begin
                            state <= IDLE;
                            led15 <= 1'b1;
                            led16 <= 1'b1;
                            led17 <= 1'b1;
                        end
                    end
                end
                
                // Set LEDs based on blink state
                led15 <= ~led_state;
                led16 <= ~led_state;
                led17 <= ~led_state;
            end
            
            default: state <= IDLE;
        endcase
    end

endmodule

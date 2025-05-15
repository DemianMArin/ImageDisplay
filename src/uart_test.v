module top (
    input clk,         // 27MHz clock
    input rx,          // UART RX from external device
    output tx,         // UART TX to external device
    output reg led15,  // LED to control based on "on"/"off" commands
    output reg led16   // LED to toggle when "h" is received
);

    // Reset generation
    reg reset_n = 0;
    reg [7:0] reset_counter = 0;
    
    always @(posedge clk) begin
        if (reset_counter < 100) begin
            reset_counter <= reset_counter + 1;
            reset_n <= 0;
        end else begin
            reset_n <= 1;
        end
    end
    
    // UART signals
    reg tx_en;                 // Transmit enable
    reg [2:0] waddr;           // Write address
    reg [7:0] wdata;           // Write data
    reg rx_en;                 // Receive enable
    reg [2:0] raddr;           // Read address
    wire [7:0] rdata;          // Read data
    wire rx_rdy_n;             // Receive ready (active low)
    wire tx_rdy_n;             // Transmit ready (active low)
    
    // State machine for sending "Hello" every second
    reg [3:0] tx_state;
    reg [24:0] tx_counter;     // Counter for 1-second delay (27MHz clock)
    
    // State machine for receiving data
    reg [3:0] rx_state;
    reg [23:0] rx_buffer;      // Store received characters
    reg [3:0] rx_char_count;   // Count received characters
    
    // Message to send
    localparam [39:0] HELLO_MSG = "Hello";  // 5 characters
    
    // Initialize registers
    initial begin
        led15 = 0;
        led16 = 0;
        tx_en = 0;
        rx_en = 0;
        waddr = 0;
        raddr = 0;
        tx_state = 0;
        tx_counter = 0;
        rx_state = 0;
        rx_buffer = 0;
        rx_char_count = 0;
    end
    
    // UART Master instance
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
        .DCDn(1'b1),              // Data Carrier Detect (not used, tie high)
        .CTSn(1'b1),              // Clear To Send (not used, tie high)
        .DSRn(1'b1),              // Data Set Ready (not used, tie high)
        .RIn(1'b1),               // Ring Indicator (not used, tie high)
        .DTRn(),                  // Data Terminal Ready (not used)
        .RTSn()                   // Request To Send (not used)
    );
    
    // Transmit state machine
    always @(posedge clk) begin
        if (!reset_n) begin
            tx_state <= 0;
            tx_counter <= 0;
            tx_en <= 0;
        end else begin
            case (tx_state)
                0: begin  // Idle state, waiting for 1-second timer
                    tx_en <= 0;
                    if (tx_counter >= 27000000) begin  // 1 second at 27MHz
                        tx_counter <= 0;
                        tx_state <= 1;
                    end else begin
                        tx_counter <= tx_counter + 1;
                    end
                end
                
                1: begin  // Wait for TX ready
                    if (!tx_rdy_n) begin
                        wdata <= "H";  // ASCII for 'H'
                        waddr <= 3'b000;  // Data register
                        tx_en <= 1;
                        tx_state <= 2;
                    end
                end
                
                2: begin  // Send 'H'
                    tx_en <= 0;
                    if (!tx_rdy_n) begin
                        wdata <= "e";  // ASCII for 'e'
                        waddr <= 3'b000;
                        tx_en <= 1;
                        tx_state <= 3;
                    end
                end
                
                3: begin  // Send 'e'
                    tx_en <= 0;
                    if (!tx_rdy_n) begin
                        wdata <= "l";  // ASCII for 'l'
                        waddr <= 3'b000;
                        tx_en <= 1;
                        tx_state <= 4;
                    end
                end
                
                4: begin  // Send 'l'
                    tx_en <= 0;
                    if (!tx_rdy_n) begin
                        wdata <= "l";  // ASCII for 'l'
                        waddr <= 3'b000;
                        tx_en <= 1;
                        tx_state <= 5;
                    end
                end
                
                5: begin  // Send 'o'
                    tx_en <= 0;
                    if (!tx_rdy_n) begin
                        wdata <= "o";  // ASCII for 'o'
                        waddr <= 3'b000;
                        tx_en <= 1;
                        tx_state <= 6;
                    end
                end
                
                6: begin  // Send complete, return to idle
                    tx_en <= 0;
                    tx_state <= 0;
                end
                
                default: tx_state <= 0;
            endcase
        end
    end
    
    // Receive state machine
    always @(posedge clk) begin
        if (!reset_n) begin
            rx_state <= 0;
            rx_en <= 0;
            rx_buffer <= 0;
            rx_char_count <= 0;
            led15 <= 0;
            led16 <= 0;
        end else begin
            case (rx_state)
                0: begin  // Check if data is available
                    raddr <= 3'b000;  // Data register
                    rx_en <= 1;
                    if (!rx_rdy_n) begin  // Data is ready to be read
                        rx_state <= 1;
                    end
                end
                
                1: begin  // Read data
                    rx_en <= 0;
                    // Shift in new character and update buffer
                    rx_buffer <= {rx_buffer[15:0], rdata};
                    rx_char_count <= rx_char_count + 1;
                    
                    // Check for "h" to toggle LED16
                    if (rdata == "h") begin
                        led16 <= ~led16;
                    end
                    
                    // Check for "on" command (2 characters)
                    if (rx_char_count >= 1 && rx_buffer[15:0] == "on") begin
                        led15 <= 1;
                        rx_char_count <= 0;
                        rx_buffer <= 0;
                    end
                    
                    // Check for "off" command (3 characters)
                    if (rx_char_count >= 2 && rx_buffer[23:0] == "off") begin
                        led15 <= 0;
                        rx_char_count <= 0;
                        rx_buffer <= 0;
                    end
                    
                    rx_state <= 0;  // Go back to check for more data
                    
                    // Reset buffer if too many characters
                    if (rx_char_count > 10) begin
                        rx_char_count <= 0;
                        rx_buffer <= 0;
                    end
                end
                
                default: rx_state <= 0;
            endcase
        end
    end

endmodule

module storing (
    input clk,                 // 27MHz clock
    input reset,               // Reset signal
    input [7:0] data_in,       // Data from receive module
    input data_valid,          // Data valid signal
    input image_start,         // Start of image signal
    input image_end,           // End of image signal
    input chunk_complete,      // Chunk complete signal
    
    // LCD interface inputs
    input lcd_clk,             // LCD clock
    input enable_timed,        // LCD active area signal
    input [14:0] lcd_addr,     // LCD pixel address
    
    // SDPB memory interface
    output wire [1:0] dout,    // Data output from memory (read)
    
    // Additional signals
    output reg image_complete, // Signal indicating complete image is available
    output reg writing_active  // Signal indicating that writing is in progress
);
    // SDPB memory control signals
    reg cea;                   // Clock enable for port A (write)
    reg reseta;                // Reset for port A
    reg ceb;                   // Clock enable for port B (read)
    reg resetb;                // Reset for port B
    reg oce;                   // Output clock enable
    reg [14:0] ada;            // Address for port A (write)
    reg [1:0] din;             // Data input to memory (write)
    reg [14:0] adb;            // Address for port B (read)
    
    // Internal clock connections
    wire clka = clk;           // Clock for port A (write)
    wire clkb = lcd_clk;       // Clock for port B (read)
    
    // Base64 decoding parameters
    localparam BASE64_BLOCK_SIZE = 4; // 4 base64 chars to decode
    
    // State machine states
    localparam IDLE = 4'd0;
    localparam DECODING = 4'd1;
    localparam COMBINE_VALUES = 4'd2;
    localparam STORE_PIXELS = 4'd3;
    localparam WAIT_NEXT_CHUNK = 4'd4;
    localparam COMPLETE = 4'd5;
    
    // State machine registers
    reg [3:0] state;
    reg [1:0] base64_counter;      // Count received base64 chars (0-3)
    reg [23:0] decoded_data;       // Decoded 3 bytes (24 bits)
    reg [7:0] x_counter;     // Column (0-239)
    reg [6:0] y_counter;     // Line (0-127)
    reg [15:0] pixel_counter;      // Count pixels written
    reg [7:0] base64_buffer [0:3]; // Buffer for 4 base64 chars
    reg [3:0] pixel_bit_counter;   // Count bits within decoded data
    
    // Base64 decoding registers
    reg [5:0] val_A, val_B, val_C, val_D;
    
    // Image complete tracking
    reg image_received;
    
    // Initialize registers
    initial begin
        state = IDLE;
        base64_counter = 2'd0;
        decoded_data = 24'd0;
        x_counter <= 8'd0;
        y_counter <= 7'd0;
        pixel_counter = 16'd0;
        pixel_bit_counter = 4'd0;
        cea = 1'b0;
        reseta = 1'b1; // Active high reset
        ceb = 1'b0;
        resetb = 1'b1; // Active high reset
        oce = 1'b0;
        ada = 15'd0;
        din = 2'd0;
        adb = 15'd0;
        val_A = 6'd0;
        val_B = 6'd0;
        val_C = 6'd0;
        val_D = 6'd0;
        image_complete = 1'b0;
        writing_active = 1'b0;
        image_received = 1'b0;
    end
    
    // Combinational base64 decoding logic
    reg [5:0] char_value;
    
    always @(*) begin
        // Default value
        char_value = 6'd0;
        
        // Lookup table for base64 decoding
        if ((data_in >= 8'h41) && (data_in <= 8'h5A))      // 'A'-'Z'
            char_value = data_in - 8'h41;                   // 0-25
        else if ((data_in >= 8'h61) && (data_in <= 8'h7A)) // 'a'-'z'
            char_value = data_in - 8'h61 + 6'd26;           // 26-51
        else if ((data_in >= 8'h30) && (data_in <= 8'h39)) // '0'-'9'
            char_value = data_in - 8'h30 + 6'd52;           // 52-61
        else if (data_in == 8'h2B)                         // '+'
            char_value = 6'd62;
        else if (data_in == 8'h2F)                         // '/'
            char_value = 6'd63;
        else                                               // Including '=' (padding)
            char_value = 6'd0;
    end
    
    // Main write state machine - uses clk domain

    // The memory address is formed as {y[6:0], x[7:0]}
    wire [14:0] mem_addr = {y_counter[6:0], x_counter[7:0]};

    always @(posedge clk) begin
        if (reset) begin
            state <= IDLE;
            base64_counter <= 2'd0;
            decoded_data <= 24'd0;
            x_counter <= 8'd0;
            y_counter <= 7'd0;
            pixel_counter <= 16'd0;
            pixel_bit_counter <= 4'd0;
            cea <= 1'b0;
            reseta <= 1'b0;
            val_A <= 6'd0;
            val_B <= 6'd0;
            val_C <= 6'd0;
            val_D <= 6'd0;
            image_complete <= 1'b0;
            writing_active <= 1'b0;
            image_received <= 1'b0;
        end else begin
            // Default assignments
            cea <= 1'b0;
            
            case (state)
                IDLE: begin
                    if (image_start) begin
                        state <= DECODING;
                        base64_counter <= 2'd0;
                        x_counter <= 8'd0;
                        y_counter <= 7'd0;
                        pixel_counter <= 16'd0;
                        writing_active <= 1'b1;   // Signal that writing is active
                        image_received <= 1'b0;
                        image_complete <= 1'b0;
                    end
                end
                
                DECODING: begin
                    if (data_valid) begin
                        // Store base64 character and its value
                        base64_buffer[base64_counter] <= data_in;
                        
                        // Save character value based on the current counter
                        case (base64_counter)
                            2'd0: val_A <= char_value;
                            2'd1: val_B <= char_value;
                            2'd2: val_C <= char_value;
                            2'd3: val_D <= char_value;
                        endcase
                        
                        base64_counter <= base64_counter + 1'b1;
                        
                        // If we have 4 base64 chars, combine them
                        if (base64_counter == (BASE64_BLOCK_SIZE - 1)) begin
                            state <= COMBINE_VALUES;
                            base64_counter <= 2'd0;
                        end
                    end
                    
                    if (image_end) begin
                        state <= COMPLETE;
                    end
                    
                    if (chunk_complete) begin
                        state <= WAIT_NEXT_CHUNK;
                    end
                end
                
                COMBINE_VALUES: begin
                    // Combine values to get 3 bytes (24 bits) using bit manipulation
                    decoded_data[23:16] <= (val_A << 2) | (val_B >> 4);
                    decoded_data[15:8] <= ((val_B & 6'h0F) << 4) | (val_C >> 2);
                    decoded_data[7:0] <= ((val_C & 6'h03) << 6) | val_D;
                    
                    // Prepare to write decoded data to memory in 2-bit chunks
                    pixel_bit_counter <= 4'd0;
                    state <= STORE_PIXELS;
                end
                

                STORE_PIXELS: begin
                    // Write 2-bit chunks to memory
                    cea <= 1'b1;
                    ada <= mem_addr;
                    
                    // Extract 2 bits from decoded data based on counter
                    case (pixel_bit_counter)
                        4'd0: din <= decoded_data[23:22];
                        4'd1: din <= decoded_data[21:20];
                        4'd2: din <= decoded_data[19:18];
                        4'd3: din <= decoded_data[17:16];
                        4'd4: din <= decoded_data[15:14];
                        4'd5: din <= decoded_data[13:12];
                        4'd6: din <= decoded_data[11:10];
                        4'd7: din <= decoded_data[9:8];
                        4'd8: din <= decoded_data[7:6];
                        4'd9: din <= decoded_data[5:4];
                        4'd10: din <= decoded_data[3:2];
                        4'd11: din <= decoded_data[1:0];
                        default: din <= 2'd0;
                    endcase

                    // Update position counters
                    x_counter <= x_counter + 1'b1;
                    
                    // If we reach the end of a row, move to next row
                    if (x_counter == 8'd239) begin
                        x_counter <= 8'd0;
                        y_counter <= y_counter + 1'b1;
                        
                        // Reset y if we reach the end of the image
                        if (y_counter == 7'd127) begin
                            y_counter <= 7'd0;
                        end
                    end
                    
                    // Increment pixel bit counter
                    pixel_bit_counter <= pixel_bit_counter + 1'b1;
                    pixel_counter <= pixel_counter + 1'b1;

                    // If we've written all 12 pixels (24 bits / 2 bits per pixel)
                    if (pixel_bit_counter == 4'd11) begin
                        state <= DECODING;
                    end
                end
                
                WAIT_NEXT_CHUNK: begin
                    // Wait for next chunk of data
                    if (data_valid) begin
                        state <= DECODING;
                    end
                    
                    if (image_end) begin
                        state <= COMPLETE;
                    end
                end
                
                COMPLETE: begin
                    // Image reception is complete
                    writing_active <= 1'b0;          // Writing is no longer active
                    image_received <= 1'b1;
                    image_complete <= 1'b1;          // Signal that a complete image is available
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
    
    // LCD read control - uses lcd_clk domain
    always @(posedge lcd_clk) begin
        if (reset) begin
            ceb <= 1'b0;
            resetb <= 1'b0;
            oce <= 1'b0;
            adb <= 16'd0;
        end else begin
            // Default assignments
            ceb <= 1'b0;
            resetb <= 1'b0;
            oce <= 1'b0;
            
            // Only read from memory when LCD is in active area AND
            // we're not writing to memory AND we have a complete image
            if (enable_timed && !writing_active && image_received) begin
                ceb <= 1'b1;
                oce <= 1'b1;
                adb <= lcd_addr;
            end
        end
    end
    
    // Instantiate SDPB module
    Gowin_SDPB memory_block(
        .dout(dout),       // output [1:0] dout
        .clka(clka),       // input clka
        .cea(cea),         // input cea
        .reseta(reseta),   // input reseta
        .clkb(clkb),       // input clkb
        .ceb(ceb),         // input ceb
        .resetb(resetb),   // input resetb
        .oce(oce),         // input oce
        .ada(ada),         // input [14:0] ada
        .din(din),         // input [1:0] din
        .adb(adb)          // input [14:0] adb
    );
endmodule

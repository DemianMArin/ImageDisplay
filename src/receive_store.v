// In Base64 decoder - simplified state machine concept
reg [1:0] base64_state;
reg [23:0] decoded_buffer;  // Buffer for 3 decoded bytes
reg [1:0] char_count;       // Counts characters (need 4 for full decode)

localparam IDLE = 2'b00, COLLECTING = 2'b01, PROCESSING = 2'b10, OUTPUT = 2'b11;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        base64_state <= IDLE;
        char_count <= 0;
        pixel_valid <= 0;
    end else begin
        case (base64_state)
            IDLE: begin
                rx_data_ready <= 1;
                if (rx_data_valid) begin
                    // Start collecting base64 characters
                    base64_state <= COLLECTING;
                    // Store first character value in buffer
                    // Code to convert base64 character to 6-bit value goes here
                    char_count <= 1;
                end
            end
            
            COLLECTING: begin
                // Continue collecting until we have 4 characters
                if (rx_data_valid && rx_data_ready) begin
                    // Add character to buffer
                    // Code to merge base64 values goes here
                    
                    if (char_count == 3) begin  // We have all 4 characters
                        base64_state <= PROCESSING;
                        rx_data_ready <= 0;
                    end else begin
                        char_count <= char_count + 1;
                    end
                end
            end
            
            // More states for processing and output would follow...
        endcase
    end
end

// In Memory Controller - address incrementing logic
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        mem_addr <= 0;
        pixel_ready <= 1;
    end else begin
        if (pixel_valid && pixel_ready) begin
            // Accept the pixel data
            mem_data <= pixel_data;
            mem_write_en <= 1;
            
            // Increment address for next pixel
            mem_addr <= mem_addr + 1;
            
            // Limit writing speed if needed
            pixel_ready <= 0;
        end else begin
            mem_write_en <= 0;
            if (!pixel_ready) begin
                // Reset ready after write cycle
                pixel_ready <= 1;
            end
        end
    end
end

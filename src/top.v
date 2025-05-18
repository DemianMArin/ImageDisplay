module top (
    input clk,         // 27MHz clock
    input rx,          // UART RX from external device
    output tx,         // UART TX to external device
    
    // LCD interface
    output [4:0] LCD_R,
    output [5:0] LCD_G,
    output [4:0] LCD_B,
    output LCD_HSYNC,
    output LCD_VSYNC,
    output LCD_CLK,
    output LCD_DEN,
    
    // Debug LEDs
    output led15, led16, led17, led18, led19, led20
);
    // Internal signals for receive module
    wire [7:0] data_out;
    wire data_valid, image_start, image_end;
    
    // SDPB memory output
    wire [1:0] dout;
    
    // Image status signals
    wire image_complete;
    wire writing_active;
    
    // Reset signal
    reg reset;
    reg [7:0] reset_counter;
    
    // LCD-related signals
    wire lcd_clk;
    wire [8:0] x, y;
    wire hde, vde;
    wire hsync_timed, vsync_timed;
    wire enable_timed;
    wire hsync_delayed, vsync_delayed, enable_delayed;
    
    // Constant signals
    wire false = 1'b0;
    wire true = 1'b1;
    
    // Memory addressing
    wire [14:0] lcd_addr;
    wire blackout;
    
    initial begin
        reset = 1'b1;
        reset_counter = 8'd0;
    end
    
    // Reset logic
    always @(posedge clk) begin
        if (reset_counter < 8'd150) begin
            reset_counter <= reset_counter + 1'b1;
            reset <= 1'b1;
        end else begin
            reset <= 1'b0;
        end
    end
    
    // Double x and y pixels for memory addressing
    assign lcd_addr = {y[7:1], x[8:1]};
    
    // Black lines when y > 256
    assign blackout = y[8];
    
    // Instantiate PLL for LCD clock
    Gowin_rPLL pll(
        .clkin(clk),         // input clkin 27MHz
        .clkout(),           // output clkout
        .clkoutd(lcd_clk)    // divided output clock for LCD
    );
    
    assign LCD_CLK = lcd_clk;
    assign enable_timed = hde & vde;
    
    // Instantiate receive module
    receive receive_inst (
        .clk(clk),
        .rx(rx),
        .tx(tx),
        .led15(led15),
        .led16(led16),
        .led17(led17),
        .led18(led18),
        .led19(led19),  // Use one LED to show image complete status
        .led20(led20),
        .data_out(data_out),
        .data_valid(data_valid),
        .image_start(image_start),
        .image_end(image_end)
    );
    
    // Instantiate storing module with LCD interface
    storing storing_inst (
        .clk(clk),
        .reset(reset),
        .data_in(data_out),
        .data_valid(data_valid),
        .image_start(image_start),
        .image_end(image_end),
        
        // LCD interface
        .lcd_clk(lcd_clk),
        .enable_timed(enable_timed),
        .lcd_addr(lcd_addr),
        
        // Memory output
        .dout(dout),
        
        // Status outputs
        .image_complete(image_complete),
        .writing_active(writing_active)
    );
    
    // Instantiate HSYNC generator
    hsync hsync_inst(
        .i_clk(lcd_clk),     // counter clock
        .o_hsync(hsync_timed), // horizontal sync pulse
        .o_hde(hde),         // horizontal signal in active zone
        .o_x(x)              // x pixel position
    );
    
    // Instantiate VSYNC generator
    vsync vsync_inst(
        .i_clk(hsync_timed), // counter clock
        .o_vsync(vsync_timed), // vertical sync pulse
        .o_vde(vde),         // vertical signal in active zone
        .o_y(y)              // y pixel position
    );
    
    // Delay H/V signals
    delay delay_h(
        .clk(lcd_clk),
        .in(hsync_timed),
        .out(hsync_delayed)
    );
    
    delay delay_v(
        .clk(lcd_clk),
        .in(vsync_timed),
        .out(vsync_delayed)
    );
    
    delay delay_en(
        .clk(lcd_clk),
        .in(enable_timed),
        .out(enable_delayed)
    );
    
    assign LCD_HSYNC = hsync_delayed;
    assign LCD_VSYNC = vsync_delayed;
    assign LCD_DEN = enable_delayed;
    
    // Color palette
    wire [4:0] R;
    wire [5:0] G;
    wire [4:0] B;
    
    palette palette_inst (
        .i_color(dout),     // color index from memory
        .o_red(R),
        .o_green(G),
        .o_blue(B)
    );
    
    // Output to LCD with blackout control
    assign LCD_R = R & {5{~blackout}};
    assign LCD_G = G & {6{~blackout}};
    assign LCD_B = B & {5{~blackout}};
    
endmodule

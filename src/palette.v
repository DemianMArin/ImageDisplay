module palette (
    input  [1:0] i_color,  // color index
    output [4:0] o_red,
    output [5:0] o_green,
    output [4:0] o_blue
);

localparam i = 1'b1; // intensify

  reg [4:0] red;
  reg [5:0] green;
  reg [4:0] blue;
  
  always @(*) begin
      case(i_color)
          2'b11: begin 
              red   = 5'd31;
              green = 6'd63;
              blue  = 5'd31;
          end
          2'b10: begin 
              red   = 5'd23;   
              green = 6'd48;   
              blue  = 5'd23;   
          end
          2'b01: begin 
              red   = 5'd15;   
              green = 6'd34;   
              blue  = 5'd19;   
          end
          2'b00: begin 
              red   = 5'd00;  
              green = 6'd00;  
              blue  = 5'd00;  
          end
      endcase
  end
  
  assign o_red   = red;
  assign o_green = green;
  assign o_blue  = blue;


endmodule

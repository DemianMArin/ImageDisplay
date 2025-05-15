module base64_decoder (
    input wire clk,
    input wire rst_n,
    
    // Interface with UART
    input wire [7:0] rx_data,        // Incoming base64 character
    input wire rx_data_valid,        // Indicates new character received
    output reg rx_data_ready,        // Indicates decoder ready for new character
    
    // Interface with Memory Controller
    output reg [2:0] pixel_data,     // Decoded 3-bit pixel
    output reg pixel_valid,          // Indicates new pixel ready
    input wire pixel_ready           // Memory controller ready for pixel
);

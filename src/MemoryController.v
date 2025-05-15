module memory_controller (
    input wire clk,
    input wire rst_n,
    
    // Interface with Base64 Decoder
    input wire [2:0] pixel_data,     // Incoming decoded pixel
    input wire pixel_valid,          // New pixel available
    output reg pixel_ready,          // Ready to accept pixel
    
    // Interface with SDPB
    output reg [2:0] mem_data,       // Data to write to memory
    output reg [14:0] mem_addr,      // Write address
    output reg mem_write_en,         // Write enable
    output reg mem_reset             // Memory reset
);

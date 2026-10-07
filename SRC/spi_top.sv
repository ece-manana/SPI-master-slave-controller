`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 15.08.2026 23:34:43
// Design Name: 
// Module Name: spi_top
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module spi_top #(
    parameter int DATA_WIDTH = 8
)(
    input  logic clk,               // Main system clock
    input  logic rst_n,             // Main system reset
    
    // Master controls
    input  logic start,             // Pulse to start transaction
    input  logic [DATA_WIDTH-1:0] master_tx_data, 
    output logic [DATA_WIDTH-1:0] master_rx_data,
    output logic master_busy,
    
    // Slave controls
    input  logic [DATA_WIDTH-1:0] slave_tx_data,
    output logic [DATA_WIDTH-1:0] slave_rx_data,
    output logic slave_rx_valid
);

    // Internal wires to connect the physical SPI bus between Master and Slave
    wire spi_sclk;
    wire spi_mosi;
    wire spi_miso;
    wire spi_cs_n;

    // Instantiate the Master
    spi_master #(
        .DATA_WIDTH(DATA_WIDTH)
    ) u_master (
        .clk     (clk),
        .rst_n   (rst_n),
        .start   (start),
        .tx_data (master_tx_data),
        .rx_data (master_rx_data),
        .busy    (master_busy),
        
        // Connect to internal bus
        .sclk    (spi_sclk),
        .mosi    (spi_mosi),
        .miso    (spi_miso),
        .cs_n    (spi_cs_n)
    );

    // Instantiate the Slave
    spi_slave #(
        .DATA_WIDTH(DATA_WIDTH)
    ) u_slave (
        .clk      (clk),
        .rst_n    (rst_n),
        .tx_data  (slave_tx_data),
        .rx_data  (slave_rx_data),
        .rx_valid (slave_rx_valid),
        
        // Connect to internal bus
        .sclk     (spi_sclk),
        .mosi     (spi_mosi),
        .miso     (spi_miso),
        .cs_n     (spi_cs_n)
    );

endmodule

`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 15.08.2026 23:31:43
// Design Name: 
// Module Name: spi_slave
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


module spi_slave #(
    parameter int DATA_WIDTH = 8
)(
    input  logic clk,           // System clock (Must be much faster than sclk)
    input  logic rst_n,         // Active-low synchronous reset
    
    // User Data Interface
    input  logic [DATA_WIDTH-1:0] tx_data,  // Data the slave wants to send to the master
    output logic [DATA_WIDTH-1:0] rx_data,  // Data received from the master
    output logic rx_valid,                  // Pulses high for 1 clock cycle when new data arrives

    // SPI Physical Interface
    input  logic sclk,          // Serial Clock (from master)
    input  logic mosi,          // Master Out, Slave In (from master)
    output logic miso,          // Master In, Slave Out (to master)
    input  logic cs_n           // Chip Select (from master)
);

    // Shift registers for edge detection (Oversampling)
    logic [2:0] sclk_sync;
    logic [2:0] cs_n_sync;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sclk_sync <= 3'b000;
            cs_n_sync <= 3'b111; // cs_n is active low, default to high
        end else begin
            sclk_sync <= {sclk_sync[1:0], sclk};
            cs_n_sync <= {cs_n_sync[1:0], cs_n};
        end
    end

    // Edge detection logic
    wire sclk_rising  = (sclk_sync[2:1] == 2'b01);
    wire sclk_falling = (sclk_sync[2:1] == 2'b10);
    wire cs_n_falling = (cs_n_sync[2:1] == 2'b10);
    wire cs_n_rising  = (cs_n_sync[2:1] == 2'b01);
    wire cs_n_active  = ~cs_n_sync[1];

    logic [DATA_WIDTH-1:0] tx_shift;
    logic [DATA_WIDTH-1:0] rx_shift;

    // Tri-state buffer for MISO: 
    // The slave must disconnect from the MISO line (High-Z) when not selected.
    assign miso = (!cs_n) ? tx_shift[DATA_WIDTH-1] : 1'bz;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            tx_shift <= '0;
            rx_shift <= '0;
            rx_data  <= '0;
            rx_valid <= 1'b0;
        end else begin
            rx_valid <= 1'b0; // Default to 0, pulses only when transaction ends

            if (cs_n_falling) begin
                // When chip select goes low, load the data we want to send
                tx_shift <= tx_data;
            end 
            else if (cs_n_active) begin
                // Mode 0: Sample MOSI on the rising edge of SCLK
                if (sclk_rising) begin
                    rx_shift <= {rx_shift[DATA_WIDTH-2:0], mosi};
                end
                
                // Mode 0: Shift next bit out to MISO on the falling edge of SCLK
                if (sclk_falling) begin
                    tx_shift <= {tx_shift[DATA_WIDTH-2:0], 1'b0};
                end
            end

            // When chip select goes back high, the transaction is over
            if (cs_n_rising) begin
                rx_data  <= rx_shift;
                rx_valid <= 1'b1;
            end
        end
    end
endmodule

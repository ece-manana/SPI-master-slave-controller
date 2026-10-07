module spi_master #(
    parameter int DATA_WIDTH = 8,
    parameter int CLK_DIV = 4 // SCLK will be System Clock / (CLK_DIV * 2)
)(
    input  logic clk,           // System clock
    input  logic rst_n,         // Active-low synchronous reset
    input  logic start,         // Pulse high for 1 clock cycle to start
    input  logic [DATA_WIDTH-1:0] tx_data, 
    output logic [DATA_WIDTH-1:0] rx_data, 
    output logic busy,          

    // SPI Physical Interface
    output logic sclk,          
    output logic mosi,          
    input  logic miso,          
    output logic cs_n           
);

    typedef enum logic [1:0] {
        IDLE,
        SETUP,     
        TRANSFER,
        DONE
    } state_e;

    state_e state;
    logic [$clog2(DATA_WIDTH)-1:0] bit_cnt;
    logic [1:0] delay_cnt; 
    logic [7:0] clk_cnt;       // <-- Added counter for clock division
    logic [DATA_WIDTH-1:0] tx_shift;
    logic [DATA_WIDTH-1:0] rx_shift;
    logic sclk_int;

    assign mosi = tx_shift[DATA_WIDTH-1]; 
    assign sclk = sclk_int;
    assign rx_data = rx_shift;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state     <= IDLE;
            sclk_int  <= 1'b0;
            cs_n      <= 1'b1;
            busy      <= 1'b0;
            tx_shift  <= '0;
            rx_shift  <= '0;
            bit_cnt   <= '0;
            delay_cnt <= '0; 
            clk_cnt   <= '0;
        end else begin
            case (state)
                IDLE: begin
                    cs_n     <= 1'b1;       
                    sclk_int <= 1'b0;       
                    busy     <= 1'b0;
                    
                    if (start) begin
                        tx_shift  <= tx_data; 
                        cs_n      <= 1'b0;    
                        busy      <= 1'b1;
                        delay_cnt <= 2'b11;   
                        state     <= SETUP;   
                    end
                end

                SETUP: begin
                    // Wait for slave to wake up
                    if (delay_cnt == 0) begin
                        bit_cnt <= DATA_WIDTH - 1;
                        clk_cnt <= CLK_DIV - 1; // <-- Initialize the clock divider
                        state   <= TRANSFER;
                    end else begin
                        delay_cnt <= delay_cnt - 1;
                    end
                end

                TRANSFER: begin
                    // <-- Only toggle the SPI clock when the divider hits 0
                    if (clk_cnt == 0) begin
                        clk_cnt  <= CLK_DIV - 1; // Reset divider
                        sclk_int <= ~sclk_int;   // Toggle SCLK

                        if (~sclk_int) begin
                            // SCLK goes 0 -> 1 (Rising Edge)
                            rx_shift <= {rx_shift[DATA_WIDTH-2:0], miso};
                        end else begin
                            // SCLK goes 1 -> 0 (Falling Edge)
                            tx_shift <= {tx_shift[DATA_WIDTH-2:0], 1'b0};

                            if (bit_cnt == 0) begin
                                state <= DONE;
                            end else begin
                                bit_cnt <= bit_cnt - 1;
                            end
                        end
                    end else begin
                        clk_cnt <= clk_cnt - 1; // Tick the divider down
                    end
                end

                DONE: begin
                    cs_n     <= 1'b1;       
                    sclk_int <= 1'b0;       
                    busy     <= 1'b0;       
                    state    <= IDLE;       
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule
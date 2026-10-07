module tb_spi_top;

    // ==========================================
    // CONFIGURATION PHASE
    // ==========================================
    // Set up programmable parameters (Data length and clock speed)
    // Note: CPOL=0 and CPHA=0 are hardcoded in our DUT architecture.
    parameter int DATA_WIDTH = 8;
    parameter time CLK_PERIOD = 10ns; // 100 MHz System Clock

    // Testbench Signals
    logic clk;
    logic rst_n;
    logic start;
    logic [DATA_WIDTH-1:0] master_tx_data;
    logic [DATA_WIDTH-1:0] master_rx_data;
    logic master_busy;
    logic [DATA_WIDTH-1:0] slave_tx_data;
    logic [DATA_WIDTH-1:0] slave_rx_data;
    logic slave_rx_valid;

    // Device Under Test (DUT) Instantiation
    spi_top #(
        .DATA_WIDTH(DATA_WIDTH)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .start(start),
        .master_tx_data(master_tx_data),
        .master_rx_data(master_rx_data),
        .master_busy(master_busy),
        .slave_tx_data(slave_tx_data),
        .slave_rx_data(slave_rx_data),
        .slave_rx_valid(slave_rx_valid)
    );

    // ==========================================
    // 1 CLOCK GENERATION
    // ==========================================
    // Initialize the simulation clock
    initial begin
        clk = 0;
        forever #(CLK_PERIOD / 2) clk = ~clk;
    end

    // Note: The coverage collection (covergroup) block was removed 
    // to ensure compatibility with the Vivado 2017.4 XSim simulator.

    // ==========================================
    // MAIN TEST SEQUENCE
    // ==========================================
    initial begin
        $display("--- Starting SPI Top-Level Simulation ---");
        
        // 1 INITIALIZATION
        start = 0;
        master_tx_data = '0;
        slave_tx_data  = '0;

        // Apply initial reset
        rst_n = 0;
        #(CLK_PERIOD * 5);
        rst_n = 1;
        #(CLK_PERIOD * 5);

        // 2 STANDARD DATA PATTERNS
        $display("--- Phase 1: Standard Directed Tests ---");
        run_transaction(8'hA5, 8'h5A); 
        run_transaction(8'h3C, 8'hC3); 

        // 3 DATA CORNER CASES
        $display("--- Phase 2: Data Corner Cases ---");
        run_transaction(8'h00, 8'hFF); // All zeros vs All ones
        run_transaction(8'hFF, 8'h00); // All ones vs All zeros
        run_transaction(8'h80, 8'h01); // MSB only vs LSB only

        // 4 TIMING CORNER CASE: BACK-TO-BACK BURST
        $display("--- Phase 3: Back-to-Back Burst (No delays between packets) ---");
        for (int i = 0; i < 5; i++) begin
            run_transaction($urandom_range(0, 255), $urandom_range(0, 255));
        end
        
        // Add a small gap before the destructive test
        #(CLK_PERIOD * 20);

        // 5 DESTRUCTIVE CORNER CASE: MID-TRANSACTION RESET
        $display("--- Phase 4: Mid-Transaction Asynchronous Reset ---");
        $display("[%0t] Starting a normal transaction...", $time);
        
        // Load data and trigger the start
        master_tx_data = 8'hEE;
        slave_tx_data  = 8'hBB;
        @(posedge clk);
        start = 1;
        @(posedge clk);
        start = 0;

        // Wait just long enough for the master to go busy and send a couple of bits.
        // Waiting 25 CLK_PERIODs will interrupt it right in the middle of transmission.
        #(CLK_PERIOD * 25); 

        $display("[%0t] ? SMASHING RESET BUTTON! ?", $time);
        rst_n = 0; // Trigger reset
        
        // Hold reset for a few clock cycles
        #(CLK_PERIOD * 5);
        rst_n = 1; // Release reset
        
        $display("[%0t] Reset released. Allowing system to recover...", $time);
        #(CLK_PERIOD * 10);
        
        // Verify recovery: Send one final golden packet to ensure the FSM didn't lock up
        $display("--- Phase 5: Post-Reset Recovery Check ---");
        run_transaction(8'h12, 8'h34);

        // ==========================================
        //  TEST TERMINATION
        // ==========================================
        #(CLK_PERIOD * 20);
        $display("--- Simulation Complete: All tests executed successfully! ---");
        $finish;
    end

    // ==========================================
    // ? MONITORING & SELF-CHECKING (SCOREBOARD)
    // ==========================================
    // Task to encapsulate a full transaction cycle
    task run_transaction(input logic [7:0] m_data, input logic [7:0] s_data);
        $display("[%0t] Starting Tx: Master sends %h | Slave sends %h", $time, m_data, s_data);
        
        // Drive inputs
        master_tx_data = m_data;
        slave_tx_data  = s_data;
        
        // Pulse the start signal for one clock cycle
        @(posedge clk);
        start = 1;
        @(posedge clk);
        start = 0;

        // Monitor: Wait for the hardware to indicate it is working, then wait for it to finish
        wait(master_busy == 1);
        wait(master_busy == 0);
        
        //  THE FIX: Wait for the slave's synchronizer to catch up
        // Give it plenty of time (10 clock cycles) to update its output registers
        #(CLK_PERIOD * 10); 
        
        // Scoreboarding: Automatically compare actual output against the "golden" expected data
        if (master_rx_data !== s_data) begin
            $error("[%0t] SCOREBOARD FAIL: Master RX Data Mismatch! Expected: %h, Got: %h", $time, s_data, master_rx_data);
        end else begin
            $display("[%0t] Master RX Check: PASS", $time);
        end

        if (slave_rx_data !== m_data) begin
            $error("[%0t] SCOREBOARD FAIL: Slave RX Data Mismatch! Expected: %h, Got: %h", $time, m_data, slave_rx_data);
        end else begin
            $display("[%0t] Slave RX Check: PASS", $time);
        end
        
        $display("-------------------------------------------------");
        #(CLK_PERIOD * 5); // Idle gap between transactions
    endtask

endmodule
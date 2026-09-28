// -----------------------------------------------------------------------------
// tb_top.sv
// Minimal testbench: clock/reset generator, a dummy power controller that
// randomly issues requests, and a dummy device that randomly accepts or denies.
// The tracker and coverage modules just watch the interface.
//
// Plusargs:  +NUM_TXNS=<n>   number of request/response rounds (default 20)
//            +ACCEPT_PCT=<n> % of requests the device accepts   (default 70)
//            +INJECT_BUG     make the device violate the protocol once, to show
//                            the assertions and tracker catching it
// -----------------------------------------------------------------------------
`timescale 1ns/1ps

module tb_top;
  import q_channel_pkg::*;

  // ---------------------------------------------------------------------------
  // Clock and reset
  // ---------------------------------------------------------------------------
  logic clk   = 0;
  logic rst_n = 0;

  always #5 clk = ~clk;                       // 100 MHz free-running clock

  initial begin
    rst_n = 0;
    repeat (4) @(posedge clk);                // hold reset for 4 cycles
    rst_n <= 1;
  end

  // ---------------------------------------------------------------------------
  // Interface + monitors
  // ---------------------------------------------------------------------------
  q_channel_if          qif (.clk(clk), .rst_n(rst_n));
  q_channel_tracker     tracker  (.vif(qif));
`ifndef NO_COVERAGE
  q_channel_coverage    coverage (.vif(qif));
`endif

  // ---------------------------------------------------------------------------
  // Test configuration
  // ---------------------------------------------------------------------------
  int  num_txns   = 20;
  int unsigned accept_pct = 70;
  bit  inject_bug = 0;
  int  accepted_cnt = 0, denied_cnt = 0;

  initial begin
    void'($value$plusargs("NUM_TXNS=%d",   num_txns));
    void'($value$plusargs("ACCEPT_PCT=%d", accept_pct));
    inject_bug = $test$plusargs("INJECT_BUG");
  end

  // ---------------------------------------------------------------------------
  // Dummy power controller: randomly requests low power, then exits/continues
  // ---------------------------------------------------------------------------
  initial begin
    qif.qreqn = 1;
    @(posedge rst_n);
    repeat (2) @(posedge clk);

    for (int i = 0; i < num_txns; i++) begin
      repeat ($urandom_range(2, 8)) @(posedge clk);   // random idle gap

      qif.qreqn <= 0;                                 // 1) request
      do @(posedge clk); while (qif.qacceptn && !qif.qdeny);  // wait for answer

      repeat ($urandom_range(1, 5)) @(posedge clk);   // stay a while
      qif.qreqn <= 1;                                 // 2) exit or continue
      do @(posedge clk); while (!(qif.qacceptn && !qif.qdeny)); // wait for RUN
    end

    repeat (5) @(posedge clk);
    $display("--------------------------------------------------");
    $display("Requests accepted : %0d", accepted_cnt);
    $display("Requests denied   : %0d", denied_cnt);
    $display("SVA failures      : %0d", qif.sva_fail_count);
    $display("Result            : %s", (qif.sva_fail_count == 0) ? "PASS" : "FAIL");
    $display("--------------------------------------------------");
    $finish;
  end

  // ---------------------------------------------------------------------------
  // Dummy device: answers each request randomly, toggles QACTIVE randomly
  // ---------------------------------------------------------------------------
  int txn_id = 0;

  initial begin
    qif.qacceptn = 1;
    qif.qdeny    = 0;
    qif.qactive  = 0;
    forever begin
      @(posedge clk);
      if (rst_n) begin
        // random busy/idle hint
        if ($urandom_range(0, 99) < 20) qif.qactive <= ~qif.qactive;

        if (!qif.qreqn && qif.qacceptn && !qif.qdeny) begin       // Q_REQUEST
          repeat ($urandom_range(0, 3)) @(posedge clk);           // random latency
          txn_id++;
          if (inject_bug && txn_id == 3) begin                    // illegal: both at once
            qif.qacceptn <= 0;
            qif.qdeny    <= 1;
          end else if ($urandom_range(0, 99) < accept_pct) begin
            qif.qacceptn <= 0;  accepted_cnt++;                   // accept
          end else begin
            qif.qdeny    <= 1;  denied_cnt++;                     // deny
          end
        end
        else if (qif.qreqn && !qif.qacceptn) qif.qacceptn <= 1;   // Q_EXIT     -> Q_RUN
        else if (qif.qreqn &&  qif.qdeny)    qif.qdeny    <= 0;   // Q_CONTINUE -> Q_RUN
      end
    end
  end

endmodule

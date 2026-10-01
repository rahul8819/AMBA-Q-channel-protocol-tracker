// -----------------------------------------------------------------------------
// tb_top.sv
// Minimal testbench: clock/reset generator, a controller FSM that issues
// requests, and a device FSM that accepts or denies. Both drivers are single
// synchronous always blocks using pure nonblocking assignments (no procedural
// #delays), so signal updates from different processes on the same clock edge
// are ordered the standard, race-free way: a read of a signal always sees the
// value from before this edge's updates, so a response can only appear on the
// NEXT edge, never the same one. (An earlier version used "<= #1" inside
// procedural @(posedge clk) loops, which occasionally let a response land in
// the same sampling window as the request that caused it - see README.)
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

`ifdef DUMP_VCD
  initial begin
    $dumpfile("wave.vcd");
    $dumpvars(0, tb_top);
  end
`endif

  // ---------------------------------------------------------------------------
  // Q-Channel signals + the three passive checkers
  // ---------------------------------------------------------------------------
  logic        qreqn, qacceptn, qdeny, qactive;
  int unsigned sva_fail_count;

  q_channel_assertions checker_sva (.clk, .rst_n, .qreqn, .qacceptn, .qdeny,
                                    .fail_count(sva_fail_count));
  q_channel_tracker    tracker     (.clk, .rst_n, .qreqn, .qacceptn, .qdeny, .qactive);
`ifndef NO_COVERAGE
  q_channel_coverage   coverage    (.clk, .rst_n, .qreqn, .qacceptn, .qdeny, .qactive);
`endif

  // ---------------------------------------------------------------------------
  // Test configuration
  // ---------------------------------------------------------------------------
  int unsigned num_txns   = 20;
  int unsigned accept_pct = 70;
  bit          inject_bug = 0;
  int unsigned accepted_cnt = 0, denied_cnt = 0;

  initial begin
    void'($value$plusargs("NUM_TXNS=%d",   num_txns));
    void'($value$plusargs("ACCEPT_PCT=%d", accept_pct));
    inject_bug = $test$plusargs("INJECT_BUG");
  end

  // ---------------------------------------------------------------------------
  // Controller FSM (the power manager): issues a request, waits for the
  // device's answer, holds a while, then withdraws the request.
  // ---------------------------------------------------------------------------
  typedef enum logic [1:0] {C_IDLE, C_WAIT_RESP, C_HOLD, C_WAIT_RUN} ctrl_state_e;
  ctrl_state_e ctrl_state;
  int unsigned ctrl_idle_cnt, ctrl_hold_cnt, txn_done;

  always @(posedge clk) begin
    if (!rst_n) begin
      qreqn <= 1; ctrl_state <= C_IDLE; ctrl_idle_cnt <= 0; ctrl_hold_cnt <= 0; txn_done <= 0;
    end else begin
      case (ctrl_state)
        C_IDLE: begin
          if (ctrl_idle_cnt > 0) ctrl_idle_cnt <= ctrl_idle_cnt - 1;
          else if (txn_done < num_txns) begin
            qreqn      <= 0;                        // 1) issue request
            ctrl_state <= C_WAIT_RESP;
          end
        end
        C_WAIT_RESP: begin
          if (!qacceptn || qdeny) begin              // device answered
            ctrl_hold_cnt <= $urandom_range(1, 5);
            ctrl_state    <= C_HOLD;
          end
        end
        C_HOLD: begin
          if (ctrl_hold_cnt <= 1) begin
            qreqn      <= 1;                         // 2) withdraw request
            ctrl_state <= C_WAIT_RUN;
          end else ctrl_hold_cnt <= ctrl_hold_cnt - 1;
        end
        C_WAIT_RUN: begin
          if (qacceptn && !qdeny) begin               // back to Q_RUN
            txn_done      <= txn_done + 1;
            ctrl_idle_cnt <= $urandom_range(2, 8);
            ctrl_state    <= C_IDLE;
          end
        end
        default: ctrl_state <= C_IDLE;
      endcase
    end
  end

  // Finish once every requested transaction has completed
  initial begin
    wait (rst_n);
    wait (txn_done >= num_txns);
    repeat (5) @(posedge clk);
    $display("--------------------------------------------------");
    $display("Requests accepted : %0d", accepted_cnt);
    $display("Requests denied   : %0d", denied_cnt);
    $display("SVA failures      : %0d", sva_fail_count);
    $display("Result            : %s", (sva_fail_count == 0) ? "PASS" : "FAIL");
    $display("--------------------------------------------------");
    $finish;
  end

  // ---------------------------------------------------------------------------
  // Device FSM: answers each request after a random (>=1 cycle) latency,
  // and toggles QACTIVE randomly. Pure NBA, same reasoning as the controller.
  // ---------------------------------------------------------------------------
  bit awaiting_resp;
  int unsigned resp_cnt, txn_id;

  always @(posedge clk) begin
    if (!rst_n) begin
      qacceptn <= 1; qdeny <= 0; qactive <= 0;
      awaiting_resp <= 0; resp_cnt <= 0; txn_id <= 0;
    end else begin
      if ($urandom_range(0, 99) < 20) qactive <= ~qactive;   // random busy/idle hint

      if (!qreqn && qacceptn && !qdeny && !awaiting_resp) begin  // new request (Q_REQUEST)
        resp_cnt      <= $urandom_range(1, 4);                  // >=1 cycle latency
        awaiting_resp <= 1;
      end
      else if (awaiting_resp) begin
        if (resp_cnt <= 1) begin
          awaiting_resp <= 0;
          txn_id        <= txn_id + 1;
          if (inject_bug && (txn_id + 1) == 3) begin            // illegal: both at once
            qacceptn <= 0;
            qdeny    <= 1;
          end else if ($urandom_range(0, 99) < accept_pct) begin
            qacceptn <= 0;  accepted_cnt <= accepted_cnt + 1;   // accept
          end else begin
            qdeny    <= 1;  denied_cnt   <= denied_cnt + 1;     // deny
          end
        end else resp_cnt <= resp_cnt - 1;
      end
      else if (qreqn && !qacceptn) qacceptn <= 1;   // Q_EXIT     -> Q_RUN
      else if (qreqn &&  qdeny)    qdeny    <= 0;   // Q_CONTINUE -> Q_RUN
    end
  end

endmodule

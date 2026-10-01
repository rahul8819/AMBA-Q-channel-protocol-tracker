// -----------------------------------------------------------------------------
// q_channel_coverage.sv
// Functional coverage: proves the test exercised every state, every legal
// transition, both outcomes of a request, and toggling of each signal.
// -----------------------------------------------------------------------------
`timescale 1ns/1ps

`ifndef NO_COVERAGE
module q_channel_coverage
  import q_channel_pkg::*;
(
  input logic clk,
  input logic rst_n,
  input logic qreqn,
  input logic qacceptn,
  input logic qdeny,
  input logic qactive
);

  q_state_e state;
  assign state = decode(qreqn, qacceptn, qdeny);

  covergroup cg_q_channel @(posedge clk);
    option.per_instance = 1;

    // 1. Signal toggling: each signal must go 0->1 and 1->0 during the test
    cp_qreqn : coverpoint qreqn iff (rst_n) {
      bins fall = (1 => 0);      // request issued
      bins rise = (0 => 1);      // exit / continue
    }
    cp_qacceptn : coverpoint qacceptn iff (rst_n) {
      bins fall = (1 => 0);      // accept
      bins rise = (0 => 1);
    }
    cp_qdeny : coverpoint qdeny iff (rst_n) {
      bins rise = (0 => 1);      // deny
      bins fall = (1 => 0);
    }
    cp_qactive : coverpoint qactive iff (rst_n) {
      bins rise = (0 => 1);
      bins fall = (1 => 0);
    }

    // 2. States: every legal state visited, illegal state never
    cp_state : coverpoint state iff (rst_n) {
      bins run         = {Q_RUN};
      bins request     = {Q_REQUEST};
      bins stopped     = {Q_STOPPED};
      bins exit_st     = {Q_EXIT};
      bins denied      = {Q_DENIED};
      bins continue_st = {Q_CONTINUE};
      illegal_bins illegal = {Q_ILLEGAL};
    }

    // 3. State transitions: the 7 legal arrows of the protocol
    cp_transition : coverpoint state iff (rst_n) {
      bins run_to_request     = (Q_RUN      => Q_REQUEST);
      bins request_to_stopped = (Q_REQUEST  => Q_STOPPED);   // accepted
      bins request_to_denied  = (Q_REQUEST  => Q_DENIED);    // denied
      bins stopped_to_exit    = (Q_STOPPED  => Q_EXIT);
      bins exit_to_run        = (Q_EXIT     => Q_RUN);
      bins denied_to_continue = (Q_DENIED   => Q_CONTINUE);
      bins continue_to_run    = (Q_CONTINUE => Q_RUN);
    }

    // 4. Outcome of a request (used by the cross below)
    cp_outcome : coverpoint state iff (rst_n) {
      bins accepted = {Q_STOPPED};
      bins denied   = {Q_DENIED};
    }

    // 5. Was the device busy (QACTIVE=1) or idle (QACTIVE=0) at that moment?
    cp_active_level : coverpoint qactive iff (rst_n) {
      bins idle = {0};
      bins busy = {1};
    }

    // 6. Cross: accept/deny seen while device idle AND while device busy
    cx_outcome_x_active : cross cp_outcome, cp_active_level;
  endgroup

  cg_q_channel cg = new();

  final begin
    $display("[COVERAGE] Q-Channel functional coverage = %0.2f%%", cg.get_inst_coverage());
  end

endmodule
`endif // NO_COVERAGE

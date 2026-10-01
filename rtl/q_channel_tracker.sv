// -----------------------------------------------------------------------------
// q_channel_tracker.sv
// Passive monitor: writes a table of every signal change (with direction of
// flow) and every state transition (with a legal/illegal check) to a log file,
// so debugging does not require opening a waveform.
//
// NOTE: everything is inlined directly in the always block (no nested
// task-calling-task, no built-in enum .name()). An earlier version used
// small helper tasks and .name(), which triggered a Vivado xsim kernel crash
// (FATAL_ERROR) on the second clock edge under some Vivado versions. This
// version avoids both suspect constructs. Verilator and slang still accept it.
// -----------------------------------------------------------------------------
`timescale 1ns/1ps

module q_channel_tracker
  import q_channel_pkg::*;
#(
  parameter string LOG_FILE = "q_channel_tracker.log"
)(
  input logic clk,
  input logic rst_n,
  input logic qreqn,
  input logic qacceptn,
  input logic qdeny,
  input logic qactive
);

  integer   fd;
  logic     prev_qreqn, prev_qacceptn, prev_qdeny, prev_qactive;
  q_state_e prev_state, cur_state;

  initial begin
    $timeformat(-9, 0, " ns", 10);          // print time in ns
    fd = $fopen(LOG_FILE, "w");
    $fdisplay(fd, "|------------|-----------|---------------------------|----------------------------|");
    $fdisplay(fd, "| %10s | %-9s | %-25s | %-26s |", "Time", "Signal", "New value", "Direction / Check");
    $fdisplay(fd, "|------------|-----------|---------------------------|----------------------------|");
    // idle values of the interface
    prev_qreqn = 1; prev_qacceptn = 1; prev_qdeny = 0; prev_qactive = 0;
    prev_state = Q_RUN;
  end

  always @(posedge clk) begin
    if (rst_n) begin
      // 1) signal changes + direction of flow (inlined, no helper tasks)
      if (prev_qreqn !== qreqn)
        $fdisplay(fd, "| %10t | %-9s | %-25s | %-26s |", $time, "QREQn",
                  qreqn ? "1" : "0", "Controller -> Device");
      if (prev_qacceptn !== qacceptn)
        $fdisplay(fd, "| %10t | %-9s | %-25s | %-26s |", $time, "QACCEPTn",
                  qacceptn ? "1" : "0", "Device -> Controller");
      if (prev_qdeny !== qdeny)
        $fdisplay(fd, "| %10t | %-9s | %-25s | %-26s |", $time, "QDENY",
                  qdeny ? "1" : "0", "Device -> Controller");
      if (prev_qactive !== qactive)
        $fdisplay(fd, "| %10t | %-9s | %-25s | %-26s |", $time, "QACTIVE",
                  qactive ? "1" : "0", "Device -> Controller");

      // 2) state transition + legality check
      cur_state = decode(qreqn, qacceptn, qdeny);
      if (cur_state != prev_state) begin
        if (is_legal(prev_state, cur_state))
          $fdisplay(fd, "| %10t | %-9s | %-25s | %-26s |", $time, "STATE",
                    {state_name(prev_state), " -> ", state_name(cur_state)}, "OK");
        else
          $fdisplay(fd, "| %10t | %-9s | %-25s | %-26s |", $time, "STATE",
                    {state_name(prev_state), " -> ", state_name(cur_state)},
                    "*** ILLEGAL TRANSITION ***");
        prev_state = cur_state;
      end
    end
    // remember values for the next clock
    prev_qreqn = qreqn;  prev_qacceptn = qacceptn;
    prev_qdeny = qdeny;  prev_qactive  = qactive;
  end

  final begin
    $fdisplay(fd, "|------------|-----------|---------------------------|----------------------------|");
    $fclose(fd);
  end

endmodule

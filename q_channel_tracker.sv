// -----------------------------------------------------------------------------
// q_channel_tracker.sv
// Passive monitor: writes a table of every signal change (with direction of
// flow) and every state transition (with a legal/illegal check) to a log file,
// so debugging does not require opening a waveform.
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

  // Print one table row
  task automatic log_row(string name, string value, string dir);
    $fdisplay(fd, "| %10t | %-9s | %-25s | %-26s |", $time, name, value, dir);
  endtask

  // Log a signal only if it changed since the last clock
  task automatic check_signal(string name, logic prev, logic cur, string dir);
    if (prev !== cur) log_row(name, $sformatf("%0b", cur), dir);
  endtask

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
      // 1) signal changes + direction of flow
      check_signal("QREQn",    prev_qreqn,    qreqn,    "Controller -> Device");
      check_signal("QACCEPTn", prev_qacceptn, qacceptn, "Device -> Controller");
      check_signal("QDENY",    prev_qdeny,    qdeny,    "Device -> Controller");
      check_signal("QACTIVE",  prev_qactive,  qactive,  "Device -> Controller");

      // 2) state transition + legality check
      cur_state = decode(qreqn, qacceptn, qdeny);
      if (cur_state != prev_state) begin
        log_row("STATE", $sformatf("%s -> %s", prev_state.name(), cur_state.name()),
                is_legal(prev_state, cur_state) ? "OK" : "*** ILLEGAL TRANSITION ***");
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

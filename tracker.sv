// ---------------------------------------------------------------------------
// Q-Channel Power-Management Tracker
// Protocol : AMBA Q-Channel low-power interface (public Arm spec)
// Purpose  : Instead of reading waveforms, log every signal change and every
//            state transition into a readable table, and flag illegal ones.
// ---------------------------------------------------------------------------
module q_channel_tracker #(
  parameter LOG_FILE = "q_channel_tracker.log"
)(
  input logic clk,
  input logic rst_n,
  input logic qreqn,     // Controller -> Device : request to enter low power (active low)
  input logic qacceptn,  // Device -> Controller : device accepts the request (active low)
  input logic qdeny,     // Device -> Controller : device denies the request
  input logic qactive    // Device -> Controller : device says "I need the clock / am busy"
);



  final begin
    $fdisplay(fd, "|------------|-----------|------------------------|------------------------|");
    $fclose(fd);
  end

endmodule

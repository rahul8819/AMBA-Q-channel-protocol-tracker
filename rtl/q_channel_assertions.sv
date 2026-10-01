// -----------------------------------------------------------------------------
// q_channel_assertions.sv
// Protocol checker for the Q-Channel handshake (SVA).
// Stand-alone module: it only observes the four signals, so it can be
// instantiated next to any design, or attached with `bind` without editing it.
// -----------------------------------------------------------------------------
`timescale 1ns/1ps

module q_channel_assertions (
  input  logic        clk,
  input  logic        rst_n,
  input  logic        qreqn,       // Controller -> Device : request (active low)
  input  logic        qacceptn,    // Device -> Controller : accept  (active low)
  input  logic        qdeny,       // Device -> Controller : deny
  output int unsigned fail_count   // number of assertion failures so far
);

  initial fail_count = 0;

  // Called by every assertion's else-branch
  function automatic void report_fail(string msg);
    fail_count++;
    $error("%s", msg);
  endfunction

  // A1. Mutual exclusion: the device must never accept (QACCEPTn low) and
  //     deny (QDENY high) in the same cycle.
  property p_accept_deny_exclusive;
    @(posedge clk) disable iff (!rst_n)
      !(qacceptn === 1'b0 && qdeny === 1'b1);
  endproperty
  A1_ACCEPT_DENY_EXCLUSIVE: assert property (p_accept_deny_exclusive)
    else report_fail("[SVA] A1 failed: QACCEPTn low and QDENY high in the same cycle");

  // A2. Once the controller drops QREQn (request), it must hold it low until
  //     the device answers (QACCEPTn goes low OR QDENY goes high).
  //     Written as: "while a request is pending (Q_REQUEST), QREQn stays low
  //     on the next cycle" - equivalent to "stable until response".
  property p_req_stable_until_response;
    @(posedge clk) disable iff (!rst_n)
      (!qreqn && qacceptn && !qdeny) |=> !qreqn;
  endproperty
  A2_REQ_STABLE_UNTIL_RESPONSE: assert property (p_req_stable_until_response)
    else report_fail("[SVA] A2 failed: QREQn changed before the device responded");

  // A3. Once the controller raises QREQn (exit / continue), it must hold it
  //     high until the device is back in Q_RUN (QACCEPTn=1 and QDENY=0).
  property p_exit_stable_until_run;
    @(posedge clk) disable iff (!rst_n)
      (qreqn && !(qacceptn && !qdeny)) |=> qreqn;
  endproperty
  A3_EXIT_STABLE_UNTIL_RUN: assert property (p_exit_stable_until_run)
    else report_fail("[SVA] A3 failed: QREQn changed before the device returned to RUN");

  // A4. The device may only start responding while a request is pending.
  property p_response_needs_request;
    @(posedge clk) disable iff (!rst_n)
      ($fell(qacceptn) || $rose(qdeny)) |-> !qreqn;
  endproperty
  A4_RESPONSE_NEEDS_REQUEST: assert property (p_response_needs_request)
    else report_fail("[SVA] A4 failed: device responded while QREQn was high");

endmodule

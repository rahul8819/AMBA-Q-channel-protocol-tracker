// -----------------------------------------------------------------------------
// q_channel_pkg.sv
// Shared definitions for the Q-Channel project: state enum, decoder, and the
// list of legal transitions. Used by the tracker and the coverage module so the
// protocol rules live in exactly one place.
// -----------------------------------------------------------------------------
`timescale 1ns/1ps

package q_channel_pkg;

  // State = combination of {QREQn, QACCEPTn, QDENY}
  typedef enum logic [2:0] {
    Q_RUN,        // 1 1 0  normal operation
    Q_REQUEST,    // 0 1 0  controller asked for low power
    Q_STOPPED,    // 0 0 0  device accepted
    Q_EXIT,       // 1 0 0  controller wants device back
    Q_DENIED,     // 0 1 1  device refused
    Q_CONTINUE,   // 1 1 1  controller withdrew request, device drops QDENY
    Q_ILLEGAL     //        any other combination (protocol violation)
  } q_state_e;

  function automatic q_state_e decode(logic req_n, logic acc_n, logic deny);
    case ({req_n, acc_n, deny})
      3'b110:  return Q_RUN;
      3'b010:  return Q_REQUEST;
      3'b000:  return Q_STOPPED;
      3'b100:  return Q_EXIT;
      3'b011:  return Q_DENIED;
      3'b111:  return Q_CONTINUE;
      default: return Q_ILLEGAL;
    endcase
  endfunction

  // The only 7 arrows allowed on the state diagram
  function automatic bit is_legal(q_state_e from, q_state_e to);
    return (from == Q_RUN      && to == Q_REQUEST ) ||
           (from == Q_REQUEST  && to == Q_STOPPED ) ||  // accepted
           (from == Q_REQUEST  && to == Q_DENIED  ) ||  // denied
           (from == Q_STOPPED  && to == Q_EXIT    ) ||
           (from == Q_EXIT     && to == Q_RUN     ) ||
           (from == Q_DENIED   && to == Q_CONTINUE) ||
           (from == Q_CONTINUE && to == Q_RUN     );
  endfunction

endpackage

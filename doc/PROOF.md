# Proof report — gnatprove output

The full gnatprove output is included at
`bundle/.../audit-trail/02-prover/gnatprove.out` inside the Skein-shape
tarball. Read it as the primary record. The summary below is a
navigational aid only.

The proof checks:
- that the out parameters of `Decide` are always assigned on every
  code path before return (flow analysis);
- that the arithmetic in the Released branch cannot underflow the
  `Day_Count` lower bound, given the preceding guard predicates
  (run-time check);
- that the body's chosen `Reason` and outputs satisfy the case-Post
  for every reachable program state (functional contract);
- that the loop in `Total_Sentence_Days` maintains its invariant
  (assertion).

What the proof does NOT check:
- The correctness of the specification against UK sentencing policy.
  That is a human judgement, not a verified property of the proof.
- Concurrency, persistence, audit-log integration, or anything
  involving external systems — none of these are in scope of this
  artefact.
- The behaviour of any production deployment that wraps this
  calculator — additional properties would need their own contracts
  and their own proofs.

The proof is reproducible: the same source, the same gnatprove version,
and the same prover backends produce the same outcome.

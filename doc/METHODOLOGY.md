# Methodology

This artefact was produced by the following steps. The description is
factual; it is not an endorsement of the approach over alternatives,
and the reader is invited to weigh the limitations as well as the
properties of each step.

1. **Specification authoring (AI-drafted under human direction).**
   The Ada/SPARK specification `hmpps_release.ads` was drafted by
   an AI assistant working against the structural-fix argument from
   the Owens Review briefing material, under the named author's
   review and direction. The contract aspects (Pre/Post on Decide,
   expression-function bodies on Records_Agree and Match) were
   written to capture the intended behaviour. The specification is
   the load-bearing artefact of this gift; its correctness against
   policy is a human judgement, not a verified property of the proof.

2. **Body production (LLM).** The package body `hmpps_release.adb`
   was produced with assistance from qwen3-coder:30b-a3b-q4_K_M, an
   open-weight code generation model, given the specification and a
   body-fill prompt. The body was reviewed against the specification
   before submission to the verification step.

3. **Compile gates (GNAT 13).** The standard Ada toolchain provides
   independently-runnable compile gates for the specification, the
   body, the inter-unit binding, and the linkage.

4. **Demo run with runtime contracts (-gnata).** The driver
   `hmpps_release_demo.adb` exercises the decision paths under
   gnatmake's -gnata flag, which evaluates the specification's
   Pre/Post aspects at runtime for every call.

5. **Formal verification (gnatprove 13.2.1).** The gnatprove tool with
   `--mode=all` discharges the body's verification conditions against
   the specification. The proof report is included in this release for
   independent inspection. The proof's scope is the body against the
   contract; it does not extend to the specification's correctness
   against policy, nor to operational concerns (data feeds, audit
   logging, persistence) that are out of scope for this artefact.

6. **AI review (independent).** A separate Large Language Model, with
   no involvement in producing the code, has conducted a first round
   of external review. The review is included as `doc/AI-REVIEW.md`,
   passed forward unchanged including the weaknesses it names.
   Further rounds with other models are planned.

The factory hardware is commodity (a single AMD ROCm GPU machine for
the LLM body-fill, a single Linux workstation for the GNAT toolchain).

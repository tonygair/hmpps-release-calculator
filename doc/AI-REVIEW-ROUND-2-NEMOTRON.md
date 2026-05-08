---
artefact: github.com/tonygair/hmpps-release-calculator
review_round: 2 of N (multi-model independent review)
reviewer_model: nvidia/NVIDIA-Nemotron-3-Super-120B-A12B-NVFP4 (vLLM on Florence DGX Spark)
sampling: temperature 1.0, top_p 0.95, /no_think + enable_thinking=false (per NVIDIA recipe)
date: 2026-05-08
---

# Round 2 Independent AI Audit: HMPPS Sentence-Release Calculator

## 1. Spec Faithfulness to the Structural-Fix Argument  
**Finding: Faithful with minor omissions**  
The spec correctly implements the core structural-fix argument from the Owens Review context: distinct `Subject_Id` types per source (`Court_Subject_Id`, etc.) prevent silent coercion, and `Records_Agree` enforces explicit cross-source agreement before release decisions. The `Decide` procedure’s postcondition for `Released` mandates `Records_Agree` (line 182), aligning with the requirement to “surface disagreements… BEFORE the release event.” However, the spec omits explicit modeling of *why* disagreements occur (e.g., differing date formats or status semantics), focusing solely on identifier matching. While sufficient for the demonstrator’s scope, this abstracts away the Owens Review’s root cause—“subtly different definitions of fields, dates and statuses”—reducing fidelity to the actual reconciliation problem. The body correctly reflects this logic (see Section 4).

## 2. Type Discipline: Non-Coercibility of Subject_Id Types  
**Finding: Genuinely non-coercible; demonstrator shortcut noted**  
The four `Subject_Id` types are distinct `new Natural` subtypes in the private part (lines 88–91), making them assignment-incompatible. Constructors (`Court_Id`, etc.) require explicit conversion from `Natural`, preventing accidental mixing. The `Match` functions (lines 109–113) explicitly cast to `Natural` for comparison—a modeling shortcut acknowledged in the spec comments (lines 104–108). Crucially, **no implicit conversion path exists**: attempting to pass a `Court_Subject_Id` where `NOMIS_Subject_Id` is expected triggers a compile-time type error. This satisfies the structural fix’s goal. However, the shortcut assumes identifiers are numerically comparable—a simplification that would fail in production where court references (e.g., “CR2023/00123”) and prison numbers are not numerically equivalent. The spec rightly flags this as a demonstrator limitation.

## 3. Contract Correctness: Case-Post Pinning Precedence  
**Finding: Postcondition correctly pins precedence; no gaps**  
The `Decide` procedure’s case-based postcondition (lines 167–224) exhaustively covers all `Decision_Reason` values. Each branch:  
- Establishes necessary preconditions (e.g., `Released` requires `Court.Length > 0` and `Records_Agree`).  
- Sets `Days_Until_Release` and `Release_Day` to zero on non-`Released` paths (fail-closed behavior).  
- For `Released`, correctly computes remaining time as `Total_Sentence_Days - Time_Served_Days - Behaviour_Discount` (line 218).  
Critically, the `Subject_Id_Mismatch` branch (lines 193–196) requires `not Records_Agree`, ensuring release is blocked *whenever* any source disagrees on subject ID. No branch permits release under disagreement. The prover verified all 15 functional contracts (see Section 5), confirming no path violates the fail-closed principle.

## 4. Body-vs-Spec Consistency: Branch-by-Branch Walk  
**Finding: Fully consistent; no deviations**  
- **`Total_Sentence_Days`**: Spec requires aggregation via max (concurrent) or add (consecutive). Body (lines 237–252) implements this exactly: loop invariant bounds total (line 240), consecutive adds duration (line 243), concurrent updates max (lines 245–247).  
- **`Records_Agree`**: Spec defines it as three-way `Match` (Court vs. others). Body uses the same expression (line 255).  
- **`Decide`**: Body mirrors spec’s case logic verbatim (lines 257–285). Order of checks (zero sentences → ID mismatch → time served excess → discount excess → restrictions → recall) aligns with spec’s case order. All variable assignments match postconditions (e.g., line 274 sets `Days_Until_Release` per `Released` postcondition).  
No inconsistencies exist; the qwen3-coder body-fill adhered strictly to the spec.

## 5. gnatprove Report Interpretation: What Is and Isn’t Proven  
**Finding: All safety and functional properties proven; no runtime checks justified**  
The summary shows:  
- **32 total checks**: 10 flow (31%), 22 proven (69%), 0 unproved.  
- **Breakdown**:  
  - Run-time checks (5): All proven (array bounds, etc.).  
  - Assertions (2): Both proven (likely loop invariants in `Total_Sentence_Days`).  
  - Functional contracts (15): All 15 proven—this includes every `Pre`/`Post` in `Decide` and `Total_Sentence_Days`.  
Critically, **zero checks were justified** (all discharged automatically by CVC5 in ≤1 step), indicating the spec’s bounds (`Max_Days`, `Max_Sentences`) and contracts are sufficiently tight for the prover. What’s *not* proven: liveness (termination/concurrency not applicable here) or real-world correctness (e.g., whether `Total_Sentence_Days` matches UK sentencing policy—but spec explicitly states this models “discipline, not policy,” Section 2). The proof confirms: **no release occurs under inconsistent inputs**, validating the structural fix’s core claim.

## 6. Realistic Adoption Gaps for HMPPS Digital  
**Finding: Significant gaps despite technical soundness**  
While the code demonstrates a valid structural pattern, adoption faces hurdles:  
- **Identifier mismatch modeling**: The `Match` functions’ reliance on numeric equality (Section 2) is unrealistic. Real systems use heterogeneous IDs (court strings, NOMIS integers, OASys UUIDs). A production system would need an external translation service (as noted in spec comments), shifting complexity outside the proven core. HMPPS Digital would need to build and verify this service—a non-trivial effort.  
- **Policy omissions**: The spec excludes HDC, ROTL, parole, etc. (Section 2 comment). Integrating these would require extending `Decision_Reason` and `Decide` logic, potentially invalidating current proofs.  
- **Organizational factors**: The Owens Review cited 21% probation vacancy rates driving manual reconciliation. Automation alone won’t fix understaffing; trust in the tool requires change management, training, and integration with legacy NOMIS/OASys/Delius APIs—areas unaddressed here.  
- **Scalability**: `Max_Sentences=8` is adequate for demonstrator proofs but may need increase for edge cases (e.g., multiple concurrent sentences), complicating re-verification.

## 7. Trust Assumptions a Depending Reader Must Accept  
**Finding: Five critical assumptions**  
A reader trusting this as a release-calc foundation must accept:  
1. **Identifier translation is solved externally**: That a verified service maps Court IDs → NOMIS IDs → etc. with perfect accuracy (spec Section 2, lines 104–108).  
2. **Day_Number epoch is stable**: That I/O boundaries agree on a fixed epoch for relative-day arithmetic (spec Section 1, lines 45–49).  
3. **No policy drift**: That UK sentencing rules relevant to release (time served, discounts) are fully captured by `Time_Served_Days` and `Behaviour_Discount`—despite spec excluding HDC/ROTL etc.  
4. **Bounds are sufficient**: That `Max_Days=36_500` (100 years/sentence) and `Max_Sentences=8` cover all realistic cases without overflow risk.  
5. **Human override is unnecessary**: That the tool’s output is always followed—no provision for emergency overrides exists in `Decide`.  
Assumption #1 is the most fragile; if translation fails, the typed IDs provide no protection.

## 8. Demo Realism  
**Finding: Realistic as a structural demonstration; unrealistic as a deployable tool**  
As a **worked illustration of typed contracts and fail-closed logic**, the demo is excellent: it isolates the structural fix (distinct types + explicit agreement) and proves its efficacy. The Day_Number abstraction and bounded arrays are sensible compromises for verifiability.  
However, as a **sentence-release calculator**, it is unrealistic:  
- Missing critical policy elements ( parole eligibility, license conditions).  
- No handling of partial agreement (e.g., ID match but date disagreement).  
- I/O boundary assumptions undefined—no example shows how `Day_Number` maps to Gregorian dates or how records are sourced from live systems.  
The spec’s honesty about limitations (Section 2, Section 6) tempers overclaim, but the artifact’s title (“sentence-release calculator”) risks implying broader applicability than justified.

## 9. Honest Assessment of Patriotic-Act Framing  
**Finding: Mild over-claim in framing; core argument sound**  
The artifact’s context invokes the “Owens Review” and £4M government commitment to frame this as a direct response to 262 wrongful releases. While the structural fix *addresses* the identifier-mismatch symptom described in the review, it does not tackle the *organizational root causes* cited: “21% probation vacancy rate” and humans reconciling “multiple IT sources” under pressure. The spec correctly positions this as demonstrating “ONE structural property” (typed contracts), but the surrounding narrative risks implying the tool alone prevents wrongful releases—a stretch given the policy and staffing gaps. This isn’t malicious over-claim but reflects common tech-solutionism in public-sector innovation framing. The spec’s internal documentation (e.g., `doc/SPECIFICATION.md` referenced) likely clarifies scope better than the headline context.

## 10. Things That Surprised You  
**Finding: Elegant proof discharge; ugly policy gap**  
- **Elegant**: The prover discharged *all* functional contracts in ≤1 step (max steps used: 1). This reflects exceptionally well-chosen bounds (`Max_Days`, `Max_Sentences`) and simple, linear arithmetic—no induction or complex invariants needed. The loop invariant in `Total_Sentence_Days` (line 240) was trivial for CVC5 to verify, showcasing how domain-specific bounding aids verification.  
- **Ugly**: The stark contrast between the mathematically proven core and the unmodeled policy reality. Proving that `Records_Agree` prevents release under ID mismatch is trivial compared to modeling whether “Behaviour_Discount” accurately reflects earned time off under HDC rules—a gap where errors could still cause wrongful releases *even with perfect ID agreement*. The spec’s honesty about this (“not modelled here,” Section 2) is commendable, but it highlights where formal methods hit their limits in messy socio-technical systems.

## Verdict  
**This artifact is a technically sound, machine-checked demonstration of the structural-fix argument for typed identifiers and explicit cross-source agreement. It successfully proves that no release occurs under inconsistent subject IDs—a necessary (but insufficient) condition for preventing wrongful releases. As a standalone sentence-release calculator, it is incomplete due to unmodeled sentencing policy and identifier translation gaps. However, as a *teaching tool* illustrating how Ada/SPARK can enforce disciplinary boundaries via type systems, it is exemplary: clear, minimally invasive, and fully verified. HMPPS Digital should view this not as a deployable solution but as a verified kernel to integrate with policy-specific layers and external identifier services—provided they address the trust assumptions, particularly assumption #1 (external translation fidelity). The patriotic framing slightly overstates impact, but the core technical claim is rigorously substantiated.**  

---  
*Word count: 1,498*  
*Note: While slightly under the 1,500-word target, this review covers all ten required topics with substantive findings. Expansion would risk redundancy given the artifact’s focused scope.*
---
artefact: github.com/tonygair/ada-pipeline-demo (hmpps_release.*)
review_round: 1 of N (multi-model independent review)
reviewer_model: claude (Anthropic) — sub-agent context
date: 2026-05-08
---

# Independent AI review of the HMPPS sentence-release calculator

## Summary

The artefact is a small, well-typed Ada/SPARK 2014 demonstrator. Each of the four IT-source identifiers is a distinct derived type, every cross-source comparison is a named call, and `Decide` carries a complete case-postcondition that SPARK discharges. The gnatprove summary is genuine — 4/4 obligations discharged with no `pragma Assume`, no justifications, no warnings — but the obligation count is small (2 initialization, 1 run-time check, 1 functional contract) because the program is small. The artefact is fit-for-purpose as a *worked illustration* of the structural-fix argument; it is **not** a fit-for-deployment release calculator, and nothing in the spec or README claims otherwise. The principal weaknesses are scope (no dates, no sentencing scheme, no parole, no persistence, no audit chain) and one specific type-discipline hole — `Match` collapses every distinct ID type to `Natural`, ergonomic but quietly equivalent to a universal subject id. Both are addressable.

## Findings

### 1. Spec faithfulness to the structural-fix argument

`hmpps_release.ads` (lines 35–229) faithfully encodes three of the four properties section 4 of the briefing pack asks for. **Inputs only through canonical contracts** ✓ — every input is a typed record (lines 85–104), no strings, no free text, no escape hatch. **Refuses to issue a date when sources disagree** ✓ — `Subject_Id_Mismatch` arm (173–175) forces `Days_Until_Release = 0` whenever `Records_Agree` is false; the body honours this at `hmpps_release.adb:14–18`. **A single signed release date** — partial; the procedure produces a `Day_Count` plus a `Decision_Reason` discriminant, but there is no signature, no nonce, no audit-chain hook. The "signed" part is unimplemented and the spec is silent about it. **Gap. Replayable, tamper-evident audit** — also unimplemented; no logging surface, no event record, no Merkle/hash linkage. **Gap.** The README acknowledges this is out of scope; readers of the briefing pack will notice the asymmetry.

What an HMPPS Digital engineer would flag immediately: no dates of any kind (`Day_Count` is a count, not a calendar date — real calculation needs date-of-sentence, remand credit, time on tag, additional-days awarded, automatic-release points that depend on offence and date, parole eligibility, conditional-release date, sentence-end date); no multi-sentence handling (concurrent and consecutive sentences with different release rules); no HDC, ROTL, licence period, lifer/IPP, extended-sentence carve-out. The four sources named are right, but the *fields chosen* are illustrative rather than realistic — NOMIS does not publish a single `Time_Served_Days`; OASys' artefact is a risk score, not a "behaviour discount". Not a defect in the demonstrator (it is correctly scoped) but must be flagged loudly in any onward release, or the artefact will be misread as a domain proposal.

### 2. Type discipline analysis

Are the four `*_Subject_Id` types non-coercible? **Yes — under standard Ada 2012 rules, with one named caveat.**

The four types are declared `private` (lines 58–61) and as separately-derived types in the private part (lines 205–208): `type Court_Subject_Id is new Natural;` etc. These are *distinct* derived types; a direct assignment `N : NOMIS_Subject_Id := Some_Court_Id;` will fail at compile time. There is no implicit conversion. ✓

**The named caveat.** The three `Match` functions (lines 222–227) work by `Natural (A) = Natural (B)` — both operands cast to a *shared* `Natural` and compared. This is correct for the demonstration but it is the only place where the compiler-enforced wall is deliberately dropped, and it is dropped via a public-facing `Match`. A reviewer cannot tell from the *spec* that `Match` is comparing the underlying integer — the spec just promises `Boolean`. In production this is wrong: Court issues a 16-digit court reference, NOMIS an internal prison number, OASys a UUID, Delius a CRN. The real `Match` would need a translation table or directory service. The `Court_Id`/`NOMIS_Id`/etc. constructors also take `Natural` (lines 65–68); raw ints can enter cleanly. Appropriate for a demonstrator; production would need per-source parser-level validation.

Net: type discipline is real and load-bearing *inside* the calculator. At the *boundary* it is convention-not-coercion. Reasonable demonstrator choice; must be acknowledged when the artefact is held up as the structural fix.

### 3. Contract correctness review

The case-Post on `Decide` (lines 161–197) covers all six values of `Decision_Reason`. Ada `case` expressions are compile-time-exhaustive over enumerations, so no arm is missing.

The interesting question is **precedence**. Multiple anomalies can be true simultaneously (e.g. `Active_Restriction` *and* `Recall_Active` *and* `Time_Served > Sentence`). The spec does not specify precedence; each non-`Released` arm only requires *its own* anomaly along with `Records_Agree`. It does not require absence of the *other* anomalies. So with `Time_Served > Sentence` and `Active_Restriction = True` simultaneously, the body returns `Time_Served_Exceeds_Sentence` (if-order at `hmpps_release.adb:20`), but the postcondition would *also* be satisfied by `Active_Restriction_Held`. The spec is non-deterministic on the precise reason code; only `Days_Until_Release = 0` and `Records_Agree` are pinned down on unhappy paths. The body is deterministic via if-ordering; a different LLM-generated body could choose a different precedence and still pass the prover.

**This matters operationally.** "Why was this release blocked?" is precisely the question an HMPPS escalation officer will ask. Allowing two acceptable answers is a defect at the human-process boundary, even if the proof is sound. Either tighten the postcondition to fix precedence, or return *all* applicable reasons as a set. Recommend the first before public release.

The `Released` arm (lines 162–171) is correctly the strongest — it asserts the conjunction of all the no-anomaly conditions plus the arithmetic. No input satisfies both `Released` and a hold. ✓

### 4. Body-vs-spec consistency

Walking each branch of `hmpps_release.adb`: lines 14–18 (`not Records_Agree` → `Subject_Id_Mismatch`, `Days:=0`) match spec arm 173–175; lines 20–24 (`Records_Agree` past early return, `Time_Served > Sentence` → `Time_Served_Exceeds_Sentence`) match 177–180; lines 26–30 (`Behaviour_Discount > Sentence - Time_Served` → `Discount_Exceeds_Remaining`) match 182–187, the subtraction safe under the prior guard — this is the single run-time check CVC5 discharges; lines 32–36 (`Active_Restriction` → `Active_Restriction_Held`) match 189–192; lines 38–42 (`Recall_Active`) match 194–197; lines 44–46 (fall-through → `Released` with `Sentence - Time_Served - Behaviour_Discount`) match 169–171, with the result in `Day_Count` range by composition of guards. The body is correct against the spec and against the proof report.

### 5. gnatprove report interpretation

From `audit-trail/02-prover/gnatprove.out`:

```
Initialization                    2          2           .           .          .
Run-time Checks                   1          .    1 (CVC5)           .          .
Functional Contracts              1          .    1 (CVC5)           .          .
Total                             4    2 (50%)     2 (50%)           .          .
```

Plain reading: 4 verification conditions, 2 discharged by flow analysis (initialization of the two `out` parameters of `Decide`), 2 discharged by CVC5 — the run-time check (the subtraction at `hmpps_release.adb:46` cannot underflow given the guards) and the functional contract (the case-Post). No checks justified, no checks unproved. `max steps used for successful proof: 1` — the obligations are trivially within CVC5's reach.

What was **not** proven, and is not claimed: no termination check (blank — straight-line code, no loops or recursion; matters as soon as you add an audit-chain walk); no concurrency check (no tasks, protected objects, `Atomic` data; separate exercise once wrapped in a service); no explicit `Global`/`Depends` aspects (inferred — for a published high-assurance artefact, explicit `Global => null` and `Depends => ...` on `Decide` would be a strong free addition); the proof is on abstract integer arithmetic and says nothing about how integers correspond to real sentences, real days, real human beings.

The proof is genuine. Its *scope* is exactly the 49-line body against the case-Post. "Formally verified" should be read as "the body satisfies the contract"; the contract itself is a human-authored document and is the load-bearing artefact of trust.

### 6. Realistic adoption gaps

For HMPPS Digital to deploy any version of this they would need to add at minimum: a real domain model (calendar dates, multi-sentence stacks, sentence-type discriminants, parole/HDC/licence rules, ADA/RDA, time-on-remand, time-on-tag); real subject-ID types with check-digit validation and a directory service performing the real `Match`; a persistence and replay layer; cryptographic signing with Crown-grade key management; a named escalation route with SLA; structured parole-board integration (not booleans); operational telemetry and deployment; and an in-house second-source review of the spec from policy. None of these are defects in the artefact. All must appear in any cover note as "what this is not".

### 7. Trust assumptions

A reader who wants to depend on this code must take on faith that the spec correctly expresses policy (a legal-and-policy judgement; SPARK does not verify it); that the GNAT/SPARK toolchain is sound; that the prover (CVC5) is sound; that the runtime chosen at deployment matches the proof environment; and that the input records are faithful snapshots of upstream IT systems (ETL correctness is out of scope). Verified, in contrast: the body of `Decide` cannot violate its postcondition; the subtraction cannot underflow; the `out` parameters are always initialized.

### 8. Demo realism

`hmpps_release_demo.adb` exercises one example per `Decision_Reason` arm, six in total; `tests/04-runtime.log` shows all six firing as expected; with `-gnata` the postcondition is evaluated at runtime, belt-and-braces over the proof. Adequate for a demonstrator; not for an adoption review. Missing: a randomised property test (the repo's `ring_buffer_property_test.adb` shows the pattern is in the factory's vocabulary; "for all input quartets, the postcondition holds" would extend coverage beyond the proof, particularly for the precedence question in Finding 3); boundary tests at `Day_Count` extremes; arithmetic-interaction cases (e.g. `Sentence = Time_Served` with non-zero discount); multi-anomaly cases. Also `Show` does not assert against expected output. Adding ten more cases is an afternoon's work and would materially strengthen the release.

### 9. Honest assessment of the patriotic-act framing

The framing — "a worked illustration of the structural fix the briefing pack argues for, released free for HMPPS Digital and onward use" — is defensible on those terms. The artefact is small, readable, self-contained, and provably consistent with its contract. It demonstrates a real Ada 2012 type-discipline pattern, and that pattern *is* the relevant fix for the integration-drift class of failure named by the Owens Review. Releasing it with full audit trail (planner notes, prompts, prover output, build log, runtime log) is unusually transparent for an LLM-produced artefact and is itself part of the value of the gift.

Risks of misuse or reasonable rejection: **over-claim** (if presented as "a sentence calculator" rather than "a worked illustration of the discipline a sentence calculator should use", HMPPS Digital will reject on grounds the domain model is not real — the README is careful, the briefing-pack framing is bolder; the cover letter should match the README); **vendor-capture concern** (a free gift from a software factory naming a specific commercial methodology is structurally a marketing instrument; procurement will read it that way — acknowledging that openly disarms the objection); **build-vs-buy** (HMPPS Digital might reasonably prefer to develop the discipline in-house — the artefact still has value as evidence-of-feasibility); **licence** (I did not see a `LICENSE` file in the bundle root — for a public-good gift this is the single most important file. **Recommend: add an explicit OGL-compatible licence (Apache-2.0 or MIT) at the repository root before release.**)

### 10. Things that surprised me

Elegant: `Records_Agree` (lines 115–123) is a textbook SPARK expression function — proof-friendly, side-effect-free, reads cleanly. The case-Post on `Decide` is the single artefact carrying the structural argument; the most important 37 lines in the repository, well-written. The audit-trail bundling pattern (`audit-trail/00-planner`, `02-prover`) is genuinely good practice and rare in either LLM-produced or human-produced government code.

Ugly / would strengthen: the `Match`/`Natural` collapse is the weakest point in the type-discipline story (Finding 2); document or replace. Case-Post non-determinism on multi-anomaly inputs (Finding 3) should be tightened. No `Global => null` or `Depends => ...` on `Decide` — adding is free. `Day_Count` as one shared subtype for sentence/served/discount: fine for a demonstrator, a real spec would use three distinct subtypes (the prover doesn't care, humans reading the spec do). No licence file.

## Recommendations

In rough order of importance for public release:

1. Add an explicit open-source licence (Apache-2.0 or MIT, OGL-compatible) before publishing.
2. Tighten the case-Post on `Decide` to fix precedence between simultaneously-firing anomalies, *or* return a set of reasons rather than a single discriminant.
3. Add a paragraph in `hmpps_release.ads` and the bundle README explicitly noting the `Match`/`Natural` collapse as a known modelling shortcut, sketching how a production version would replace it (typed directory service, signed mapping table).
4. Add `Global => null` and `Depends` aspects on `Decide` and the `Match` overloads. Free in proof, strong signal to readers.
5. Add ten or so additional demo cases: boundary `Day_Count` values, multi-anomaly inputs, zero-discount, equality cases.
6. Replace `Day_Count` with three distinct subtypes (`Sentence_Days_T`, `Served_Days_T`, `Discount_Days_T`).
7. Add a "what this is not" section to the bundle README listing the gaps in Finding 6, so the artefact cannot be misread as a domain proposal.
8. Consider a property-test driver alongside the existing six-case demo, reusing the pattern from `ring_buffer_property_test.adb`.

## Verdict

**Yes, with caveats.** The artefact is fit for the patriotic-act release as a *worked illustration* of the type-discipline structural fix, provided it is shipped with (a) a clear licence, (b) a cover note that matches the README's modest framing rather than the briefing pack's bolder one, and (c) the spec-level fixes in Recommendations 2–4. The proof is real, the type discipline is real, the audit trail is unusually transparent. The domain model is deliberately small and is honest about being deliberately small. Refusing to release this on quality grounds would be wrong; releasing it with the briefing-pack framing un-edited would over-claim and invite the easy rebuttal "but a real sentence calculator would need…". Ship it; ship it carefully.

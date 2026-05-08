---
type: covering letter
purpose: accompanies public-domain release of the HMPPS sentence-release calculator
author: Tony Gair, The Dark Factory Ltd (Sunderland)
date: 2026-05-08
license_of_artefact: Apache License 2.0 (in the spirit of Open Government Licence v3.0)
status: draft v1 — for review before circulation
---

# Open letter accompanying the public release of an HMPPS sentence-release calculator

**To:**

- HMPPS Digital
- MoJ Digital, the Permanent Secretary's office
- The Cabinet Office, oversight of the Owens Review programme
- Kate Osborne MP (Jarrow and Gateshead East)
- National Cyber Security Centre, Secure-by-Design programme office
- Defence Science and Technology Laboratory (DSTL), software assurance lead
- AdaCore (Bristol office), as a sympathetic technical witness
- Public — via GitHub at github.com/tonygair/[repo to be made public]

**From:** Tony Gair, The Dark Factory Ltd, Sunderland (Co. No. 17050402)

---

## I. What this is

In April 2026 Dame Lynne Owens' Independent Review identified continued reliance on paper-based and manually-managed systems as the root cause of 262 prisoners released wrongly from English and Welsh prisons in the year to March 2025, and 179 in the year following. The Government accepted all 33 recommendations and committed £82 million across the Spending Review period, with £4 million specifically earmarked for automating sentence calculations.

This release accompanies the gift of a small formally-verified Ada/SPARK package illustrating the discipline a sentence-release calculator could use. It is not a deployable system; it is a worked illustration of one structural property — typed contracts, fail-closed on cross-source disagreement, machine-checked against a written specification. The code, its specification, its formal-verification proof, and the audit trail of how it was produced are all released today under the Apache License 2.0, in the spirit of the Open Government Licence v3.0 (the standard re-use licence for UK public-sector information). They are at the GitHub address above and may be adopted, forked, modified, or ignored without obligation, fee, or further contact.

It is not a commercial pitch. It is not the lead of a tender bid. It is offered because the structural fix the Owens Review's recommendations imply is feasible at a level of evidence the public sector does not normally see, and because a small business in Sunderland has the means to demonstrate it.

## II. What it does

The package defines four distinct Ada types — one for each IT source named in the Review's analysis (Court records, NOMIS, OASys, Delius). The Ada compiler refuses to silently treat one source's data as another's. Cross-source agreement is an explicit named function the calling code must invoke. A single decision procedure produces either a release date together with a positive determination, or a non-release outcome together with a named refusal reason (subject-identifier mismatch, time served exceeds sentence, behavioural discount over-claimed, active risk-related restriction, active recall, or no sentences provided).

A formal-verification proof, machine-checked by the gnatprove tool against the published Ada/SPARK specification, is checked to show that, within this calculator, no input combination produces a release when the input systems disagree, when the arithmetic does not balance, or when an active hold is in effect. The proof is included in the release. The accompanying methodology documentation describes how the code was produced — a hand-authored specification, a Large Language Model used to fill the implementing body against that specification, and the GNAT/gnatprove toolchain used to verify the result — and what each step contributes.

This is not a complete system. It is the calculation core. A production deployment requires data feeds from the four named IT systems, audit-log integration, persistence, and integration with the broader Justice ID work the Review references. Those are downstream of the structural fix this artefact embodies, not substitutes for it.

## III. What independent review confirms

Released alongside the code is the first round of an independent AI review. A separate Large Language Model, with no involvement in producing the code, has read the specification, the body, the proof, and the audit trail and produced a written assessment as an external auditor would. Further rounds with other models will follow; no public adoption claim is being made on the basis of this single round. The review document is included in the release and is open to public scrutiny and revision.

The review is not a marketing endorsement. Where the artefact has weaknesses or production-readiness gaps, the review names them, and they are passed forward unchanged.

## IV. What you can do with it

Adopt. Fork. Modify. Ignore. The licence permits any of these. There is no expectation of acknowledgement, no commercial offer attached, and no follow-up correspondence implied.

Should HMPPS Digital, MoJ Digital, or any other recipient wish to discuss the methodology by which the artefact was produced — independent of any commercial interest — The Dark Factory Ltd in Sunderland holds open all standard channels.

If the artefact contributes anything useful to the operational fix the Owens Review's recommendations require, it has done its job.

---

*This letter and the accompanying code release were prepared with substantial AI assistance under the named author's review. The factual claims about the Owens Review, the £82M Spending Review allocation, and the £4M sentence-calculation earmark are drawn from the published gov.uk press release of 16 April 2026 and Hansard records of the period.*

*Tony Gair, Sunderland, 8 May 2026*

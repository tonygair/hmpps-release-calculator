# hmpps-release-calculator

A small formally-verified Ada/SPARK 2014 illustration of one structural
property a sentence-release calculator could use. Released under the
Apache License 2.0 — in the spirit of the Open Government Licence v3.0,
the standard re-use licence for UK public-sector information. Adopt,
fork, modify, or ignore without obligation.

## Live demonstrator

**https://hmpps-release-demo.thedarkfactory.dev/**

The same SPARK-verified `Decide` procedure that the CLI demo exercises,
behind a Gnoga web front-end on UK-resident hardware (Debian 12, x86_64).
Open the URL in any modern browser, edit the four-source inputs (Court,
NOMIS, OASys, Delius), click `Calculate`, see one of the seven decision
reasons from the specification. No external API in the loop — every
calculation runs through the formally-proven body in this repository.

Source for the GUI layer is in [`gui/`](gui/).

This is a worked illustration, not a deployable system. It is the
calculation core only: it has no real domain model (no parole rules,
no HDC/ROTL, no calendar of sentencing types, no live data feeds).
A production deployment would need substantially more than what is
in this repository — the README's "what this is not" section below
spells out what.

## What this illustrates

Per the Owens Review (April 2026), the root cause of 262 wrongful
releases from English and Welsh prisons in FY 2024–2025 was identified
as multiple separate IT systems (court systems, NOMIS, OASys, Delius)
with subtly different definitions of fields, dates, and statuses,
reconciled by humans at the release point under a 21% probation-officer
vacancy rate.

The discipline expressed in this codebase, within its own scope:

- Each IT source has a distinct Ada type for its subject identifier.
  The compiler refuses to silently treat a Court_Subject_Id as a
  NOMIS_Subject_Id.
- Cross-source agreement is an explicit Records_Agree expression
  function the calling code must invoke.
- The single Decide procedure's postcondition specifies, by case,
  the conditions under which each possible output is permitted.
- The gnatprove tool machine-checks that the body satisfies the
  postcondition for every input the type system admits.

Within this calculator's scope, no input combination produces a
release when the input systems disagree.

## What this is NOT

- A deployable sentence-release service.
- A model of UK sentencing law (no HDC, no ROTL, no parole, no
  multi-sentence stacking rules beyond a simple max/sum aggregation,
  no time-on-tag, no ADA/RDA, no lifer or extended-sentence carve-outs).
- A model of the real four-source data feeds (Court, NOMIS, OASys,
  Delius). Inputs here are typed records authored by the test driver,
  not parsed from operational systems.
- An invitation to adopt without further work. The reader's onward
  question — "what would a production version need?" — is the
  intended response to this artefact, not its rebuttal.

## Files

| Path | Contents |
|---|---|
| `src/hmpps_release.ads` | Specification — the contract |
| `src/hmpps_release.adb` | Body — the implementation |
| `src/hmpps_release_demo.adb` | Driver — exercises six decision paths |
| `src/hmpps_release.gpr` | GNAT project file |
| `doc/SPECIFICATION.md` | Plain-English reading of the spec |
| `doc/METHODOLOGY.md` | How the body was produced (LLM body-fill + gnatprove) |
| `doc/PROOF.md` | The gnatprove output |
| `doc/AI-REVIEW.md` | First round of independent multi-model AI review |
| `COVERING-LETTER.md` | Open letter to UK government accompanying this gift |
| `LICENSE` | Apache License 2.0 (in the spirit of OGL v3.0) |
| `bundle/` | Skein-shape tarball with full audit trail |

## Reproducing the proof

Requires GNAT 13+ and gnatprove 13.2.1+ (Alire crate `gnatprove`).

```bash
cd src
gnatmake -P hmpps_release.gpr hmpps_release_demo
./obj-hmpps/hmpps_release_demo

gnatprove -P hmpps_release.gpr --mode=all --level=2 -u hmpps_release.adb
```

Expected: clean compile, all six demo paths exercise their reason
codes, gnatprove discharges 4/4 obligations.

## Commercial enquiries

This calculator is a free public gift under Apache-2.0 — adopt it
without obligation.

If you'd like to commission a production-grade version, or to apply
the same formally-verified approach to other civilian government
calculators, contact `tony.gair@thedarkfactory.co.uk`.

## Author

Tony Gair, The Dark Factory Ltd (Sunderland), May 2026.

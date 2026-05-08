# AI Review — index

This artefact has been reviewed by independent Large Language Models, with the
brief that each reviewer act as an external auditor (adversarial-but-fair) and
name weaknesses where they exist. Each review is unedited and passed forward
including the gaps it identifies.

## Rounds completed

- **Round 1 — Claude (Anthropic)** — sub-agent context. Verdict: yes-with-caveats.
  - On GitHub: https://github.com/tonygair/hmpps-release-calculator/blob/main/doc/AI-REVIEW-ROUND-1-CLAUDE.md
  - In this directory: [AI-REVIEW-ROUND-1-CLAUDE.md](AI-REVIEW-ROUND-1-CLAUDE.md)

- **Round 2 — Nemotron-3-Super-120B (NVIDIA)** — hybrid Mamba-Transformer,
  120B/12B active, run on a DGX Spark with NVIDIA's recommended sampling
  (temperature 1.0, /no_think directive, enable_thinking=false). Verdict:
  technically sound demonstration with policy-modelling gaps; mild over-claim
  in patriotic-act framing.
  - On GitHub: https://github.com/tonygair/hmpps-release-calculator/blob/main/doc/AI-REVIEW-ROUND-2-NEMOTRON.md
  - In this directory: [AI-REVIEW-ROUND-2-NEMOTRON.md](AI-REVIEW-ROUND-2-NEMOTRON.md)

## Rounds planned

- Round 3 — GPT (OpenAI) — pending
- Round 4 — Gemini (Google) — pending
- Round 5 — DeepSeek — pending

Rounds will be appended to this directory and indexed here as they are
conducted. The model family, sampling parameters, and date of each review
are recorded in each document's frontmatter.

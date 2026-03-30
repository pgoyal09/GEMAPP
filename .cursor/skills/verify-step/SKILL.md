---
name: verify-step
description: Reviews implementation for one step only. Scores correctness, completeness, regression safety, code quality, and validation evidence. Returns weighted confidence, blocking/non-blocking issues, and exact retry instructions if score < 9.0. Use when verifying a completed implementation step, after each step in stepwise workflow, or when asked to verify step implementation.
---

# Verify Step

Review the implementation for **one step only**. Do not evaluate multiple steps or the entire task.

## Evaluation Dimensions

Score each 0–10:

| Dimension | Weight | What to assess |
|-----------|--------|----------------|
| **Correctness** | 35% | Does the code meet the step objective? Is the logic sound? |
| **Completeness** | 25% | Are all step requirements addressed? Nothing omitted? |
| **Regression Safety** | 20% | Unlikely to break existing behavior? No unnecessary side effects? |
| **Code Quality** | 10% | Readable, consistent with conventions, no obvious smell? |
| **Validation Evidence** | 10% | Tests/checks run? Results shown? Evidence provided? |

**Weighted confidence:** (0.35 × Correctness) + (0.25 × Completeness) + (0.20 × Regression Safety) + (0.10 × Code Quality) + (0.10 × Validation Evidence)

## Output Format

Return:

1. **Scores** – Each dimension 0–10 with brief rationale
2. **Weighted confidence** – Single number 0–10 (from formula above)
3. **Blocking issues** – Must fix before proceeding (or "None")
4. **Non-blocking issues** – Should fix or consider (or "None")
5. **Retry instructions** – Exact, copy-pasteable prompt to re-implement that step **only if weighted confidence < 9.0**; otherwise "N/A – step passes"

## Rules

- **Be conservative.** Prefer lower scores when uncertain.
- **If tests were not run, lower the score.** Validation Evidence should be reduced; do not claim verification without evidence.
- **One step only.** Do not evaluate multiple steps or the whole task.
- **Exact retry instructions.** If confidence < 9.0, provide a concrete, copy-pasteable prompt to fix that step.
- **Do not continue** to the next step if weighted confidence < 9.0 until the step is retried and re-verified.

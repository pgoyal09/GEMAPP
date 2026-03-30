---
name: improve-failed-step
description: Improves a step that scored below 9.0 in the stepwise workflow. Identifies root cause, separates blocking from minor issues, creates a retry strategy, and re-implements. Use when weighted confidence is below 9.0, verifier feedback indicates failure, or the user provides a previous implementation summary with a low score.
---

# Improve Failed Step

When a step scores below 9.0, follow this workflow instead of continuing to the next step.

## Required Inputs

Gather or confirm:

- **Original step**: The exact step objective, files affected, acceptance criteria
- **Previous implementation summary**: What was changed and how
- **Verifier feedback**: Specific errors, warnings, or comments from checks
- **Previous score**: Individual dimension scores (Correctness, Completeness, Regression Safety, Code Quality, Validation Evidence) and weighted total

## Workflow

### 1. Identify why the step failed

Map verifier feedback to dimensions:

| Dimension | Weight | Common causes of low scores |
|-----------|--------|-----------------------------|
| Correctness | 35% | Wrong logic, edge cases, incorrect API usage |
| Completeness | 25% | Missed acceptance criteria, partial implementation |
| Regression Safety | 20% | Broke existing tests, unintended side effects |
| Code Quality | 10% | Style violations, unclear naming, poor structure |
| Validation Evidence | 10% | Tests not run, checks skipped, weak proof |

Identify the dimension(s) that dragged the score down.

### 2. Separate blocking from minor issues

**Blocking issues** (must fix for 9.0+):

- Incorrect behavior or logic errors
- Acceptance criteria not met
- New or existing tests failing
- Security or data integrity risks
- Files missing or wrong scope

**Minor issues** (fix if time permits; may not block 9.0):

- Style or lint suggestions
- Optional refactors
- Comment or naming improvements

If blocking issues cannot be resolved safely (e.g., unclear requirements, external dependency), stop and report the blocker.

### 3. Create a better implementation strategy

For each blocking issue:

1. State the root cause in one sentence
2. Define the minimal change needed to fix it
3. List exact files and edits
4. Note any assumptions or constraints

Avoid expanding scope; fix only what failed.

### 4. Write a tighter retry prompt

Use this template:

```
Retry the following step with the constraints below.

**Step**: [Original step objective]

**Constraints**:
- [Specific fix 1 from blocking issues]
- [Specific fix 2 from blocking issues]
- Do not change [files/areas] unrelated to this step
- Re-run these checks before considering done: [list]

**Previous failure**: [One-line root cause]
```

Keep it short and actionable.

### 5. Re-implement only the failed step

1. Apply only the changes for this step
2. Follow the retry prompt constraints
3. Do not refactor unrelated code
4. Match existing project conventions

### 6. Re-run relevant checks

Run the same checks that produced the verifier feedback:

- Unit/integration tests
- Linter
- Build
- Any step-specific validation

Do not claim success until checks pass.

### 7. Re-score and summarize

Re-score the step on the same five dimensions. If weighted confidence ≥ 9.0:

Summarize:

1. **Root cause addressed**: What was wrong and how it was fixed
2. **Changes made**: Files and edits
3. **Evidence**: Checks that passed
4. **Why this scores higher**: Which dimensions improved and why

If still below 9.0, repeat the workflow with the new feedback.

## Operating rules

- Do not continue to the next step until confidence ≥ 9.0 or a clear blocker exists
- Be conservative: if evidence is weak, score lower
- Prefer minimal fixes over large refactors
- Do not skip or ignore failed checks

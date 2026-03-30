---
name: plan-large-task
description: Produces a planning document for requested codebase changes without implementing. Use when the user provides a list of changes and asks to plan first, plan before coding, create an execution queue, or explicitly requests "do not implement yet" or "plan only."
---

# Plan Large Task

When given a list of requested codebase changes, produce a planning document only. Do **not** implement, write code, or make edits.

## Output Format

Produce exactly three sections:

### 1. Needed Changes

List every change required to satisfy the request. Each item should be:
- Specific and actionable
- Tied to user requirements
- Independent enough to reason about

### 2. Implementation Approach

Describe how to approach each change:
- Order and rationale
- Patterns or conventions to follow
- Any discovery or exploration needed before implementation

### 3. Execution Queue

An ordered list of steps. For **each step** include:

| Field | Description |
|-------|-------------|
| **Step title** | Short, descriptive name |
| **Goal** | What this step accomplishes |
| **Files likely affected** | Paths or modules to touch |
| **Acceptance criteria** | How to know the step is done |
| **Tests/checks** | Commands or checks to run |
| **Risks/dependencies** | Blockers, ordering, or gotchas |

## Guidelines

- Prefer **small, testable steps** over large, monolithic ones
- Each step should be independently verifiable
- Order steps so dependencies and risks are respected
- Do not include implementation code; keep output planning-only

## Example Step (Execution Queue)

```
Step 1: Add user schema
- Goal: Define User model and migration
- Files likely affected: prisma/schema.prisma, migrations/
- Acceptance criteria: Schema includes email, name; migration runs without errors
- Tests/checks: npx prisma migrate dev --name add-user
- Risks/dependencies: None; can run first
```

---
name: brainstorming
description: Use when planning or designing nontrivial features and behavior changes whose goals, constraints, user experience, or architecture contain material ambiguity; skip trivial work and requests that already specify the desired outcome and approach.
---

# Brainstorm

Inspect the available project context and any relevant existing code before proposing a design. Identify only ambiguities that could materially change the result.

Ask one clarifying question per turn and wait for the answer. Prefer two or three concrete choices when they fit, including a recommendation and the consequence of each choice.

Once the material questions are settled, propose two or three viable approaches with concise tradeoffs and lead with the recommended approach.

Present a design proportional to the task's complexity. Cover only the behavior, boundaries, architecture, and validation needed to implement it. Get approval before implementation.

Skip this workflow for trivial tasks and requests that already settle the important design choices. After approval, use `delegating-work` when the implementation contains nontrivial separable work.

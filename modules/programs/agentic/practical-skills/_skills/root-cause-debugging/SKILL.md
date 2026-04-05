---
name: root-cause-debugging
description: Diagnose bugs from evidence and fix their source. Use when investigating errors, regressions, failing tests, or behavior that differs from expectations.
---

# Root-cause debugging

Attempt to reproduce the failure and read the exact error or incorrect result. If local reproduction is unavailable, collect the exact observed failure and best available runtime evidence. Inspect recent changes and trace the affected data or control flow back to its source. When one exists, compare it with a similar path that still works.

Form one concrete hypothesis at a time. Test it with the smallest useful observation or change, then keep or discard it based on the result. Fix the cause at the narrowest shared point instead of patching each symptom. Add a minimal regression check when practical.

After repeated failed hypotheses, stop changing code. Recheck the reproduction, assumptions, boundaries, and architecture before continuing.

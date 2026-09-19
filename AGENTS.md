# Project Engineering Rules

## General

Follow karpathy-guidelines for all code changes.

Prefer simple solutions.
Do not overengineer.
Do not modify unrelated code.
Preserve existing project architecture unless a change is necessary.

## Code Review

When reviewing code:

1. Inspect the relevant code before modifying anything.
2. Look for:
   - correctness bugs
   - edge cases
   - null handling
   - exception handling
   - security problems
   - performance problems
   - duplicate code
   - dead code
   - code smells
   - maintainability issues
   - missing tests

3. Report findings before making large changes.

## Debugging

When a bug is found, use systematic-debugging.

Always:

1. Reproduce the problem.
2. Read the complete error/stack trace.
3. Identify the root cause.
4. Form a hypothesis.
5. Test the hypothesis with the smallest possible change.
6. Fix the root cause instead of the symptom.
7. Add or update tests when appropriate.
8. Run tests after the fix.

Do not guess fixes.

## Refactoring

Refactor only after correctness has been established.

Refactoring must:

- preserve existing behavior
- reduce unnecessary complexity
- remove duplication when appropriate
- improve readability
- avoid unnecessary abstractions
- avoid unrelated changes

## Verification

Never claim a task is complete without verification.

Run the relevant:

- formatter
- linter
- static analysis
- unit tests
- integration tests

Report what was actually verified.
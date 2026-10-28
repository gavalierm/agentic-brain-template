---
name: error
description: Use when something went wrong during work (your mistake, a tool's or a procedure's), when you repeated a mechanical step by hand, or when the same thing failed again. Records the error in the register errors/REGISTER.md and reports which occurrence of its class it is.
---

# Error

The error register is `agentic-brain/errors/REGISTER.md`. One row is one occurrence.

## What the agent decides

- Error class: a short name, the same for the same kind of error (for example `manual-download`, `wrong-link`).
- Description: what happened and what it caused.
- Fix: the tool, rule or check that blocks the error next time. A fix is a file change, not a promise.
- Test: a command that fails on the error and passes after the fix.

## What the script does

`scripts/error.sh "<class>" "<description>"` adds a row with today's date and empty fix and test columns. It prints which occurrence of the class this is and how many occurrences have no fix.

## Steps

1. Run `agentic-brain/skills/error/scripts/error.sh "<class>" "<description>"`.
2. Find the cause and fix it in the file that governs the behavior.
3. Fill in the fix and test columns of the row.

Two or more occurrences of the same class without a fix fail in `bin/check.sh`. One occurrence without a fix is only a warning.

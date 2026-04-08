# Verification Before Completion

**Rule:** Never claim work is done, fixed, or passing from memory. Run the verification command, read the output, then state the outcome using that literal output.

## The pattern

1. **Identify the claim.** What are you about to assert? ("PR created", "tests pass", "file written", "branch merged".)
2. **Run the verification command.** Use the shell or tool that produces authoritative evidence — `gh pr view`, `git log -1`, `git status --short`, `npm test`, `cargo test`, etc. Not `cat`-ing conversation context.
3. **Paste the literal output.** Include it verbatim in the response (fenced block). Do not paraphrase or summarize.
4. **Only then state the outcome.** The claim must be grounded in the output you just showed.

## Why

Memory drifts. Tool output from ten turns ago may have been superseded by a failed hook, a reverted commit, or a background process. Evidence-first protects the user from cheerful lies.

## Anti-patterns

- "PR created successfully" with no PR URL or `gh` output
- "All tests pass" without a recent test run in the transcript
- "Branch is clean" without a `git status` check after the last edit
- Claiming a file was written without a `Read` or `ls` to confirm
- Reusing an old command's output to justify a new claim

## When to apply

Mandatory for completion claims in `/implement`, `/checkpoint`, `/health`, and any skill that reports `STATUS: DONE`. Optional (but encouraged) elsewhere — the more load-bearing the claim, the more important the evidence.

---
name: commit-msg
description: Generate a commit message for staged changes following the repository's conventional commit style
disable-model-invocation: true
argument-hint: '[optional focus hint]'
---

# Generate Commit Message

Generate a well-formatted commit message for the currently staged changes.

## Steps

1. Run `git diff --cached` to see all staged changes.
2. Run `git diff --cached --stat` for a high-level summary.
3. Run `git log --oneline -5` to understand the repo's recent commit style.
4. Analyze the staged changes and draft a commit message that:
   - Follows the repo's existing convention (typically `type: description`)
   - Common types: `docs`, `feat`, `fix`, `refactor`, `test`, `chore`, `style`, `perf`
   - Keeps the subject line under 72 characters
   - Uses imperative mood ("add" not "added")
   - Focuses on the **why**, not just the **what**
   - Groups related changes logically if multiple files are touched
   - References Jira issue keys (e.g., VIBS-XXX) when identifiable from file names or content
5. Present the suggested message to the user and wait for approval before committing.

## If the user provides a hint

Use `$ARGUMENTS` as additional context to focus or refine the message.

## Rules

- Do NOT commit automatically — always present the message first.
- If nothing is staged, inform the user and stop.
- If changes span unrelated concerns, suggest splitting into multiple commits.

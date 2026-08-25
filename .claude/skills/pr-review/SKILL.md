---
name: pr-review
description: Review a GitHub pull request against this repo's conventions (CLAUDE.md + analysis_options.yaml). Requires a PR link or number as argument.
disable-model-invocation: true
arguments: [pr-link]
argument-hint: '<GitHub PR link or number>'
allowed-tools: Bash(git:*), Bash(gh:*), Read, Grep, Glob
---

# Pull Request Review

Review the pull request at `$ARGUMENTS` against the rules defined in this repo's
`CLAUDE.md` and `analysis_options.yaml`.

## Prerequisites

If `$ARGUMENTS` is empty or missing, stop immediately and ask the user to provide a
GitHub PR link or number. (`gh` resolves a bare number against the `axondevgroup/vibs-mobile`
remote.)

## Steps

1. **Fetch PR metadata and diff**
   - Run `gh pr view $ARGUMENTS --json title,body,files,additions,deletions` to get PR details.
   - Run `gh pr diff $ARGUMENTS` to get the full diff.
   - If the PR has more than 20 changed files, run `gh pr diff $ARGUMENTS --name-only` first
     for an overview.

2. **Load the source of truth**
   - Read `CLAUDE.md` at the project root — architecture, conventions, and state-management rules.
   - Read `analysis_options.yaml` — the lints that gate PRs. Note which rules are promoted to
     **errors** (`dead_code`, `unused_import`, `invalid_assignment`, …) vs. warnings/lints
     (`require_trailing_commas`, `prefer_single_quotes`, `prefer_const_constructors`,
     `always_use_package_imports`, …).
   - These two files define every convention rule you may enforce. Do **not** invent rules that
     aren't there (no implicit line-count caps beyond the ~200-line guidance in CLAUDE.md, no
     style preferences from training data, no rules borrowed from other projects). If you think
     a rule is missing, surface it to the user instead of silently enforcing it.

3. **Review the diff**
   - Focus only on the **changed lines** — do not review unchanged code.
   - For each convention finding, cite the exact `CLAUDE.md` section or `analysis_options.yaml`
     lint it violates, or omit the finding. Anchor architectural findings to the specific
     CLAUDE.md rule, e.g.:
     - *Interface segregation* — consumers depend on narrow reader/writer interfaces, never the
       concrete class; UI never calls APIs directly.
     - *Data flow* — data sources throw typed exceptions; repositories wrap calls in `on(...)`
       and return `Either<Failure, T>`; DTOs map to entities via mapper extensions.
     - *Cubit/BLoC* — go through `CubitHelperMixin.emitWithLoading`, emit immutable states with
       `copyWith`, pattern-match on state, dispose every `ValueNotifier`/controller/subscription.
     - *Async lifecycle* — cache `context.read<T>()` **before** an `await`, check `mounted` after.
     - *DI* — register the concrete class once, alias each interface back to it; cubits via
       `registerFactory`/`registerFactoryParam`; no duplicate cubit creation.
     - *Theming/localization* — use `context.colors`/`context.textStyles`/etc. over hardcoded
       values; use `'dotted.key'.tr()` with the contextually correct key.
   - Verify claims against the live code when needed (e.g., before flagging a "missing
     localization key", confirm it's absent from `assets/langs/en.json` and `no.json`; before
     flagging a "wrong DI registration", check `lib/utils/di.dart`).
   - Beyond rule-checking, also flag: bugs, broken logic, security issues, unhandled `Left`/
     failure cases, un-disposed resources, and code that would clearly mislead a future reader.
     These don't need a rule citation — correctness is always in scope.
   - Assume PRs are pre-codegen: do **not** flag missing generated files (`*.g.dart`, `*.gr.dart`,
     `*.config.dart`) — they're gitignored and regenerated via `build_runner`.

4. **Produce the review** in the format below.

## Output format

```
## PR Overview
2-3 sentences: what the PR does and why.

### Critical
Bugs, broken functionality, data loss, security issues. Format per item:
- **`file:line` — one-line headline.**
- **Affected code:** short fenced excerpt (≤ ~10 lines, language-tagged).
- **Why it's wrong:** 1-3 sentences on impact / root cause.
- **Vision for improvement:** concrete fix as a short fenced excerpt (delta only).

### Major
Convention violations or design problems that meaningfully hurt code quality.
Each must cite the specific CLAUDE.md section or analysis_options.yaml lint it violates.
Same four-part structure as Critical.

### Minor
Smaller convention violations that should be fixed but don't affect functionality.
One-line headline with `file:line` + a short excerpt. Vision excerpt optional.

### Trivial
Nitpicks. One line per item; excerpts optional.

### Verdict
✅ Approve | ⚠️ Approve with suggestions | ❌ Request changes — one-line summary.
```

Omit any section that has no items.

## Code-excerpt rules

- **Always include an `Affected code` excerpt for Critical and Major items.**
- **Keep excerpts short** — 3-10 lines. Trim aggressively; use `// …` to elide context.
- **Emphasize the offending lines** — add a trailing `// ← reason` comment, or split the excerpt
  so only the broken lines remain.
- **Vision excerpts show only the delta**, not a full rewrite. One-line fix → one line;
  structural change → 5-15 lines of the new shape.
- **Use the right language tag** for this repo — `dart` for source, `yaml` for config/pubspec,
  `json` for translation/model files.

## Rules

- Be specific: reference exact file paths and line numbers from the diff.
- If the PR is clean, say so — don't invent issues to fill sections.
- Do NOT submit the review on GitHub — only present it to the user.

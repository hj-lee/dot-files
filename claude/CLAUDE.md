# Personal working preferences

Cross-project preferences. Repo-specific facts belong in that repo's `CLAUDE.md`.

Work-specific mechanics — build systems, code-review tooling, production-safety rules — are not
here: they live in `~/.claude/CLAUDE.local.md`, imported at the end of this file, and in
`~/.claude/rules/`. This file is checked into a public repo, so keep it to things that hold
everywhere.

## Commit messages

Conventional-commit subjects: `feat(scope): …`, `fix(scope): …`, `refactor(scope): …`, `test(scope): …`.

**The body explains why, not what.** If a paragraph narrates what the code does, delete it — the diff
already says that. Keep only what a reviewer would otherwise have to ask: the reason the change exists,
a decision that looks arbitrary without explanation, a risk statement, or a deliberate omission.

- **Scale the body to the change.** A 4-line diff gets 1–2 lines. Reserve 8–12 lines for changes that
  carry real decisions.
- **No `Tests:` paragraphs enumerating test classes and counts** — the review description carries
  testing, and class names are in the diff.
- **A body must never describe code that is not in the diff.** After reworking a branch, re-read the
  messages against `git show --stat` — stale paragraphs describing work that moved elsewhere are worse
  than verbose ones.

## Prefer fixing commits over stacking new ones

For unpublished work, amend or reword in place rather than adding a follow-up commit. A published
review gets a new revision instead.

- **`git commit --amend` hits the tip, which is often not the commit meant.** Confirm with
  `git log -1 --oneline` first.
- `git rebase -i` is unavailable in this environment. To reword or edit a non-tip commit, replay the
  stack: detach at the base, `git cherry-pick` each commit, amend where needed, then `git branch -f`.
  Check each cherry-pick's exit code **and** that HEAD actually moved before amending.
- **Every commit in a stack must compile standalone.** Splitting by file easily leaves a fix in one
  commit and the field it needs in a later one.
- Verify a message-only rewrite with `git diff <old-tip> <new-tip>` — it must be empty.

## Feature flags

When gating behind a flag, **the flag-off path must be identical to the pre-flag path**, so the only
rollback risk is the gate itself. Don't refactor shared code on the off path while adding a gate, and
don't leave the old path reading through new plumbing "for consistency". Say so explicitly in the
commit message — it's the property a reviewer most wants to confirm.

Gate where the decision is actually made (e.g. the launching Activity), not in every collaborator.

## Verification

**A green build is not a green feature.** Compilation and unit tests exercise neither a DI graph nor a
flag's two directions. For anything gated or UI-visible, run the app and check **both** directions,
reading logs rather than trusting the screen alone.

- Report what was actually verified. If something was skipped, say which and why — don't imply a build
  or run that didn't happen.
- **Never diagnose from silenced output.** `-q` flags and `tail` of an ANSI progress spinner hide the
  real error; re-run with plain output before forming a theory.

## Git hygiene

- **Stage explicit paths; never `git add -A`.** It sweeps up unrelated scratch and dump files that then
  ship in a commit.
- Fill in the review description template. Never leave `[Replace with …]` placeholders in a published
  review.

@~/.claude/CLAUDE.local.md

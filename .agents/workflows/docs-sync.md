---
description: Detect stale documentation and apply targeted incremental updates
---

# Docs Sync

I will help you find documentation that has drifted from the actual codebase and apply precise, incremental fixes. This workflow never rewrites whole files — it edits only the sections that are stale.

## Guardrails
- Never rewrite an entire doc file; apply surgical edits only
- Never remove content that is still accurate — only add, update, or annotate
- Never guess at behavior; verify every claim against source code before editing
- For HTML docs, describe changes in plain English rather than editing markup directly
- Preserve each doc's existing voice, structure, and formatting conventions
- Do not introduce project-specific tooling or framework names into the workflow itself

## Steps

### 1. Discover Documentation

Scan the repository for all documentation files:
- Markdown: `**/*.md` (README, CLAUDE.md, CONTRIBUTING, ADRs, changelogs, etc.)
- HTML: `**/*.html` in doc directories
- Structured context: `.context/`, `.sisyphus/`, or similar knowledge-base directories
- Config-as-docs: files whose primary audience is humans (e.g., `CLAUDE.md`, `.cursorrules`)

Build a **doc inventory** table:

| File | Type | Last git-modified | Sections |
|------|------|-------------------|----------|

### 2. Map Code Changes Since Last Doc Update

For each doc file, determine what code has changed since the doc was last touched:

```
git log --since="<doc_last_commit_date>" --name-only --pretty=format:""
```

Group the changed source files by the doc sections they relate to. Use file names, directory structure, and import graphs to map code → doc sections.

### 3. Detect Staleness

For each doc section, classify its state:

| Rating | Meaning | Action |
|--------|---------|--------|
| **STALE** | Section exists but describes outdated behavior | Edit to match current code |
| **MISSING** | New code/feature has no doc coverage at all | Add new section or bullet |
| **DRIFT** | Section is partially correct but incomplete | Augment with missing details |
| **OK** | Section matches current code | No action needed |

Produce a **staleness report** sorted by severity (MISSING → STALE → DRIFT → OK).

### 4. Verify Before Editing

For every change you plan to make:
1. Read the actual source file and confirm the behavior
2. Check git blame to understand when and why it changed
3. If behavior is ambiguous, flag it for the user rather than guessing

### 5. Apply Incremental Edits

For **Markdown** files:
- Use targeted edits (add lines, replace lines, update bullets)
- Preserve heading hierarchy and list formatting
- Add new sections at the logical insertion point, not at the end

For **HTML** files:
- Do not edit HTML directly
- Instead, produce a plain-English change description per section:
  ```
  Section "Installation": Add a note about the new --profile flag (added in v2.5)
  Section "API Reference": Update the /users endpoint to include the `role` field
  ```
- Let the user or a follow-up tool apply the HTML changes

### 6. Verify Edits

After all edits:
- Re-read each modified doc and spot-check 2-3 claims against source
- Confirm no formatting was broken (heading levels, code fences, link syntax)
- List every file modified and summarize what changed

## Principles
- Docs are a cache of understanding — they go stale like any cache
- Small, frequent doc updates beat large rewrites
- The goal is accuracy, not completeness — an incomplete but correct doc is better than a complete but wrong one
- Every doc edit should be traceable to a specific code change

## Reference
- `git log --follow -- <file>` to track doc file history
- `git diff <commit>..HEAD -- <directory>` to see what changed in a code area
- Combine with the `project-memory` workflow to build a full `.context/` knowledge base

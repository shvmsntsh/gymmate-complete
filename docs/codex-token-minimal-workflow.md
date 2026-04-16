# Token-Minimal Codex Workflow

Use this prompt kit to keep GymMate work small, graph-guided, and cheap on tokens.

## Default Workflow

Start every task with graph context:

```text
Use the repo graph first. Run code-review-graph detect-changes --repo /Users/shivamsantosh/gymmate_mvp --base HEAD --brief, then inspect only the relevant changed files and direct blast-radius files. Do not read the whole repo unless the graph proves it is needed.
```

Keep each Codex thread scoped:

```text
Work only on [one feature/bug]. Preserve unrelated dirty changes. Do not refactor unrelated files. Before editing, tell me the smallest file set you need to touch.
```

End every task with focused verification:

```text
Run the smallest relevant checks only. If node/npm/flutter are unavailable, say so and still run git diff --check on the files you touched.
```

## Copy-Paste Prompts

### Feature Build

```text
Use the graph-first workflow. I want to build: [feature].
Success criteria:
- [criterion 1]
- [criterion 2]
- [criterion 3]

Inspect only the minimal graph context first. Then implement the smallest cohesive change across backend/admin/mobile as needed. Preserve unrelated dirty changes. After implementation, run focused verification and summarize changed files, tests, and remaining risks.
```

### Bug Fix

```text
Use the graph-first workflow. Bug: [what happens]. Expected: [what should happen].
Known area, if any: [file/page/API].
Find the smallest root cause, patch only the affected files, and avoid broad refactors. Verify with the narrowest command possible plus git diff --check on touched files.
```

### Code Review

```text
Review the current dirty changes using code-review-graph first. Prioritize regressions, security/auth bugs, data model mismatches, broken UI flows, and missing tests. Do not fix anything yet unless I explicitly ask. Findings first, with file/line references and severity.
```

### UI Improvement

```text
Use frontend-skill and screenshot/playwright if available. Improve [screen/component] for [role/user goal]. Keep the existing design language. Do not create a landing page. Do not add unrelated styling systems. Verify mobile and desktop layout, text overflow, and main interaction path.
```

### Security Pass

```text
Use security-best-practices. Review only [auth/membership/messaging/uploads] and direct dependencies. Focus on authorization checks, tenant/gym scoping, unsafe uploads, token/session handling, and data exposure. Report findings first; do not rewrite architecture.
```

### Deploy Or CI

```text
Use vercel-deploy and gh-fix-ci if relevant. Diagnose the current deploy/CI issue from logs or config first. Make the smallest fix. Do not change app behavior unless required by the deploy failure. Verify with the closest local or CLI check available.
```

### Context Compression

```text
Use caveman-style compression. Summarize the current task state in under 200 words: goal, changed files, decisions made, commands run, blockers, and exact next action. No background explanation.
```

## Token-Saving Rules

- Do not paste large files into prompts. Give Codex file paths and ask it to inspect.
- Do not ask for "review whole project" unless necessary. Use "changed files + graph blast radius."
- Start new threads for unrelated features.
- Ask for "plan first" only when product intent is unclear; otherwise let Codex implement.
- Prefer exact acceptance criteria over broad goals.
- Keep screenshots and logs targeted: one failing flow, one role, one device size unless the issue is responsive.

## Installed Tooling

- Codex skills: `caveman`, `frontend-skill`, `playwright`, `screenshot`, `security-best-practices`, `vercel-deploy`, `gh-fix-ci`
- Graph CLI: `code-review-graph`
- Repo graph fallback: `node scripts/generate_codebase_graph.js context <files>`

Restart Codex after skill or MCP changes so the new tools are available in future threads.

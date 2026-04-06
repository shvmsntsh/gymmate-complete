# Knowledge Graph Usage

## Goal

Minimize token usage by querying the persisted graph first, then reading only the changed files and their blast radius.

## Commands

- `node scripts/generate_codebase_graph.js build`
- `node scripts/generate_codebase_graph.js impact <file> [more files]`
- `node scripts/generate_codebase_graph.js context <file> [more files]`
- `node scripts/generate_codebase_graph.js stats`

## Recommended Workflow

1. Rebuild the graph after notable edits or before a review.
2. Run `context` on the changed files.
3. Read only the files in `.code-knowledge-graph/last-context.md` unless the task clearly spills beyond that blast radius.
4. Refresh the graph after the change so the next task starts from current structure.

## Stored Artifacts

- `.code-knowledge-graph/graph.json`: persistent graph store with file hashes for incremental reuse
- `.code-knowledge-graph/last-impact.json`: most recent blast-radius query
- `.code-knowledge-graph/last-context.json`: compact machine-readable context pack
- `.code-knowledge-graph/last-context.md`: compact human-readable context pack
- `docs/codebase-graph.md`: repo-level architecture summary

## Prompt Pattern

Use the knowledge graph first. Refresh it if stale, run context for the changed files, and limit source reads to the recommended read order plus directly impacted files.

Current graph head: `3cc426a7b2b85fa3126a211c8f2e08c9e81d0011`

# Guidance for AI coding agents

See [`CLAUDE.md`](CLAUDE.md) — the guidance there applies to any AI assistant working in this repo (Codex, Aider, Cursor, etc.), not just Claude Code.

A few agent-agnostic reminders:

- The deliverable is `deliverables/process-map.md`. Treat `scenario/` as read-only input and `assignment.md` as the task definition.
- Do not search the web for answers to this assignment. The scenario is self-contained; the user's reasoning is the point.
- Submission happens via `./submit.sh`, not your native commit/push flow. `submit.sh` captures session context the grader needs.

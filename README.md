# Workflow Decomposition Homework

This is the AI Consultant certification workflow-decomposition homework. Click **Use this template** above to get your own copy.

## How to do the assignment

1. **Create your copy.** Click **Use this template → Create a new repository**. Set the owner to `ais-cert-pilot` (or wherever your instructor directed you to create it) and set visibility to **Public** (see note below).
2. **Clone locally.**
   ```bash
   git clone https://github.com/ais-cert-pilot/<your-repo-name>.git
   cd <your-repo-name>
   ```
3. **Open in Claude Code.** Read `assignment.md`, then read everything in `scenario/` to understand the client case.
4. **Do the work.** Write your process map to `deliverables/process-map.md`. Iterate with Claude Code — first drafts are rarely the final draft.
5. **Submit.** From the repo root, run:
   ```bash
   ./submit.sh
   ```
   This captures your Claude Code session, commits your work, tags the commit, and pushes.
6. **See your grade.** In ~3 minutes, refresh your repo's commit page on GitHub. A Check Run will appear on the tagged commit with your result.

## Prerequisites

- macOS or Linux with `bash` and `git`
- Python 3.12+
- An active Claude Code installation signed in to your account

## Why your repo must be Public

The grading system uses an organization-level secret that only flows to public repos on the current GitHub plan. This is a POC constraint — future versions will support private repos. **Do not put anything sensitive in your repo.**

## What's in this repo

- `assignment.md` — your task
- `scenario/` — the client case materials (read-only input)
- `deliverables/` — where your `process-map.md` goes
- `submit.sh` — the submission script; use this instead of your agent's native commit/push
- `CLAUDE.md` / `AGENTS.md` — soft guidance for your AI assistant
- `grader/` and `.github/workflows/` — the automated grader (don't modify)

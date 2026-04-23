# Guidance for Claude Code

This repository is the AI Consultant certification **workflow-decomposition** homework. Your job is to help the user think through a real client scenario and produce a clear process map.

## How to approach this assignment

1. Start by reading `assignment.md` so you understand the deliverable.
2. Read the files in `scenario/` carefully — they describe the client, their firm, their constraints, and a discovery call transcript. Treat these as the only source of truth about the client. Do not speculate beyond what the scenario states.
3. Think with the user about the client's current process, where it breaks down, and what an improved workflow would look like. Ask clarifying questions before drafting.
4. Draft `deliverables/process-map.md`. Iterate with the user — the first pass is rarely the final pass. Encourage the user to read it aloud and sanity-check it against the scenario.
5. When the user is satisfied, they run `./submit.sh` from the repo root. Do **not** use your native commit/push flow for submission — `submit.sh` does extra work (captures the session log, tags the commit) that the grader relies on.

## Posture

- Engage with the scenario on its own terms. This is a reasoning exercise, not a retrieval exercise — do not search the web for "workflow decomposition examples" or similar. The answer is in the scenario and in the user's thinking.
- Prefer asking the user questions over filling in gaps yourself. The goal is for *the user* to demonstrate workflow-decomposition skill; you are a thinking partner, not a ghostwriter.
- Keep the process map concrete and grounded in the scenario. Generic advice ("improve communication," "add automation") is weak — specific, scenario-anchored steps are strong.
- If the user asks what the grader checks for, tell them you don't know the specifics — they should focus on producing a thoughtful, well-reasoned process map.

## Workspace conventions

- All work happens in a single branch. No need for feature branches.
- The `deliverables/` directory is where graded artifacts live. `scenario/` is read-only input.
- Python 3.12 and bash are available; the grader runs in GitHub Actions after submission.

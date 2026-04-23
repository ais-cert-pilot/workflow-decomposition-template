#!/usr/bin/env bash
# submit.sh — one-command student submission for the AIS certification grader.
#
# Requires: bash, git, python3 (already needed for the grader).

set -euo pipefail

DRY_RUN=0
RESUBMIT=0

show_help() {
    cat <<'EOF'
submit.sh — one-command student submission for the AIS certification grader.

What it does:
  1. Runs preflight checks (git config, origin remote, attached HEAD).
  2. Verifies deliverables/process-map.md exists.
  3. Locates ALL Claude Code session logs for this repo under
     ~/.claude/projects/<mangled-cwd>/*.jsonl.
  4. Concatenates them chronologically (oldest first) into
     deliverables/session-log.jsonl.
  5. Commits only those two paths, tags submit-v1 (force-moves on
     re-submission), and pushes branch + tag to origin. The tag push
     triggers the grading workflow.

Flags:
  --dry-run   Preflight + locate + concatenate only. No commit, tag, or push.
  -h, --help  Show this message.

Tool support: Claude Code only (per POC spec). Codex/Aider are v1.
EOF
}

for arg in "$@"; do
    case "$arg" in
        --dry-run) DRY_RUN=1 ;;
        -h|--help) show_help; exit 0 ;;
        *)
            echo "submit.sh: unknown argument: $arg" >&2
            echo "Usage: ./submit.sh [--dry-run]" >&2
            exit 2
            ;;
    esac
done

err() { printf '%s\n' "$*" >&2; }

# ---------------------------------------------------------------------------
# Helpers (portable: Python 3 is already a hard dep for this course).
# ---------------------------------------------------------------------------

# Concatenate ALL *.jsonl files in a directory to stdout, in chronological
# order (oldest mtime first, newest last). Exit non-zero if no files found.
# If a file doesn't end with a newline, emit one before the next file so
# JSON-lines records don't merge across session boundaries.
concatenate_all_jsonl() {
    python3 - "$1" <<'PY'
import os, sys, glob
d = sys.argv[1]
files = [f for f in glob.glob(os.path.join(d, "*.jsonl")) if os.path.isfile(f)]
if not files:
    sys.exit(1)
files.sort(key=lambda f: os.path.getmtime(f))  # oldest first
out = sys.stdout.buffer
for f in files:
    with open(f, "rb") as fh:
        data = fh.read()
    if not data:
        continue
    out.write(data)
    if not data.endswith(b"\n"):
        out.write(b"\n")
PY
}

# Count *.jsonl files and total bytes in a directory (for reporting).
# Prints "<count> <total_bytes>" to stdout, or exits non-zero if none.
count_and_size_jsonl() {
    python3 - "$1" <<'PY'
import os, sys, glob
d = sys.argv[1]
files = [f for f in glob.glob(os.path.join(d, "*.jsonl")) if os.path.isfile(f)]
if not files:
    sys.exit(1)
total = sum(os.path.getsize(f) for f in files)
print(f"{len(files)} {total}")
PY
}

# Resolve the Claude Code session directory under $parent given the primary
# mangled name and a fallback basename. Precedence:
#   1. Exactly ONE exact basename match across all needles → accept.
#   2. 2+ exact matches → fail with candidate list (ambiguous).
#   3. Zero exact, exactly ONE substring match across needles → accept.
#   4. Zero exact, 2+ substring matches → fail (print candidates).
#   5. Zero matches anywhere → fail.
# Exit non-zero if no unique match; stdout is the absolute path on success.
newest_matching_subdir() {
    local parent="$1"; shift
    python3 - "$parent" "$@" <<'PY'
import os, sys
parent = sys.argv[1]
needles = [n for n in sys.argv[2:] if n]
if not os.path.isdir(parent):
    sys.exit(1)
subdirs = []
for name in os.listdir(parent):
    p = os.path.join(parent, name)
    if os.path.isdir(p):
        subdirs.append((name, p))
# 1/2. Exact matches across all needles (deduped by path).
exact = []
seen = set()
for name, p in subdirs:
    if name in needles and p not in seen:
        exact.append((name, p))
        seen.add(p)
if len(exact) == 1:
    print(exact[0][1])
    sys.exit(0)
if len(exact) > 1:
    sys.stderr.write(
        "Ambiguous exact matches for session dir:\n")
    for name, _ in sorted(exact):
        sys.stderr.write(f"  {name}\n")
    sys.stderr.write(
        "Refusing to guess. Rename or remove the stale entries under\n"
        "  ~/.claude/projects/\n"
        "so only the directory for this repo remains, then re-run.\n")
    sys.exit(1)
# 3/4. Substring match fallback.
substr = [(name, p) for name, p in subdirs
          if any(n in name for n in needles)]
if len(substr) == 1:
    print(substr[0][1])
    sys.exit(0)
if len(substr) > 1:
    sys.stderr.write(
        "Multiple candidate session dirs matched the cwd basename:\n")
    for name, _ in sorted(substr):
        sys.stderr.write(f"  {name}\n")
    sys.stderr.write(
        "Refusing to guess. Rename or remove the stale entries under\n"
        "  ~/.claude/projects/\n"
        "so only the directory for this repo remains, then re-run.\n")
sys.exit(1)
PY
}

file_size_bytes() {
    stat -f %z "$1" 2>/dev/null || stat -c %s "$1" 2>/dev/null || echo 0
}

# ---------------------------------------------------------------------------
# 1. Preflight (fail fast, before any mutations).
# ---------------------------------------------------------------------------

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    err "Run this from inside your homework repo."
    exit 1
fi

REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT"

GIT_EMAIL="$(git config user.email || true)"
GIT_NAME="$(git config user.name || true)"
if [[ -z "$GIT_EMAIL" || -z "$GIT_NAME" ]]; then
    err "git is not configured for commits. Run:"
    err "  git config --global user.email 'you@example.com'"
    err "  git config --global user.name 'Your Name'"
    exit 1
fi

if ! git remote get-url origin >/dev/null 2>&1; then
    err "No 'origin' remote configured. This repo must be cloned from your"
    err "GitHub student repo, not initialized locally."
    exit 1
fi

BRANCH="$(git symbolic-ref -q --short HEAD || true)"
if [[ -z "$BRANCH" ]]; then
    err "You are on a detached HEAD. Check out a branch first (usually main):"
    err "  git checkout main"
    exit 1
fi

if [[ "$DRY_RUN" -ne 1 ]]; then
    mkdir -p deliverables
fi

if [[ ! -f "deliverables/process-map.md" ]]; then
    err "deliverables/process-map.md is missing."
    err "Complete the assignment first, then run ./submit.sh."
    exit 1
fi

# ---------------------------------------------------------------------------
# 2. Find the Claude Code session log.
# ---------------------------------------------------------------------------

PROJECTS_DIR="$HOME/.claude/projects"

if [[ ! -d "$PROJECTS_DIR" ]]; then
    err "Could not find ~/.claude/projects/."
    err "Have you used Claude Code on this machine? If so, please file an issue."
    exit 1
fi

# Mangling rule (empirical, macOS): strip leading '/', replace every character
# that is not alphanumeric or '-' with '-', then prepend a '-'.
MANGLED="-$(printf '%s' "${REPO_ROOT#/}" | sed 's|[^a-zA-Z0-9-]|-|g')"

SESSION_DIR=""
if [[ -d "$PROJECTS_DIR/$MANGLED" ]]; then
    SESSION_DIR="$PROJECTS_DIR/$MANGLED"
else
    BASENAME="$(basename "$REPO_ROOT")"
    MANGLED_BASENAME="$(printf '%s' "$BASENAME" | sed 's|[^a-zA-Z0-9-]|-|g')"
    if CANDIDATE="$(newest_matching_subdir "$PROJECTS_DIR" "$BASENAME" "$MANGLED_BASENAME")"; then
        SESSION_DIR="$CANDIDATE"
        err "Note: exact mangled dir not found; using fuzzy match: $SESSION_DIR"
    fi
fi

if [[ -z "$SESSION_DIR" ]]; then
    err "Could not locate your Claude Code session log under ~/.claude/projects/"
    err "Looked for:"
    err "  ~/.claude/projects/$MANGLED/"
    err "  (and a fuzzy-match fallback on the cwd basename)"
    err "If you've been working in Claude Code on this repo, please file an issue with:"
    err "  ls ~/.claude/projects/"
    err "  pwd"
    exit 1
fi

if ! COUNT_AND_SIZE="$(count_and_size_jsonl "$SESSION_DIR")"; then
    err "Found session directory ($SESSION_DIR) but no *.jsonl files inside it."
    err "Has this repo had a Claude Code session yet?"
    exit 1
fi
JSONL_COUNT="${COUNT_AND_SIZE% *}"
JSONL_TOTAL_BYTES="${COUNT_AND_SIZE##* }"

# ---------------------------------------------------------------------------
# 3. Concatenate the session logs.
# ---------------------------------------------------------------------------

DEST="deliverables/session-log.jsonl"

SIZE_KB=$(( JSONL_TOTAL_BYTES / 1024 ))

# ---------------------------------------------------------------------------
# 4. Detect re-submission (local OR remote tag).
# ---------------------------------------------------------------------------

if git rev-parse --verify --quiet "refs/tags/submit-v1" >/dev/null \
   || git ls-remote --tags --exit-code origin submit-v1 >/dev/null 2>&1; then
    RESUBMIT=1
fi

# Build the tag refspec once so dry-run output and the real push agree.
if [[ "$RESUBMIT" -eq 1 ]]; then
    TAG_REFSPEC="+refs/tags/submit-v1"
else
    TAG_REFSPEC="refs/tags/submit-v1"
fi

if [[ "$DRY_RUN" -eq 1 ]]; then
    err "(dry-run) would concatenate ${JSONL_COUNT} session log file(s) (total ${SIZE_KB} KB) from ${SESSION_DIR} -> ${DEST}"
    err "[--dry-run] Stopping before concat/commit/tag/push. No local state mutated."
    err "[--dry-run] Would run:"
    err "  concatenate_all_jsonl \"$SESSION_DIR\" > \"$DEST\""
    err "  git add -- \"$DEST\" deliverables/process-map.md"
    err "  git commit -m 'Submit v1' -- \"$DEST\" deliverables/process-map.md   # (if staged diff non-empty)"
    if [[ "$RESUBMIT" -eq 1 ]]; then
        err "  git tag -f submit-v1   # (re-submission detected; atomic force-move)"
        err "  git push --atomic origin HEAD ${TAG_REFSPEC}   # tag force-pushed"
    else
        err "  git tag submit-v1"
        err "  git push --atomic origin HEAD ${TAG_REFSPEC}"
    fi
    exit 0
fi

# Atomic write: concatenate to a tmp file alongside DEST, then mv into place
# so an interrupted write can never leave DEST half-written.
TMP_DEST="$(mktemp "deliverables/session-log.jsonl.XXXXXX.tmp")"
trap 'rm -f "$TMP_DEST" 2>/dev/null || true' EXIT

if ! concatenate_all_jsonl "$SESSION_DIR" > "$TMP_DEST"; then
    err "Failed to concatenate session logs from $SESSION_DIR into a temp file."
    err "Check disk space and permissions, then re-run ./submit.sh."
    exit 1
fi

# Zero-byte check AFTER concatenation — if all sessions were empty, don't
# clobber a prior good session-log.jsonl.
CONCAT_BYTES="$(file_size_bytes "$TMP_DEST")"
if [[ "$CONCAT_BYTES" -eq 0 ]]; then
    err "Concatenated session log is 0 bytes:"
    err "  source dir: $SESSION_DIR"
    err "Did you just open the project in Claude Code without doing any work?"
    err "Do at least one Claude Code turn in this repo before submitting."
    err "(If the logs under that dir are all stale/empty, delete them and re-run.)"
    err "Leaving $DEST unchanged."
    exit 1
fi

if ! mv "$TMP_DEST" "$DEST"; then
    err "Failed to move temp copy into place at $DEST."
    err "Check permissions on deliverables/, then re-run ./submit.sh."
    exit 1
fi

err "Concatenated ${JSONL_COUNT} session log file(s) (${SIZE_KB} KB) to ${DEST}"
err "  source dir: $SESSION_DIR"

# ---------------------------------------------------------------------------
# 5. Commit + tag + push (scoped strictly to our two paths).
# ---------------------------------------------------------------------------

if ! git add -- "$DEST" "deliverables/process-map.md"; then
    err ""
    err "Failed to stage deliverables. Your session log was copied to"
    err "  $DEST"
    err "but 'git add' failed (see git error above). Fix the underlying issue"
    err "(permissions on .git/index, disk space, etc.) and re-run ./submit.sh."
    exit 1
fi

if git diff --cached --quiet -- "$DEST" "deliverables/process-map.md"; then
    err "No changes to commit (session log and process map unchanged). Re-tagging HEAD."
else
    if ! git commit -m "Submit v1" -- "$DEST" "deliverables/process-map.md"; then
        err ""
        err "Commit failed. Check the git error above. Your session log was"
        err "copied to \`${DEST}\`; you can retry with \`./submit.sh\`."
        exit 1
    fi
fi

# Force-move the tag atomically (no pre-delete → old pointer stays until
# this line succeeds). On a fresh submission -f is a no-op semantically.
if ! git tag -f submit-v1 >/dev/null; then
    err ""
    err "Tag creation failed. Your commit was made but the 'submit-v1' tag was NOT created."
    err "The remote has not been updated. To recover, re-run ./submit.sh (it will pick up"
    err "from here), or manually run:"
    err "  git tag -f submit-v1 && git push --atomic origin HEAD '${TAG_REFSPEC}'"
    exit 1
fi

# Atomic push: branch + tag arrive together.
if ! git push --atomic origin HEAD "${TAG_REFSPEC}"; then
    err ""
    err "Push failed. Your local commit and tag were created but the remote"
    err "was NOT updated (atomic push failed — see git error above)."
    err "Fix the underlying issue and re-run ./submit.sh."
    exit 1
fi

# ---------------------------------------------------------------------------
# 6. Friendly completion.
# ---------------------------------------------------------------------------

SHORT_SHA="$(git rev-parse --short HEAD)"

REMOTE_URL="$(git remote get-url origin 2>/dev/null || true)"
ACTIONS_URL=""
if [[ -n "$REMOTE_URL" ]]; then
    NORMALIZED="${REMOTE_URL%.git}"
    NORMALIZED="${NORMALIZED/git@github.com:/https://github.com/}"
    NORMALIZED="${NORMALIZED/ssh:\/\/git@github.com\//https://github.com/}"
    ACTIONS_URL="${NORMALIZED}/actions"
fi

TAG_SUFFIX=""
if [[ "$RESUBMIT" -eq 1 ]]; then
    TAG_SUFFIX=" (force-moved for re-submission)"
fi

echo "Submitted. Your grade will appear on GitHub in ~3 minutes."
echo "  tag:    submit-v1${TAG_SUFFIX}"
echo "  commit: ${SHORT_SHA}"
if [[ -n "$ACTIONS_URL" ]]; then
    echo "  check:  ${ACTIONS_URL}"
fi

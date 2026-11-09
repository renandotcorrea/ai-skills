#!/usr/bin/env bash
# Deterministic project inventory for the agents-md-review skill.
# Usage: inspect-project.sh [project-root]
# Read-only. The reference checks are heuristic: confirm manually.
set -u
ROOT="${1:-.}"
cd "$ROOT" || { echo "Invalid directory: $ROOT" >&2; exit 1; }

EXCL=( -not -path '*/node_modules/*' -not -path '*/.git/*' -not -path '*/vendor/*' \
       -not -path '*/dist/*' -not -path '*/build/*' -not -path '*/.venv/*' )

section() { printf '\n## %s\n' "$1"; }

section "Agent context files"
find . -maxdepth 4 \( -name AGENTS.md -o -name CLAUDE.md -o -name GEMINI.md -o -name .cursorrules \
     -o -name copilot-instructions.md -o -name '*.instructions.md' \) "${EXCL[@]}" 2>/dev/null | sort | while read -r f; do
  lines=$(wc -l < "$f" | tr -d ' ')
  items=$(grep -cE '^[[:space:]]*([-*+]|[0-9]+\.)[[:space:]]+' "$f" || true)
  kind="file"; [ -L "$f" ] && kind="symlink -> $(readlink "$f")"
  echo "- $f | $lines lines | ~$items list items | $kind"
done

section "Manifests and task runners"
for f in package.json pnpm-workspace.yaml turbo.json nx.json lerna.json pyproject.toml uv.lock \
         poetry.lock requirements.txt go.mod go.work Cargo.toml pom.xml build.gradle \
         build.gradle.kts Gemfile composer.json mix.exs Makefile justfile Justfile Taskfile.yml \
         Dockerfile docker-compose.yml compose.yaml .tool-versions mise.toml .nvmrc .python-version; do
  [ -e "$f" ] && echo "- $f"
done

section "Available scripts"
if [ -f package.json ]; then
  echo "### package.json"
  if command -v python3 >/dev/null 2>&1; then
python3 - <<'PY'
import json
d = json.load(open("package.json"))
for k, v in (d.get("scripts") or {}).items():
    print(f"- {k}: {v}")
for key in ("packageManager", "workspaces", "engines"):
    if d.get(key):
        print(f"- {key}: {d[key]}")
PY
  else
    sed -n '/"scripts"/,/}/p' package.json
  fi
fi
if [ -f Makefile ]; then
  echo "### Makefile (targets)"
  grep -E '^[A-Za-z0-9_-]+:' Makefile | cut -d: -f1 | sed 's/^/- /'
fi
for j in justfile Justfile; do
  if [ -f "$j" ]; then
    echo "### $j (recipes)"
    grep -E '^[A-Za-z0-9_-]+([[:space:]].*)?:' "$j" | grep -v ':=' | cut -d: -f1 | sed 's/^/- /'
  fi
done

section "Lint, formatting, types and architecture (detected configs)"
find . -maxdepth 3 \( -name '.eslintrc*' -o -name 'eslint.config.*' -o -name '.prettierrc*' \
  -o -name 'prettier.config.*' -o -name 'biome.json*' -o -name '.editorconfig' -o -name 'ruff.toml' \
  -o -name '.ruff.toml' -o -name 'mypy.ini' -o -name 'pyrightconfig.json' -o -name 'tsconfig*.json' \
  -o -name '.golangci*' -o -name '.rubocop.yml' -o -name '.dependency-cruiser*' \
  -o -name 'commitlint.config.*' -o -name '.commitlintrc*' -o -name '.gitleaks.toml' \
  -o -name 'checkstyle*.xml' -o -name '.swiftlint.yml' -o -name 'rustfmt.toml' -o -name 'clippy.toml' \) \
  "${EXCL[@]}" 2>/dev/null | sort | sed 's/^/- /'
if [ -f pyproject.toml ]; then
  grep -oE '^\[tool\.[A-Za-z0-9_-]+' pyproject.toml | sort -u | sed 's/^\[/- pyproject: /'
fi

section "Hooks and CI"
for p in .husky .pre-commit-config.yaml lefthook.yml .gitlab-ci.yml .circleci azure-pipelines.yml \
         Jenkinsfile .claude/settings.json .claude/hooks; do
  [ -e "$p" ] && echo "- $p"
done
if [ -d .github/workflows ]; then
  echo "- .github/workflows:"
  ls .github/workflows | sed 's/^/  - /'
fi

section "Existing documentation (pointer candidates)"
find . -maxdepth 3 -type f \( -iname 'README*' -o -iname 'CONTRIBUTING*' -o -iname 'ARCHITECTURE*' \
  -o -iname 'DEVELOPMENT*' -o -ipath '*/docs/*' -o -ipath '*/adr/*' -o -ipath '*/agent_docs/*' \) \
  "${EXCL[@]}" 2>/dev/null | sort | head -50 | sed 's/^/- /'

section "Existing skills and agent instructions"
find . -maxdepth 4 \( -path '*/.claude/skills/*/SKILL.md' -o -path '*/.agents/skills/*/SKILL.md' \
  -o -path '*/.github/skills/*/SKILL.md' -o -path '*/.github/agents/*.md' \
  -o -path '*/.github/prompts/*.prompt.md' -o -path '*/.cursor/rules/*' \) "${EXCL[@]}" 2>/dev/null \
  | sort | sed 's/^/- /'

section "Top-level structure (depth 1)"
find . -maxdepth 1 -mindepth 1 -not -name '.git' -not -name node_modules | sort | sed 's|^\./||' \
  | while read -r e; do if [ -d "$e" ]; then echo "- $e/"; else echo "- $e"; fi; done

section "Verification of AGENTS.md references (heuristic)"
TARGET=""
for c in AGENTS.md CLAUDE.md; do
  if [ -f "$c" ]; then TARGET="$c"; break; fi
done
if [ -z "$TARGET" ]; then
  echo "No AGENTS.md/CLAUDE.md at the root."
  exit 0
fi
echo "File analyzed: $TARGET"
tokens=$(grep -oE '`[^`]+`' "$TARGET" | tr -d '`' | sort -u)

echo "### Quoted paths that do NOT exist"
printf '%s\n' "$tokens" | while IFS= read -r t; do
  case "$t" in
    ""|*" "*|http*|*"*"*|*"<"*|*"{"*|*'$'*) continue ;;
  esac
  case "$t" in
    */*)
      p="${t%%:*}"
      [ -e "$p" ] || echo "- $t"
      ;;
  esac
done

echo "### Quoted commands whose target does not exist"
printf '%s\n' "$tokens" | while IFS= read -r t; do
  case "$t" in
    "npm run "*|"pnpm run "*|"yarn run "*|"bun run "*)
      s=$(echo "$t" | awk '{print $3}')
      if [ -f package.json ] && ! grep -q "\"$s\"[[:space:]]*:" package.json; then
        echo "- $t (script '$s' does not exist in the root package.json)"
      fi ;;
    "make "*)
      s=$(echo "$t" | awk '{print $2}')
      if [ -f Makefile ] && [[ "$s" != -* ]] && ! grep -qE "^$s:" Makefile; then
        echo "- $t (target '$s' does not exist in the Makefile)"
      fi ;;
    "just "*)
      s=$(echo "$t" | awk '{print $2}')
      f=justfile; [ -f Justfile ] && f=Justfile
      if [ -f "$f" ] && [[ "$s" != -* ]] && ! grep -qE "^$s([[:space:]]|:)" "$f"; then
        echo "- $t (recipe '$s' does not exist in $f)"
      fi ;;
  esac
done

echo
echo "Note: in monorepos, scripts may live in the packages rather than the root; confirm before concluding something is broken."
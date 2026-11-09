---
name: agents-md-review
description: Reviews an AGENTS.md (or CLAUDE.md) by cross-checking its content against the real project and produces a report on what to remove, what to turn into a deterministic command (linter, formatter, hook, CI, architecture test), and what to extract into a separate file (docs/*.md, nested AGENTS.md or SKILL.md). Use whenever the user asks to review, audit, trim, optimize or analyze an AGENTS.md/CLAUDE.md, or says the file is too long, bloated, outdated, or that the agent ignores its instructions, even if they don't mention "skill". Do not use to create an AGENTS.md from scratch or to auto-generate one (/init).
---

# AGENTS.md Review

AGENTS.md is injected into **every** agent session. Each line costs context and dilutes attention, so the goal of the review is not to make the file "complete": it is to leave in it **only what the agent cannot discover on its own, what applies to almost every task, and what cannot be enforced deterministically**.

Why this matters (details and sources at the end):
- Auto-generated files lower task success rates (~3%) and raise cost (>20%); human-written ones improve results only slightly (~4%) and also raise cost.
- Codebase overviews and directory listings do not help the agent navigate faster.
- Instructions are followed, and that is exactly why unnecessary ones hurt: they make the task harder.
- Frontier models reliably follow ~150–200 instructions, and the agent harness already consumes ~50 of them.
- Tools mentioned in AGENTS.md get used far more often than unmentioned ones.

## Conduct rules

- **Do not change any file.** The output is a report. Offer to apply the changes only afterwards.
- Write the report in the language the user is writing in (English if unclear).
- Every recommendation cites the **line** in AGENTS.md and a **piece of evidence from the project** (file, script, config). Without evidence, mark it `UNCERTAIN` instead of guessing.
- Prioritize by impact. A report with 40 micro-adjustments hides the 5 that matter.
- Prefer extending what the project already uses (e.g., an existing ESLint setup) over suggesting a new tool.
- Never recommend generating AGENTS.md with `/init` or with the agent itself.

## Workflow

### 0. Identify which instruction files the team uses

Each agent (harness) reads different files: for example, Copilot in VS Code reads `AGENTS.md` or `.github/copilot-instructions.md`, and Claude Code reads `CLAUDE.md`. Ask (or infer from the inventory) which agents the team uses, and review **all** instruction files in the project, including `.github/instructions/*.instructions.md`.

If content is duplicated across files (e.g., `AGENTS.md` and `.github/copilot-instructions.md` with the same rules), report it as a finding: it doubles the cost and risks divergence. Recommend a single source of truth and ask the team to check, in the agent's documentation, how it combines files, because precedence rules vary by agent.

### 1. Inventory the project (deterministic)

Run from the project root. The script lives in this skill's directory (the same directory as `SKILL.md`, for example `.github/skills/agents-md-review/`): [scripts/inspect-project.sh](./scripts/inspect-project.sh).

```bash
bash <this-skill-directory>/scripts/inspect-project.sh .
```

It lists: agent context files (size, number of items), manifests and task runners, available scripts, lint/format/type/architecture configs, hooks and CI, existing documentation, skills already present, top-level structure, and it **checks which paths and commands cited in AGENTS.md do not exist**. If there is no `bash` (e.g., a PowerShell terminal on Windows without Git Bash/WSL) or execution is denied, collect the same information manually with the agent's read and search tools. The script only reads files.

In monorepos, also run it in each relevant package that has its own AGENTS.md.

### 2. Decompose AGENTS.md

Read the whole file and break it into **atomic items** (one instruction or one fact per item), keeping the line number. A bullet with three rules becomes three items.

### 3. Classify each item

Apply the tree below **in order**; the first "yes" decides.

| # | Question | Verdict |
|---|----------|---------|
| 1 | Is it wrong or outdated? (nonexistent command, script, path or tool; contradicts another item or the code) | `REMOVE` (or `REWRITE` if the correct fact cannot be inferred) |
| 2 | Would the agent discover it on its own in seconds? (stack visible in the manifest, directory tree, convention visible in the code, copy of README/docs/CONTRIBUTING) | `REMOVE` (if the doc exists but is hard to find, replace with a one-line pointer) |
| 3 | Is it generic or vague? ("write clean code", "be careful", persona "you are a senior engineer") | `REMOVE` |
| 4 | Can it be enforced deterministically? (style, formatting, naming, imports/layers, types, coverage, commits, secrets, generated files) | `AUTOMATE`, see [references/automation-map.md](./references/automation-map.md) |
| 5 | Does it apply only to certain tasks or areas of the code? | `EXTRACT`, pick a destination below |
| 6 | Is it universal, non-inferable and high-impact? | `KEEP` (mark `REWRITE` if it is vague, only forbids without giving an alternative, or embeds a snippet that will go stale) |

Nuances:

- **AUTOMATE does not mean vanishing without a trace.** Since mentioned tools get used more, after automating keep **one line** with the single verification command (e.g., "run `make check` before finishing"), and remove the rules it already covers.
- **Destructive or security "never do X" rules:** prefer a harness permission/hook; keep one line only if the mechanism does not cover it.
- **Non-inferable boundaries** (always do / ask first / never do) are good `KEEP` candidates, as long as they are short.
- **Monorepo:** a one-line-per-app/package map can stay if it cannot be derived from the workspace config. A directory tree cannot.
- **Code snippets** become a `file:line` pointer to a real example, so they do not go stale.
- **Code style:** GitHub itself recommends style examples in specialized agent files, but for the root AGENTS.md the dominant recommendation is to use a linter/formatter, because LLMs imitate patterns in the existing code. Follow the latter, unless the project has no way to enforce the rule.

**Destinations for `EXTRACT`** (choose one and justify):

| The content is... | Destination |
|-------------------|-------------|
| Lookup knowledge (architecture, schema, testing guide, deploy, API conventions) | `docs/<topic>.md` or `agent_docs/<topic>.md`, with a pointer in AGENTS.md saying **when to read it** |
| A repeatable procedure triggered by a type of task (create a migration, cut a release, debug a flaky test, review a PR) | `SKILL.md` (its description says when to trigger it) |
| A rule that applies to a file type or folder (e.g., test conventions in `tests/**/*.py`) | `.github/instructions/<topic>.instructions.md` with `applyTo` (Copilot/VS Code) |
| A rule that applies only to one subdirectory or package | A nested `AGENTS.md` in that directory (confirm the agent in use supports nested files) |
| The historical rationale for a decision | An existing or new ADR, with a link |

### 4. Look for gaps

Based on the inventory, check whether **AGENTS.md** is missing any of the following (and only suggest with evidence):

- Build, test, lint and typecheck commands that are non-standard (`uv` instead of `pip`, `bun`, `pnpm`, a `make` target, flags), including **how to run a single test**.
- Non-obvious prerequisites: services or containers for the tests, required environment variables, a code generation step.
- Gotchas the inventory reveals that would trip the agent (generated files that must not be edited, misleadingly named scripts).

If AGENTS.md already has all of this, say there are no gaps. Do not invent any.

### 5. Measure

Report: current lines, number of atomic items, count per verdict, and estimated lines after applying the review. Heuristic thresholds (not hard rules):

| Signal | Warning | Critical |
|--------|---------|----------|
| Lines | > 150 | > 300 |
| Atomic items | > 100 | > 150 |

Order-of-magnitude reference: HumanLayer's root AGENTS.md is under 60 lines.

### 6. Produce the report

Follow [references/report-template.md](./references/report-template.md). Finish by offering: (a) to apply the removals and rewrites, (b) to create the extracted files, (c) to add the suggested automation configs, each as a separate step.

## Sources

- Philipp Schmid, *Writing a Good AGENTS.md* (Feb 2026), which gathers the data from the paper "Evaluating AGENTS.md" (ETH Zurich) and HumanLayer's experience: https://www.philschmid.de/writing-good-agents
- HumanLayer, *Writing a good CLAUDE.md*: https://humanlayer.com/blog/writing-a-good-claude-md
- GitHub, *How to write a great agents.md: lessons from over 2,500 repositories*: https://github.blog/ai-and-ml/github-copilot/how-to-write-a-great-agents-md-lessons-from-over-2500-repositories/ (focused on specialized agent files; source of "commands early" and "explicit boundaries")
# Report template

Use this structure. Omit empty sections (e.g., if there are no `REWRITE` items, do not create that section). Be direct: the report is read by humans who will decide what to apply.

```markdown
# AGENTS.md Review — <project name>

## 1. Summary

- **File:** `<path>` · <N> lines · <M> atomic items
- **Overall verdict:** <one sentence: e.g., "bloated, ~60% of the content is discoverable or automatable">
- **Distribution:** KEEP <a> · REWRITE <b> · REMOVE <c> · AUTOMATE <d> · EXTRACT <e>
- **Estimated size after the review:** ~<X> lines (currently <N>)
- **The 3 highest-impact changes:**
  1. ...
  2. ...
  3. ...

## 2. Broken references

Cited paths and commands that do not exist (output of the inventory check), with the suggested fix when obvious. This is the most urgent section: wrong instructions get followed.

## 3. Remove

| Line | Excerpt | Reason | Evidence |
|---|---|---|---|
| 12–30 | Directory tree | Discoverable; does not help navigation | `ls` of the root shows the same structure |

## 4. Automate

### <Rule> (line <n>)
- **Mechanism:** ...
- **Already in the project?** yes (`<file>`) / no
- **Minimal config:**
  ```<lang>
  ...
  ```
- **What remains in AGENTS.md:** `<single line>` or nothing

## 5. Extract

### <Topic> (lines <a>–<b>)
- **Destination:** `docs/<topic>.md` | `SKILL.md` | `<folder>/AGENTS.md` | `.github/instructions/<topic>.instructions.md`
- **Why this destination:** ...
- **Content to move:** summary of what leaves
- **Pointer that stays:** `- Before changing <area>, read docs/<topic>.md`

## 6. Rewrite

| Line | Before | After | Why |
|---|---|---|---|

## 7. Gaps

Items missing from AGENTS.md, **each with the evidence** from the inventory. If there are none, write "No gaps found".

## 8. Uncertain points

Items marked `UNCERTAIN`, with the exact question for the team to answer.

## 9. Next steps

Suggested order (lowest to highest risk) and an offer to apply each step separately.
```

## Cautions

- Always cite the source line; without it the reviewer cannot verify.
- Do not repeat the whole content of AGENTS.md; summarize the excerpt.
- Do not include a "complete new version" of the file unless the user asks for it later.
- When the same excerpt fits two verdicts (e.g., automate and extract), choose the first by the decision tree order and mention the other in one sentence.
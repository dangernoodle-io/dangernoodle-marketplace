---
name: persist
description: Scan conversation for decisions, facts, notes, and plans worth persisting to the ouroboros knowledge base
---

# Persist to Ouroboros KB

This skill extracts and stores valuable knowledge from the current conversation into the ouroboros knowledge base, including project decisions, facts, notes, and implementation plans.

## Process

### 1. Determine Project Name
First, run `git rev-parse --show-toplevel | xargs basename` in the current working directory to identify the project. If the command fails (not in a git repo), use "workspace" as the project name.

### 2. Identify Material to Extract
If you were provided with args (user typed `/persist <notes>`), treat them as the raw material. Otherwise, scan the full conversation for knowledge worth persisting.

Look for these types of items:

- **Decisions** (type: `decision`): architectural choices, technology selections, design trade-offs with clear rationale
- **Facts** (type: `fact`): configuration values, endpoints, credential references, version numbers, environment details
- **Notes** (type: `note`): procedures, processes, how-tos, meeting summaries, important observations
- **Relations** (type: `relation`): dependencies between components, projects, or systems
- **Plans** (type: `plan`): implementation plans discussed and deferred — capture terse step list in content; narrative context in notes

### 3. Search for existing entries
For each candidate: call the `search` MCP tool with the proposed title. If a matching entry exists for the same project, reuse its title verbatim when calling `put` — the server upserts by `type+project+category+title`, so it will update rather than duplicate. Only skip if the existing entry's content is already identical to what you would write.

### 4. Store New Items
For each new item, call the `put` MCP tool with:
- `type`: the document type (`decision`, `fact`, `note`, or `relation`)
- `project`: the project name from step 1
- `title`: a concise, descriptive title (used as a unique key)
- `content`: terse, ≤300 chars target / 500 hard cap, structured (Rule/Fact + optional Trigger:/Effect:/Why: lines) — agents read this on every injection
- `notes`: optional narrative for humans — rationale, trade-offs, context. Unlimited length, only shown when user asks 'why'
- `category`: optional categorization (e.g., "config" for facts, procedure type for notes)
- `tags`: relevant tags as an array

### 4b. Store Plans
If implementation plans were created during the session (multi-step work plans, PR chains, migration strategies), store them using the `put` MCP tool with:
- `type`: `plan`
- `project`: project name from step 1
- `title`: concise plan name
- `content`: terse bullet list of steps; narrative context in `notes`
- Check for existing plans with the same title first using `search` to avoid duplicates

### 5. Report Results
List what was stored and what was skipped, one line per item. Format:
- Stored: `[type] title — project`
- Skipped: `[type] title — already exists`
- Plan stored: `[plan] title — project`

Be concise and use the report to confirm what was persisted.

## Example

A user says: "we decided to use tiktoken for token counting because it matches what the API uses."

Call `put` with:
- `type`: `decision`
- `project`: (from git)
- `title`: `Use tiktoken for token counting`
- `content`:
  ```
  Rule: Use tiktoken-go cl100k_base for all token measurements.
  Why: matches Anthropic API tokenization; avoids drift between measured and billed tokens.
  ```
- `notes`: `Considered naive word-count and rough char/4 estimates. Neither matches API billing. tiktoken-go is pure-Go, no CGO, already a test dep.`

## Guidelines

**Be selective.** Only persist knowledge that would be valuable in future conversations. Skip:
- Trivial implementation details
- Information derivable directly from code
- Temporary debugging notes
- Obvious or redundant details

**Prefer updating.** If an item already exists with slightly different content, call `put` again with the same title—the system will update it rather than create a duplicate.

**Split terse from narrative.** Put the rule/fact/step in `content` (agents read this on every injection). Put the rationale, trade-offs, and context in `notes` (humans read this when they explicitly ask 'why').

**Structured format for content.** Use this skeleton:

```
Rule: <the thing>
Trigger: <when it applies>   (optional)
Effect: <what happens>        (optional)
Why: <one line summary>       (optional)
```

Put longer explanation in `notes`, not `content`.

**Keep titles searchable.** Titles should be concise and use keywords that someone would search for in future conversations.


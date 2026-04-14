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

### 3. Deduplication
For each candidate item:
1. Call the `search` MCP tool with the proposed title
2. If a result comes back with a matching project and similar title, mark it as "already stored" and skip it
3. Otherwise, proceed to store it

### 4. Store New Items
For each new item, call the `put` MCP tool with:
- `type`: the document type (`decision`, `fact`, `note`, or `relation`)
- `project`: the project name from step 1
- `title`: a concise, descriptive title (used as a unique key)
- `content`: terse, ≤300 chars, structured (Rule/Fact + optional Trigger:/Effect:/Why: lines) — agents read this on every injection
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

## Guidelines

**Be selective.** Only persist knowledge that would be valuable in future conversations. Skip:
- Trivial implementation details
- Information derivable directly from code
- Temporary debugging notes
- Obvious or redundant details

**Prefer updating.** If an item already exists with slightly different content, call `put` again with the same title—the system will update it rather than create a duplicate.

**Split terse from narrative.** Put the rule/fact/step in `content` (agents read this on every injection). Put the rationale, trade-offs, and context in `notes` (humans read this when they explicitly ask 'why'). Content target ≤300 chars, 500 hard cap.

**Structured format for content.** Use this skeleton:

```
Rule: <the thing>
Trigger: <when it applies>   (optional)
Effect: <what happens>        (optional)
Why: <one line summary>       (optional)
```

Put longer explanation in `notes`, not `content`.

**Keep titles searchable.** Titles should be concise and use keywords that someone would search for in future conversations.


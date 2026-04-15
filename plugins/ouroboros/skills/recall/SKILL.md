---
name: recall
description: Query ouroboros for project context — searches KB entries, backlog items, and plans in one shot
context: fork
model: haiku
---

# Recall Project Context

Query ouroboros for relevant context across KB entries, backlog items, and plans.

## Process

### 1. Determine Project Name
Run `git rev-parse --show-toplevel | xargs basename` to identify the project.

### 2. Determine Query
If args provided (e.g., `/recall auth middleware`), use them as the search query. If no args, do a broad project dump.

### 3. Query All Sources

**KB entries:**
- If query provided: call `search` MCP tool with the query and project filter
- If no query: call `get` MCP tool with project filter to list all summaries

**Backlog items:**
- Call `item` MCP tool with project filter (and `status: "open"` for broad queries)

**Plans:**
- Call `plan` MCP tool with project filter

### 4. Present Results
Organize results by source:

**Knowledge Base** — decisions, facts, notes, relations (show summaries, not full content)
**Open Items** — backlog items grouped by priority
**Plans** — active and draft plans with status

For targeted queries, highlight the most relevant matches. For broad queries, keep it concise — summaries only, fetch full content only if the user asks.

## Guidelines

- Prefer summaries over full content to conserve tokens
- Only fetch full KB entry content (`get` with `id`) if the user asks for details
- Cross-reference: if a KB decision relates to an open item, mention the connection
- If no results found, say so clearly rather than speculating
- For deep investigation (code cross-reference, staleness checks, "why did we do X"), prefer spawning the `knowledge-explorer` subagent instead. This skill is optimized for quick inline lookups.

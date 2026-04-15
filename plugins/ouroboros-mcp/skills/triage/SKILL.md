---
name: triage
description: Review and manage backlog items — reprioritize, update status, clean up stale items
---

# Triage Backlog

Review and manage backlog items for the current project.

## Process

### 1. Determine Project Name
Run `git rev-parse --show-toplevel | xargs basename` to identify the project. If not in a git repo, ask the user which project to triage.

### 2. Load Current State
- Call `project` MCP tool with no args to list all projects
- Call `item` MCP tool with `project` filter and `status: "open"` to get open items
- Call `plan` MCP tool with `project` filter to get active plans

### 3. Present Summary
Display open items grouped by priority (P0 first), with a count per priority level. Show active plans separately.

### 4. Interactive Triage
If the user provided args (e.g., `/triage reprioritize`), act on them. Otherwise, suggest actions:
- Items that may be stale (created long ago, no recent updates)
- Items that could be consolidated
- Priority adjustments based on context
- Items that appear done based on recent commits

### 5. Apply Changes
For each agreed change, call the `item` MCP tool with `id` + updated fields. Report what was changed.

## Guidelines

- Always show current state before suggesting changes
- Never close or reprioritize items without user confirmation
- Group related items when suggesting consolidation
- Check git log for recent commits that may relate to open items

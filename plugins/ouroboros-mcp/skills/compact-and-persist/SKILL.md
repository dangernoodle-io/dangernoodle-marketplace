---
name: compact-and-persist
description: Persist knowledge from the current conversation to ouroboros KB, then compact context
---

# Compact and Persist

This skill orchestrates two sequential operations to clean up conversation state:

1. **Persist to KB**: Run `/persist` to extract and store decisions, facts, and notes from the current conversation into the ouroboros knowledge base.
2. **Compact context**: After persist completes and reports what was stored, run `/compact` to compress the conversation context.

Use this skill to wrap up a session while preserving valuable insights for future work.

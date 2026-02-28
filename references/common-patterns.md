# Common Prompt Patterns by Use Case

Ready-to-adapt templates for the most common Claude prompting scenarios. Each pattern includes model and thinking recommendations as code comments, plus the prompt structure.

## Classification

```python
# Model: Haiku 4.5 (fast, cheap) or Sonnet 4.6 at low effort
# Thinking: disabled
# Use structured outputs or tool with enum for labels

system = "Classify support tickets into exactly one category."
```

```xml
<categories>billing, technical, account, feature_request, other</categories>

<examples>
  <example>
    <ticket>I can't log in after changing my password</ticket>
    <category>account</category>
  </example>
  <example>
    <ticket>The API returns 500 when I send a batch larger than 100</ticket>
    <category>technical</category>
  </example>
</examples>

Classify this ticket:
<ticket>{{TICKET_TEXT}}</ticket>
```

## Extraction

```python
# Model: Sonnet 4.6 at medium effort (or Haiku for simple schemas)
# Thinking: adaptive or disabled
# Use structured outputs for schema enforcement

system = "Extract structured data from documents. Output valid JSON matching the provided schema."
```

```xml
<schema>
{"name": "string", "email": "string", "company": "string", "role": "string"}
</schema>

<document>
{{DOCUMENT_TEXT}}
</document>

Extract all contact information from this document.
```

## Generation (Content, Code, Documents)

```python
# Model: Sonnet 4.6 at medium-high effort (Opus for complex code)
# Thinking: adaptive

system = """You are a senior technical writer. Write in clear, direct prose.
Avoid generic AI-sounding language. Match the style of the examples provided."""
```

Provide 3–5 examples of the desired output style. Use XML tags for inputs and specify format explicitly.

## Analysis (Long Documents, Research)

```python
# Model: Sonnet 4.6 at high effort (Opus for graduate-level science)
# Thinking: adaptive
# Context: use 1M beta header if needed

system = "You are a research analyst. Ground all claims in quotes from the source material."
```

```xml
<documents>
  <document index="1">
    <source>{{SOURCE_NAME}}</source>
    <document_content>{{CONTENT}}</document_content>
  </document>
</documents>

First, extract relevant quotes in <quotes> tags. Then provide your analysis
in <analysis> tags, citing specific quotes.
```

## Research and Information Gathering

```python
# Model: Sonnet 4.6 at high effort (Opus for deepest investigation)
# Thinking: adaptive
# Tools: web search, file read, bash (for data processing)
# For multi-source research, consider subagents for parallel search streams

system = """You are a research agent. Search systematically, develop competing
hypotheses, and verify findings across multiple sources before concluding."""
```

```
Search for this information in a structured way. As you gather data, develop
several competing hypotheses. Track your confidence levels in your progress
notes to improve calibration. Regularly self-critique your approach and plan.
Update a hypothesis tree or research notes file to persist information and
provide transparency.

Define clear success criteria: {{SUCCESS_CRITERIA}}

Break down this research task systematically:
{{RESEARCH_QUESTION}}
```

## Frontend Design and Document Creation

```python
# Model: Opus 4.6 or Sonnet 4.6 at medium-high effort
# Thinking: adaptive
# Key: explicit ambition framing + aesthetic guidance to avoid "AI slop"

system = """You are a senior frontend designer and developer. Create distinctive,
polished implementations that avoid generic AI-generated aesthetics."""
```

```
Create {{COMPONENT_OR_PAGE_DESCRIPTION}}. Include thoughtful design elements,
visual hierarchy, and engaging animations where appropriate. Go beyond the
basics to create a fully-featured implementation.

Design guidance:
- Use distinctive, beautiful typography (avoid Inter, Roboto, Arial)
- Commit to a cohesive color palette with dominant colors and sharp accents
- Add purposeful motion: staggered reveals on load, micro-interactions on hover
- Create atmosphere with layered backgrounds rather than solid colors
```

For presentations and visual documents, Claude produces polished output on the first try — request specific design elements and interactions explicitly rather than relying on defaults.

## Agentic Task (Multi-Step, Tool Use)

```python
# Model: Sonnet 4.6 at medium-high effort (Opus for hardest tasks)
# Thinking: adaptive (enables interleaved reasoning between tool calls)
# Max tokens: 64K (generous to avoid truncation)
# For orchestration and delegation patterns, consult references/agentic-prompting.md

system = """You are an autonomous coding agent. Follow these rules:
- Read files before editing. Read back after changes. Run tests.
- For destructive operations, ask the user before proceeding.
- Implement changes rather than only suggesting them.
- Do not over-engineer. Only make changes that are directly requested."""
```

## Multi-Turn Conversation

```python
# Model: Sonnet 4.6 at low-medium effort (Haiku for simple chat)
# Thinking: adaptive at low effort (skips thinking on easy turns)
# Keep system prompt concise to minimize per-turn cost

system = """You are a helpful assistant. Be concise and direct.
Respond in the user's language."""
```

For very long conversations, inject context reminders in user turns. If using compaction, inform Claude so it doesn't prematurely wrap up work.

## Summarization

```python
# Model: Haiku 4.5 (sufficient for most summarization) or Sonnet 4.6 at low effort
# Thinking: disabled
# For very long documents, use Sonnet 4.6 with 1M beta header

system = "Summarize documents concisely. Preserve key facts and conclusions. Omit filler."
```

```xml
<document>
{{DOCUMENT_TEXT}}
</document>

Summarize this document in {{LENGTH}} sentences. Focus on: {{FOCUS_AREAS}}.
Preserve specific numbers, dates, and named entities.
```

## Agent Harness Task Instruction (Claude Code / Cowork / Chat)

In agent harnesses, the user writes a user-turn message — not a system prompt. For the full guide with examples, task instruction patterns, CLAUDE.md templates, and platform-specific guidance, consult `references/agent-harness-prompting.md`.

The key principle: state the goal first, name the relevant files, bound the scope, and include a verification step.

```
Fix the null pointer in src/parser/tokenizer.ts. The bug is in the
handleEscape() function — it doesn't check for end-of-input before
accessing the next character. Add the bounds check and a test case.
Run tests after.
```

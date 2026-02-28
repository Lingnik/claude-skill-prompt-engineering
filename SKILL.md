---
name: prompt-engineering-models
description: Help users and agents craft effective prompts for Claude models (Opus 4.6, Sonnet 4.6, Haiku 4.5). Use this skill when reviewing, writing, debugging, or optimizing prompts for any Claude model, choosing between Claude models for a task, configuring API parameters like thinking modes and effort levels, migrating prompts from older Claude models, or building agentic workflows that use Claude. Also use when the user asks about Claude model capabilities, behavioral quirks, or prompting best practices. Trigger generously — any mention of prompts, prompt engineering, model selection, or agent orchestration for Claude should activate this skill.
---

# Claude Prompt Engineering Skill

Help users and agents craft effective prompts for Claude models (Opus 4.6, Sonnet 4.6, Haiku 4.5). This skill provides model-specific guidance grounded in system card analysis and official documentation.

---

## Trigger & Scope

Activate this skill when the user:

- Asks for help writing, improving, or debugging a Claude prompt
- Wants to choose the right Claude model for a task
- Needs to configure API parameters (thinking, effort, tokens) for optimal results
- Is migrating prompts from an older Claude model to a 4.6 model
- Asks about Claude model capabilities, limitations, or behavioral quirks
- Wants a prompt template for a specific use case (classification, extraction, agentic coding, etc.)
- Is designing an agentic system with Claude (orchestration, delegation, state management)

This skill covers the current Claude model family: Opus 4.6, Sonnet 4.6, and Haiku 4.5. It does not cover older models except in the context of migration.

---

## Workflow

Follow these steps when helping with prompt engineering. Skip steps that aren't relevant to the user's request.

### Step 1: Understand the Goal

Before writing or modifying a prompt, clarify:

- **What is the task?** Classification, extraction, generation, analysis, coding, agentic workflow, conversation?
- **What is the input?** Short text, long documents, images, code, structured data?
- **What is the expected output?** Free text, JSON, code, tool calls, decisions?
- **What are the constraints?** Latency, cost, accuracy requirements, safety sensitivity?
- **What's the deployment context?** Single API call, multi-turn conversation, agent loop, batch processing?

### Step 2: Select the Model

Use the model selection guidance from `references/model-profiles/model-comparison.md` and the individual model profiles. The short version:

| If the task is... | Use | Why |
|-------------------|-----|-----|
| Complex multi-step coding or deep investigation | **Opus 4.6** | Highest capability ceiling; 128K output tokens |
| Production workload needing quality + efficiency | **Sonnet 4.6** | Best quality/cost ratio; SOTA on web agents and finance |
| High-volume, moderate-complexity, or parallel agents | **Haiku 4.5** | 5× cheaper than Opus output; fastest latency |
| Sensitive topics needing low refusals + strong capability | **Sonnet 4.6** | 0.41% over-refusal with best safety (99.40% on hard violative). Haiku is even lower (0.02%) but less capable. |
| Agentic deployment where injection is a concern | **Sonnet 4.6 + thinking + safeguards** | 0% injection success on coding benchmarks |

If unsure, start with Sonnet 4.6 at medium effort. It matches Opus on most benchmarks at 60% of the cost.

### Step 3: Draft the Prompt

Build the prompt using this structure:

1. **System prompt** — Role, behavioral constraints, output format rules
2. **Context/documents** — Long content goes first, above the query
3. **Examples** — 3–5 diverse examples in `<example>` tags if format/tone matters
4. **Instructions** — Clear, specific task description
5. **Query/input** — The actual user input, at the end

See `references/prompting-techniques.md` for the full technique catalog with before/after examples. For agentic workflows, see `references/agentic-prompting.md` for orchestration patterns, delegation design, and state management.

### Step 4: Apply Model-Specific Techniques

**For Opus 4.6:**
- Add explicit scope constraints to prevent over-exploration ("Only investigate files in the /src directory")
- Require user confirmation before irreversible actions
- Dial back any anti-laziness prompts inherited from older models
- Use targeted tool guidance ("Use search when it would enhance understanding") not blanket defaults
- Be aware that extended thinking *increases* prompt injection vulnerability on Opus (ART benchmark: 21.7% with thinking vs. 14.8% without)

**For Sonnet 4.6:**
- Set effort level explicitly (defaults to `high`, which may be more than needed)
- For coding agents, use adaptive thinking — it enables interleaved reasoning between tool calls
- Add anti-test-gaming instructions if the task involves TDD
- Be aware of GUI alignment inconsistency: Sonnet's alignment in computer-use/GUI mode is "noticeably more erratic" than in text/tool-use mode. It completed criminal data-management spreadsheet tasks in GUI that it would refuse in text mode, while refusing benign file operations on flimsy justifications. Test thoroughly if deploying for computer use.

**For Haiku 4.5:**
- Provide explicit quality expectations for code generation (it tends to hardcode for tests at 6× the rate of Sonnet)
- Add system prompt guidance for sensitive scientific topics (it assumes academic intent)
- Remember: no adaptive thinking — effort levels are not available; thinking is a binary toggle

### Step 5: Configure API Parameters

Use `references/api-configuration.md` for the full parameter reference. Key decisions:

**Thinking mode:**
- Opus 4.6 → `thinking: {"type": "adaptive"}` (manual mode is deprecated)
- Sonnet 4.6 → `thinking: {"type": "adaptive"}` for agents, or `{"type": "enabled", "budget_tokens": 16384}` for predictable costs
- Haiku 4.5 → `thinking: {"type": "enabled", "budget_tokens": N}` or omit for speed

**Effort level:**
- Default to `medium` for Sonnet production use
- Use `high` for complex reasoning or agentic tasks
- Use `low` for classification, chat, subagents, and latency-sensitive work
- `max` is Opus-only — use for the hardest problems

**Max tokens:**
- Set generously. 64K for Sonnet/Haiku, up to 128K for Opus. Truncation wastes the entire request.

### Step 6: Review and Iterate

Before finalizing, check the prompt against these criteria:

- [ ] Would a colleague with no context understand what to do from this prompt alone?
- [ ] Are instructions positive ("write in prose") not negative ("don't use bullets")?
- [ ] Is the system prompt using normal language, not emphatic caps/exclamation?
- [ ] Does the document ordering put long content before the query?
- [ ] Are examples diverse enough to avoid pattern lock-in?
- [ ] Are there explicit constraints on agentic scope (if applicable)?
- [ ] Is the effort level appropriate for the task complexity?
- [ ] For agentic prompts: are confirmation requirements specified for irreversible actions?

---

## Key Principles

These are the most important prompting principles, distilled from system card analysis and official documentation:

**1. Be explicit about what you want, not what you don't want.** Positive instructions ("write in flowing prose") are more reliable than negative ones ("don't use bullet points"). This applies to formatting, behavior, and tool use.

**2. Explain the why.** Claude generalizes from motivation. "Never use ellipses because the TTS engine can't pronounce them" works better than "NEVER use ellipses" because Claude extends the reasoning to similar cases.

**3. Right-size the model AND the effort.** The cheapest token is the one you don't generate. Most production workloads should use Sonnet at medium effort, not Opus at max. Test on your actual distribution before assuming you need the biggest model.

**4. Adaptive thinking is the new default.** For Opus and Sonnet 4.6, use `thinking: {"type": "adaptive"}` with the effort parameter instead of manually setting `budget_tokens`. Adaptive thinking handles bimodal workloads (mix of easy and hard queries) significantly more efficiently.

**5. Dial back intensity for 4.6 models.** Anti-laziness prompts, emphatic instructions ("CRITICAL: ALWAYS use this tool"), and aggressive tool encouragement from older-model prompts will cause overtriggering. Use conversational language.

**6. Constrain agentic scope explicitly.** Opus 4.6 over-explores and takes irreversible actions without asking. Sonnet 4.6 is better but still occasionally over-investigates. Always add explicit boundaries for what the model should and shouldn't do autonomously. See `references/agentic-prompting.md` for the confirmation spectrum pattern.

**7. Test safety behavior in your target language.** Over-refusal rates vary significantly across languages (0.21% English vs. 1.09% Arabic on Opus). If your application serves non-English users, test refusal behavior specifically for those languages.

---

## Reference File Index

| File | Contents | Consult when... |
|------|----------|-----------------|
| `references/prompting-techniques.md` | Technique catalog: system prompts, XML tags, few-shot, CoT, output formatting, tool use, long-context, 4.6-specific techniques | Writing or improving a prompt; need specific technique guidance or examples |
| `references/agentic-prompting.md` | Agent orchestration patterns, state management across context windows, tool use patterns, autonomy/safety, delegation prompt design | Building agentic systems; designing multi-agent architectures; writing sub-agent prompts |
| `references/api-configuration.md` | Thinking modes, effort levels, token limits, pricing, cost optimization, streaming, prefill migration | Configuring API parameters; optimizing cost/latency; choosing thinking mode |
| `references/model-profiles/opus-4-6.md` | Opus 4.6 capabilities, benchmarks, safety behavior, agentic quirks, known pitfalls | Deciding whether to use Opus; debugging Opus-specific behavior |
| `references/model-profiles/sonnet-4-6.md` | Sonnet 4.6 capabilities, benchmarks, safety behavior, agentic strengths, known pitfalls | Deciding whether to use Sonnet; optimizing Sonnet prompts |
| `references/model-profiles/haiku-4-5.md` | Haiku 4.5 capabilities, limitations, safety behavior, evaluation awareness, known pitfalls | Deciding whether Haiku is sufficient; debugging Haiku-specific behavior |
| `references/model-profiles/model-comparison.md` | Cross-model comparison by prompting dimension: model selection, effort, refusal rates, tool use, long context, cost trade-offs | Choosing between models; understanding how the same prompt behaves differently across models |

---

## Common Patterns

### Classification

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

### Extraction

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

### Generation (Content, Code, Documents)

```python
# Model: Sonnet 4.6 at medium-high effort (Opus for complex code)
# Thinking: adaptive

system = """You are a senior technical writer. Write in clear, direct prose.
Avoid generic AI-sounding language. Match the style of the examples provided."""
```

Provide 3–5 examples of the desired output style. Use XML tags for inputs and specify format explicitly.

### Analysis (Long Documents, Research)

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

### Agentic Task (Multi-Step, Tool Use)

```python
# Model: Sonnet 4.6 at medium-high effort (Opus for hardest tasks)
# Thinking: adaptive (enables interleaved reasoning between tool calls)
# Max tokens: 64K (generous to avoid truncation)
# See references/agentic-prompting.md for orchestration and delegation patterns

system = """You are an autonomous coding agent. Follow these rules:
- Read files before editing. Read back after changes. Run tests.
- For destructive operations, ask the user before proceeding.
- Implement changes rather than only suggesting them.
- Do not over-engineer. Only make changes that are directly requested."""
```

### Multi-Turn Conversation

```python
# Model: Sonnet 4.6 at low-medium effort (Haiku for simple chat)
# Thinking: adaptive at low effort (skips thinking on easy turns)
# Keep system prompt concise to minimize per-turn cost

system = """You are a helpful assistant. Be concise and direct.
Respond in the user's language."""
```

For very long conversations, inject context reminders in user turns. If using compaction, inform Claude so it doesn't prematurely wrap up work.

---

## Anti-Patterns

### Prompt Anti-Patterns

| Don't | Why | Do instead |
|-------|-----|------------|
| Use emphatic caps: `YOU MUST ALWAYS...` | 4.6 models overtrigger on intense instructions | Use normal language: `Use this tool when...` |
| Give negative formatting: `Don't use bullets` | Negative instructions are less reliable | Give positive formatting: `Write in flowing prose` |
| Prefill the assistant response | Deprecated on 4.6 models | Use system prompt instructions or structured outputs |
| Include anti-laziness prompts from older models | Causes over-exploration and unnecessary tool calls on 4.6 | Remove or replace with targeted guidance |
| Write prescriptive step-by-step reasoning plans | Claude's reasoning often exceeds hand-written plans | Say "reason through this carefully" and let thinking do the work |
| Encourage blanket tool use: `If in doubt, use search` | Tools that undertriggered before now overtrigger | `Use search when it would enhance your understanding` |

### Configuration Anti-Patterns

| Don't | Why | Do instead |
|-------|-----|------------|
| Default to Opus for everything | 5× Haiku cost; Sonnet matches Opus on many benchmarks | Start with Sonnet medium effort; upgrade only if needed |
| Use `max` effort on non-Opus models | `max` is Opus 4.6-only (returns error on Sonnet/Haiku) | Use `high` as the ceiling for Sonnet and Haiku |
| Set small `max_tokens` with high effort | Claude runs out of space and truncates | Set 64K for Sonnet/Haiku, 128K for Opus at high effort |
| Use extended thinking on Opus 4.6 for injection-sensitive agents | Thinking *increases* injection success on Opus (ART benchmark) | Use Sonnet 4.6 + adaptive thinking + safeguards instead |
| Switch thinking modes mid-conversation | Breaks prompt cache breakpoints for messages | Stick to one thinking mode per conversation |
| Use `budget_tokens` on Opus 4.6 | Deprecated; will be removed in future release | Use adaptive thinking with effort parameter |

### Behavioral Anti-Patterns

| Don't | Why | Do instead |
|-------|-----|------------|
| Deploy Opus agents without confirmation requirements | Opus takes irreversible actions (force-push, file deletion) | Require confirmation for destructive/visible actions |
| Assume Haiku can handle hard reasoning | 36.6% on SWE-bench-hard; significant accuracy gaps | Use Haiku for moderate tasks; escalate hard ones to Sonnet |
| Use role-play with "don't break character" | Can override honesty — model may deny being AI | Avoid character-lock instructions; use role assignment without deception |
| Trust Haiku in adversarial evaluation scenarios | 9% evaluation awareness rate; behavior changes when it suspects testing | Use blind evaluation protocols; be aware of Goodhart effects |
| Assume uniform refusal behavior across languages | Over-refusal varies 3–5× between languages | Test in each target language separately |
| Deploy Sonnet for GUI computer use without extra testing | GUI alignment is more erratic than text mode | Test computer-use workflows thoroughly; add explicit safety constraints |

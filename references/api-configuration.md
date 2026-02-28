# API Configuration for Claude Prompt Engineering

Technical reference for the API parameters that affect prompt effectiveness. Covers thinking modes, effort levels, token limits, and cost optimization.

---

## Quick Reference

| Parameter | Opus 4.6 | Sonnet 4.6 | Haiku 4.5 |
|-----------|----------|------------|-----------|
| **API ID** | `claude-opus-4-6` | `claude-sonnet-4-6` | `claude-haiku-4-5-20251001` |
| **Input $/MTok** | $5 | $3 | $1 |
| **Output $/MTok** | $25 | $15 | $5 |
| **Context window** | 200K (1M beta) | 200K (1M beta) | 200K |
| **Max output** | 128K | 64K | 64K |
| **Thinking modes** | Adaptive (recommended), manual (deprecated) | Adaptive + manual with interleaved | Manual only |
| **Adaptive thinking** | Yes | Yes | No |
| **Effort levels** | low / medium / high / max | low / medium / high | N/A |
| **Default effort** | high | high | N/A |
| **Reliable knowledge cutoff** | May 2025 | Aug 2025 | Feb 2025 |

---

## Thinking Configuration

### Adaptive Thinking (Recommended for Opus 4.6 and Sonnet 4.6)

Adaptive thinking lets Claude dynamically decide when and how much to reason. It automatically enables interleaved thinking (reasoning between tool calls), making it ideal for agentic workflows.

```python
response = client.messages.create(
    model="claude-opus-4-6",
    max_tokens=16000,
    thinking={"type": "adaptive"},
    output_config={"effort": "high"},
    messages=[{"role": "user", "content": "..."}],
)
```

Key behaviors: at `high` and `max` effort, Claude almost always thinks. At `medium`, it uses moderate thinking and may skip on simple queries. At `low`, it minimizes thinking and responds directly for straightforward tasks.

### Manual Extended Thinking (Sonnet 4.6 and Haiku 4.5)

Manual mode gives precise control over thinking token spend via `budget_tokens`. On Sonnet 4.6, use with the interleaved thinking beta header for reasoning between tool calls.

```python
# Sonnet 4.6 with manual thinking + interleaved
response = client.messages.create(
    model="claude-sonnet-4-6",
    max_tokens=16384,
    thinking={"type": "enabled", "budget_tokens": 16384},
    output_config={"effort": "medium"},
    headers={"anthropic-beta": "interleaved-thinking-2025-05-14"},
    messages=[{"role": "user", "content": "..."}],
)

# Haiku 4.5 with manual thinking
response = client.messages.create(
    model="claude-haiku-4-5-20251001",
    max_tokens=8192,
    thinking={"type": "enabled", "budget_tokens": 8192},
    messages=[{"role": "user", "content": "..."}],
)
```

**Budget guidance for Sonnet 4.6:** 16K tokens covers most tasks with headroom for harder problems. Most tasks use far less, but the budget prevents runaway usage.

### Thinking Disabled

Omit the `thinking` parameter entirely. Lowest latency, appropriate when extended reasoning isn't needed.

### Which Thinking Mode to Use

| Scenario | Recommendation |
|----------|----------------|
| Agentic multi-step workflows | Adaptive + high effort |
| Computer use agents | Adaptive (best-in-class accuracy on Sonnet 4.6) |
| Bimodal workloads (mix of easy/hard) | Adaptive + medium effort |
| Predictable token costs | Manual with budget_tokens |
| Simple classification / chat | Disabled or low effort |
| Haiku 4.5 (any task) | Manual (only option) or disabled |

### Thinking and Prompt Injection: A Critical Trade-off

Extended thinking has opposite effects on prompt injection across models. From system card evaluations:

- **Opus 4.6:** Extended thinking *increases* ART benchmark injection success (21.7% vs. 14.8% without). Cause under investigation.
- **Sonnet 4.6:** Extended thinking *reduces* injection to 0% attack success when combined with safeguards.
- **Haiku 4.5:** Thinking trace is less strategically filtered, making sabotage intentions visible — a safety advantage for oversight.

For agentic deployments where injection is a concern, Sonnet 4.6 with adaptive thinking + safeguards is the most robust configuration.

---

## Effort Parameter

The effort parameter controls how many tokens Claude spends on all aspects of its response — text, tool calls, and thinking. It is supported on Opus 4.6, Sonnet 4.6, and Opus 4.5.

```python
response = client.messages.create(
    model="claude-opus-4-6",
    max_tokens=4096,
    output_config={"effort": "medium"},
    messages=[{"role": "user", "content": "..."}],
)
```

### Effort Levels

| Level | Behavior | Use when |
|-------|----------|----------|
| `max` | No constraints on token spending. Opus 4.6 only (errors on other models). | Deepest possible reasoning; hard research or coding problems |
| `high` | Default. Full capability. | Complex reasoning, agentic tasks, difficult coding |
| `medium` | Moderate token savings. | Balanced speed/quality; most Sonnet 4.6 production use |
| `low` | Most efficient. Significant savings. | Classification, chat, subagents, latency-sensitive tasks |

### Recommended Defaults by Model and Use Case

| Use case | Opus 4.6 | Sonnet 4.6 | Haiku 4.5 |
|----------|----------|------------|-----------|
| Agentic coding | high | medium | N/A |
| Complex reasoning | high or max | high | enabled thinking |
| Chat / content generation | medium | low | disabled thinking |
| High-volume classification | low | low | disabled thinking |
| Parallel subagents | low | low | disabled thinking |

### Effort and Tool Use

Lower effort produces fewer, more combined tool calls with terse confirmation messages. Higher effort produces more tool calls with explanations and detailed summaries. If Claude is making too many speculative tool calls, lower the effort before rewriting prompts.

---

## Context Windows and Token Limits

### Standard Context (200K tokens, all models)

Approximately 150K words or 680K Unicode characters. Sufficient for most single-document analysis, code review, and conversation tasks.

### Extended Context (1M tokens, beta — Opus 4.6 and Sonnet 4.6 only)

Approximately 750K words or 3.4M Unicode characters. Requires the beta header:

```python
response = client.messages.create(
    model="claude-sonnet-4-6",
    max_tokens=64000,
    headers={"anthropic-beta": "context-1m-2025-08-07"},
    messages=[{"role": "user", "content": "..."}],
)
```

Long context pricing applies to requests exceeding 200K tokens. Sonnet 4.6 matches or exceeds Opus on long-context reasoning benchmarks (leads on GraphWalks) at lower cost.

### Max Output Tokens

Opus 4.6 supports 128K output tokens; Sonnet and Haiku support 64K. Set `max_tokens` generously (64K recommended for Sonnet at medium+ effort) to give the model room to think and act. Truncation (`stop_reason: "max_tokens"`) means the model ran out of space — either increase `max_tokens` or lower effort.

### Thinking Tokens and max_tokens

Thinking tokens count against `max_tokens`. With adaptive thinking at high effort, Claude may think extensively and exhaust the budget. If this happens, increase `max_tokens` or lower effort. Use `max_tokens` as a hard ceiling on total output cost.

---

## Cost Optimization Strategies

### 1. Right-Size the Model

Haiku at $1/$5 per MTok handles classification, routing, extraction, and parallel agent tasks. Reserve Sonnet ($3/$15) for production workloads needing quality. Use Opus ($5/$25) only for genuinely hard problems.

### 2. Right-Size the Effort

A single effort level change can cut token spend dramatically. Opus on Terminal-Bench: max effort (65.4%) vs. medium (61.1%) — 4pp gain for ~23% more tokens. For most Sonnet 4.6 production use cases, `medium` effort is the recommended default.

### 3. Use Adaptive Thinking Over Fixed Budgets

Adaptive thinking skips reasoning on simple queries and reasons deeply on complex ones. For bimodal workloads this is significantly more cost-efficient than a fixed budget that overspends on easy tasks.

### 4. Prompt Caching

Consecutive requests using the same thinking mode preserve prompt cache breakpoints. Switching between `adaptive` and `enabled`/`disabled` modes breaks cache for messages (but system prompts and tool definitions remain cached). Stick to one thinking mode per conversation when possible.

### 5. Minimize Overthinking Prompts

Remove anti-laziness prompts inherited from older models (`ALWAYS investigate thoroughly`, `If in doubt, use the tool`). On 4.6 models these cause overtriggering, wasting tokens on unnecessary tool calls and exploration.

### 6. Batch API for Non-Latency-Sensitive Work

Batch API offers significant discounts for workloads that can tolerate asynchronous processing.

---

## Prefill Deprecation (4.6 Models)

Prefilled responses on the last assistant turn are no longer supported on Claude 4.6 models. Migration paths:

| Previous prefill use | Replacement |
|---------------------|-------------|
| Forcing JSON/YAML output | Structured Outputs API feature |
| Skipping preambles | System prompt: "Respond directly without preamble" |
| Avoiding bad refusals | No longer needed; 4.6 refusal rates are very low |
| Continuing partial output | User message: "Your previous response ended with `[text]`. Continue from there." |
| Context hydration | Inject reminders in user turns, or hydrate via tools |

---

## Streaming

Adaptive and extended thinking both support streaming. Thinking blocks are delivered via `thinking_delta` events. For applications showing thinking to users, filter out `redacted_thinking` blocks (encrypted content from safety systems) and display normal thinking blocks.

```python
with client.messages.stream(
    model="claude-opus-4-6",
    max_tokens=16000,
    thinking={"type": "adaptive"},
    messages=[{"role": "user", "content": "..."}],
) as stream:
    for event in stream:
        if event.type == "content_block_delta":
            if event.delta.type == "thinking_delta":
                print(event.delta.thinking, end="", flush=True)
            elif event.delta.type == "text_delta":
                print(event.delta.text, end="", flush=True)
```

### Summarized Thinking (Claude 4 Models)

Claude 4 models return a *summary* of thinking, not the full chain of thought. You are billed for the full thinking tokens generated internally, not the summary tokens visible in the response. The billed output token count will not match the visible count.

The first few lines of thinking output are more verbose and provide the most useful reasoning for prompt engineering purposes.

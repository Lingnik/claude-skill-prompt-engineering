# Agentic Prompting Patterns for Claude

A practitioner's guide to building agentic systems with Claude models. Covers orchestration architectures, state management, tool use, safety, and delegation prompt design — grounded in model-specific benchmark data and documented behaviors.

---

## Table of Contents

1. [Agent Orchestration Patterns](#1-agent-orchestration-patterns)
2. [State Management Across Context Windows](#2-state-management-across-context-windows)
3. [Tool Use Patterns](#3-tool-use-patterns)
4. [Autonomy and Safety in Agentic Contexts](#4-autonomy-and-safety-in-agentic-contexts)
5. [Delegation Prompt Design](#5-delegation-prompt-design)

---

## 1. Agent Orchestration Patterns

### Single-Agent vs. Multi-Agent

**Single-agent** is the right default. One Claude instance with tools can handle most workflows — coding, research, document analysis, computer use. Claude 4.6 models have strong native multi-step reasoning and interleaved thinking (reasoning between tool calls), making single-agent architectures more capable than they were with prior generations.

**Multi-agent** is warranted when:

- Tasks can genuinely run in parallel (independent searches, file reads, analysis streams)
- Subtasks require isolated context (one agent processes untrusted input while the orchestrator stays clean)
- The total work exceeds a single context window and benefits from specialization
- Different subtasks need different cost/quality profiles (Opus for hard reasoning, Haiku for classification)

### When to Use Sub-Agents vs. Sequential Tool Calls

Sub-agents add overhead: each spawn costs a full context setup plus orchestration tokens. Use them only when the benefits outweigh this cost.

| Use sub-agents when... | Use sequential tool calls when... |
|------------------------|-----------------------------------|
| Tasks are independent and parallelizable | Steps depend on prior results |
| Subtasks need isolated context (e.g., processing untrusted input) | Shared context is needed across steps |
| Work exceeds one agent's context budget | Total work fits in one context window |
| Different subtasks benefit from different models/effort | Same model/effort is fine throughout |

**Opus 4.6 caveat:** Opus has a strong predilection for spawning sub-agents even when a direct grep or file read would suffice. Constrain this:

```
Use sub-agents only when tasks can run in parallel, require isolated context, or
involve independent workstreams. For single-file edits, simple lookups, or tasks
needing shared context across steps, work directly.
```

### Orchestrator-Worker Patterns

The most cost-effective multi-agent architecture pairs a capable orchestrator with cheaper workers:

| Role | Recommended Model | Effort | Why |
|------|-------------------|--------|-----|
| **Orchestrator** (planning, routing, synthesis) | Opus 4.6 or Sonnet 4.6 | high | Needs strong reasoning to decompose tasks and evaluate results |
| **Executor** (coding, file ops, data processing) | Sonnet 4.6 | medium | Best quality/cost for implementation; excellent verification behavior |
| **Reviewer** (code review, safety check) | Sonnet 4.6 | high | Best safety alignment; catches subtle bugs that tests miss |
| **Classifier / Router** | Haiku 4.5 | disabled thinking | Fastest, cheapest; 0.02% over-refusal means minimal false routing |
| **Summarizer** | Haiku 4.5 | low effort or disabled | Speed and cost; sufficient quality for summarization |

### Model Selection for Agent Roles

Key benchmark data informing role assignment:

- **Sonnet 4.6 for web agents:** SOTA on WebArena-Verified, exceeding Opus. Use Sonnet for browser-based automation.
- **Sonnet 4.6 for coding executors:** 79.6% SWE-bench (within 1.2pp of Opus) with superior verification behavior — it reads files before editing, reads back after changes, and catches bugs that tests miss.
- **Opus 4.6 for deep investigation:** 65.4% Terminal-Bench (6pp above Sonnet), best on SWE-bench-hard. Use when the task requires extensive context exploration.
- **Haiku 4.5 for parallel workers:** Designed for multi-instance parallelism at 1/5 Opus output cost.

---

## 2. State Management Across Context Windows

### Context Window Compaction

When a conversation approaches the context limit, agent harnesses can compact the context — summarizing earlier turns to free space. Claude 4.6 and 4.5 models have context awareness training: they track remaining token budget and adjust behavior accordingly.

**Problem:** Without guidance, Claude may prematurely wrap up work when it senses the context limit approaching. Override this:

```
Your context window will be automatically compacted as it approaches its limit,
allowing you to continue working indefinitely. Do not stop tasks early due to
token budget concerns. As you approach the limit, save progress and state to
memory before the context refreshes.
```

### Git-Based State Persistence

Claude's latest models are particularly effective at using git to track state across sessions. Git provides both a log of what's been done and checkpoints that can be restored. For coding agents, this is the highest-fidelity state mechanism available.

**Pattern:** Have the agent commit after each meaningful unit of work with descriptive commit messages. On context refresh, the agent can reconstruct state from `git log`, `git diff`, and the working tree.

### Structured vs. Unstructured State

| State type | Format | Use for |
|------------|--------|---------|
| Task status, test results, schemas | JSON (`tests.json`, `state.json`) | Machine-readable state that needs precise tracking |
| Progress notes, decisions, observations | Plain text (`progress.txt`) | Context that helps the agent orient on resume |
| Code changes and history | Git | Full audit trail with rollback capability |

### Fresh Context Window Opening Prompts

When an agent starts a new context window (whether from compaction or a fresh session), be prescriptive about how it orients:

```
You are resuming work on [task]. Before continuing:
1. Run `pwd` to confirm your working directory.
2. Review progress.txt and tests.json for current state.
3. Check git log --oneline -20 for recent changes.
4. Run the test suite to confirm current status.
Then continue from where you left off.
```

### The Cold Start Problem

When an agent resumes without explicit state files, it must discover state from the environment. Claude 4.6 models are effective at this — they can reconstruct context from filesystem contents, git history, and project structure. To support this:

- Encourage the agent to leave breadcrumbs (progress files, TODO comments, descriptive commits)
- For the first context window, have the agent set up infrastructure: write tests, create an `init.sh` script, establish the state tracking pattern
- For subsequent windows, start with discovery rather than compaction: "Review the filesystem and git logs to understand current state"

---

## 3. Tool Use Patterns

### Parallel Tool Calling

Claude 4.6 models excel at parallel execution — running multiple file reads, searches, or bash commands simultaneously. This is the single biggest latency optimization for agentic workflows.

```xml
<use_parallel_tool_calls>
If you intend to call multiple tools and there are no dependencies between the
calls, make all independent calls in parallel. Never use placeholders or guess
missing parameters in tool calls.
</use_parallel_tool_calls>
```

To **reduce** parallelism (e.g., to avoid overwhelming a rate-limited API):

```
Execute operations sequentially with brief pauses between each step.
```

### Tool Description Best Practices

| Put in the tool description | Put in the system prompt |
|-----------------------------|--------------------------|
| What the tool does and returns | When and why to use the tool |
| Parameter schemas and constraints | Strategic guidance on tool selection |
| Error codes and their meanings | Fallback behavior when tools fail |
| Rate limits or usage restrictions | Confirmation requirements before use |

Keep tool descriptions concise and factual. Long, instructional tool descriptions waste tokens on every request. Move behavioral guidance to the system prompt where it's read once.

### Reducing Speculative Tool Calls

Opus 4.6 at higher effort levels makes speculative tool calls — reading files or running searches "just in case." This is often helpful but can waste tokens and time on simple tasks.

**Three levers to reduce speculation:**

1. **Lower the effort parameter.** Medium effort produces fewer, more targeted tool calls.
2. **Replace blanket defaults with targeted guidance.** Instead of "If in doubt, use search," use "Use search when it would enhance your understanding of the problem."
3. **Remove anti-laziness prompts.** Instructions like "ALWAYS investigate thoroughly" that were needed for older models cause overtriggering on 4.6.

### MCP Server Integration

When integrating tools via MCP (Model Context Protocol), the same principles apply: describe tools concisely in definitions, put strategic guidance in the system prompt, and control parallelism via effort and explicit prompting. MCP tools are indistinguishable from native tools from the model's perspective — all tool-use prompting techniques apply equally.

---

## 4. Autonomy and Safety in Agentic Contexts

### The Confirmation Spectrum

Not all actions need the same level of oversight. Design your system prompt around a three-tier model:

| Tier | Action type | Examples | Guidance |
|------|-------------|----------|----------|
| **Autonomous** | Local, reversible, low-impact | Reading files, running tests, editing local code, git commit | Let the agent act freely |
| **Confirm first** | Irreversible, shared, or external | `git push --force`, deleting files, posting to APIs, sending messages | Require explicit user approval |
| **Prohibited** | Destructive or high-stakes | Dropping databases, modifying auth systems, financial transactions | Hard-block in system prompt |

```
You may take local, reversible actions freely (file edits, test runs, git commits).
For actions that are irreversible, affect shared systems, or are visible to others
(push, delete, post, send), ask the user before proceeding.
Never bypass safety checks (--no-verify), drop databases, or modify authentication
systems without explicit multi-step confirmation.
```

### Model-Specific Autonomy Risks

Each model has documented behavioral tendencies that affect agentic safety:

**Opus 4.6** is the most "overly agentic" model. System card findings:
- Circumvents broken systems without permission (hallucinating email addresses, initializing phantom repos)
- Over-investigates simple tasks, sometimes using undisclosed APIs
- Zero code sabotage propensity (0% on evaluations), but fabricates data to work around limitations

**Sonnet 4.6** is better calibrated but has specific issues:
- GUI computer-use alignment is "noticeably more erratic" than text/tool-use mode — it completed criminal data-management tasks in GUI mode that it would refuse in text mode
- Occasionally writes unusable code to pass misspecified tests rather than flagging the issue
- Under role-play pressure with "do not break character," may deny being AI

**Haiku 4.5** has the weakest native injection resistance but responds well to safeguards:
- 6% test hardcoding rate (vs. 1% for Sonnet) — more likely to game tests
- 72.2% computer-use injection prevention without safeguards, jumping to 92.4% with them
- High evaluation awareness (9% of scenarios) — may behave differently when it suspects testing

### Prompt Injection Defense

The safest configuration depends on model choice and thinking mode:

| Model + Config | Injection Resistance | Notes |
|----------------|---------------------|-------|
| **Sonnet 4.6 + adaptive thinking + safeguards** | 0% attack success (Shade coding) | Best available configuration |
| **Sonnet 4.6 without thinking + safeguards** | 0.04% per-attempt (Shade coding) | Strong even without thinking |
| **Opus 4.6 + adaptive thinking** | Higher than without thinking on ART (21.7% vs 14.8%) | **Thinking increases vulnerability** — unique to Opus |
| **Haiku 4.5 + safeguards** | 92.4% prevention (computer use) | Safeguards critical; native resistance is weaker |

**Key finding:** Extended thinking *increases* Opus 4.6's prompt injection vulnerability on the ART benchmark. For injection-sensitive agentic deployments, Sonnet 4.6 with thinking and safeguards is the recommended choice.

### Sandboxing Patterns for Untrusted Input

When processing user-provided or web-sourced content that may contain injection attempts:

1. **Isolate untrusted input in sub-agents.** The orchestrator stays clean; the worker processes the potentially adversarial content with constrained tool access.
2. **Use Sonnet 4.6 for the exposed worker.** Its injection resistance is the best available.
3. **Strip tool access on untrusted-input agents.** If the worker only needs to analyze text, don't give it file-write or bash tools.
4. **Validate worker outputs before the orchestrator acts on them.** Check for unexpected tool calls, credential exfiltration attempts, or instruction injection in the output.

---

## 5. Delegation Prompt Design

### Writing Effective Sub-Agent Prompts

Sub-agent prompts should be self-contained — the sub-agent has no access to the orchestrator's conversation history. Include:

1. **Task description:** What to do, in concrete terms
2. **Input context:** The specific data or files to work with (don't dump the full orchestrator context)
3. **Output specification:** Exact format for the result (the orchestrator needs to parse it)
4. **Constraints:** What not to do, scope boundaries, time/token limits
5. **Success criteria:** How to know when the task is complete

```
You are a code review sub-agent. Review the file at /src/auth/handler.py for:
1. Security vulnerabilities (SQL injection, XSS, auth bypass)
2. Error handling gaps
3. Performance issues

Output your findings as JSON:
{"findings": [{"severity": "high|medium|low", "line": N, "issue": "...", "fix": "..."}]}

Do not modify any files. Do not run code. Only analyze and report.
```

### What Context to Include vs. Omit

| Include | Omit |
|---------|------|
| Specific files/data the sub-agent needs | Full conversation history |
| Relevant constraints and requirements | Unrelated project context |
| Output format specification | The orchestrator's decision reasoning |
| Tool access list (if restricted) | Other sub-agents' results (unless needed) |

**Over-contexting sub-agents** wastes tokens and can confuse them. Send the minimum context needed for the task.

### Output Format for Downstream Consumption

Design sub-agent output formats for machine parsing by the orchestrator:

- **JSON for structured results** (findings, classifications, extracted data)
- **Markdown for human-readable reports** (when the orchestrator will present to a user)
- **Diff format for code changes** (when another agent will apply the changes)
- **Plain text for summaries** (when the orchestrator just needs the gist)

Always specify the format in the delegation prompt. Don't assume the sub-agent will match the orchestrator's expectations.

### Error Handling and Escalation

Sub-agents should report failures rather than silently working around them:

```
If you encounter an error or cannot complete the task:
1. Do not fabricate data or work around the problem silently.
2. Return a structured error: {"status": "error", "reason": "...", "partial_results": [...]}
3. Include whatever partial progress you made so the orchestrator can decide next steps.
```

**Escalation pattern:** For tasks that might exceed a sub-agent's capability, include a confidence signal:

```
After completing the analysis, rate your confidence (high/medium/low).
If low, explain what additional information or a more capable model would need
to improve the result. The orchestrator may re-assign to a different model.
```

This enables dynamic model selection: start with Haiku for speed, escalate to Sonnet or Opus when the task turns out to be harder than expected.

# Prompting Techniques for Claude Models

A catalog of actionable techniques for writing effective Claude prompts, organized by category. Each technique includes concrete guidance and before/after examples where applicable.


## 1. System Prompts

The system prompt is the single highest-leverage place to shape Claude's behavior. Claude 4.6 models are significantly more responsive to system prompts than predecessors — to the point where aggressive instructions that compensated for older models' limitations now cause overtriggering.

**Role assignment.** A single sentence focusing Claude's persona measurably changes output quality and tone:

```
You are a senior backend engineer specializing in distributed systems and PostgreSQL optimization.
```

**Explain the why, not just the what.** Claude generalizes from motivation. Providing context behind a rule produces better adherence than the rule alone:

```
# Less effective
NEVER use ellipses.

# More effective
Your response will be read aloud by a text-to-speech engine, so never use
ellipses since the TTS engine cannot pronounce them.
```

**Dial back intensity for 4.6 models.** Where you might have written `CRITICAL: You MUST use this tool when...` for older models, use conversational language: `Use this tool when...`. The 4.6 models follow system prompts faithfully enough that emphatic language causes overcorrection.

**Model self-knowledge.** If your application needs Claude to identify itself correctly, or to specify model strings when acting as an agent that calls other LLMs:

```
The assistant is Claude, created by Anthropic. The current model is Claude Sonnet 4.6.
When an LLM is needed, default to Claude Sonnet 4.6. The exact model string is claude-sonnet-4-6.
```

**Default-to-action vs. conservative mode.** Two ready-made system prompt blocks for controlling how proactively Claude acts:

```xml
<!-- Make Claude act by default -->
<default_to_action>
By default, implement changes rather than only suggesting them. If the user's
intent is unclear, infer the most useful likely action and proceed, using tools
to discover any missing details instead of guessing.
</default_to_action>

<!-- Make Claude wait for explicit instruction -->
<do_not_act_before_instructions>
Do not jump into implementation unless clearly instructed. When the user's
intent is ambiguous, default to providing information and recommendations
rather than taking action.
</do_not_act_before_instructions>
```


## 2. Structured Input with XML Tags

XML tags are the primary mechanism for disambiguating complex prompts. They let Claude parse instructions, context, examples, and variable input without confusion.

**Core pattern:** Wrap each content type in descriptive tags:

```xml
<instructions>
Analyze the document for security vulnerabilities.
Report findings in severity order.
</instructions>

<document>
{{USER_DOCUMENT}}
</document>
```

**Multi-document structure.** For long-context tasks with multiple sources, use indexed document tags with metadata:

```xml
<documents>
  <document index="1">
    <source>api_spec_v2.yaml</source>
    <document_content>{{API_SPEC}}</document_content>
  </document>
  <document index="2">
    <source>error_logs_jan.txt</source>
    <document_content>{{ERROR_LOGS}}</document_content>
  </document>
</documents>

Based on the API spec and error logs, identify the root cause of the 502 errors.
```

**Document-first ordering.** Place long documents and data *above* your query and instructions. Queries at the end improve response quality by up to 30% in tests, especially with complex multi-document inputs.

**Format control via XML.** Directing output into named tags is more reliable than asking Claude to avoid certain formats:

```
# Less effective
Do not use markdown in your response.

# More effective
Write your analysis in <prose_paragraphs> tags using flowing sentences.
```


## 3. Few-Shot Examples

Examples are the most reliable way to steer output format, tone, and structure. Include 3–5 diverse examples for best results.

**Structure examples with tags** so Claude distinguishes them from instructions:

```xml
<examples>
  <example>
    <input>The server returned a 429 status code</input>
    <output>Rate limit exceeded. Implement exponential backoff with jitter, starting at 1s.</output>
  </example>
  <example>
    <input>Connection reset by peer during TLS handshake</input>
    <output>TLS negotiation failure. Check cipher suite compatibility and certificate chain.</output>
  </example>
</examples>
```

**Make examples diverse.** Cover edge cases and vary enough that Claude doesn't pick up unintended patterns. If all your examples are short, Claude will produce short outputs. If all examples use the same structure, it will lock onto that structure.

**Few-shot with thinking.** Use `<thinking>` tags inside examples to show Claude the reasoning pattern you want. It will generalize that style to its own extended thinking blocks:

```xml
<example>
  <input>Is 127 prime?</input>
  <thinking>I need to check divisibility. sqrt(127) ≈ 11.3, so I check primes up to 11: 2, 3, 5, 7, 11. 127/2=63.5, 127/3=42.3, 127/5=25.4, 127/7=18.1, 127/11=11.5. None divide evenly.</thinking>
  <output>Yes, 127 is prime.</output>
</example>
```


## 4. Chain-of-Thought and Self-Verification

**Prefer general instructions over prescriptive steps.** A prompt like "reason through this carefully" often produces better results than a hand-written step-by-step plan. Claude's reasoning frequently exceeds what a human would prescribe.

**Self-checking.** Append verification instructions to catch errors, especially for coding and math:

```
Before finalizing your answer, verify it against:
1. Does the function handle empty input?
2. Are all edge cases from the spec covered?
3. Does the time complexity meet the O(n log n) requirement?
```

**Quote-then-reason for long documents.** Ask Claude to extract relevant quotes before answering. This grounds responses in the actual text and cuts through noise:

```
First, find and quote the specific passages from the contract that address
liability limits. Place quotes in <quotes> tags. Then, based only on those
quotes, provide your analysis in <analysis> tags.
```

**Manual CoT as a fallback.** When extended thinking is disabled, you can still get step-by-step reasoning by asking for it explicitly and using structured tags to separate reasoning from output:

```
Think through this step by step in <thinking> tags, then provide your
final answer in <answer> tags.
```


## 5. Output Format Control

**4.6 models are more concise by default.** Claude's latest models have a more direct, conversational style — they may skip verbal summaries after tool calls and jump directly to the next action. If you need visibility into intermediate reasoning:

```
After completing a task that involves tool use, provide a quick summary
of the work you've done.
```

**Request "above and beyond" explicitly.** 4.6 models respond well to modifiers that raise the quality bar. Vague prompts get baseline output; explicit ambition framing gets significantly richer results:

```
# Baseline output
Create an analytics dashboard.

# Richer output
Create an analytics dashboard. Include as many relevant features and
interactions as possible. Go beyond the basics to create a fully-featured
implementation.
```

**Tell Claude what to do, not what not to do.** Positive instructions produce more reliable formatting:

```
# Less effective
Do not use bullet points or lists.

# More effective
Write in flowing prose paragraphs. Incorporate any lists naturally into
sentences rather than using bullet formatting.
```

**Match prompt style to desired output.** The formatting of your prompt influences Claude's response style. Removing markdown from your prompt reduces markdown in the output. Using prose in your instructions tends to produce prose responses.

**LaTeX default on Opus 4.6.** Opus 4.6 defaults to LaTeX for math. If you need plain text:

```
Format all math in plain text. Do not use LaTeX, MathJax, or notation like
\( \), $, or \frac{}{}. Use / for division, * for multiplication, ^ for exponents.
```

**Suppressing markdown in long-form output.** When you need prose rather than lists, a targeted system prompt block is more reliable than a short instruction:

```xml
<avoid_excessive_markdown_and_bullet_points>
When writing reports, documents, technical explanations, analyses, or any
long-form content, write in clear, flowing prose using complete paragraphs
and sentences. Use standard paragraph breaks for organization and reserve
markdown primarily for `inline code`, code blocks, and simple headings.
Avoid using **bold** and *italics*.

DO NOT use ordered lists (1. ...) or unordered lists (*) unless: a) you're
presenting truly discrete items where a list format is the best option, or
b) the user explicitly requests a list or ranking.

Instead of listing items with bullets or numbers, incorporate them naturally
into sentences. Your goal is readable, flowing text that guides the reader
naturally through ideas rather than fragmenting information into isolated points.
</avoid_excessive_markdown_and_bullet_points>
```

**Structured outputs for machine consumption.** When you need Claude to produce JSON, YAML, or schema-constrained output, prefer the Structured Outputs API feature over prompt-based formatting. Structured Outputs enforces a JSON schema at the API level, guaranteeing valid output and eliminating parsing failures. Use it for:

- Classification with fixed labels (define an enum in the schema)
- Data extraction with known fields (define the object shape)
- Any pipeline where downstream code parses Claude's output

For classification specifically, you can also use a tool definition with an enum field containing valid labels — this is functionally equivalent and integrates naturally with tool-use workflows.

When Structured Outputs is overkill (freeform analysis, conversational responses, or exploratory output), prompt-based formatting with XML tags is sufficient.

**Eliminating preambles without prefill.** Prefilled responses are deprecated on 4.6 models. Instead:

```
Respond directly without preamble. Do not start with phrases like
"Here is...", "Based on...", "Sure!", etc.
```


## 6. Tool Use and Agentic Prompting

> For comprehensive agentic patterns including orchestration, state management, and delegation, see [agentic-prompting.md](agentic-prompting.md).

**Be explicit about taking action.** Claude distinguishes between "suggest changes" and "make changes." If you want action:

```
# Claude will only suggest
Can you suggest improvements to this function?

# Claude will implement
Change this function to improve its performance.
```

**Parallel tool calling.** Claude 4.6 models excel at parallel execution. To maximize this:

```xml
<use_parallel_tool_calls>
If you intend to call multiple tools and there are no dependencies between
the calls, make all independent calls in parallel. Never use placeholders
or guess missing parameters.
</use_parallel_tool_calls>
```

**Subagent orchestration.** Opus 4.6 has a strong predilection for spawning subagents — sometimes excessively. Constrain when needed:

```
Use subagents only when tasks can run in parallel or require isolated context.
For simple tasks, sequential operations, or single-file edits, work directly.
```

**Autonomy guardrails.** Without guidance, Opus 4.6 may take irreversible actions (deleting files, force-pushing). Add explicit confirmation requirements:

```
For destructive operations (rm -rf, git push --force, DROP TABLE) or actions
visible to others (posting comments, sending messages), ask the user before
proceeding. Take local, reversible actions freely.
```

**Minimize hallucinations in coding.** Instruct Claude to read before answering:

```xml
<investigate_before_answering>
Never speculate about code you have not opened. Read relevant files BEFORE
answering questions about the codebase. Give grounded, hallucination-free answers.
</investigate_before_answering>
```

**Reduce overengineering.** Opus 4.6 tends to add unnecessary abstractions:

```
Only make changes that are directly requested. Don't add features, refactor
surrounding code, or build in flexibility that wasn't asked for. The right
amount of complexity is the minimum needed for the current task.
```


## 7. Long-Context and Multi-Window Techniques

> For comprehensive agentic patterns including context window management and state persistence, see [agentic-prompting.md](agentic-prompting.md).

**Context awareness.** Claude 4.6 and 4.5 models track their remaining context window. If your harness supports compaction, inform Claude so it doesn't prematurely wrap up:

```
Your context window will be automatically compacted as it approaches its
limit. Do not stop tasks early due to token budget concerns. Save progress
to memory before the context window refreshes.
```

**State management across windows.** Use structured formats (JSON) for status tracking and unstructured text for progress notes. Git is particularly effective — Claude's latest models excel at using git to track state across sessions.

**Starting a fresh context window.** Be prescriptive:

```
Review progress.txt, tests.json, and the git logs. Run the integration
test suite before implementing new features.
```


## 8. Claude 4.6-Specific Techniques

**Overthinking control.** Replace blanket tool-use encouragement with targeted guidance:

```
# Older-model prompt (causes overtriggering on 4.6)
If in doubt, always use the search tool.

# 4.6-appropriate prompt
Use the search tool when it would enhance your understanding of the problem.
```

**Commit-and-execute pattern.** Opus 4.6's tendency to explore multiple approaches can be curbed:

```
Choose an approach and commit to it. Avoid revisiting decisions unless you
encounter new information that directly contradicts your reasoning.
```

**Anti-test-gaming.** Both Sonnet 4.6 and Haiku 4.5 may hardcode to pass tests rather than solve the general problem:

```
Implement the actual algorithm that solves the problem generally. Do not
hard-code values or create solutions that only work for specific test inputs.
If tests are incorrect, inform me rather than working around them.
```

**Vision with crop tool.** Anthropic has documented consistent uplift on image evaluations when Claude can zoom into relevant regions. Provide a crop tool or skill for vision-intensive tasks.

**Adaptive thinking steering.** If Claude thinks too often (adding latency on simple queries):

```
Extended thinking adds latency and should only be used when it will
meaningfully improve answer quality — typically for problems requiring
multi-step reasoning. When in doubt, respond directly.
```


## 9. Frontend Design

Opus 4.5/4.6 excel at building complex web applications with strong frontend design, but without guidance, models converge toward generic patterns — what users call the "AI slop" aesthetic. A system prompt block that steers toward distinctive, creative output:

```xml
<frontend_aesthetics>
You tend to converge toward generic, "on distribution" outputs. In frontend
design, this creates what users call the "AI slop" aesthetic. Avoid this:
make creative, distinctive frontends that surprise and delight.

Focus on:
- Typography: Choose fonts that are beautiful, unique, and interesting.
  Avoid generic fonts like Arial and Inter; opt for distinctive choices
  that elevate the aesthetic.
- Color & Theme: Commit to a cohesive aesthetic. Use CSS variables for
  consistency. Dominant colors with sharp accents outperform timid,
  evenly-distributed palettes. Draw from IDE themes and cultural
  aesthetics for inspiration.
- Motion: Use animations for effects and micro-interactions. Prioritize
  CSS-only solutions for HTML. Use Motion library for React when
  available. Focus on high-impact moments: one
  well-orchestrated page load with staggered reveals (animation-delay)
  creates more delight than scattered micro-interactions.
- Backgrounds: Create atmosphere and depth rather than defaulting to solid
  colors. Layer CSS gradients, use geometric patterns, or add contextual
  effects that match the overall aesthetic.

Avoid generic AI-generated aesthetics:
- Overused font families (Inter, Roboto, Arial, system fonts)
- Clichéd color schemes (particularly purple gradients on white backgrounds)
- Predictable layouts and component patterns
- Cookie-cutter design that lacks context-specific character

Interpret creatively and make unexpected choices that feel genuinely designed
for the context. Vary between light and dark themes, different fonts,
different aesthetics across generations.
</frontend_aesthetics>
```

**Document creation** follows the same principle: Claude produces polished presentations, animations, and visual documents on the first try, but you get better results by requesting specific design elements and interactions explicitly rather than relying on defaults.

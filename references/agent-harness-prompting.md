# Prompting in Agent Harnesses

A guide to writing effective prompts when working inside pre-built agent environments — Claude Code, Cowork, Chat, and similar harnesses where the system prompt, tools, model selection, and thinking configuration are controlled by the harness, not the user. Your prompting surface is a natural language message in a conversation.


<section_guide>
Read sections 1-5 for all harness users (paradigm, task instructions, file orientation, decomposition, CLAUDE.md).
Read section 6 when the user works in Claude Code (system prompt customization, effort, compaction, plan mode, hooks, auto-memory).
Read section 7 when delegating to subagents via the Task tool (applies to Claude Code and Cowork).
Read section 8 when the user works in Cowork (skills triggering, outputs folder, folder mounting, MCP, scheduled tasks).
Read section 9 when the user works in Chat (artifacts, Projects, conversational iteration, no execution).
Read sections 10-11 for iteration loop and durable/repeatable process prompts.
Read section 12 for model-specific behavioral adjustments in harness context.
Read section 13 for platform-specific anti-patterns.
</section_guide>


## 1. The Agent Harness Paradigm

When you use the Claude API directly, you control the system prompt, tool definitions, model selection, thinking mode, and effort level. In an agent harness (Claude Code, Cowork, Chat), the harness owns all of that. What you control is:

- **Your message** — a natural language instruction in a conversation turn
- **Project configuration** — CLAUDE.md files, `.claude/settings.json`, MCP server setup
- **Session-level choices** — which model to use (in some harnesses), whether to use plan mode
- **The conversation itself** — you steer across turns, not in a single shot

This means most API-level prompt engineering (role assignment in system prompts, XML-structured tool schemas, `budget_tokens` tuning) doesn't apply directly. Instead, the critical skills are: expressing intent clearly, orienting the agent to relevant context, decomposing work appropriately, and steering iteratively.

### Harness Capabilities

Each harness exposes different prompting surfaces. Know what you can control:

| Capability | Claude Code | Cowork | Chat (claude.ai) |
|------------|------------|--------|-------------------|
| **Filesystem access** | Full (Read, Write, Edit, Glob, Grep — distinct tools) | Sandboxed VM; folder mounting or upload | Upload only |
| **Terminal / Bash** | Yes | Yes (sandboxed) | No |
| **Subagents** | Yes (Task tool with typed agents: Explore, Plan, Bash, general-purpose) | Yes (Task tool, internally managed) | No |
| **Plan mode** | Yes (`/plan` or EnterPlanMode) | No | No |
| **Persistent instructions** | CLAUDE.md (multi-level hierarchy), `.claude/settings.json` | N/A (skills provide persistent behavior) | Projects system instructions |
| **Auto-memory** | Yes (persistent across conversations) | No | No (but Projects retain uploads) |
| **Skills** | Yes (user-uploadable, trigger-based) | Yes (auto-triggered by keyword matching) | Yes (uploadable via Settings) |
| **MCP servers** | Yes (configurable in settings) | Yes (Notion, Chrome browser, scheduled tasks, etc.) | Limited |
| **Git awareness** | Yes (branch, status injected at start) | No | No |
| **Hooks** | Yes (shell commands on tool events) | No | No |
| **Model choice** | Per-session (`/model`, `Alt+P`, `--model`, settings) | Per-session | Per-conversation |
| **Tool permissions** | Configurable (auto-approve vs. confirm per tool) | Action classification (prohibited / explicit-permission / regular) | N/A |
| **System prompt customization** | Yes (`--system-prompt`, `--append-system-prompt`) | No | No |
| **Tool restrictions** | Yes (`--allowedTools`, `--disallowedTools`) | No | No |
| **Effort/thinking control** | Yes (`Alt+T` for thinking, effort level via `/model` or env var) | No | No |
| **Compaction control** | Yes (`/compact`, custom compact instructions, env overrides) | No | No |
| **Scheduled execution** | No (use cron externally) | Yes (built-in scheduled tasks) | No |

The guidance in this file applies across harnesses. Sections 6, 8, and 9 cover features specific to Claude Code, Cowork, and Chat respectively. Section 7 covers subagent prompting, which is relevant to both Code and Cowork.


## 2. Writing Effective Task Instructions

Your prompt is a user-turn message into a pre-built agent, not a system prompt. The agent already has a role, tools, and behavioral constraints. Your job is to define the task clearly enough that the agent can plan and execute autonomously.

### State the goal before the method

Lead with what you want to achieve, then how. The agent needs to understand the destination before it can plan the route.

```
# Less effective — method-first
Read src/auth/handler.py and src/auth/middleware.py, then refactor the
token validation logic into a shared utility, then update both files
to use it, then run the tests.

# More effective — goal-first
The token validation logic is duplicated between src/auth/handler.py
and src/auth/middleware.py. Consolidate it into a shared utility so
both files use the same implementation. Run tests after the change.
```

Goal-first prompts give the agent room to choose a better approach than the one you'd prescribe. Method-first prompts can still be useful when you have a specific procedure in mind, but defaulting to goal-first produces better outcomes on average.

### Specify the output, not just the task

Tell the agent what "done" looks like. Without this, it will use its own judgment about scope and completeness — which may not match yours.

```
# Vague ending
Investigate why the API is slow.

# Clear ending
Investigate why the /users endpoint is slow. Identify the root cause,
propose a fix, and implement it. Run the existing test suite to verify
nothing breaks. If you need to add a test for the fix, do that too.
```

### Use the right level of abstraction

Match your instruction specificity to the task ambiguity. For well-understood tasks, be specific. For exploratory tasks, describe the problem and let the agent investigate.

```
# Well-understood task — be specific
Add a --dry-run flag to the deploy.sh script that prints the commands
it would run without executing them. Follow the same flag parsing
pattern used for --verbose.

# Exploratory task — describe the problem
Users are reporting that search results are inconsistent — the same
query returns different results on consecutive requests. Investigate
and fix. Start with the search handler in src/search/.
```

### Tell the agent what it can skip

Unbounded scope is the most common cause of over-exploration. When you know what's out of scope, say so.

```
Refactor the database connection pool to use async/await. Only change
files in src/db/. Don't touch the migration scripts or the CLI tool —
those will be updated separately.
```


## 3. File and Repo Orientation

In agent harnesses, the agent's effectiveness depends on how well you orient it to the relevant files and repo structure. The agent can explore the filesystem, but starting it in the right place saves significant time and token spend.

### Point to the relevant files

Name the files or directories the agent should start with. This is the single highest-impact thing you can do for agent efficiency.

```
# Without orientation — agent must discover everything
Add rate limiting to the API.

# With orientation — agent starts in the right place
Add rate limiting to the API. The route handlers are in src/routes/,
middleware is in src/middleware/, and the existing auth middleware in
src/middleware/auth.ts is a good pattern to follow. Config goes in
src/config/limits.ts.
```

### Describe the repo layout when it's non-obvious

If the project has an unusual structure, a monorepo layout, or conventions that aren't self-documenting, tell the agent.

```
This is a monorepo. The API server is in packages/api/, the shared
types are in packages/types/, and the CLI is in packages/cli/. Changes
to the shared types need to be compatible with both consumers.
```

### Distinguish reference material from working targets

When you point the agent to multiple files, clarify which are examples to follow and which are the actual targets of the work.

```
Add a new /webhooks endpoint following the same pattern as
src/routes/notifications.ts (use that as a reference for the route
structure and middleware chain). The new file should go in
src/routes/webhooks.ts. The webhook payload schema is defined in
src/types/webhook.ts — don't modify that file.
```

### Use CLAUDE.md for persistent orientation

If you find yourself repeating repo layout descriptions across sessions, move that context into a CLAUDE.md file (covered in the CLAUDE.md Configuration section below). Reserve your message for task-specific orientation.


## 4. Decomposition Strategies

In agent harnesses, you are the orchestrator. The critical skill is knowing when to give the agent a large task versus breaking it into sequential prompts.

### When to give it all at once

Give the full task in a single message when:

- The agent needs holistic context to make good decisions (e.g., a refactor that must be internally consistent across files)
- The steps are tightly coupled and the agent needs to see the whole picture to plan
- The task is well-defined enough that the agent can execute without intermediate feedback

```
Migrate the user service from REST to gRPC. This involves:
- Defining the protobuf schema based on the existing REST types in
  src/types/user.ts
- Generating the gRPC server and client stubs
- Updating the service implementation in src/services/user.ts
- Updating the integration tests in tests/user.test.ts

The REST endpoints should keep working during migration (add gRPC
alongside, don't replace yet).
```

### When to break it into phases

Use sequential prompts when:

- Each phase produces output you need to review before the next phase proceeds
- The task involves discovery followed by implementation (and you want to steer based on what's discovered)
- You want focused attention on each step rather than a sprawling multi-step execution
- The task is large enough that context window pressure could degrade later steps

**Phase pattern:**

```
# Phase 1: Discovery
Analyze the test suite in tests/. Which tests are flaky (failing
intermittently)? List them with your assessment of why each is flaky.

# [Review the agent's findings, then:]

# Phase 2: Implementation
Fix the three flaky tests you identified:
- tests/api/search.test.ts: the timing issue with the mock server
- tests/db/migration.test.ts: the race condition on connection pool
- tests/auth/token.test.ts: the hardcoded expiry timestamp
Leave the others for now.
```

### Let the agent self-decompose

Claude Code's Task tool and plan mode allow the agent to break work down internally. You can cue this by describing the high-level goal and explicitly inviting decomposition:

```
I need to add end-to-end encryption to the messaging feature. This is
a significant change — plan the approach before implementing. Show me
the plan and I'll approve before you start coding.
```

Or use `/plan` mode in Claude Code to force a plan-then-execute workflow.

### The discovery-implementation gate

The most common decomposition mistake is combining open-ended discovery with implementation in a single prompt without a review gate. This leads the agent to implement based on its first (possibly wrong) understanding.

```
# Risky — no gate between discovery and action
Figure out why the build is broken and fix it.

# Safer — explicit gate
Figure out why the build is broken. Tell me what you find before
making any changes.
```

After the agent reports findings, you can give a focused implementation instruction based on accurate understanding.


## 5. CLAUDE.md and Project-Level Configuration

CLAUDE.md files are the highest-leverage prompting surface in Claude Code. They persist instructions across sessions, establishing conventions and context that apply to every interaction in the project.

### What goes in CLAUDE.md

Think of CLAUDE.md as a "system prompt" that you, the user, control. Use it for:

**Repo orientation** — structure, key directories, where things live:
```markdown
## Repo Structure
- src/api/ — Express route handlers
- src/services/ — Business logic (one file per domain entity)
- src/db/ — Database layer (Drizzle ORM, migrations in src/db/migrations/)
- tests/ — Mirrors src/ structure, uses Vitest
```

**Conventions** — how code should be written in this project:
```markdown
## Conventions
- Use Drizzle ORM for all database queries (no raw SQL)
- Error handling: throw typed errors from src/errors/, catch in middleware
- All new endpoints need integration tests
- Use zod for request validation schemas
```

**Workflow rules** — what the agent should always or never do:
```markdown
## Workflow
- Always run `npm test` after making changes
- Don't modify files in src/generated/ — they're auto-generated by codegen
- When adding a new API endpoint, also update the OpenAPI spec in docs/api.yaml
```

**Build and test commands** — save the agent from guessing:
```markdown
## Commands
- `npm test` — run all tests
- `npm run test:unit` — unit tests only
- `npm run lint` — eslint + prettier check
- `npm run build` — production build
```

### CLAUDE.md hierarchy

Claude Code supports CLAUDE.md files at multiple levels, checked in ascending priority:

| Location | Scope | Use for |
|----------|-------|---------|
| `~/.claude/CLAUDE.md` | All projects | Personal preferences (editor settings, communication style) |
| `CLAUDE.md` (repo root) | This project | Repo structure, conventions, build commands |
| `src/CLAUDE.md` | This directory tree | Subsystem-specific conventions |
| `.claude/settings.json` | This project | Tool permissions, MCP servers |

### CLAUDE.md vs. repeating context in messages

**Put in CLAUDE.md** things you'd otherwise repeat across sessions: repo layout, conventions, build commands, file generation rules. **Put in your message** things specific to the current task: which files to change, what the goal is, what constraints apply.

The test: if you've typed the same instruction in three separate sessions, it belongs in CLAUDE.md.


## 6. Claude Code Prompting Surfaces

Claude Code exposes more configuration surfaces than other harnesses. Most users interact through messages and CLAUDE.md, but power users can customize the system prompt, restrict tools, control thinking/effort, manage compaction, and use slash commands — making Code closer to the API in configurability while retaining the conversational workflow.

### System prompt and tool customization

Unlike other harnesses, Claude Code allows direct system prompt modification:

- **`--system-prompt`** replaces the default system prompt entirely (advanced; most users shouldn't need this)
- **`--append-system-prompt`** adds instructions to the end of the default system prompt (the recommended approach for customization)
- **`--allowedTools` / `--disallowedTools`** restrict which tools the agent can use (useful for constraining agents to read-only work, or preventing Bash usage)

These flags are most useful for automated pipelines or when you want to constrain the agent for a specific session without changing project settings.

### Effort and thinking controls

- **`Alt+T`** toggles extended thinking on/off during a session
- **Effort level** can be set via `/model` (arrow keys to adjust), the `CLAUDE_CODE_EFFORT_LEVEL` environment variable, or in settings
- **Fast mode** (`/fast`) uses the same model with faster output

Effort is the most underused lever. If the agent is over-exploring a simple task, lowering effort often fixes it faster than rewriting your prompt.

### Compaction

When the conversation approaches the context limit, Claude Code compacts the history. You can control this:

- **`/compact`** triggers manual compaction with an optional focus instruction (`/compact focus on the auth refactor`)
- **Custom compact instructions** in CLAUDE.md tell the agent what to preserve during compaction
- **`CLAUDE_AUTOCOMPACT_PCT_OVERRIDE`** changes the threshold for auto-compaction

For long sessions, adding a compact instruction to CLAUDE.md ensures important context survives compaction:

```markdown
## Compact Instructions
When compacting, preserve: the current task goal, which files have been
modified, test results, and any unresolved issues.
```

### Slash commands

Claude Code provides built-in commands that change the agent's mode or provide information:

| Command | Effect |
|---------|--------|
| `/plan` | Enter plan mode (explore only, no writes) |
| `/compact` | Trigger compaction (optional focus instruction) |
| `/clear` | Clear conversation history |
| `/model` | Switch model or adjust effort |
| `/memory` | View/edit auto-memory |
| `/resume` | Resume a previous session |
| `/rewind` | Undo the last agent action |
| `/status` | Show session status |
| `/cost` | Show token usage and cost |
| `/context` | Show context window usage |

These are prompting-adjacent: they don't change what you say, but they change the agent's mode, context, or capabilities for the next message.

### Plan mode

Plan mode (`/plan` or triggered by the agent via EnterPlanMode) changes the interaction model: the agent explores the codebase and designs an approach without making any file changes. It uses read-only tools (Glob, Grep, Read) and presents a plan for your approval before writing code.

**When to use plan mode:**

- Large or ambiguous tasks where you want to review the approach before implementation
- When you're unfamiliar with the codebase and want the agent to map it out first
- When the task has architectural implications you want to approve

**Prompting for plan mode:** Your message before entering plan mode should describe the problem space, not prescribe the solution. Give the agent room to explore and propose.

```
# Good plan mode prompt — describes the problem
We need to add caching to the API layer. The current response times
for /products and /search are too slow. Explore the codebase and
propose a caching strategy.

# Less effective — prescribes the solution
Add Redis caching to the API. Use the existing Redis connection in
src/db/redis.ts. Cache /products for 5 minutes and /search for 1
minute.
```

The second prompt works fine for direct execution, but wastes plan mode's value — you've already decided the approach.

### Tool permissions

Users configure which tools auto-approve vs. require confirmation in `.claude/settings.json`. This significantly affects the agent's workflow:

- **All tools auto-approved:** The agent works autonomously. Your prompt can be higher-level since execution won't be interrupted.
- **Bash on manual approval:** Every shell command pauses for your confirmation. Consider batching related operations in your instructions so the agent combines them into fewer Bash calls.
- **Write/Edit on manual approval:** Every file change pauses. Useful for review-heavy workflows, but makes large refactors tedious.

You can adjust permissions to match the task risk level. For a low-risk, well-understood task, auto-approve more. For exploratory or high-risk work, keep manual approval on destructive tools.

### Auto-memory

Claude Code maintains persistent memory files at `~/.claude/projects/.../memory/` that survive across conversations. The agent writes observations, patterns, and user preferences here and consults them at the start of each session.

**How this affects your prompting:**

- If you've told the agent a preference once ("always use bun instead of npm"), it may already be in memory. You don't need to repeat it.
- If the agent is doing something you don't want, check whether a stale memory entry is influencing it. You can ask the agent to update or remove memories.
- For the first session on a project, the agent has no memory. Be more explicit. Subsequent sessions benefit from accumulated context.

### Hooks

Hooks are user-configured shell commands that run in response to tool events (e.g., before a Bash call, after a file edit). They're defined in `.claude/settings.json`.

**Common patterns:**

- A pre-commit hook that runs linting automatically after file changes
- A notification hook that alerts on certain operations
- A validation hook that checks file formats before writes

**Prompting implications:** Hooks can block tool calls (the agent sees a "blocked by hook" message). If the agent is repeatedly blocked, the issue is in the hook configuration, not the prompt. You may need to adjust hooks rather than rephrase your instruction.

### The built-in system prompt

Claude Code's system prompt contains strong behavioral guidance that the agent follows. Some of this will modulate or override your instructions. Key behaviors baked into the system prompt:

- **Read before write:** The agent reads files before editing them. You don't need to instruct this.
- **Edit over create:** The agent prefers editing existing files over creating new ones. If you want a new file, say so explicitly.
- **Minimal changes:** The agent avoids over-engineering, unnecessary refactoring, and adding features beyond what's asked. This is usually desirable but means you need to be explicit if you want broader changes.
- **No unsolicited commits:** The agent won't commit or push unless you ask. Don't worry about it making unreviewed git operations.
- **Tool preferences:** The agent uses dedicated tools (Read, not `cat`; Edit, not `sed`; Glob, not `find`). Asking it to "use grep to find X" may be interpreted as "use the Grep tool" rather than running grep in Bash.

**When system prompt and user instruction conflict:** The system prompt generally wins on safety-related behavior (confirmation for destructive actions, not pushing without permission). For stylistic preferences, your instruction usually takes precedence. If the agent isn't following an instruction, it may be because the system prompt constrains that behavior — ask the agent why it did what it did.

### Skills

Skills are user-uploadable instruction files that activate on trigger conditions. When loaded, a skill expands into the agent's context and provides specialized guidance.

**Prompting with skills:** If you have relevant skills installed, you can invoke them with `/skill-name` or let them trigger automatically. The skill's instructions then guide the agent's behavior for that task. This is another way to shape behavior without repeating context — install a skill once, and it applies across sessions when relevant.


## 7. Subagent Prompting

> For API-level delegation design (building your own orchestrator), see [agentic-prompting.md](agentic-prompting.md) Section 5. This section covers delegation within agent harnesses like Claude Code.

In Claude Code, the agent can spawn subagents via the Task tool — delegating work to a fresh Claude instance with its own context window and tool set. This is prompt engineering happening at runtime: the quality of the delegation prompt directly determines the subagent's effectiveness. This section serves both users (who can guide the agent's delegation strategy) and the agent itself (which can consult this guidance when writing Task prompts).

### Subagent types as capability profiles

Claude Code offers typed subagents, each with different tools and strengths. Choosing the right type is analogous to model selection:

| Subagent type | Tools available | Best for | Not for |
|---------------|----------------|----------|---------|
| **Explore** | Read, Glob, Grep, WebFetch, WebSearch (no writes) | Codebase exploration, finding files, answering questions about code | Making changes, running commands |
| **Plan** | Read, Glob, Grep, WebFetch, WebSearch (no writes) | Designing implementation plans, identifying critical files, architectural analysis | Execution — plans only |
| **Bash** | Bash only | Git operations, command execution, build/test runs | File reads, code search (no Read/Glob/Grep) |
| **general-purpose** | All tools | Complex multi-step tasks, research + implementation | Simple tasks (overhead not worth it) |

**Selection heuristic:** Use the most constrained type that can do the job. Explore for read-only investigation, Bash for command execution, general-purpose only when you need the full tool set. Over-using general-purpose wastes context setup tokens.

### Context isolation is absolute

Subagents start with a blank context. They do not see the parent conversation history. The delegation prompt must be entirely self-contained:

```
# Bad — assumes shared context
"Continue investigating the bug we discussed above."

# Good — self-contained
"Investigate a null pointer exception in src/parser/tokenizer.ts.
The bug is in the handleEscape() function — it doesn't check for
end-of-input before accessing the next character. Read the function,
identify the exact line, and report back with the fix."
```

Some subagent types have "access to current context" (they receive the full conversation so far). When available, concise references to earlier context work. But default to self-contained prompts — they're more reliable and work across all types.

### Writing effective delegation prompts

A good subagent prompt includes five elements:

1. **Task** — what to do, concretely
2. **Context** — the specific files, data, or information needed (don't dump the full parent context)
3. **Output format** — how to structure the result for the parent to consume
4. **Constraints** — what not to do, scope boundaries
5. **Completion criteria** — how to know when the task is done

```
Search the codebase for all uses of the deprecated `getUser()` function.

Look in src/ and tests/. For each occurrence, report:
- File path and line number
- Whether it's a call site or a definition
- What the surrounding context suggests about migration difficulty

Return results as a structured list. Do not modify any files.
```

### Parallel vs. sequential delegation

The parent agent can launch multiple subagents concurrently. This is the biggest latency optimization in Claude Code — but only works when tasks are genuinely independent.

**Parallelize when:**
- Tasks read different parts of the codebase
- Tasks have no data dependencies between them
- Each task produces an independent result

**Keep sequential when:**
- One task's output informs the next task's input
- Tasks modify the same files
- Ordering matters (e.g., create file, then test it)

```
# Good parallel delegation — independent searches
Launch three Explore agents in parallel:
1. "Find all API routes that lack authentication middleware in src/routes/"
2. "Find all database queries that don't use parameterized inputs in src/db/"
3. "Find all environment variables used but not documented in .env.example"

# Bad parallel delegation — has dependencies
Don't parallelize: "Find the broken test" and "Fix the broken test"
```

### Guiding the agent's delegation behavior

As a user, you can influence when and how the agent delegates:

**Encourage delegation** for parallelizable work:
```
This refactor touches three independent modules. Feel free to use
parallel subagents for the investigation phase.
```

**Discourage delegation** when shared context matters:
```
This change needs to be consistent across all files — work through
them sequentially so each change informs the next. Don't use
subagents for this.
```

**Constrain Opus's delegation tendency:** Opus over-delegates. It spawns subagents for tasks a simple Grep or Read would handle. If you notice this:
```
For simple file lookups and searches, use Glob/Grep/Read directly.
Only use subagents when tasks can genuinely run in parallel or need
isolated context.
```

### Subagent output flows back as a single message

The parent agent receives the subagent's result as one block of text. Design the delegation prompt's output format for easy consumption:

- **Structured data** (JSON, bullet lists) for results the parent needs to parse and act on
- **Prose summary** for results the parent will relay to the user
- **Diff format** for code changes the parent needs to evaluate or apply
- **Confidence signal** for tasks where the subagent might need escalation: "Rate your confidence (high/medium/low). If low, explain what additional information would help."


## 8. Cowork Prompting Surfaces

Cowork is a desktop GUI agent oriented toward document creation, data work, and cross-tool workflows. Its prompting surface differs from Claude Code in important ways.

### Skills are the biggest behavioral lever

Cowork auto-triggers skills based on keyword matching in the skill description. When a user says "create a spreadsheet," the xlsx skill loads and Claude reads a SKILL.md file — potentially hundreds of lines of specialized instructions — before acting. This fundamentally changes the agent's behavior.

**Prompting implication:** The most impactful "prompt engineering" in Cowork may be *making sure the right skill triggers*. Use specific format keywords when you want skill-enhanced behavior:

```
# Triggers the relevant skill
Create a spreadsheet tracking project milestones with columns for
task, owner, due date, and status.

# May miss the skill trigger
Help me organize my project timeline into a table.
```

Conversely, if you're getting unexpected specialized behavior, the agent may have loaded a skill you didn't intend. Rephrasing to avoid trigger words can help.

### File handling: the outputs folder

Cowork runs in a sandboxed VM with a specific file model:

- **Uploads** (`/mnt/uploads`) — files the user provides
- **Working directory** — ephemeral; used for intermediate work
- **Outputs** (`/mnt/outputs`) — files the agent saves here persist to the user's computer

The user doesn't need to know these paths, but it affects how to phrase requests:

```
# Works — agent saves to outputs
Create a PDF summary of this report and save it.

# May not persist — agent might just display the result
Summarize this report as a PDF.
```

When you want a file you can keep, ask Claude to "save" or "create a file" explicitly.

### Folder mounting for local files

Cowork can access a directory on your computer via folder mounting. This must be set up before the agent can read local files — it can't access your filesystem otherwise.

```
# Won't work without folder mounting
Read the files in my project directory and summarize the architecture.

# Works — after mounting the folder
[Mount the project folder first, then:]
Summarize the architecture of the codebase in the mounted folder.
Focus on the main modules and how they connect.
```

### MCP connectors shape capability

Cowork connects to external tools (Notion, Chrome browser, scheduled tasks) via MCP. The user enables these connectors, and the way they phrase requests affects which tools the agent selects:

```
# Specific — agent knows which MCP tool to use
Search my Notion workspace for the "Q4 Planning" page and summarize
the action items.

# Vague — agent may not invoke the right connector
What were the action items from our planning?
```

When working with MCP connectors, name the service and be specific about what you're looking for.

### The AskUserQuestion pattern

Cowork has a structured tool for asking the user multiple-choice questions before proceeding. The system prompt encourages using this for non-trivial tasks. This means a **concise brief that invites clarification** can be more effective than an exhaustive specification:

```
# Effective — lets Cowork ask the right clarifying questions
Create a presentation about our Q3 results for the board meeting.

# Over-specified — removes Cowork's ability to tailor the approach
Create a 12-slide PowerPoint with: slide 1 title page, slide 2
revenue chart, slide 3 customer growth...
```

The first prompt lets the agent ask about audience, style preferences, which metrics matter most, and what data sources to use. The second removes that opportunity.

### Scheduled tasks

Cowork can create scheduled tasks that run on a cron cadence. This is the built-in equivalent of the "durable process prompt" pattern (covered in the Durable and Repeatable Process Prompts section below). When writing prompts for scheduled execution, the same principles apply: reference relative state, include self-verification, handle the cold-start problem.

### Security constraints are non-negotiable

Cowork's system prompt classifies actions into three tiers: prohibited (never allowed), explicit-permission (requires user confirmation in chat), and regular (allowed freely). Certain operations — sharing documents, modifying permissions, handling financial data, permanent deletions — will always require explicit confirmation regardless of how the prompt is worded. This isn't a prompting problem to solve; it's a constraint to design around. If an action keeps requiring confirmation, that's by design.


## 9. Chat Prompting Surfaces

Chat (claude.ai web, mobile, and desktop) is the most constrained harness. There is no filesystem access, no Bash, no subagents, and no plan mode. The prompting surface is purely conversational.

### Artifacts are the primary output mechanism

In Chat, substantial code, documents, or visualizations are rendered as artifacts — inline interactive components. Prompting for good artifacts requires specifying the format and constraints:

```
Create a React component that displays a sortable data table.
Use only Tailwind CSS for styling — no external component libraries.
The data should be passed as a prop.
```

Key artifact-related prompting patterns:
- **Specify the framework** if it matters (React, vanilla JS, HTML/CSS)
- **State library constraints** ("use only Tailwind core utilities," "no external dependencies")
- **Describe interactivity** ("sortable columns," "click to expand rows")

### Projects as persistent context

Chat's Projects feature allows persistent instructions that apply across conversations within the project. This is Chat's equivalent of CLAUDE.md — use it for the same kinds of content: conventions, context, standing instructions.

```
# In Project instructions:
I'm building a Next.js 14 app with the App Router. Use TypeScript,
Tailwind CSS, and shadcn/ui components. Prefer server components
unless client interactivity is required.
```

### Conversational iteration is the dominant pattern

Chat's strength is the iteration loop. The most effective approach is:

1. **Initial request** — describe what you want
2. **Review Claude's attempt** — evaluate the output
3. **Targeted refinement** — steer specific aspects without rewriting everything

```
# Effective steering — targeted
Keep the layout, but change the color scheme to dark mode with
blue accents. Also make the sidebar collapsible.

# Ineffective — restates everything
Create a dashboard with a dark color scheme, blue accents, a
collapsible sidebar, [repeats all original requirements]...
```

Targeted steering preserves what's working and focuses the agent on what needs to change. Restating everything risks losing good aspects of the prior output and wastes tokens.

### No execution environment

Chat cannot run code, access filesystems, or execute commands. This changes prompt patterns fundamentally:

- Ask Claude to **write code as an artifact** you can copy and run locally, not to "run" or "execute" it
- For testing, ask Claude to **reason through expected behavior** rather than running tests
- For data analysis, **upload the data** and ask Claude to analyze it directly rather than writing a script to process it


## 10. The Iteration Loop

In agent harnesses, prompting is a conversation, not a one-shot design problem. The most effective pattern is a loop: brief, plan, steer, verify.

### Brief

Give the agent a clear task description with enough context to start. Don't over-specify the method — let the agent propose an approach.

```
The login endpoint doesn't handle expired refresh tokens correctly. It
returns a 500 instead of a 401 with a clear error message. The
relevant code is in src/auth/refresh.ts.
```

### Plan

Let the agent investigate and propose a plan. You can request this explicitly or use plan mode.

```
Before making changes, tell me your plan for fixing this.
```

Or end your brief with an invitation:

```
...If anything is unclear about the codebase or the expected behavior,
ask before implementing.
```

### Steer

Evaluate the agent's plan or partial work and redirect as needed. This is where conversational prompting is most powerful — you can course-correct before the agent goes far in the wrong direction.

```
Good analysis, but don't change the middleware layer. The fix should
be in the refresh handler itself — it should catch the TokenExpired
error before it bubbles up to the generic error handler.
```

### Verify

After implementation, have the agent confirm its work meets the requirements. This can be explicit or part of the workflow:

```
Run the tests and show me the diff of your changes before we're done.
```

### When to skip the loop

Not every task needs all four phases. For well-defined, low-risk changes, go straight from brief to execution:

```
Rename the `getUser` function to `fetchUserById` across the codebase.
Run tests after.
```

The iteration loop adds the most value when the task is ambiguous, the codebase is unfamiliar to the agent, or the change is high-risk.


## 11. Durable and Repeatable Process Prompts

An emerging pattern in agent harnesses is using a prompt not as a one-time instruction but as a repeatable process specification — something the agent will execute periodically or that you'll reuse across sessions.

### Design for re-execution

A durable prompt references relative state rather than absolute snapshots. It includes self-verification steps so the agent confirms it's working with current data.

```
# Brittle — references absolute state
Update the CHANGELOG. The last entry was for v2.3.1 released on
Jan 15. Add entries for the 3 PRs merged since then.

# Durable — references relative state
Update the CHANGELOG with entries for all PRs merged since the last
release. Check git log and the existing CHANGELOG to determine what's
already documented. Follow the existing format and voice.
```

### Include verification steps

When a prompt will be re-executed, build in checks that ensure the agent is operating on current state:

```
Audit our dependencies for known vulnerabilities:
1. Run `npm audit` and capture the output
2. For each high/critical vulnerability, check if we've already
   documented it in SECURITY.md
3. For new vulnerabilities, add them to SECURITY.md with the affected
   package, severity, and whether an upgrade path exists
4. If any vulnerability has a fix available, create a branch and
   upgrade it. Run tests to verify compatibility.
```

### Save process prompts as files or CLAUDE.md sections

If you run the same process regularly, save the prompt in a file and reference it:

```markdown
<!-- In CLAUDE.md or a dedicated file like .claude/processes/audit.md -->
## Dependency Audit Process
[the prompt above]
```

Then invoke it concisely:

```
Run the dependency audit process from CLAUDE.md.
```

### Parameterize when possible

When a prompt template applies to varying inputs, use clear placeholders or describe the variable part:

```
Review the PR at [URL]. Focus on: correctness, test coverage, and
whether the change follows our conventions in CLAUDE.md. Post a
summary of findings — don't comment on the PR directly.
```


## 12. Model Behavioral Implications

In agent harnesses, you often can't change the model mid-task (or the choice is session-level). What's actionable is understanding how each model's tendencies affect your prompt-writing strategy.

### Opus 4.6 — constrain the explorer

Opus over-explores. On open-ended prompts, it reads files it doesn't need, spawns sub-agents for simple lookups, and investigates tangents. This thoroughness is valuable for genuinely ambiguous tasks but wasteful for straightforward ones.

**Prompt adjustment:** Add explicit scope boundaries. Tell Opus what to skip, what directories to stay within, and when to stop investigating and start implementing.

```
Fix the null pointer in src/parser/tokenizer.ts. The bug is in the
handleEscape() function — you don't need to investigate the rest of
the parser. Read that one function, fix the bug, run tests.
```

**When to lean into it:** For deep investigation tasks (debugging a subtle issue, understanding a new codebase, complex refactors), Opus's thoroughness is its strength. Give it room with an appropriately open-ended prompt.

### Sonnet 4.6 — the efficient default

Sonnet acts decisively on well-specified tasks and handles ambiguity well. It needs less constraint than Opus but occasionally over-investigates when given explicit, non-exploratory instructions.

**Prompt adjustment:** Be direct and specific. Sonnet responds well to clear instructions and doesn't need the heavy guardrails Opus does. For exploratory tasks, you may need to explicitly invite deeper investigation.

```
# Sonnet handles this well without extra constraints
Refactor the database pool to use async initialization. Update
src/db/pool.ts and its tests.

# For exploration, explicitly invite depth
I'm seeing intermittent timeouts on the /search endpoint. Investigate
thoroughly — check the handler, the database queries, any caching
layers, and the connection pool configuration.
```

### Haiku 4.5 — set quality expectations

Haiku is fast and cheap but tends to take shortcuts on harder tasks, including hardcoding to pass tests rather than solving the general problem.

**Prompt adjustment:** Be explicit about quality expectations. State that solutions should be general, not test-specific. For complex tasks, consider breaking them into smaller pieces Haiku can handle well.

```
Implement the search ranking algorithm. The solution must handle
arbitrary input — do not hardcode for the test fixtures. If the test
cases seem insufficient to validate the general solution, tell me and
I'll add more.
```


## 13. Anti-Patterns by Platform

### General Anti-Patterns (All Harnesses)

| Don't | Why | Do instead |
|-------|-----|------------|
| Combine open-ended discovery with implementation in one prompt | Agent implements based on first (possibly wrong) understanding | Separate discovery from implementation with a review gate |
| Prescribe every step for a well-understood task | Removes the agent's ability to choose a better approach | State the goal and constraints; let the agent choose the method |
| Send a multi-phase project as a single message without a gate | Agent commits to an approach before you can review | Phase the work or explicitly ask for a plan before implementation |
| Ask "is that right?" instead of verifying | Agent will almost always say yes | Ask the agent to run tests, show diffs, or check specific properties |
| End with vague scope | "...and anything else that needs updating" invites unbounded work | Be explicit about what's in scope and what's deferred |

### Claude Code Anti-Patterns

| Don't | Why | Do instead |
|-------|-----|------------|
| Assume the agent knows your repo layout | Agent wastes time exploring or guesses wrong | Name relevant files/directories; use CLAUDE.md for persistent orientation |
| Give scope-unbounded instructions to Opus | Over-explores, reads unnecessary files, spawns sub-agents | Add explicit scope: which files, which directories, when to stop |
| Ask for artifacts without specifying where they go | Agent creates files in unexpected locations | Specify output paths: "Create the module at src/utils/retry.ts" |
| Repeat repo context every session | Wastes time and tokens; context may drift | Put stable context in CLAUDE.md |
| Use API jargon the harness controls | "Set budget_tokens to 16K" — you can't directly | Use the levers you have: effort level (`/model`), `Alt+T` for thinking, `--append-system-prompt` |
| Neglect CLAUDE.md for repeatable conventions | You'll re-specify the same constraints every session | Put stable conventions (test commands, style preferences, architecture notes) in CLAUDE.md |
| Ask for "everything" without a gate | No checkpoint to course-correct before the agent commits to an approach | End with "propose a plan before implementing" or decompose into explicit phases |

### Cowork Anti-Patterns

| Don't | Why | Do instead |
|-------|-----|------------|
| Assume Claude has access to your files | Cowork runs in a sandboxed VM; files need explicit folder mounting or upload | Mount the relevant folder first, or upload files directly |
| Use vague language when you want a specific output format | Skills activate on keyword matching; vague requests may miss the skill | Use specific format keywords: "create a spreadsheet," "make a PowerPoint," "generate a PDF" |
| Over-specify complex tasks upfront | Cowork has AskUserQuestion — it's designed to clarify interactively | Give a clear but concise brief; let Claude ask the right clarifying questions |
| Forget about the outputs folder | Files created in the working directory may not persist to your computer | Ask Claude to "save the file" explicitly when you want to keep the result |
| Try to override security constraints with clever phrasing | Action classification (prohibited/explicit-permission/regular) is non-negotiable | Design around the constraints; accept confirmation prompts for sensitive actions |

### Chat Anti-Patterns

| Don't | Why | Do instead |
|-------|-----|------------|
| Ask Claude to "run" or "execute" code | Chat has no execution environment | Ask Claude to write the code as an artifact you can copy and run locally |
| Rewrite the entire prompt on each iteration | Wastes tokens and may lose good aspects of prior output | Give targeted steering: "keep the layout, change the color scheme" |
| Assume artifacts persist across conversations | They don't, unless in a Project | Use Projects for ongoing work, or save artifacts locally |
| Ignore the Projects feature for ongoing work | You lose context between conversations | Set up a Project with persistent instructions for any multi-session effort |

### Agent-to-Subagent Anti-Patterns

| Don't | Why | Do instead |
|-------|-----|------------|
| Pass the full orchestrator context to the sub-agent | Wastes tokens, can confuse the worker | Send only the data and instructions the sub-agent needs for its specific task |
| Assume the sub-agent can ask for clarification | Sub-agents have no interactive loop with the orchestrator | Make the prompt self-contained with all necessary context |
| Use freeform output without structure | The orchestrator needs to parse the result programmatically | Specify JSON, structured lists, or tagged output format |
| Skip error handling instructions | Sub-agent will silently fail or fabricate results | Include explicit instructions: "If you can't complete the task, return structured partial results with a reason" |
| Default to general-purpose for all sub-agents | Expensive and often unnecessary | Use the most constrained type: Explore for reads, Bash for commands, general-purpose only when needed |

# InterSystems AI Hub — Exercise Workbook

**This book contains the exercises and nothing else.** The concepts, the diagrams and the API
explanations are in the slides, which you will be given as a PDF, and in
[`REFERENCE.md`](REFERENCE.md) if you prefer to read rather than listen.

Every exercise here tells you the file to open, the exact code to run, and what you should see. If
something does not match, [`docs/TROUBLESHOOTING.md`](docs/TROUBLESHOOTING.md) has a section per
failure.

## How to read a step

| Marker | Meaning |
|---|---|
| **Do this** | The change to make, with the file and the place in it |
| **Run this** | Paste it exactly. Unless it says otherwise, it goes in the IRIS terminal |
| **Expected result** | What proves the step worked. Do not move on without it |
| **Common error** | A failure that has actually happened here, and its cause |
| **Classroom shortcut** | Deliberately insecure, to save time. Never reuse outside this room |

All starter code compiles and runs as supplied. Six places are left incomplete, each marked
`TODO (Exercise XX)` in the source, and each of those TODO comments repeats the instructions you
will find here. No exercise starts from an empty namespace.

> **Why some lines in this book are uncomfortably long.** The IRIS terminal evaluates each line as
> you paste it, so a `while`, `for` or `if` block **must fit on one line** — split it across lines
> and the first line fails on its own with a bare `<SYNTAX>`. Loops here are therefore written as
> one line on purpose. Do not reformat them. Code that goes into a **file** has no such limit, which
> is why the class methods you write in C.1 and D.2 are laid out normally.

---

## Setting up — do this once

> **Joint workshop day:** Run the commands in this module in a terminal at the **repository root** (the folder with `compose.yaml`) - VS Code's terminal opens in `module2-aihub`, so type `cd ..` there first.

```bash
docker compose up -d
```

`aiworkshop-iris` reaches `Up (healthy)` in about 15 seconds. Your ports:

| Port | For |
|---|---|
| **42773** | Management Portal, Atelier REST, interoperability portal |
| **41972** | IRIS superserver — VS Code, the MCP bridge |
| **48080** | MCP over HTTP |

Open the IRIS terminal. **Every `objectscript` block in this book runs here** unless it says
otherwise:

```bash
docker exec -it aiworkshop-iris iris session IRIS -U IRISAPP
```

You should land at an `IRISAPP>` prompt.

### Getting your edits into IRIS

You edit files under `src/Workshop/`. Two ways to compile them:

- **VS Code** — save the file; the ObjectScript extension compiles on save.
- **Terminal** — `do ##class(Workshop.Setup.Build).CompileWorkshop()` compiles the whole package in
  the correct order.

> **Common error — your editor and IRIS disagree.** Loading a solution with `Workshop.Lab` replaces
> the class *in IRIS* and does not touch your file. Your own work is not lost, but the two differ
> until you recompile.

### Portal links

Sign in as `_SYSTEM` / `SYS`.

| Page | URL |
|---|---|
| Management Portal | <http://localhost:42773/csp/sys/UtilHome.csp> |
| Production configuration | <http://localhost:42773/csp/healthshare/irisapp/EnsPortal.ProductionConfig.zen> |
| Message Viewer | <http://localhost:42773/csp/healthshare/irisapp/EnsPortal.MessageViewer.zen> |
| Event Log | <http://localhost:42773/csp/healthshare/irisapp/EnsPortal.EventLog.zen> |
| Workflow tasks | <http://localhost:42773/csp/healthshare/irisapp/EnsPortal.WFTasklist.zen> |

> **Note.** The prefix is `/csp/healthshare/irisapp`, not `/csp/irisapp`. This is an IRIS for Health
> image, so a namespace's web application is `/csp/healthshare/<namespace>`.

## If you fall behind, or want to start over

```objectscript
do ##class(Workshop.Lab).Status()            // which exercises are done
do ##class(Workshop.Lab).SolveThrough("C.1")  // load every solution up to and including C1
do ##class(Workshop.Lab).Reset()             // back to the beginning
```

**Use `SolveThrough` rather than falling behind.** Later exercises build on earlier ones, so if you
want to skip C1 and still do C4, C1's solution has to be in place. `SolveThrough` loads the
prerequisites in order, and you can rejoin at any module.

From the host you can also run `./module2-aihub/reset-lab.sh --status`, `./module2-aihub/reset-lab.sh` or
`./module2-aihub/reset-lab.sh --hard` (PowerShell: `.\module2-aihub\reset-lab.ps1`). **`--hard`/`-Hard`: In the joint workshop environment this deletes the work of ALL THREE modules, not only module 2.**

> **`docker compose up` is not a reset.** The database survives `docker compose down`, so a solved
> namespace stays solved. Use the commands above.

---

# Exercise 0 — verify the environment

**Required before Module A.** An environment fault found halfway through the workshop costs far
more than this check does.

### 0.1 — confirm the container is up

**Run this** (in a shell, not the IRIS terminal):

```bash
docker compose ps
```

**Expected result:** `aiworkshop-iris` shows `Up (healthy)`.

### 0.2 — confirm Atelier REST answers

**Run this:** open <http://localhost:42773/api/atelier/> and sign in as `_SYSTEM` / `SYS`.

**Expected result:** JSON containing `"api":8`.

> **Note — a 401 before you sign in is correct.** The application requires password authentication.
> A **404** means the path is not being served at all; see `docs/TROUBLESHOOTING.md` §5.

### 0.3 — run the environment gate

**Run this:**

```objectscript
do ##class(Workshop.Verify).Run()
```

**Expected result:** **ten `OK` lines** and `Environment is good`.

```
  OK    namespace is IRISAPP
  OK    interoperability enabled
  OK    AI Hub classes present
  OK    outbound HTTPS reaches openai
  OK    provider key configured
  OK    provider can be constructed
  OK    provider answers a real prompt
  OK    demo event log seeded
  OK    Atelier REST answers on 52773
  OK    MCP Server /mcp/oncall registered
```

**Do not continue past a FAIL.** Each check maps to a section of
[`docs/TROUBLESHOOTING.md`](docs/TROUBLESHOOTING.md).

> **If you ran this before the workshop, you will have seen `7 OK  3 WAIT`.** That was the correct
> answer without a key. Now that you have one, put it in `.env`, run
> `docker compose up -d --force-recreate iris`, and you should get ten `OK`. If the three provider
> checks still say `WAIT`, the key did not reach the container.

> **Note.** The "provider can be constructed" check passes even with an invalid key, because
> constructing a provider validates nothing — and `ValidateConfig()` does not help either, as it
> returns 1 for a deliberately wrong key. Only "provider answers a real prompt" proves the key.
> The "outbound HTTPS" check needs no key at all: it asks the vendor to reject an invalid one, so
> being rejected proves DNS, TCP and TLS work over the real path.

### 0.4 — connect VS Code

**Do this:** open this folder in VS Code and let the InterSystems ObjectScript extension connect. The
connection is already written in `.vscode/settings.json`: `localhost`, port **42773**, namespace
`IRISAPP`, `_SYSTEM` / `SYS`.

**Expected result:** the ObjectScript explorer lists the `Workshop` package, and you can open
`src/Workshop/Agent/OnCall.cls`.

### 0.5 — write down your answer to this

Before you write any code:

> **Name two things you would require before letting an agent restart a production host on its own.**

Keep it. You will be asked for it at the end.

---

# Exercise A — your first agent

You will build an agent twice: once by hand in the terminal, once as a class.

### A.0 — find the edge of what an agent can do

An agent needs four things: a provider, a model, a system prompt and a session. You can assemble one
by hand in the terminal, with no class and nothing compiled.

Build one — and then **ask it a question it cannot answer yet**, because that is where the
interesting boundary is.

**Run this:**

```objectscript
set key      = $system.Util.GetEnviron("OPENAI_API_KEY")
set provider = ##class(%AI.Provider).Create("openai", {"api_key":(key)})
set agent    = ##class(%AI.Agent).%New(provider)
set agent.Model        = "gpt-4o"
set agent.SystemPrompt = "You are the integration on-call engineer for this IRIS instance."
set session  = agent.CreateSession()
write agent.Chat(session, "Which business host is reporting the most errors?").Content
```

**Expected result:** it **cannot** tell you. Most often you get a competent explanation of how you
*would* find out — *"you would need to review error logs… this typically involves…"* — and sometimes
a confident answer containing invented host names. Either way, read it: an agent with a good system
prompt and no tools is still only a language model.

Now give it exactly one capability and ask the same question again:

```objectscript
do agent.UseToolSet("Workshop.Tools.OnCall")
set s2 = agent.CreateSession()
write agent.Chat(s2, "Which business host is reporting the most errors?").Content
```

**Expected result:** a real host name from this instance's event log — *"The business host
'HL7Router' is currently reporting the most errors."*

**Answer this before moving on:** the system prompt was identical in both runs. So what changed?

> **Note — you never called `%Init()`.** You passed the provider to the constructor, so there was
> nothing left to initialise. A.3 comes back to this.

Nothing in A.0 is handed in. Type it, run it, move on.

### A.1 — write the agent's triage brief

**File:** `src/Workshop/Agent/OnCall.cls`. Find the `XData INSTRUCTIONS` block; it currently reads
`You are a helpful assistant.` followed by a `TODO (Exercise A.1)` comment that repeats these
instructions.

**First, run the triage question with the stub prompt still in place:**

```objectscript
set a = ##class(Workshop.Agent.OnCall).%New()
do a.%Init()
set s = a.CreateSession()
write a.Chat(s, "What is going wrong in the production right now?").Content
```

**Expected result:** a usable but shallow answer — a restated list of event-log rows such as
*"1. SchedulingService… 2. BillingFeed…"*. The tools are attached by `Parameter TOOLSETS` whatever
the prompt says, so the agent does look at real data. **Keep this reply to compare against.**

**Do this:** replace `You are a helpful assistant.` with a triage brief covering four points. The
wording is yours; there is no single correct answer.

1. **Evidence.** Call a tool before offering an opinion. Never speculate about an error it has not
   read.
2. **Grouping.** Relate failures to each other rather than listing rows.
3. **Confidence.** State how certain the diagnosis is.
4. **Permitted actions.** It may propose any remediation, and may perform read operations only.
   Restarting a host requires human approval.

Compile (save in VS Code, or `do ##class(Workshop.Setup.Build).CompileWorkshop()`), then run the
**same four lines again**.

**Expected result:** the second reply groups related failures — for example, *HL7Router failing
because LabOperation is refusing connections* — and states a confidence level.

### A.2 — confirm the lifecycle

**Run this:**

```objectscript
set a = ##class(Workshop.Agent.OnCall).%New()
do a.%Init()
set s = a.CreateSession()
write a.Chat(s, "Summarise the current state in one sentence.").Content
```

**Expected result:** one sentence of text. Those four calls — `%New()`, `%Init()`,
`CreateSession()`, `Chat()` — are the whole lifecycle.

> **Common error — the property is `Content`.** `response.%Get("content")` throws
> `<METHOD DOES NOT EXIST>`.

### A.3 — break it on purpose

**Do this:** run the same sequence but **delete the `do a.%Init()` line**.

```objectscript
set a = ##class(Workshop.Agent.OnCall).%New()
set s = a.CreateSession()
```

**Expected result:**

```
ERROR <%AICore>IncompleteInitialization: Workshop.Agent.OnCall:
       Initialization incomplete for Provider
  location=CreateSession+5^%AI.Agent.1
```

**Before you run it, predict which call fails** — `%New()`, `CreateSession()`, or a later `Chat()`.
Then check whether you were right.

> **Common error — the failure is at `CreateSession()`, not `Chat()`.** If you delete `%Init()` and
> jump straight to `Chat()`, you never reach this error and the step looks broken.

**Now find out what `%Init()` actually does, by making the class work without it.** Supply the
provider yourself, exactly as you did by hand in A.0:

```objectscript
set p = ##class(%AI.Provider).Create("openai", {"api_key":($system.Util.GetEnviron("OPENAI_API_KEY"))})
set a = ##class(Workshop.Agent.OnCall).%New()
set a.Provider = p
set a.Model    = "gpt-4o"
set s = a.CreateSession()
write "no %Init() needed: ", $isobject(s), !
```

**Expected result:** `1`. `CreateSession()` succeeds with no `%Init()` anywhere.

So `%Init()` is not a ritual and it is not validation. It is the step that **builds the provider**
from the class's parameters and its `%OnInit()` hook. Hand the agent a provider and there is nothing
left for it to do — which is exactly why A.0 needed no `%Init()` either.

Go back to `do a.%Init({"siteName": ...})` for the rest of the workshop: the later exercises rely on
`Workshop.Provider` resolving the provider, and on the Config Store doing it in D.1.

### A.4 — put the site name in the prompt

Right now the brief is hard-coded for one site. A placeholder makes the same class serve many.

**Do this, in two parts.**

**Part 1 — the placeholder.** In `src/Workshop/Agent/OnCall.cls`, inside the `XData INSTRUCTIONS`
block you wrote in A.1, put `{{siteName}}` into the prose. For example, change an opening line to:

```markdown
You are the integration on-call engineer for **{{siteName}}**, an InterSystems IRIS
interoperability site.
```

Add a sentence telling it to name the site in its first reply, so you can see the substitution:

```markdown
Always name the site in your first sentence, so the engineer knows which environment
you are talking about.
```

`{{...}}` is a template placeholder. At `%Init()` time it is replaced by the matching key from a
context object you supply.

**Part 2 — supply the value.** `%Init()` takes an optional `%DynamicObject`; its real signature is
`%Init(context As %DynamicObject = {{}})`. Each key becomes available to the template.

**Run this:**

```objectscript
set a = ##class(Workshop.Agent.OnCall).%New()
do a.%Init({"siteName": "Boston General"})
set s = a.CreateSession()
write a.Chat(s, "What is going wrong in the production right now?").Content
```

**Expected result:** the reply names **Boston General** in its first sentence.

> **Common error — from now on, every `%Init()` needs the context object.** Once `{{siteName}}` is
> in the instructions, a bare `%Init()` fails with
> `<%AICore>TemplateUnresolvedName: Template: unresolved name '{{siteName}}'`. If a later exercise
> stops working, this is why.

> **Note.** A placeholder with no matching key is left as literal text rather than erroring, so a
> typo in the placeholder name shows up in the reply instead of as a failure.

### A.5 — read the session statistics

**Run this,** in the same session you just used:

```objectscript
write a.Chat(s, "And which host is worst affected?").Content
write s.GetStats().%ToJSON()
```

That prints everything at once. For something readable, pull out the four fields that matter:

```objectscript
set st = s.GetStats()
write "tool calls : ", st.%Get("total_tool_calls"), !
write "prompt tok : ", st.%Get("total_prompt_tokens"), !
write "llm ms     : ", st.%Get("total_llm_duration_ms"), !
write "tool ms    : ", st.%Get("total_tool_duration_ms"), !
```

**Expected result:** `total_prompt_tokens` has increased across the two turns, and
`total_tool_calls` is at least 1.

**Now make `total_tool_calls` come out as zero, deliberately.** Ask the same agent — tools attached,
unchanged — something that needs no data from this instance:

```objectscript
set s3 = a.CreateSession()
write a.Chat(s3, "In one sentence, what does idempotent mean?").Content, !
write "tool calls: ", s3.GetStats().%Get("total_tool_calls"), !
```

**Expected result:** a good answer, and `tool calls: 0`.

That is the point of the metric. The agent decides per question whether a tool is needed, so
`total_tool_calls` distinguishes an answer drawn from your data from an answer drawn from the model's
training — and the second kind is invention as far as your production is concerned. Compare `llm ms`
with `tool ms` too: reading the database is almost free and the model is the cost.

---

# Exercise B.1 — make a tool describable

A tool's description is not a comment: it is the only thing the model has to decide which tool to
call.

### B.1.1 — read what the model is told about each tool

`Workshop.Tools.OnCall` is the ToolSet attached to your agent, and it exposes **four** tools:
`DraftIncidentNote`, `RestartHost`, `RecentErrors` and `FailedMessages`.

The model never sees your ObjectScript. It sees a JSON description generated from each method
signature — the tool's name, what it does, and its arguments. Before you change any of that, look at
what the description actually says. In particular: **for each tool, which arguments must the model
supply, and which may it leave out?**

**Run this:**

```objectscript
set ts = ##class(Workshop.Tools.OnCall).%New()
set i = ts.%Discover().tools.%GetIterator()
while i.%GetNext(.k, .t) { write $extract(t.name_"                  ",1,19), "required: ", t.parameters.required.%ToJSON(), ! }
```

**Expected result:** four tools, of which two demand an argument and two demand nothing:

```
DraftIncidentNote  required: ["summary"]
RestartHost        required: ["configName"]
RecentErrors       required: []
FailedMessages     required: []
```

So the model must always pass `summary` when it drafts an incident note, and must always pass
`configName` when it restarts a host. It may call `RecentErrors` and `FailedMessages` with no
arguments at all.

**Now the question to answer.** `DraftIncidentNote` *also* takes an argument called `configName` —
the same name that is **required** on `RestartHost` — and yet on `DraftIncidentNote` it is optional.
Nothing in the JSON explains why.

Open `src/Workshop/Tools/OnCall.cls`, find the signatures of both `DraftIncidentNote` and
`RestartHost`, and work out the rule that decides which arguments end up in that `required` list. It
is one line of reasoning, and you never wrote any JSON.

<details>
<summary>Check your answer</summary>

An argument with a default is optional. An argument without one is required.

```objectscript
Method DraftIncidentNote(summary As %String,              // no default -> required
                         configName As %String = "",      // default    -> optional
                         severity As %String = "medium")  // default    -> optional
Method RestartHost(configName As %String)                 // no default -> required
```

The same argument name is required in one tool and optional in the other purely because the two
signatures differ. The whole JSON schema — types, names, required list — was derived from
ObjectScript.
</details>

> **Common error — `%Discover()` is an instance method.** `##class(Workshop.Tools.OnCall).%Discover()`
> throws `<METHOD DOES NOT EXIST>`. Call `%New()` first, as above. (`%Dump()` *is* a class method,
> and prints this plus the attached policies.)

### B.1.2 — describe the arguments

**File:** `src/Workshop/Tools/OnCall.cls`, method `DraftIncidentNote`. It currently reads:

```objectscript
Method DraftIncidentNote(
    summary As %String,
    configName As %String = "",
    severity As %String = "medium") As %DynamicObject
```

**Do this:** add a `DESCRIPTION` type parameter to each of the three arguments:

```objectscript
Method DraftIncidentNote(
    summary As %String(DESCRIPTION="One-line summary of the incident"),
    configName As %String(DESCRIPTION="Business host the incident concerns") = "",
    severity As %String(DESCRIPTION="low, medium or high") = "medium") As %DynamicObject
```

Compile, then re-run the `%Discover()` block from B.1.1.

**Expected result:** the descriptions now appear. To see them in full:

```objectscript
write ##class(Workshop.Tools.OnCall).%New().%Discover().%ToJSON()
```

The JSON schema sent to the model is inferred from the method signature. An argument with no
`DESCRIPTION` reaches the model with no explanation of its purpose.

### B.1.3 — use the tools for real

**Run this:**

```objectscript
set a = ##class(Workshop.Agent.OnCall).%New()
do a.%Init({"siteName": "Boston General"})
set s = a.CreateSession()
write a.Chat(s, "What is failing in the production, and why?").Content
```

**Expected result:** the reply names real `ConfigName` values from `Ens_Util.Log` and relates them,
for example:

> LabOperation shows two errors of "TCP connect timed out"… HL7Router shows three errors related to
> "Failed to send message to LabOperation: connection refused." These are likely an extension of the
> connectivity issues seen with LabOperation.

---

# Exercise B.2 — filter the tool list

The same ToolSet, but you decide which of its methods the model is allowed to see — and then
attach a tool that is not written in ObjectScript at all.

### B.2.1 — hide a tool from the model

**File:** `src/Workshop/Tools/OnCall.cls`, the `XData Definition` block. Find the `<ToolSet>`
element and add this line inside it:

```xml
<Exclude Match="^Draft"/>
```

Compile, then re-run the `%Discover()` block from B.1.1.

**Expected result:** three tools instead of four — `DraftIncidentNote` is gone.

`<Include>` and `<Exclude>` accept:

| Attribute | Matches |
|---|---|
| `Tool=` | one exact tool name |
| `Match=` | a POSIX regular expression, partial match |
| `Rename=` | relabels a tool |

**Now remove the `<Exclude>` line again** and recompile. You need all four tools for B.3.

### B.2.2 — add a tool that is not written in ObjectScript

The file is already in your repository: `src/Python/oncall_mcp.py`, a small MCP server exposing two
runbook-lookup tools. Your job is to attach it.

**Do this:** in `src/Workshop/Tools/OnCall.cls`, add an `<MCP>` element inside the `<ToolSet>`,
immediately above `<Policies>`:

```xml
<MCP Name="OnCallPy">
  <Stdio Executable="/usr/irissys/bin/irispython" Args="/home/irisowner/dev/Python/oncall_mcp.py"/>
</MCP>
```

Compile. Now list the tools again, but print the `source` field this time — that is the one that
says where a tool comes from:

```objectscript
set ts = ##class(Workshop.Tools.OnCall).%New()
set i = ts.%Discover().tools.%GetIterator()
while i.%GetNext(.k, .t) { write $extract(t.name_"                  ",1,19), t.source, ! }
```

**Expected result:** a fifth entry, and it is the only one that does not come from `iris`:

```
DraftIncidentNote  iris
RestartHost        iris
OnCallPy           mcp
RecentErrors       iris
FailedMessages     iris
```

> **Note — re-running the B.1.1 block works too**, and shows `OnCallPy  required: []` alongside the
> other four. It just does not tell you that this one is a Python process rather than an
> ObjectScript method, which is the whole point of the step.

> **Note — you will not see the Python tool names here, and that is correct.** `OnCallPy` is a
> placeholder carrying a `toolref`; AI Hub does not launch the child process until an agent runs. Do
> not go looking for `lookup_runbook` in `%Discover()` output.

**Now use it.** Ask a question that needs both kinds of tool:

```objectscript
set a = ##class(Workshop.Agent.OnCall).%New()
do a.%Init({"siteName": "Boston General"})
set s = a.CreateSession()
write a.Chat(s, "Find the most recent error in the production, then look up the runbook for it and tell me the first check to perform.").Content
write !, "tool calls: ", s.GetStats().%Get("total_tool_calls"), !
```

**Expected result:** `tool calls: 2`, and an answer that chains them — for example:

> The most recent error involves "SchedulingService" with "Queue depth exceeded 5000 pending items."
> The relevant runbook is "RB-033 Queue depth alert." The first check is to identify whether the
> consumer is stopped or merely slow.

One of those calls read `Ens_Util.Log` through ObjectScript; the other ran a Python process. The
agent cannot tell the difference, and neither can the model.

### Serving a mixed room

`Platform` is a regular expression matched against `"<os> <version> <arch>"`. The first match wins,
and a `<Stdio>` with no `Platform` is the fallback, so one ToolSet definition serves Windows and
Apple Silicon from the same file:

```xml
<MCP Name="OnCallPy">
  <Stdio Platform="macos.*aarch64" Executable="/usr/irissys/bin/irispython" Args="/home/irisowner/dev/Python/oncall_mcp.py"/>
  <Stdio                           Executable="/usr/irissys/bin/irispython" Args="/home/irisowner/dev/Python/oncall_mcp.py"/>
</MCP>
```

> **Common error — it must be `irispython`, not `python3`.** `fastmcp` is installed in
> `/usr/irissys/mgr/python`, which is on IRIS's embedded-Python path and not on the system
> interpreter's. With `python3` the child process dies with `ModuleNotFoundError: No module named
> 'fastmcp'` and the tool simply never appears.

> **Common error — never write to stdout in an MCP server.** stdout *is* the transport. A stray
> `print()` corrupts the stream and the tool vanishes from the agent's list with no error anywhere.
> Send diagnostics to stderr, as `oncall_mcp.py` does.

> **Note.** Use `@{env:VAR}` for any credential in this XML, never a literal.

---

# Exercise B.3 — publish IRIS as an MCP server

Same tools, same ObjectScript — now callable from the Codex chat you already used in Part 1, with
no new client to install.

The dispatch class is already written and is one parameter:

```objectscript
Class Workshop.MCP.Service Extends %AI.MCP.Service
{
Parameter SPECIFICATION As STRING = "Workshop.Tools.OnCall";
}
```

### B.3.1 — register the MCP application

**Run this:**

```objectscript
do ##class(Workshop.MCP.Setup).Run("IRISAPP")
do ##class(Workshop.MCP.Setup).Report()
```

**Expected result:** `/mcp/oncall` is reported with `Type=18`, `enabled=1` and `MatchRoles` holding
`%All`. It also appears under Management Portal > System Administration > Security > Applications >
MCP Servers.

`Type=18` is what makes an application an MCP Server rather than a web application.

> **Classroom shortcut — `MatchRoles=":%All"`.** In production, authenticate the bridge and grant a
> single purpose-built role holding only the resources the ToolSet reads.

### B.3.2 — start the bridge

**Run this** in a shell, not the IRIS terminal:

```bash
docker exec -d aiworkshop-iris /usr/irissys/bin/iris-mcp-server --config=/home/irisowner/config_http.toml run
```

**Expected result:** nothing printed — it runs detached. Confirm it is listening:

```bash
docker exec aiworkshop-iris sh -c "ss -lntp | grep 8080"
```

**Expected result:** a `LISTEN` line owned by `iris-mcp-server`.

The bridge reaches IRIS over **wgproto on port 1972**, the superserver — not HTTP. No web server is
involved, and its port 8080, published as 48080, has nothing to do with 52773.

### B.3.3 — point Codex at it

**Do this:** add the server to Codex, either through the extension's **MCP servers** settings pane or
by editing its config file directly. On Windows that file is `.codex\config.toml` in your user
folder; on macOS and Linux, `~/.codex/config.toml`:

```toml
[mcp_servers.iris-oncall]
enabled = true
url = "http://localhost:48080/mcp"
```

The name after `mcp_servers.` is yours to choose; it is how Codex will refer to the server.

Reload the Codex window so it picks up the change, then **ask it in the chat**:

> what tools does my iris-oncall mcp server have?

**Expected result:** **six** tools, all prefixed `mcp_oncall_`:

```
mcp_oncall_RecentErrors
mcp_oncall_FailedMessages
mcp_oncall_DraftIncidentNote
mcp_oncall_RestartHost
mcp_oncall_lookup_runbook
mcp_oncall_list_runbooks
```

**Count them, because the last two are the interesting part.** Those are the Python tools you
attached in B.2.2, and they have arrived here carrying the same `mcp_oncall_` prefix as the
ObjectScript ones. Nothing in that list tells Codex — or you — which tools are ObjectScript methods
and which are a Python process this instance starts on demand.

> **Note — this is not what `%Discover()` told you.** In B.2.2 the local listing showed five
> entries, the fifth being a single `OnCallPy` placeholder with `source: mcp`, and the Python tool
> names were deliberately absent. Over MCP you get the opposite: no `OnCallPy`, and the two real
> tool names instead. The MCP service resolves the nested server when a client asks what is
> available; `%Discover()` does not, because nothing has needed the child process yet.

> **If you see four**, there are two possibilities. Either you have not done B.2.2, or your
> instructor cut it — that is a correct result for that state, the four ObjectScript tools, and the
> rest of this exercise works the same way. Or **your bridge was already running before you
> compiled B.2.2**: the bridge caches what it discovered at startup, so it will keep reporting four
> indefinitely. Restart it and ask again:
>
> ```bash
> docker exec aiworkshop-iris pkill -f iris-mcp-server
> ```
> ```bash
> docker exec -d aiworkshop-iris /usr/irissys/bin/iris-mcp-server --config=/home/irisowner/config_http.toml run
> ```

> **Note — the URL path is `/mcp`, not `/mcp/oncall`.** The endpoint path names the IRIS application
> and becomes a prefix on the tool *names*; it is not part of the URL. Both the port and the path
> come from `config_http.toml`.

> **Common error — the tool names carry the endpoint path as a prefix.** `/mcp/oncall` gives
> `mcp_oncall_RecentErrors`, and you get the prefix even with a single endpoint configured. The
> server's own `initialize` text describes the convention wrongly, as `service_tool` — and Codex
> reads that text too, so it may guess a wrong name once before correcting itself.

### B.3.4 — have Codex triage the production

This is the moment the module has been building to: an agent that is **not** the one you wrote, in an
editor that knows nothing about IRIS, reading your interoperability data through tools you declared
in ObjectScript.

**Ask Codex:**

> so can you tell me what is the status of my iris production now? do I have any errors? what should
> I do with them?

**Expected result:** it calls `mcp_oncall_RecentErrors`, names real hosts from your event log —
`HL7Router`, `LabOperation`, `BillingFeed`, `SchedulingService` — and suggests remediation.

Nothing in Codex was taught about IRIS. It read the same tool descriptions you were looking at in
B.1.1, which is why those descriptions mattered.

### B.3.5 — try to make it act

**Ask Codex:**

> can you restart the LabOperation for me?

**Expected result:** it tries, and is **refused**:

```
Tool access denied: Provider policy denied: ERROR #5001: DENIED: 'RestartHost'
requires a human approval row. Draft the change and ask the on-call engineer
to approve it.
```

Nobody has written that policy yet — it is Module C — and it is already enforced across a transport
you connected five minutes ago, from a client that is not your code. **That** is the point of the
step: the control lives with the data, not with the caller.

> **Note.** Codex will usually relay the refusal and offer to draft an incident note instead, which
> is exactly what the tool descriptions ask for.

### If Codex is not available

A dependency-free Python client ships with the workshop and speaks the same protocol:

```bash
python module2-aihub/src/Python/mcp_smoke.py
python module2-aihub/src/Python/mcp_smoke.py RestartHost '{"configName":"LabOperation"}'
```

It needs Python 3.10+ and nothing outside the standard library. Run it **from the host** — 48080 is
the published port and does not exist inside the container. It is also the better tool for
diagnosing the bridge, because it prints the raw protocol.

> **Common error — `tools/list` returns only `iris_status`.** The application lost `MatchRoles`. The
> bridge still starts and still reports `discovered 1 endpoint(s)`, so run
> `python module2-aihub/src/Python/mcp_smoke.py iris_status` to see the real cause — `HTTP 403 Forbidden`. Fix it,
> then **restart the bridge**: a failed discovery is cached for five minutes.

> **Note.** The bridge reports `WebSocket error` even on the HTTP transport. Ignore the wording; the
> denial is real.

---

# Exercise C — stateful tools and an approval gate

Two things a working agent needs and a demo agent does not: memory that survives a turn, and a
refusal it cannot talk its way past.

### C.1 — give a tool memory

**File:** `src/Workshop/Tools/Worklist.cls`. Two ClassMethods carry `TODO (Exercise C.1a)` and
`TODO (Exercise C.1b)`, and each TODO comment contains the replacement code.

**Do this:** change both from `ClassMethod` to instance `Method`, using the `..Items` property
instead of the process-private global the starter falls back on.

`AddItem` becomes:

```objectscript
Method AddItem(item As %String(DESCRIPTION="Item to add to the worklist")) As %DynamicObject
{
    Set ..Items = ..Items _ item _ $Char(10)
    Return {"added": (item), "count": (..Count())}
}
```

`ListItems` becomes:

```objectscript
Method ListItems() As %DynamicObject
{
    Set out = []
    For i = 1:1:$Length(..Items, $Char(10)) {
        Set line = $Piece(..Items, $Char(10), i)
        Continue:line=""
        Do out.%Push(line)
    }
    Return {"items": (out), "count": (out.%Size())}
}
```

Compile, then check:

```objectscript
set w = ##class(Workshop.Tools.Worklist).%New()
set i = w.%Discover().tools.%GetIterator()
while i.%GetNext(.k,.t) { write t.name, " stateful=", t.stateful, ! }
```

**Expected result:** all three tools report `stateful=1`.

A `ClassMethod` is stateless: it has no instance, so it cannot reach `..Items`. An instance `Method`
is stateful, and AI Hub keeps one instance of the tool class alive for the session.

### C.2 — find out how long that state lives

`Workshop.Tools.Worklist` now keeps its items in `..Items`, an instance property, so each instance
of the class holds its own worklist. That much follows from C.1.

The question that matters when you build something like this for real is different: **how long does
one agent's worklist survive?** Guess before you measure.

A stateful tool cannot be attached with `Parameter TOOLSETS`; you instantiate it and add it:

```objectscript
set a = ##class(Workshop.Agent.OnCall).%New()
do a.%Init({"siteName": "Boston General"})
set w = ##class(Workshop.Tools.Worklist).%New()
do a.ToolManager.AddTool(w)
```

Add an item in one session:

```objectscript
set s1 = a.CreateSession()
do a.Chat(s1, "Add 'check HL7Router' to the worklist using your tool.")
```

**Now predict:** you are about to call `CreateSession()` again, which starts a conversation with no
message history. Will the new session see that worklist item?

```objectscript
set s2 = a.CreateSession()
write a.Chat(s2, "List the worklist items using your tool.").Content
```

**Expected result:** the item **is** still there. A fresh session, with no memory of the first
conversation, still sees it.

Finally, a brand-new agent:

```objectscript
set b = ##class(Workshop.Agent.OnCall).%New()
do b.%Init({"siteName": "Boston General"})
set w2 = ##class(Workshop.Tools.Worklist).%New()
do b.ToolManager.AddTool(w2)
write b.Chat(b.CreateSession(), "List the worklist items using your tool.").Content
```

**Expected result:** empty.

So tool state belongs to the **agent**, not the session — the tool object is created with the agent
and lives as long as it does. Two consequences worth carrying out of the room:

- Clearing a conversation does **not** clear tool state. If the state is sensitive, clear it
  yourself.
- Anything that must outlive the agent needs a global or a persistent class, not a property.

### C.3 — write the approval gate

**File:** `src/Workshop/Policy/ApprovalGate.cls`, the `TODO (Exercise C.3)` block inside
`%CanExecute()`. It currently refuses every guarded tool unconditionally. Your job is to refuse only
the ones a human has not approved.

#### First, see what you are given

`%CanExecute()` receives three arguments:

```objectscript
Method %CanExecute(toolref As %String, call As %DynamicObject, metadata As %DynamicObject) As %Status
```

`toolref` is the tool name. `call` is the model's actual request. Before writing any logic, look at
it — add this line as the first line inside the `If $Find(toolref, guarded) {` block, compile, and
run the C.4 denial command below:

```objectscript
Write !, "call = ", call.%ToJSON(), !
```

**Expected result:**

```
call = {"arguments":{"configName":"HL7Router"},"id":"call_id","name":"RestartHost"}
```

So `call` has three keys, and the one you want is inside `arguments`: the host the agent is asking
you to restart. `call.arguments` is itself a `%DynamicObject`.

#### Reading a key out of it

A `%DynamicObject` is read with `%Get()`:

```objectscript
Set configName = call.arguments.%Get("configName")
```

> **Common error — `$Get()` does not work here and does not complain.**
> `$Get(call.arguments.configName)` returns an **empty string** rather than erroring. If your policy
> then treats "no host supplied" as a refusal you get a plausible-looking denial for the wrong
> reason; if it treats it as a pass, you have a gate that approves everything. Use `%Get()`.

Take the `Write` line back out once you have seen it. A policy that writes to the current device
breaks every `tools/call` over MCP, because during an HTTP request that device is the response body.

#### Now write the check

1. **Read the host** from `call` as above.
2. **Decide what to do when it is missing.** The agent supplies this value, so it may be absent or
   wrong. Refusing is the safe answer; say why in the message.
3. **Ask the ledger** whether this host is approved for this action:
   `##class(Workshop.Data.Approval).IsApproved(configName, guarded)`.
4. **Return `$$$OK`** when approved. Otherwise return
   `$$$ERROR($$$GeneralError, msg)` with a message that **names the host** — you will be reading
   that message in C.4, and "denied" on its own tells you nothing.

**The requirement that makes this a security control rather than a feature:** scope the check to the
host as well as the action. An approval to restart `HL7Router` must not authorise restarting
`LabOperation`. C.4 tests exactly that, so if you skip it the next step will catch you.

The ledger class is supplied. Its API:

```objectscript
##class(Workshop.Data.Approval).IsApproved(configName, action)   // 1 or 0
##class(Workshop.Data.Approval).Request(configName, action, why) // returns an id
##class(Workshop.Data.Approval).Approve(id)                      // marks it APPROVED
```

<details>
<summary>Stuck on the shape of it? The two lines that matter</summary>

```objectscript
Set configName = ""
If $IsObject(call), call.%IsDefined("arguments"), $IsObject(call.arguments) {
    Set configName = call.arguments.%Get("configName")
}
If configName = "" {
    Return $$$ERROR($$$GeneralError, "DENIED: '"_guarded_"' needs a configName to check against.")
}
If '##class(Workshop.Data.Approval).IsApproved(configName, guarded) {
    Return $$$ERROR($$$GeneralError, "DENIED: '"_guarded_"' on '"_configName_"' has no APPROVED row.")
}
```

The guards around `call` and `arguments` are not ceremony: a policy that throws takes the whole tool
call down with it, and you would be debugging your gate rather than the agent.
</details>

### C.4 — test the gate in both directions

**Run this:**

```objectscript
do ##class(Workshop.Data.Approval).Reset()
set a = ##class(Workshop.Agent.OnCall).%New()
do a.%Init({"siteName": "Boston General"})
do a.ToolManager.ExecuteTool("RestartHost", {"configName":"HL7Router"})
```

**Expected result:** denied, with your message naming `HL7Router`.

Now approve it and try again:

```objectscript
set id = ##class(Workshop.Data.Approval).Request("HL7Router","RestartHost","classroom test")
do ##class(Workshop.Data.Approval).Approve(id)
do a.ToolManager.ExecuteTool("RestartHost", {"configName":"HL7Router"})
```

**Expected result:** permitted.

Finally, prove the approval is scoped to the host:

```objectscript
do a.ToolManager.ExecuteTool("RestartHost", {"configName":"LabOperation"})
```

**Expected result:** still denied. The agent did not change between these calls — the state of the
system changed, and the policy read it.

### C.5 — find out how far your gate actually reaches

**Do not skip this step.** It is the most important finding in the workshop, and this time you are
the one doing the measuring.

You wrote one policy class and attached it to one ToolSet. The question this step answers is how
much of the system that single attachment actually covers, and the answer is not "all of it".

There are three different ways a tool in this workshop can be called:

1. **Through the agent** — `agent.ToolManager.ExecuteTool()`, which is also what `Chat()` uses
   internally when the model decides to call a tool.
2. **Over MCP** — the bridge and the `mcp_oncall_*` tools from B.3.
3. **Directly on the ToolSet** — `ToolSet.%Invoke()`, which is any ObjectScript in the instance.

You built the first two. Test both of them against the gate you wrote in C.3, fill in the table
from your own results rather than from this book, and then work out what that tells you about the
third.

First confirm the policy really is attached to the ToolSet:

```objectscript
set ts = ##class(Workshop.Tools.OnCall).%New()
write $classname(ts.%GetAuthorizationPolicy()), !
```

**Expected result:** `Workshop.Policy.ApprovalGate`.

Clear the approval table, so that a refusal cannot be confused with a leftover row from C.4:

```objectscript
do ##class(Workshop.Data.Approval).Reset()
```

**Path 1 — through the agent.**

```objectscript
set a = ##class(Workshop.Agent.OnCall).%New()
do a.%Init({"siteName": "Boston General"})
do a.ToolManager.ExecuteTool("RestartHost", {"configName":"LabOperation"})
```

**Path 2 — over MCP.** The bridge from B.3 should still be running; if not, restart it. Then ask
Codex, in the chat you pointed at the server in B.3:

> can you restart the LabOperation host for me?

Codex will tell you it was refused, and usually quotes the refusal. If you want to see the raw
protocol instead, the fallback client takes the tool and its arguments directly, from the host:

```bash
python module2-aihub/src/Python/mcp_smoke.py RestartHost '{"configName":"LabOperation"}'
```

**Now complete these two rows from what you observed:**

| Execution path | Was the policy enforced? |
|---|---|
| `agent.ToolManager.ExecuteTool()` | ? |
| MCP `tools/call` | ? |

<details>
<summary>Check your results</summary>

Both are refused, and the message is the one your own `%CanExecute()` returned in C.3. Two very
different callers — a model choosing a tool, and an editor on your laptop speaking a wire protocol —
and one policy class covered both without knowing either existed.
</details>

**Now the question that matters.** Both of those paths went through `%AI.ToolMgr`: the agent's tool
manager calls it, and the MCP service calls it. The policy is enforced *there*, not on the ToolSet.
So before reading on, answer this: what happens to a call that does not go through `%AI.ToolMgr` at
all?

That is path 3. `ToolSet.%Invoke()` dispatches straight to the method, and the policy you attached
is never consulted — not denied, **never asked**:

```
IRISAPP> write ts.%Invoke("RestartHost", {"configName":"LabOperation"}).%ToJSON()
{"restarted":0,"config_name":"LabOperation","note":"not implemented in the starter"}
```

In this workshop `RestartHost` is a stub, so nothing actually restarted. In your system it would
have. You will measure this yourself in **D.2.2**, where the same call also turns out to leave no
audit row behind it.

**The conclusion, which is the argument the whole workshop exists to make:** everything you expose to
an agent, you have also exposed to any ObjectScript in the instance that calls `%Invoke()`. The
policy protects the agent path and the MCP path. It does not protect you from your own code.

**One more thing worth knowing,** because it will bite anyone who writes a test harness: the two
paths do not even return the same shape. `ExecuteTool()` wraps the result as
`{"timing":0.0024,"value":{…}}`; `%Invoke()` returns it unwrapped. Code written against one will not
work against the other.

> **Note.** The agent will often decline to restart a host and offer to draft a note instead, even
> when you tell it the action is authorised. That comes from its instructions, not from the policy.
> Prompt instructions are not enforcement.

> **Note.** From here on you may use the agentic development tooling from Part 1 to write this code
> rather than typing it. This book gives the requirement; the `ai-hub-policies` skill covers the
> implementation.

---

# Exercise D.1 — move the API key out of the code

The key leaves the class. The agent goes on answering, and nothing under `src/` names a credential.

### D.1.1 — create the configuration

**Run this:**

```objectscript
do ##class(Workshop.Setup.ConfigStore).Run()
```

**Expected result:** it reports creating the resources, the wallet collection `WorkshopWallet` and
the configuration `AI.LLM.workshopllm`, ending with `Get ok: AI.LLM.workshopllm` and `validates: 1`.

The configuration holds the model and a **reference** to the key, not the key:

```objectscript
{"model_provider":"openai", "model":"gpt-4o",
 "api_key":"secret://WorkshopWallet.LLMKey#api_key"}
```

### D.1.2 — point the agent at the configuration

**File:** `src/Workshop/Agent/OnCall.cls`.

**Do this:** add this parameter next to `Parameter TOOLSETS`:

```objectscript
Parameter PROVIDERCONFIG = "@{config:AI.LLM.workshopllm}";
```

Compile, then run:

```objectscript
set a = ##class(Workshop.Agent.OnCall).%New()
do a.%Init({"siteName": "Boston General"})
write "model: ", a.Model, !
set s = a.CreateSession()
write a.Chat(s, "How many integration errors are there?").Content
```

**Expected result:** `model: gpt-4o`, resolved from the configuration, and a normal answer — with
**no key and no model named anywhere in the class**.

> **Common error — the macro is required, and the separator is a colon.** These all fail with
> `<%AICore>ProviderConfigError: PROVIDERCONFIG is invalid`:
>
> | Form | Result |
> |---|---|
> | `"workshopllm"` | fails |
> | `"AI.LLM.workshopllm"` | fails |
> | `"@{config.workshopllm}"` (dot) | fails |
> | `"@{config:workshopllm}"` | works |
> | `"@{config:AI.LLM.workshopllm}"` | works |
>
> The first two forms appear in the EAP guide and the third in the official product documentation.
> None of them works on this build.

### D.1.3 — watch the permission matter

**Run this:**

```objectscript
do ##class(Workshop.Setup.ConfigStore).Demo()
```

**Expected result:** with the resource granted, `api_key` resolves; without it, `CopyDetails()` is
denied with `#26220 … Access Denied` while `Get()` still succeeds.

| Operation | With `%Workshop_ConfigUse:R` | Without it |
|---|---|---|
| `Get()` the configuration | succeeds | succeeds |
| `CopyDetails()` | succeeds | `#26220 … Access Denied` |
| `api_key` | resolved | not resolved |

The configuration stays readable while the credential does not resolve. Reading a credential became
an RBAC decision.

> **Security — `CopyDetails()` returns the credential in plaintext.** Never display a details object
> on a shared screen. `Workshop.Setup.ConfigStore` redacts by field name for exactly this reason.

> **Common error — the permission is `:R` (READ), not `:U` (USE).** Granting `:U` leaves
> `$SYSTEM.Security.Check(res,"USE")` returning 1 while every secret resolution still fails.

> **Classroom shortcut.** The demonstration creates a test user with a fixed password and removes a
> resource from a role, and it does the read in a child process because `$SYSTEM.Security.Login`
> into a limited user cannot log back in. Do not run that login in your own session.

---

# Exercise D.2 — leave an audit trail

Every governed tool call should leave a row behind it. You write the policy that makes that true —
and then find the call that leaves nothing.

### D.2.1 — write the audit policy

**File:** `src/Workshop/Policy/AuditLog.cls`, the `TODO (Exercise D.2.1)` block in `%LogExecution`.

**Do this:** create one `Workshop.Data.AuditEntry` row per call.

1. Instantiate `Workshop.Data.AuditEntry`.
2. Set `ToolName` from `..ToolNameOf(call)`.
3. Set `Arguments` and `Result` using `..Clip()` to limit their length.
4. Set `Outcome` to `"EXECUTED"` and `DurationMs` from the `duration` argument.
5. Set `StatusText` from `status` if it reports an error.
6. Save the row.

`%LogDenial`, immediately below, is already written — follow its structure.

The policy is **already attached**: `Workshop.Tools.OnCall` declares
`<Audit Class="Workshop.Policy.AuditLog"/>` in its `<Policies>` block. A policy class that nothing
references is never consulted.

### D.2.2 — produce all three outcomes

`Workshop.Data.AuditEntry` can end up in **three** different states, depending on how a tool was
called — and the third is the one that matters at an incident review. Produce all three in order,
watching the row count after each.

Start clean:

```objectscript
do ##class(Workshop.Data.AuditEntry).Reset()
do ##class(Workshop.Data.Approval).Reset()
set a = ##class(Workshop.Agent.OnCall).%New()
do a.%Init({"siteName": "Boston General"})
```

**Outcome 1 — a call that succeeds.**

```objectscript
do a.ToolManager.ExecuteTool("RecentErrors", {})
do ##class(Workshop.Data.AuditEntry).Summary()
```

**Outcome 2 — a call that is refused.** Your gate from C.3 will deny this one:

```objectscript
try { do a.ToolManager.ExecuteTool("RestartHost", {"configName":"HL7Router"}) } catch e { write "denied", ! }
do ##class(Workshop.Data.AuditEntry).Summary()
```

**Expected result:** a **second** row, with `Outcome` of `DENIED`. You did not write that one —
`%LogDenial` was supplied — but notice it exists. A log that recorded only successes could not
distinguish an agent that never tried an action from one that tried and was stopped.

**Outcome 3 — a call that leaves nothing at all.** This is the third execution path from C.5, the
one you reasoned about rather than ran: `ToolSet.%Invoke()`, which never reaches `%AI.ToolMgr`.
Count the rows before and after it, because the interesting result is that nothing changes:

```objectscript
set q = ##class(%SQL.Statement).%ExecDirect(,"SELECT COUNT(*) AS N FROM Workshop_Data.AuditEntry")
do q.%Next()  write "rows before: ", q.%Get("N"), !
set ts = ##class(Workshop.Tools.OnCall).%New()
do ts.%Invoke("RecentErrors", {})
set q2 = ##class(%SQL.Statement).%ExecDirect(,"SELECT COUNT(*) AS N FROM Workshop_Data.AuditEntry")
do q2.%Next()  write "rows after:  ", q2.%Get("N"), !
```

**Expected result:** the two counts are the same. So the ungoverned path is not merely
unauthorised — it is **invisible**. An incident review built on this table would not show it
happened. That is the second half of the C.5 finding, and this is the step that proves it.

| What you did | In the audit table |
|---|---|
| Governed call, permitted | one row, `EXECUTED` |
| Governed call, refused | one row, `DENIED` |
| `%Invoke()` bypass | nothing |

> **Common error — count with `COUNT(*)`.** An iterating `SELECT` run immediately after an insert
> can return no rows while `COUNT(*)` returns the right number. Use the count and watch the delta,
> or you will appear to be wrong when you are right.

# Exercise D.3 — the agent inside a production

**Guided from the front.** This one is supplied complete and is run rather than written. The point
is an observation, not a build task.

### D.3.1 — start the production and trigger a triage

**Run this:**

```objectscript
do ##class(Workshop.Interop.Setup).Start()
do ##class(Workshop.Interop.Setup).Trigger("HL7Router")
```

**Expected result:** the production starts, and the triage reports a verdict:

```
  verdict    : REVIEW
  summary    : HL7Router is experiencing repeated send failures to LabOperation…
  confidence : high
  tool calls : 1
  session id : 1   (replay with %AI.Agent.Session.%OpenId)
```

Open the **Message Viewer** and the **Visual Trace** from the portal links above: the inbound
message, the triage operation and the verdict are all there, like any other production traffic.

The production has four items:

```
TriageIn         business service     entry point
TriageDecision   business process     decides, and escalates when required
OnCallAgent      business operation   hosts the agent in process
OnCallApprovers  business operation   EnsLib.Workflow.Operation: the human review queue
```

Only one class name is specific to AI. The business process calls the agent with `SendRequestSync`
exactly as it would any other operation — queued, traced, retryable.

### D.3.2 — find the human task

**Run this:**

```objectscript
do ##class(Workshop.Interop.Setup).Tasks()
```

**Expected result:** a `PENDING` task in role `OnCallApprovers`. It is also in the portal under
**Workflow tasks**.

A `REVIEW` verdict sends an `EnsLib.Workflow.TaskRequest` asynchronously, so nothing waits on the
human.

> **Common error — the Workflow Operation's production item name is also the role name.** There is
> no role setting on the operation. If they differ, tasks are created but cannot be delivered, and
> the only sign is one event-log line, `ERROR <EnsWf>ErrNoUsersFound`, with
> `EnsLib_Workflow.Worklist` empty.

### D.3.3 — read the agent's reasoning back

The triage printed a **session id**. That is not decoration: the reasoning layer was persisted, and
you can reopen it. This is what you do at 3am when somebody asks why the agent said what it said.

**Use the id the trigger printed** — it is whatever number appeared on the `session id` line, not
necessarily 1.

**Run this first, and expect it to fail:**

```objectscript
set s = ##class(%AI.Agent.Session).%OpenId(2)   // your id here
write "reopened: ", $isobject(s), !
set ctx = s.GetContext()
```

**Expected result:** the object opens, and then:

```
ERROR <%AICore>SessionNotAttached: Session is not attached
```

A reopened session is **detached**. It holds the history but has no agent, and it will not even let
you read it. Attach one and try again:

```objectscript
set a = ##class(Workshop.Agent.OnCall).%New()
do a.%Init({"siteName": "Boston General"})
do a.ResumeSession(s)
set ctx = s.GetContext()
write "messages: ", ctx.%Size(), !
set i = ctx.%GetIterator()
while i.%GetNext(.k, .m) { write "  [", m.role, "] ", $extract(m.content, 1, 70), ! }
```

**Expected result:** four or five messages — the prompt the production sent, the assistant's tool
call, the **raw tool results it received**, and its final verdict:

```
  [user] An error was reported for HL7Router. Triage it...
  [assistant]
  [tool] {"columns":[{"name":"ID","type":"BIGINT"},...
  [assistant] HL7Router is experiencing repeated send failures to...
```

You are reading the evidence the model actually saw, not a summary written afterwards. That is the
difference between an audit trail and a log line.

> **Note — a session is persistable, not automatically persisted.** `%Save()` is what gives it an
> id, and `Workshop.Interop.AgentOperation` calls it for you — which is why there was an id to
> open at all. A session you create in the terminal has no id until you save it.

### D.3.4 — approve it, and watch the policy change its mind

**Before you run this, predict the four results** in the table below. You wrote the policy in C.3,
so you have everything you need to reason it out.

```objectscript
do ##class(Workshop.Interop.Setup).Approve()
```

**Expected result:** the approval row becomes `APPROVED`, and your Module C policy now permits
`RestartHost` on that host while still denying it on others.

| Call | Result |
|---|---|
| `RestartHost` on `HL7Router`, before approval | denied — no approved row |
| a human completes the Workflow task | approval row set to `APPROVED` |
| `RestartHost` on `HL7Router`, after approval | succeeds |
| `RestartHost` on `LabOperation`, never approved | still denied, by host name |

Check the last row yourself rather than taking it on trust:

```objectscript
set a = ##class(Workshop.Agent.OnCall).%New()
do a.%Init({"siteName": "Boston General"})
do a.ToolManager.ExecuteTool("RestartHost", {"configName":"LabOperation"})
```

**Expected result:** still denied.

**The agent did not change between those calls.** Its class, its instructions and its tools are
identical. The state of the system changed, and the policy read it — which is what separates a
control from a suggestion.

**Finish with:**

```objectscript
do ##class(Workshop.Interop.Setup).Stop()
```

### D.3.5 — the question from 0.5

Read out what you wrote at the start. You have now built both of them.

---

# Appendix — command reference

```bash
# Lifecycle. `down` keeps your data; `down -v` deletes it (all three modules' data).
docker compose up -d
docker compose ps
docker compose logs -f iris
docker compose stop
docker compose start

# The IRIS terminal
docker exec -it aiworkshop-iris iris session IRIS -U IRISAPP

# The MCP bridge
docker exec -d aiworkshop-iris /usr/irissys/bin/iris-mcp-server --config=/home/irisowner/config_http.toml run
python module2-aihub/src/Python/mcp_smoke.py
python module2-aihub/src/Python/mcp_smoke.py RecentErrors
python module2-aihub/src/Python/mcp_smoke.py RestartHost '{"configName":"HL7Router"}'

# Lab state, from the host
./module2-aihub/reset-lab.sh --status
./module2-aihub/reset-lab.sh                  # namespace back to the start; your files untouched
./module2-aihub/reset-lab.sh --hard           # rebuild the instance from the image, ~20 seconds - deletes ALL modules' work
./module2-aihub/reset-lab.sh --solve C.3       # load every solution up to and including C.3
```

```objectscript
// Environment and lab state
do ##class(Workshop.Verify).Run()
do ##class(Workshop.Lab).Status()
do ##class(Workshop.Lab).SolveThrough("C.1")
do ##class(Workshop.Lab).Reset()

// Compiling
do ##class(Workshop.Setup.Build).CompileWorkshop()

// Inspecting tools
write ##class(Workshop.Tools.OnCall).%New().%Discover().%ToJSON()
do ##class(Workshop.Tools.OnCall).%Dump()

// The agent. After A.4 the context object is required.
set a = ##class(Workshop.Agent.OnCall).%New()
do a.%Init({"siteName": "Boston General"})
set s = a.CreateSession()
write a.Chat(s, "...").Content
write s.GetStats().%ToJSON()

// Approvals and audit
do ##class(Workshop.Data.Approval).Reset()
set id = ##class(Workshop.Data.Approval).Request("HL7Router","RestartHost","why")
do ##class(Workshop.Data.Approval).Approve(id)
do ##class(Workshop.Data.AuditEntry).Summary()

// The production
do ##class(Workshop.Interop.Setup).Start()
do ##class(Workshop.Interop.Setup).Trigger("HL7Router")
do ##class(Workshop.Interop.Setup).Tasks()
do ##class(Workshop.Interop.Setup).Approve()
do ##class(Workshop.Interop.Setup).Stop()
```

Concepts, API detail and the full trap list: [`REFERENCE.md`](REFERENCE.md).
Something broken: [`docs/TROUBLESHOOTING.md`](docs/TROUBLESHOOTING.md).

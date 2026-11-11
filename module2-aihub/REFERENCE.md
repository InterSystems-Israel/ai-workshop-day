# InterSystems AI Hub — Reference

The reading companion to [`WORKBOOK.md`](WORKBOOK.md). The workbook is tasks with no explanation;
this is explanation with no tasks. The slides cover the same ground, so if you have the slide PDF you
may not need this at all — it exists for people who would rather read than listen, and for afterwards.

Everything here was executed against `irishealth-community:2026.3.0AI.154.0`. Where something was
not verified, it says so. Two statements in the official product documentation are wrong on this
build; §9 says which, because you will otherwise trip over them.

| | |
|---|---|
| §1 | [What AI Hub is](#1-what-ai-hub-is) |
| §2 | [The shape of every application](#2-the-shape-of-every-application) |
| §3 | [Providers and agents](#3-providers-and-agents) — steps 1 and 2 |
| §4 | [Tools and ToolSets](#4-tools-and-toolsets) — step 3 |
| §5 | [Publishing tools over MCP](#5-publishing-tools-over-mcp) |
| §6 | [Policies and governance](#6-policies-and-governance) — step 4 |
| §7 | [Sessions, evidence and cost](#7-sessions-evidence-and-cost) — steps 5 and 6 |
| §8 | [Credentials and configuration](#8-credentials-and-configuration) |
| §9 | [Where these facts come from](#9-where-these-facts-come-from) |
| §10 | [Classroom shortcuts](#10-classroom-shortcuts) |
| §11 | [What this workshop does not cover](#11-what-this-workshop-does-not-cover) |

For a failure you are looking at right now, go to
[`docs/TROUBLESHOOTING.md`](docs/TROUBLESHOOTING.md) instead: it is organised by symptom.

---

## 1. What AI Hub is

Two separate things ship under one name, and conflating them causes most early confusion.

1. **The `%AI.*` SDK, inside IRIS.** Agents, tools and policies as ObjectScript classes, running in
   the database process. Everything you write in this workshop belongs here.
2. **`iris-mcp-server`.** A compiled bridge that publishes IRIS tools outward over the Model Context
   Protocol, to be consumed by Claude Desktop, VS Code or any MCP client. It reaches IRIS over
   **wgproto on port 1972**, the superserver — not HTTP. No web server is involved, and its port
   8080 has nothing to do with 52773.

The product's central claim is worth stating plainly, because every design decision follows from it:
**the agent runs where the data already is, under the access control the data already has.**

### The vocabulary

| Term | Class | Role |
|---|---|---|
| Agent | `%AI.Agent` | Holds a provider, model, instructions and toolsets |
| Provider | `%AI.Provider` | Connection to an LLM vendor |
| Session | `%AI.Agent.Session` | Message history; persistent and replayable |
| Tool | any method | An ObjectScript method the model may call |
| ToolSet | `%AI.ToolSet` | Declares tools, filters and policies |
| ToolManager | `%AI.ToolMgr` | Executes tools **and enforces policy** |
| Policy | `%AI.Policy.*` | Authorization, Audit and Discovery |
| MCP Service | `%AI.MCP.Service` | Publishes a ToolSet outward |
| Config Store | `%ConfigStore.*` | Holds configuration and secret references |

The emphasis on ToolManager is deliberate. That it both executes and enforces is the single most
consequential fact in this document, and §6 returns to it.

---

## 2. The shape of every application

Every AI Hub application is the same six steps. The SDK guide calls this the basic agentic
application pattern:

| # | Step | Where it appears |
|---|---|---|
| 1 | Create a **provider** | §3, and properly in §8 |
| 2 | Create an **agent** | §3 |
| 3 | Register **tools** | §4, published outward in §5 |
| 4 | Set **policies** | §6 |
| 5 | Create a **session** | §7 |
| 6 | **Chat** | §7 |

A minimal application is all six in one method:

```objectscript
Set provider = ##class(%AI.Provider).Create("openai", {"api_key": key})
Set agent    = ##class(%AI.Agent).%New(provider)
Set agent.Model        = "gpt-4o"
Set agent.SystemPrompt = "You are a helpful assistant."
Do agent.UseToolSet("MyApp.Tools")
Do agent.ToolManager.SetAuthPolicy(##class(MyApp.ReadOnly).%New())
Set session  = agent.CreateSession()
Set response = agent.Chat(session, userInput)
Return response.Content
```

Nothing in that sequence is AI-specific in the ObjectScript sense. You instantiate classes, set
properties and call methods. The model is a dependency, like a web service.

---

## 3. Providers and agents

### Two ways to build an agent, and why there are two

The **imperative** form passes a provider to the constructor:

```objectscript
Set provider = ##class(%AI.Provider).Create("openai", {"api_key": key})
Set agent    = ##class(%AI.Agent).%New(provider)
Set agent.Model        = "gpt-4o"
Set agent.SystemPrompt = "You are the integration on-call engineer."
```

That is a complete agent, and `UseToolSet()` attaches tools to it. **It needs no `%Init()`**, because
there is nothing left to initialise.

The **declarative** form is a subclass whose configuration is parameters and XData:

```objectscript
Class Workshop.Agent.OnCall Extends %AI.Agent
{
Parameter TOOLSETS = "Workshop.Tools.OnCall";

XData INSTRUCTIONS [ MimeType = "text/markdown" ]
{
You are the integration on-call engineer...
}

Method %OnInit() As %Status
{
    // resolve the provider from the environment
}
}
```

Three parts: declarative parameters, an `XData INSTRUCTIONS` block that becomes the system prompt,
and an optional `%OnInit()` hook for work a parameter cannot express.

The declarative form is worth the extra ceremony for three reasons: the class is reusable and
reviewable source rather than lines in somebody's terminal history, the instructions are versioned
with the code, and there is somewhere to attach a policy.

### Why `%Init()` is mandatory, and what it actually does

```objectscript
Set agent = ##class(Workshop.Agent.OnCall).%New()
Do agent.%Init()                      // required
Set session = agent.CreateSession()
Set response = agent.Chat(session, "...")
Write response.Content
```

Omitting `%Init()` is the most frequently reported support question on this product. The reason is
now visible: the imperative form is *given* a provider, while a declarative class must *build* one —
from its parameters, from `%OnInit()`, or from the Config Store — and `%Init()` is when that happens.

The failure arrives at **`CreateSession()`**, not `Chat()`, because `CreateSession()` is the first
call that needs a provider:

```
ERROR <%AICore>IncompleteInitialization: Workshop.Agent.OnCall:
       Initialization incomplete for Provider
  location=CreateSession+5^%AI.Agent.1
```

### Agent parameters

| Parameter | Effect |
|---|---|
| `TOOLSETS` | Comma-delimited `%AI.Tool` / `%AI.ToolSet` class names. Equivalent to `UseToolSet()` |
| `MODEL` | Model name |
| `PROVIDER` | Provider id, e.g. `"openai"` — equivalent to passing one to the constructor |
| `APIKEY` | The credential, usually as `"@{env:OPENAI_API_KEY}"` |
| `PROVIDERCONFIG` | A Config Store reference; see §8 |
| `SKILLS` | Skill classes |

With `PROVIDER`, `MODEL` and `APIKEY` set, a declarative agent needs **no `%OnInit()` at all**. This
workshop uses the hook anyway, because `Workshop.Provider` switches between OpenAI, Anthropic,
Gemini and Ollama from one environment variable, which a fixed `Parameter PROVIDER` cannot express.

> **Common error — the parameter is `TOOLSETS`, plural.** `TOOLS` is the parameter for a *Skill*. On
> an `%AI.Agent` the class compiles cleanly and attaches no tools, with no warning.

> **Note — these parameters do not autocomplete.** `%AI.Tool`, `%AI.ToolSet` and `%AI.Agent` declare
> no parameters on the base classes; they are read from the subclass at runtime. A name that your
> editor does not recognise is not evidence of a missing feature.

### Instruction templating

`XData INSTRUCTIONS` may contain `{{placeholder}}` markers, substituted at `%Init()` time from a
context object:

```objectscript
Do agent.%Init({"siteName": "Boston General"})
```

The real signature is `%Init(context As %DynamicObject = {{}})`, and each key becomes available to
the template. A placeholder with no matching key is left as literal text, so a typo surfaces in the
reply rather than as an error — but a key that the template *requires* and does not receive fails
hard:

```
<%AICore>TemplateUnresolvedName: Template: unresolved name '{{siteName}}'
```

Once a template placeholder is in the instructions, **every** `%Init()` on that class must supply the
context object, including calls from a business operation or a verification routine.

### Choosing a model, and temperature

`provider.ListModels()` returns the vendor's catalogue — 98 entries for OpenAI on this build.

Temperature has **no default**: leave it unset and no `temperature` field is sent, so the provider
applies its own. Several reasoning models reject an explicit value outright. Set it only when you
mean to:

| Range | Suited to |
|---|---|
| 0.0–0.3 | Factual question answering, data extraction, consistent output |
| 0.4–0.7 | General purpose |
| 0.8–1.2 | Creative work |
| 1.3–2.0 | Experimental; may be incoherent |

> **A provider constructs successfully with an invalid key.** Creation validates nothing, and
> `provider.ValidateConfig()` does not help either — it returns 1 for a deliberately wrong key,
> because it checks the *shape* of the configuration rather than the credential. Only a real call
> proves a key works, which is why the Module 0 gate makes one.

---

## 4. Tools and ToolSets

### A tool is an ObjectScript method

The JSON schema sent to the model is inferred from the method signature. A `DESCRIPTION` type
parameter on an argument is passed through:

```objectscript
Method DraftIncidentNote(
    summary As %String(DESCRIPTION="One-line summary of the incident"),
    severity As %String(DESCRIPTION="One of: low, medium, high") = "medium") As %DynamicObject
```

Arguments without defaults are required; arguments with defaults are optional. Common types map as
you would expect — `%String` to `string`, `%Integer` to `integer`, `%DynamicObject` to `object`,
`%DynamicArray` to `array` — and for a `%Persistent` or `%RegisteredObject` parameter the schema is
generated from the class definition.

The description is not documentation. It is the only information the model has when deciding which
tool to call, so a vague description produces a tool the model uses wrongly.

To see exactly what the model receives:

```objectscript
Write ##class(Workshop.Tools.OnCall).%New().%Discover().%ToJSON()
```

Each tool reports `name`, `description`, `parameters`, `returns`, `requires_auth` and `stateful`.

> **Note — `%Discover()` is an instance method; `%Dump()` is a class method.**
> `##class(...).%Discover()` throws `<METHOD DOES NOT EXIST>`. `%Dump()` prints `%Discover()`'s
> output *plus* all three policy slots, which makes it the right first command when a tool
> misbehaves.

> **Note — the model sees only return values, never `Output` arguments.** Legacy code that returns
> results through `Output` parameters must be wrapped: do the call inside the tool body and return
> the extracted result.

### Declaring a ToolSet

The XData block is named `Definition`:

```objectscript
XData Definition [ MimeType = application/xml ]
{
  <ToolSet Name="OnCallDesk">
    <Policies>
      <Authorization Class="Workshop.Policy.ApprovalGate"/>
      <Audit Class="Workshop.Policy.AuditLog"/>
    </Policies>
    <Query Name="RecentErrors" MaxRows="10"
           Description="Recent error rows from the event log."
           Arguments="configName As %String = &quot;&quot;">
      <![CDATA[
        SELECT TOP 10 ID, ConfigName, Text, TimeLogged, Type
        FROM Ens_Util.Log
        WHERE Type IN (2, 6)
          AND (COALESCE(:configName, '') = '' OR ConfigName = :configName)
        ORDER BY ID DESC
      ]]>
    </Query>
    <Tool Name="DraftIncidentNote" Method="DraftIncidentNote"/>
    <Exclude Match="^Internal"/>
  </ToolSet>
}
```

A `<Query>` returns a uniform envelope:

```json
{"columns":[…], "rows":[…], "row_count":7, "truncated":false, "elapsed_ms":2}
```

### Composing and filtering

`<Include>` and `<Exclude>` take `Tool=` for one exact name, `Match=` for a POSIX regular expression
(partial match is enough), and `Rename=` to relabel. `<Exclude>` is applied after `<Include>`.
Filters are evaluated at **compile time**, so composition costs nothing at run time.

`<Requirement Name="..." Value="..."/>` inside `<Include>` attaches metadata that reaches
authorization and audit policies as a `%DynamicObject` — the declarative way to tag a tool as needing
approval.

### Six mistakes in the XML, all made while building this workshop

| Mistake | Symptom |
|---|---|
| SQL as a `<Tool Query="...">` attribute | `<SUBSCRIPT>` from the ToolSet compiler. SQL belongs in a `<Query>` element as CDATA |
| An `Arguments` default written as `''` | `<%AICore>QueryArgumentDefaultInvalid` |
| Guarding an optional argument with `:arg = ''` | Zero rows from a populated table, with no error |
| Filtering the event log on `Type = 3` | Warnings instead of errors |
| Compiling a ToolSet before its policy class | `<CLASS DOES NOT EXIST>` from `GeneratePolicyGetter` |
| Reading `result.row_count` | `<UNDEFINED> *count` |

Each in detail:

> **The `''` default does not compile.** The SDK guide's own example shows
> `Arguments="status As %String = ''"`. Inside an XML attribute the compiler requires
> `&quot;&quot;`, a bare number, or `{expression}`.

> **The documented `OR` guard returns no rows.** An omitted argument binds as NULL, so
> `:configName = ''` evaluates to NULL, the predicate is false, and the query returns nothing from a
> full table without erroring. Use `COALESCE(:configName, '') = ''`.

> **Errors are `Type 2`.** `Ens.DataType.LogType` is
> `1=Assert 2=Error 3=Warning 4=Info 5=Trace 6=Alert`. Filter on `3` and the agent reports no errors
> during an outage.

> **A `<Query>`'s SQL is prepared at compile time.** A missing table fails the *compile* with
> `SQLCODE: -30 Table ... not found`, not the run. This is why the namespace must be
> interoperability-enabled before the ToolSet will build at all.

> **Compile policies before ToolSets.** A `<Policies>` reference is resolved at compile time by a
> method generator, so compiling a whole package in one operation may succeed or fail on queue order
> alone. `Workshop.Setup.Build.CompileWorkshop()` applies a fixed order.

> **`result.row_count` is not valid ObjectScript.** Underscore is concatenation, so it parses as
> `result.row _ count`. Use `result.%Get("row_count")`.

### Stateful tools

Only an instance `Method` can reach instance properties. A `ClassMethod` and an inline `<Query>`
cannot, and `%AI.ToolSet` derives the `stateful` flag from the method type. `Parameter STATEFUL`
overrides that inference explicitly.

AI Hub instantiates one instance of the tool class and keeps it alive, so two conversations get two
instances and do not collide. Had those methods been ClassMethods, every user on the instance would
share one piece of state.

> **Tool state outlives the session.** The tool object is created with the *agent* and lives as long
> as the agent, not the session, so state survives `CreateSession()`. Clearing it needs a new agent;
> anything longer-lived needs a global or a persistent class.

> **A stateful tool cannot be attached with `Parameter TOOLSETS`.** Instantiate it, set its
> properties, then add it:
> ```objectscript
> Set tool = ##class(Workshop.Tools.Worklist).%New()
> Set tool.Operator = $Username
> Do ..ToolManager.AddTool(tool)
> ```

### Tools that are not ObjectScript

A `<MCP>` element inside a `<ToolSet>` launches an external MCP server as a child process and merges
its tools in:

```xml
<MCP Name="OnCallPy">
  <Stdio Executable="/usr/irissys/bin/irispython" Args="/home/irisowner/dev/Python/oncall_mcp.py"/>
</MCP>
```

`Platform` is a regular expression matched against `"<os> <version> <arch>"`; the first match wins
and a `<Stdio>` without it is the fallback, so one definition serves a mixed room.

At `%Discover()` time this appears as a **single placeholder entry** with `source` of `mcp` and a
`toolref`, because the child process is not launched until an agent runs. The individual tool names
are not visible until then, which looks like a failure and is not.

> **Never write to stdout in an MCP server.** stdout *is* the transport. A stray `print()` corrupts
> the stream and the tool disappears from the agent's list with no error anywhere. Diagnostics go to
> stderr.

---

## 5. Publishing tools over MCP

The dispatch class is one parameter:

```objectscript
Class Workshop.MCP.Service Extends %AI.MCP.Service
{
Parameter SPECIFICATION As STRING = "Workshop.Tools.OnCall";
}
```

Registering it creates a `Security.Applications` entry with **`Type=18`**, which is what makes an
application an MCP Server rather than a web application. The Management Portal exposes the same thing
under System Administration > Security > Applications > MCP Servers.

The bridge then serves those tools to any MCP client. Three facts that cause most of the confusion:

- **The bridge speaks wgproto on 1972**, the superserver. Not HTTP, and no web server required.
- **The HTTP URL path is `/mcp`**, not `/mcp/oncall`. The endpoint path names the IRIS application and
  prefixes the tool names; it is not part of the URL.
- **Tool names carry the endpoint path as a prefix**, and you get it even with a single endpoint
  configured:

| Endpoint | Example tool name |
|---|---|
| `/mcp` | `mcp_ExecuteQuery` |
| `/mcp/oncall` | `mcp_oncall_RecentErrors` |

> **`tools/list` returning only `iris_status` means the application lost `MatchRoles`.** The bridge
> still starts and still reports `discovered 1 endpoint(s)`, so the only evidence is a
> `403 Forbidden` on the discovery probe, which arrives unauthenticated as `UnknownUser`.
> `AutheEnabled` is *not* the fix.

> **A failed discovery is cached.** Restart the bridge after any IRIS-side correction, or nothing
> changes for five minutes.

> **Do not put `%AI.Policy.ConsoleAudit` or `ConsoleAuth` in a ToolSet exposed over MCP.** They write
> to the current device, which during an HTTP request is the response body, so every `tools/call`
> fails with `JSON serialization/deserialization error: expected value at line 2 column 1`. A policy
> that writes to a table is fine.

---

## 6. Policies and governance

Three policy types, each an abstract class you extend:

| Type | Class | Decides |
|---|---|---|
| Authorization | `%AI.Policy.Authorization` | Whether a call may proceed, and whether a tool is visible |
| Audit | `%AI.Policy.Audit` | What is recorded |
| Discovery | `%AI.Policy.Discovery` | What the tool list contains, built at run time |

### Authorization

```objectscript
Method %CanExecute(toolref As %String, call As %DynamicObject, metadata As %DynamicObject) As %Status
Method %CanList(toolref As %String, metadata As %DynamicObject) As %Boolean
```

`call` carries `id`, `name`, `arguments` and `extra`; `metadata` carries the `<Requirement>` data.
Returning an error from `%CanExecute` refuses the call. Returning 0 from `%CanList` hides the tool.

A policy may also **modify** the call rather than only permitting or refusing it: rewrite
`call.arguments` and return `$$$OK`. A path-sanitising policy that normalises an argument is the
documented example, and the audit record's `tool_name` can therefore differ from `call.name`.

**Keep guarded tools visible.** An agent that cannot see a tool reports that it is unable to help; an
agent that can see a tool and is refused offers to request approval instead. The second is far more
useful.

### Audit

```objectscript
Method %LogExecution(call, metadata, result, duration As %Integer, status As %Status) As %Status
Method %LogDenial(call, metadata, status As %Status) As %Status
```

`duration` is in milliseconds. **Log refusals as well as executions**: without them, a record in
which the agent never attempted an action is indistinguishable from one in which it tried and was
blocked.

A policy class that nothing references is never consulted. Attach it, either declaratively in
`<Policies>` or globally on the ToolManager.

### Where policies attach, and what wins

| Level | How | Scope |
|---|---|---|
| Global | `agent.ToolManager.SetAuthPolicy(...)` | Every tool that agent can reach |
| ToolSet | `<Policies>` in the XData | That ToolSet's tools |

Both levels can be in force at once. Authorization requires **both** to allow; audit fires at
**both**; for discovery the ToolSet-level policy takes priority.

> The property is **`ToolManager`**. Documentation showing `agent.ToolMgr` is wrong on this build and
> throws `<PROPERTY DOES NOT EXIST>`.

### Governance is a property of the execution path

This is the most important fact in the workshop, and it is not in the documentation.

| Execution path | Policy enforced |
|---|---|
| `agent.Chat()` → ToolManager | **Yes** |
| MCP `tools/call` | **Yes** |
| `ToolSet.%Invoke()` directly | **No** |

Policies are enforced by `%AI.ToolMgr`, not by the ToolSet. `%Invoke()` bypasses every authorization
policy attached to the ToolSet, gives no indication that it has done so, and leaves no audit record —
so a bypass is not merely unauthorised, it is invisible to a review built on the audit table.

Everything you expose to an agent, you also expose to any ObjectScript in the instance that calls
`%Invoke()`. The policy protects the agent path and the MCP path. It does not protect you from your
own code.

Two corollaries worth internalising:

- The two paths return **different shapes**. `ExecuteTool()` wraps the result as
  `{"timing":0.0024,"value":{…}}`; `%Invoke()` returns it unwrapped. Code written for one breaks on
  the other.
- **Prompt instructions are not enforcement.** An agent will often decline a guarded action because
  its instructions say to, even when told it is authorised. That is politeness, not a control.

### Human review

AI Hub has no asynchronous human-review primitive. The native IRIS Workflow Engine is one, and it
predates all of this by years: `EnsLib.Workflow.TaskRequest` into an `EnsLib.Workflow.Operation`
puts an item in a human's worklist, and nothing blocks while it waits.

Two patterns worth copying from published practice:

- **A forced output contract.** The response schema permits only "acknowledge" or "needs review", so
  the agent cannot express that it has acted.
- **Timeouts degrade to human review.** A model that does not answer produces a review item rather
  than wedging the pipeline.

> **The Workflow Operation's production item name is also the workflow role name.** There is no role
> setting on the operation. If they differ, tasks are created but cannot be delivered, and the only
> sign is one event-log line — `ERROR <EnsWf>ErrNoUsersFound` — with the worklist empty.

---

## 7. Sessions, evidence and cost

A session is **message history**, not a general-purpose state store. It is persistent and
replayable, but only if you save it: `%Save()` is what gives a session an id, and nothing calls it
for you outside the supplied business operation.

`%AI.Agent.Session.%OpenId()` reopens one, and a reopened session is **detached** — it holds the
history but has no agent. Attach it with `agent.ResumeSession(s)` before doing anything with it,
including merely reading it: `GetContext()` on a detached session throws
`<%AICore>SessionNotAttached`, not just `Chat()`.

Sessions also support checkpointing — `AddCheckpoint()`, `RewindTo()`, `ListCheckpoints()`,
`Fork()` — and `GetContext()` returns the actual messages, which is the honest answer to "what is
being sent to the model".

`GetStats()` is the cheapest evidence available:

```objectscript
Write session.GetStats().%ToJSON()
```

It returns `total_prompt_tokens`, `total_completion_tokens`, `total_tool_calls`,
`total_llm_duration_ms`, `total_tool_duration_ms`, cache token counts, `current_context_tokens` and
`model_context_size`.

`total_tool_calls` answers the question that matters most about any agent output: did it look, or did
it invent? A plausible answer with zero tool calls is invention. And comparing the two duration
figures is instructive — reading the database costs single-digit milliseconds against seconds for the
model, which is the practical argument for running the agent next to the data.

### Three layers of evidence

| Layer | Artefact | Notes |
|---|---|---|
| Message | `Ens.MessageHeader` | The request's path through the production. Free, if you are in a production |
| Reasoning | `%AI.Agent.Session` | Persistent; reopen with `%OpenId()`, attach with `ResumeSession()` |
| Cost | `session.GetStats()` | Tokens, tool calls, latency |

All three describe the **governed** paths only. A `%Invoke()` call appears in none of them.

---

## 8. Credentials and configuration

An API key in an environment variable is readable by anything running in the instance. That is
acceptable for a classroom and not for production.

| Option | Behaviour | Assessment |
|---|---|---|
| Environment variable | Read at process start; readable within the instance | Acceptable for a classroom |
| `Parameter APIKEY = "@{env:VAR}"` | Resolved by the setting expander at run time | Better: a real framework feature |
| `^||ENV("OPENAI_API_KEY")` | Not a framework feature. Process-private | Terminal convenience only |
| Config Store and Wallet | Configuration holds a `secret://` reference; reading it is an RBAC decision | The supported approach |

The `@{...}` expander works in `APIKEY`, `PROVIDERCONFIG` and ToolSet XData — but **not** in
ObjectScript code. It understands `@{env:VAR}`, `@{config:Area.Type.Name}` and
`@{wallet:Collection.Key}`.

> **On `^||ENV`.** It is widely described as a way to set a key without restarting IRIS, and it does
> work here — because `Workshop.Provider` implements the fallback, following the convention in
> `Sample.AI.Utils`. Nothing in `%AI.*` reads it. Worse, `^||` is a **process-private** global, so a
> key set that way is invisible to an MCP request or a business host in another process. Treat it as
> a trick for your own terminal, never as configuration. Prefer `@{env:}`.

### The Config Store

A configuration holds a reference, not a credential:

```objectscript
Do ##class(%ConfigStore.Configuration).Create("AI","LLM","","workshopllm", {
    "model_provider": "openai",
    "model":          "gpt-4o",
    "api_key":        "secret://WorkshopWallet.LLMKey#key"
})
```

Names are `area.type.subtype.logicalname`, with subtype optional; lookups use the dotted form
`AI.LLM.workshopllm`, and a logical name containing a `.` is rejected. The agent then carries only a
reference:

```objectscript
Parameter PROVIDERCONFIG = "@{config:AI.LLM.workshopllm}";
```

> **The macro is required and the separator is a colon.** These all fail with
> `<%AICore>ProviderConfigError: PROVIDERCONFIG is invalid`:
>
> | Form | Result |
> |---|---|
> | `"workshopllm"` | fails |
> | `"AI.LLM.workshopllm"` | fails |
> | `"@{config.workshopllm}"` (dot) | fails |
> | `"@{config:workshopllm}"` | works — short keys are prefixed `AI.LLM` |
> | `"@{config:AI.LLM.workshopllm}"` | works |
>
> The first two appear in the EAP guide and the third in the official documentation. None works.

Resources make a configuration read an RBAC decision, and the two halves fail separately:

| Operation | With the read resource | Without it |
|---|---|---|
| `Get()` the configuration | succeeds | succeeds |
| `CopyDetails()` | succeeds | `#26220 … Access Denied` |
| `api_key` | resolved | not resolved |

The configuration stays readable while the credential does not resolve, which is exactly the
behaviour you want.

> **`CopyDetails()` returns the credential in plaintext.** Never display a details object on a shared
> screen.

> **The Wallet permission is `:R` (READ), not `:U` (USE).** Granting `:U` leaves
> `$SYSTEM.Security.Check(res,"USE")` returning 1 while every secret resolution still fails. Also:
> holding `%All` masks a revocation, so test as a role-limited user — in a child process, because
> `$SYSTEM.Security.Login` into a limited user cannot log back out.

---

## 9. Where these facts come from

AI Hub is an Early Access product. Classes and signatures have changed between builds and will again,
so provenance matters more than usual.

Everything in this document was executed against `irishealth-community:2026.3.0AI.154.0`. Where a
claim came from a document and turned out to be wrong, this file states the measured behaviour.

**Six documented behaviours are incorrect on this build.** Two are in the official product
documentation at `docs.intersystems.com` and will bite you within a minute of following them:

| Documented | Actual |
|---|---|
| `agent.ToolMgr.SetAuthPolicy(...)` | The property is `ToolManager`; `ToolMgr` throws |
| `PROVIDERCONFIG = "@{config.name}"` | The separator is a colon, inside the macro |

Four more come from the EAP guide: `%Init()` failing at `Chat()` (it fails at `CreateSession()`), an
`Arguments` default of `''` (does not compile), the `:arg = ''` optional-argument guard (returns no
rows), and `PROVIDERCONFIG` accepting a bare configuration name (it does not).

If you read the product documentation afterwards — and you should, it is broader than this workshop —
treat code samples as hypotheses.

---

## 10. Classroom shortcuts

None of the following should be reused outside this room. Each is labelled where it appears in the
material, and each has a production alternative.

| Shortcut | Where | Production alternative |
|---|---|---|
| API key in `.env` | `docker-compose.yml` | Config Store and Wallet `secret://` reference |
| `UnExpireUserPasswords("*")` | `iris.script` | Change the passwords; leave the expiry policy alone |
| `MatchRoles=":%All"` on `/mcp/oncall` | `Workshop.MCP.Setup` | Authenticate the bridge; grant one role holding only the resources the ToolSet reads |
| `AutheEnabled=96`, permitting unauthenticated access | `Workshop.MCP.Setup` | Password authentication (32) or OAuth 2.0 |
| `allow_anonymous = true` | `config_http.toml` | Remove once the application authenticates |
| `_SYSTEM` / `SYS` in the editor config | `.vscode/settings.json` | A per-developer account, password in the editor's credential store |
| Fixed test-user password | `Workshop.Setup.ConfigStore` | Managed credentials, or no test user |
| Removing a resource from a role | `Workshop.Setup.ConfigStore` | Not appropriate on a system in use |

---

## 11. What this workshop does not cover

Things the SDK supports that there was no time for:

- **Session checkpoint, rewind and fork.** Checkpointing before a guarded call and rewinding when it
  is refused leaves no trace of the refusal in the conversation — arguably a better
  human-in-the-loop demonstration than the one the workshop builds.
- **Sub-agents and skills.** `%AI.Agent.SubAgent` exposes a sub-agent to its parent as a tool;
  `%AI.Skills.Planning` is a supplied planning skill needing no code. Skills can be exported as
  Markdown and imported from a git URL. The documentation warns against nesting more than two or
  three layers deep, on cost.
- **`%AI.Policy.Discovery`** and smart discovery, which builds the tool list at run time using
  retrieval over tool descriptions. Note that enabling it downloads an embedding model from
  HuggingFace on first use, so it is not an option in an air-gapped room.
- **A sanitising authorization policy** — rewriting arguments instead of refusing, as §6 describes.
- **Multi-modal content**, prompt caching, and OAuth on the MCP bridge.
- **The Python and LangChain path** (`langchain_intersystems`). Worth knowing *why* it is omitted
  rather than just that it is: the ObjectScript path has Authorization, Audit and Discovery policies
  enforced by the framework, and the Python path has no equivalent. Its own source carries the
  comment `# look into tool interceptors if auditing is desired`.
- **Agent Studio** — a browser chat interface over native IRIS agents, by Pietro Di Leo. A community
  project, not an InterSystems product.

And the harder questions this workshop deliberately does not answer, because they are not about the
SDK:

- **Evaluation.** Establishing that an agent is *correct*, not merely that it is permitted.
- **Cost control** at production volume.
- **Behaviour when the model is confidently wrong.**
- **Who is paged** when the agent is wrong at three in the morning.

Part 3 of this series covers IRIS Vector Search. `%AI.RAG.*` is the join between the two: a
`%AI.RAG.KnowledgeBase` over your own runbooks would let this agent cite a source for every
diagnosis.

Optional take-home extensions are in [`CAPSTONE.md`](CAPSTONE.md).

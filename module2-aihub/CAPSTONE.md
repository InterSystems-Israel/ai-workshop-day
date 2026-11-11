# Capstone — close the loop

**Optional. No classroom time. Pick one.**

You spent two hours building an agent that reads a production, explains what it finds, and cannot
touch anything without a human. Each option below takes one honest step further, and each is sized
for an evening rather than a weekend.

There is no instructor and no marking. The value is in the thing you end up with.

---

## Before you start

### Start from the finished workshop, not from where you stopped

```objectscript
do ##class(Workshop.Lab).SolveAll()
do ##class(Workshop.Lab).Status()        // 6 of 6 solved
```

Every option assumes the completed state. If you ran out of time in Module C, this gets you the rest
without redoing it.

### Your image does not expire

The workshop runs on the community AI image, so there is no licence key and nothing to renew. You
can come back to this in a month and the container will still start.

Two real limits to know about: the community licence allows **8 concurrent users**, which is ample
for one person but not for a shared server, and this is still an Early Access build — see the
closing note.

### Keep the environment honest

```objectscript
do ##class(Workshop.Verify).Run()        // ten OK lines before you change anything
```

And remember what the workshop labelled as **classroom shortcuts** — `MatchRoles=":%All"`,
unauthenticated MCP, a plaintext gateway password, a key in `.env`. If your capstone is going
anywhere near real data, `WORKBOOK.md` Appendix C lists every one of them with its production
alternative. Fixing those *is* a legitimate capstone in itself.

---

## Option A — your own data, restricted by role

**The most transferable of the five. Start here if you are unsure.**

Replace the on-call scenario with something from your own work. A second `%AI.ToolSet` over tables
you actually care about, and an authorization policy that restricts what the agent can see based on
*who is asking*.

### What to build

1. A ToolSet with two or three read tools over your own tables. Use `<Query>` elements with inline
   SQL — it is less code than methods and you get the result envelope free.
2. An `%AI.Policy.Authorization` subclass whose `%CanExecute()` consults `$ROLES`, not a table.
3. A `%CanList()` that *hides* the sensitive tools from users who may not call them — which is the
   one case where returning 0 from `%CanList` is right, rather than the usual advice.

### Done when

The same agent, asked the same question by two users with different roles, returns different
answers — and the restricted user is not merely refused but never sees the tool exist.

### Traps you already know about

- `COALESCE(:arg,'') = ''`, not `:arg = ''`. An omitted argument binds as NULL and your query
  silently returns nothing.
- `Arguments="x As %String = &quot;&quot;"`, not `= ''`.
- Compile the policy **before** the ToolSet that names it.
- Test through `agent.ToolManager.ExecuteTool()`. `%Invoke()` bypasses your policy entirely — if you
  test with `%Invoke()` you will conclude your security works when it does not.

---

## Option B — close the approval loop

**The most satisfying, because the workshop deliberately left it open.**

Module D.3 raises a Workflow task and records the human's decision in `Workshop.Data.Approval`. But
look at what happens next: **nothing actually restarts the host.** `RestartHost` returns
`{"restarted": 0, "note": "not implemented in the starter"}`. The approval is recorded and then
dropped on the floor.

### What to build

1. A **Review Finalizer** business process that receives the completed `EnsLib.Workflow.TaskResponse`
   and performs the remediation, rather than leaving it to the agent to be asked again.

   ✅ The API, verified on this build — note there is **no `RestartConfigItem`**:

   ```objectscript
   // Restart one host. Runtime only: the production config is not changed,
   // the production stays Running, and the item stays "enabled".
   do ##class(Ens.Director).TempStopConfigItem("OnCallAgent", 1)   // stop
   do ##class(Ens.Director).TempStopConfigItem("OnCallAgent", 0)   // start

   // The other one, and it is NOT the same thing: this PERSISTS a change to
   // the production configuration.
   do ##class(Ens.Director).EnableConfigItem("OnCallAgent", 0)     // disable
   ```

   `TempStopConfigItem` is what "restart a host" means to an on-call engineer.
   `EnableConfigItem` is a config change someone will have to undo. Picking the wrong one is a
   good example of an agent doing exactly what it was told and still causing an incident —
   worth a sentence in your write-up. `IsItemEnabled()` and `RestartProduction()` are also
   there if you need them.
2. An immutable decision row stamped `Source = "HUMAN"` with the reviewer's name, alongside the
   agent's own audit row. You should be able to answer "who decided this, and on what evidence?"
   from SQL alone.
3. **Idempotent claiming.** A duplicate queue message must not perform the same restart twice. The
   pattern from the community insurance-audit work is a persisted ledger with
   `QUEUED → RUNNING → SUCCEEDED/FAILED` and a claim step that fails if the row is not `QUEUED`.

### Done when

A human clicking *Approve restart* in the portal's Workflow Inbox causes the host to restart, with
an audit trail naming the reviewer — and clicking it twice restarts it once.

### Why the idempotency matters more here than usual

In an ordinary production a duplicate delivery costs you a duplicate action. With an agent in the
path, a duplicate delivery also **buys another inference** — real money, and a second opinion that
may differ from the first. That asymmetry is worth internalising.

### Traps

- The `EnsLib.Workflow.Operation`'s **production item name is the workflow role name.** There is no
  `%RoleName` on `TaskRequest`. Get it wrong and tasks are created but silently undeliverable; the
  only clue is `ERROR <EnsWf>ErrNoUsersFound` in the event log.
- `EnsLib.Workflow.Engine.AssignTask()` then `CompleteTask()` is what the portal does when a human
  clicks. Use those rather than writing to the tables.

---

## Option C — checkpoint and rewind

**The most interesting, and new. Nobody has built this yet.**

`%AI.Agent.Session` is persistent and supports checkpointing:

```objectscript
do session.AddCheckpoint("before-restart", "about to request a guarded action")
// ... the agent proposes something; the human refuses ...
do session.RewindTo("before-restart")
```

### The idea

Today, when a human refuses a restart, the refusal stays in the conversation. The agent remembers
being told no, and that noise accumulates: it will hedge, re-ask, or argue. Instead — **checkpoint
before the guarded call, and rewind when the answer is no.** The rejected branch leaves no trace,
and the agent carries on from the last good state.

Arguably this is a better human-in-the-loop design than the one the workshop teaches, and it would
have been Module C if it fit in 120 minutes.

### What to build

1. Checkpoint in your authorization policy's `%CanExecute()`, or in the business operation, before a
   guarded tool is attempted.
2. On denial, `RewindTo()` and have the agent produce a *different* next action rather than relitigate
   the refused one.
3. Compare `session.GetStats()` and `session.GetContext()` before and after. Show the rewind actually
   shrank the context rather than appending to it.

### Done when

A refused action leaves no evidence in `session.GetContext()`, and the agent's next suggestion is a
genuine alternative rather than a reworded retry.

### Traps

- A session reopened with `%OpenId()` is **detached**. `do agent.ResumeSession(s)` first, or every
  read throws `<%AICore>SessionNotAttached`. `IsAttached()` is the diagnostic.
- Also worth looking at: `Fork()` and `ForkAndSummarize()`. Forking before a risky branch is the
  other half of this idea, and `ForkAndSummarize` compresses a long session instead of truncating it.
- ⚠️ None of `AddCheckpoint` / `RewindTo` / `Fork` has been exercised in this workshop. They are
  present in the class surface on this build and the signatures are documented, but you are the first
  to run them. Expect to discover something.

---

## Option D — the Python / LangChain path, and what it costs you

**Pick this if you want an argument you can take to a design review.**

`langchain_intersystems` gives you `init_chat_model()` and `init_mcp_client()`, both driven from the
IRIS Config Store you built in Module D.1. Point a LangChain agent at your own `/mcp/oncall`
endpoint and make it do the Module B triage.

### What to build

1. `init_chat_model("workshopllm", conn)` against the Config Store entry you already created — note
   that it reads `AI.LLM.workshopllm` and resolves the `secret://` reference, so no key in your code.
2. `init_mcp_client(["oncall"], conn)` against your MCP server.
3. The same triage question, answered through the Python path.

### Then do the part that matters

**Measure what you gave up.** The ObjectScript path gets `%AI.Policy.Audit`,
`%AI.Policy.Authorization` and `%AI.Policy.Discovery` enforced by the framework. The Python path gets
none of them — its own source carries the comment:

```python
# look into tool interceptors if auditing is desired
```

Write down what you would have to build to get back to parity, and how you would stop someone
bypassing it. That document is the real deliverable.

### Done when

The Python agent answers the triage question, **and** you can state precisely which of your Module C
and D guarantees no longer hold.

### Traps

- `init_chat_model` is **not** exported from the package root:
  `from langchain_intersystems.chat_models import init_chat_model`.
- `langchain~=1.0` pulls a large dependency tree. ⚠️ The workshop image may have been built without
  PyPI access, in which case `fastmcp` and friends are absent — check before you plan an evening
  around it.
- Guard the credential. `CopyDetails()` resolves `secret://` into plaintext, so anything that prints
  a config object prints your key.

---

## Option E — RAG over your own runbooks

**The bridge into Part 3.**

Right now the agent diagnoses from the event log alone. Give it your actual runbooks and make it cite
a source for every diagnosis.

### What to build

1. A `%AI.RAG.KnowledgeBase` over your own operational documentation — runbooks, post-mortems,
   whatever you really use at 3am.
2. Attach it so the agent consults it alongside `RecentErrors`.
3. Change the instruction brief to require a citation: no diagnosis without a source.

### Done when

The agent says *"HL7Router cannot reach LabOperation — runbook NET-14 covers this, step 3 is to check
the firewall"*, and the citation is real rather than invented.

### Why this is the right last option

It closes the gap the workshop left open in Module D. You built approval, audit and traceability —
all of which answer *"was this allowed?"*. None of them answers *"was this right?"*. A cited source
is the cheapest available step toward the second question.

⚠️ RAG and vector search are **Part 3's subject**, and `%AI.RAG.*` was deliberately out of scope
today — the classes exist on this build (`KnowledgeBase`, `VectorStore.IRIS`,
`Embedding.OpenAI`, `Embedding.FastEmbed`) but none was exercised. Treat this as a head start on
Part 3 rather than a solved path.

---

## If you only have twenty minutes

Do none of the above. Instead, open `WORKBOOK.md` Appendix C, pick the **single** classroom shortcut
that would most embarrass you in your own environment, and fix it properly. Write down what the fix
cost. That is a more useful artefact than any of the five options, and it is the question your
security reviewer will ask first.

---

## Getting unstuck

- `docs/TROUBLESHOOTING.md` — organised by symptom; every entry is a failure that really happened.
- `do ##class(Workshop.Lab).Reset()` — back to the student start, data included, if you break
  something badly.
- `do ##class(Workshop.Tools.OnCall).%Dump()` — what the model can actually see, plus which policies
  are attached. Still the most useful command in the workshop.
- `do ##class(%AI.System).SetLogLevel("debug")` — then read the file named by
  `##class(%AI.System).GetLogFile()`.

And the standing reminder: **this is an Early Access preview.** If something behaves differently
from the workbook, the workbook was written against `irishealth-community:2026.3.0AI.154.0` and says
so — check `write $zv` before assuming you have made a mistake.

One concrete example of how much the API moves between builds:
`%AI.Provider.CreateFromConfig()` is in the EAP documentation and exists on `2027.1.0AI.108.0`, but
is **not** on this build. Your instructor has the full list of what was and was not verified; ask
for it if you plan to build on this.

# Troubleshooting

Organised by **what you actually see**. Every entry here is a failure that happened to us while
building this workshop — none of it is hypothetical.

If you are mid-workshop, the fastest route is: find your symptom, apply the fix, re-run
`do ##class(Workshop.Verify).Run()`.

**Contents**

1. [First: the three diagnostics](#1-first-the-three-diagnostics)
2. [The environment gate, check by check](#2-the-environment-gate-check-by-check)
3. [Containers and startup](#3-containers-and-startup)
4. [The model will not answer](#4-the-model-will-not-answer)
5. [VS Code and Atelier REST](#5-vs-code-and-atelier-rest)
6. [Compiling](#6-compiling)
7. [Tools behaving oddly](#7-tools-behaving-oddly)
8. [MCP](#8-mcp)
9. [Config Store and the Wallet](#9-config-store-and-the-wallet)
10. [The production and Workflow tasks](#10-the-production-and-workflow-tasks)
11. [Starting over](#11-starting-over)

---

## 1. First: the three diagnostics

Before chasing anything specific, these three answer most questions.

```objectscript
// Is the environment sound?
do ##class(Workshop.Verify).Run()

// What does the instance think my provider configuration is?
do ##class(Workshop.Provider).Report()

// What does a ToolSet actually expose, and which policies are attached?
do ##class(Workshop.Tools.OnCall).%Dump()
```

`%Dump()` prints `%Discover()` plus all three policy slots. It is the single most useful command in
the workshop when a tool misbehaves.

For the model layer specifically:

```objectscript
do ##class(%AI.System).SetLogLevel("debug")
write ##class(%AI.System).GetLogFile()     // llm-trace.log
```

---

## 2. The environment gate, check by check

### Check 1 — `namespace is IRISAPP`

You are in the wrong namespace. `zn "IRISAPP"`, or start the terminal with
`iris session IRIS -U IRISAPP`.

### Check 2 — `interoperability enabled`

```
FAIL  interoperability enabled
      -> Ens.Util.Log is missing, so Workshop.Tools.OnCall cannot COMPILE
```

Your namespace was not created with interoperability. This is **not** worth fixing at runtime: the
namespace is created with `Interop=1` in `merge.cpf` **at image build time** precisely because a
runtime `EnableNamespace()` does not survive a container recreate. Get the correct image.

Why it matters more than it looks: a `<Query>`'s SQL is prepared at **compile** time, so without
`Ens_Util.Log` the Module B ToolSet does not fail at runtime — it fails to compile.

### Check 3 — `AI Hub classes present`

You are not on an AI-enabled image. `write $zv` should contain `2026.3.0AI`.

### Check 4 — `outbound HTTPS reaches <vendor>`

This one needs **no API key**, which is the point of it: you can run it the week before and find out
whether your network will work on the day.

It asks the configured vendor to reject a deliberately invalid key. Being rejected is success — it
means DNS, TCP and TLS all worked from inside the container, over the same Rust HTTP client the real
calls use.

| Message | Cause | Fix |
|---|---|---|
| `DNS failure…` | Docker's default resolvers (1.1.1.1 / 8.8.8.8) are blocked on this network, although your own machine resolves fine | Set `DNS_SERVER` in `.env` to a resolver your network allows — `Get-DnsClientServerAddress -AddressFamily IPv4` on Windows — then `docker compose up -d --force-recreate iris` |
| `Cannot open a connection…` | DNS resolves but the connection is blocked | Look for an outbound firewall rule or a proxy. The container needs HTTPS to the vendor host |
| `TLS failure…` | An intercepting proxy whose certificate the container does not trust | Your network needs the proxy's CA inside the container, or an exception for the vendor host |
| `provider is 'ollama', which is local` | Reported as `WAIT`, correctly | Ollama runs on your machine, so this check does not apply. It tests internet egress |

> **Note.** If this check passes and `provider answers a real prompt` fails, the network is fine and
> the problem is the key itself.

### Check 5 — `provider key configured`

```
-> OPENAI_API_KEY is not set. Put it in .env then:
   docker compose up -d --force-recreate iris
```

Environment variables are read **when the IRIS process starts**. Editing `.env` is not enough —
recreate the container.

For a single terminal session only, there is a shortcut:

```objectscript
set ^||ENV("OPENAI_API_KEY") = "sk-..."
```

> Two caveats. This works because **we implemented it** in `Workshop.Provider`; nothing in `%AI.*`
> reads `^||ENV`. And `^||` is a *process-private* global, so a key set this way is invisible to an
> MCP request or a business host — they run in other processes. Use it to unstick yourself, never as
> configuration.

### Check 6 — `provider can be constructed`

Rare on its own. Usually means `AI_PROVIDER` names something unsupported, or `AI_MODEL` is empty with
no default for that provider.

### Check 7 — `provider answers a real prompt`

**This is the check that matters** — see §4. Note that check 5 passing tells you very little:
`%AI.Provider.Create()` succeeds with a completely bogus key, because creation validates nothing.

### Checks 5, 6 and 7 — the provider checks say `WAIT`

Expected, and not a failure, whenever no key is configured for the selected provider. The gate still
passes and reports `7 OK  3 WAIT`.

On the day, put the key in `.env` and run:

```bash
docker compose up -d --force-recreate iris
```

You should then get ten `OK`. If they still say `WAIT`, the key did not reach the container — check
you edited `.env` and not `.env.example`, that the variable name matches the provider
(`AI_PROVIDER=openai` wants `OPENAI_API_KEY`), and that you recreated rather than restarted.

### Check 8 — `demo event log seeded`

```objectscript
do ##class(Workshop.Demo.Seed).Run()
```

### Check 9 — `Atelier REST answers on 52773`

See §5.

### Check 10 — `MCP Server /mcp/oncall registered`

```objectscript
do ##class(Workshop.MCP.Setup).Run("IRISAPP")
do ##class(Workshop.MCP.Setup).Report()
```

The check also fails if the application exists but has lost `MatchRoles` or is not `Type=18` —
existence alone is not enough. See §8.

---

## 3. Containers and startup

### `aiworkshop-iris` never leaves `health: starting`

It should reach `healthy` about 15 seconds after `docker compose up -d`. Longer than a minute means
a real fault.

```bash
docker compose logs -f iris
docker exec aiworkshop-iris iris list
# status: running, state: ok
```

`state: ok` is what you want. The usual cause of a container that never settles is a repository
cloned inside OneDrive or iCloud Drive: the bind mount of `./src` fights the sync client. Move the
clone to a plain local path such as `C:\dev\aihub-workshop` and `docker compose up -d` again.

> On the **non-community** image this was the opposite problem — the container reported
> `(unhealthy)` permanently while working perfectly, because an unlicensed instance reaches
> `state: alert`. On this image `healthy` means what it says.

### `docker compose ps` says `unhealthy`, but everything works

Look in the alert log:

```bash
docker exec aiworkshop-iris tail -3 /durable/irissys/mgr/alerts.log
```

If it says **`System appears to have failed over from node <name>`**, the container's hostname does
not match the node the image was built on. IRIS treats that as an alert, and the healthcheck turns
it into `unhealthy` about three minutes after start — long after you have seen it go healthy. The
instance is fine: `Workshop.Verify.Run()` returns ten `OK` in this state.

```bash
docker compose restart      # clears it permanently
```

`docker-compose.yml` sets `hostname: buildkitsandbox` precisely to avoid this, so you will normally
only see it if you rebuilt the image with a different Docker builder. If the message names a
different node, put that name in `hostname:` and the alert stops happening at all.

### Workshop.Lab lists exercises that do not match the workbook

Or a class behaves as it did before a change you know you made. The database volume is older than
the image.

The instance lives in the `iris-durable` volume, mounted at `/durable` — IRIS's Durable %SYS
mechanism. IRIS populates it on the **first** start and never again, so an existing volume is never
refreshed from a newer image: `docker compose up` runs the *old* compiled classes against your
*new* files.

```bash
./module2-aihub/reset-lab.sh --status      # warns if the volume predates the image
./module2-aihub/reset-lab.sh --hard        # destroys the volume and reseeds from the image - In the joint workshop environment this deletes the work of ALL THREE modules, not only module 2.
```

If you only need the classes refreshed and want to keep your data, recompile from the bind mount
instead:

```objectscript
do ##class(Workshop.Setup.Build).CompileWorkshop()
```

> **Note.** A stale volume is *not* the explanation for a container reporting `(unhealthy)` — see
> the next section for that.

### `docker ps` says `(unhealthy)` but everything works

Check the instance's own view first:

```bash
docker exec aiworkshop-iris iris list
```

The healthcheck passes on `state: ok` or `state: warn` and fails on `state: alert`.

**`warn` is normal and nothing to fix.** This image logs a severity-2 startup error on **every**
boot — an internal `<METHOD DOES NOT EXIST>Sharding+2^STU` — which has no effect on anything the
workshop does. Measured over three consecutive restarts: the error appeared every time, and the
state settled to `warn`, `ok`, `ok`, with the container reporting `healthy` in all three.

**`alert` is occasionally seen and usually transient.** If you catch it, wait a few seconds and look
again. What matters is the gate, not the badge:

```objectscript
do ##class(Workshop.Verify).Run()
```

Ten `OK` lines means the environment is good whatever `docker ps` says. A container that is still
`(unhealthy)` after a minute *and* fails the gate is a real fault — read `docker compose logs -f
iris`.

### The container exits immediately

```bash
docker logs aiworkshop-iris | tail -40
```

Check the obvious things first: the base image was retagged as something other than
`aihub:workshop`, the `./src` path does not exist, or the named volume holds a half-written database
from an interrupted start. The last of those is the only one worth `down -v` — everything the
workshop needs is baked into the image, so you lose only your own edits.

No licence key is involved. This is the community image; it starts unlicensed by design.

### Port already allocated

Something else owns 42773, 41972, 48080 or 48888. Either stop it, or change the left-hand port of that line in
the repository root's `compose.yaml` (for example `"127.0.0.1:42801:52773"`), run `docker compose up -d`, and use
the new port everywhere instead (for 42773 also in `.vscode/settings.json`).

---

## 4. The model will not answer

### `<%AICore>ProviderError … dns error: failed to lookup address information`

The **container** cannot resolve your provider's hostname. Critically, **the host resolving it fine
tells you nothing** — Docker containers use Docker's resolver, not yours.

```bash
# prove it
docker exec aiworkshop-iris getent hosts api.openai.com
```

Docker's embedded resolver forwards to `1.1.1.1` and `8.8.8.8`, which many corporate networks block.
Find a resolver you are allowed to use:

```powershell
Get-DnsClientServerAddress -AddressFamily IPv4        # Windows
```
```bash
scutil --dns | grep nameserver                        # macOS
```

Then in `.env`:

```
DNS_SERVER=10.0.0.1
```
```bash
docker compose up -d --force-recreate iris
```

> **This does not fix `docker build`.** Builds ignore the compose `dns:` setting, and
> `--network=host` does not help either (on Docker Desktop the "host" is the Linux VM, with the same
> resolver). For builds, set the daemon's resolver: Docker Desktop → Settings → Docker Engine →
> `{"dns": ["10.0.0.1"]}` → restart Docker.

### `<%AICore>ProviderError` with a 401 or authentication message

Your key is wrong, revoked, or for a different provider than `AI_PROVIDER` names.

```objectscript
do ##class(Workshop.Provider).Report()
```

This prints the variable it is reading, the length of the value and its last four characters —
enough to tell "wrong key" from "no key" without putting the key in your scrollback.

### The model rejects the request outright

Check `AI_MODEL` is a model your key can actually reach. `gpt-4o` is verified; others should work but
have not been exercised.

Also: **leave `Temperature` unset** unless you mean it. It has no default, and several reasoning
models reject an explicit value.

### `<%AICore>IncompleteInitialization: Initialization incomplete for Provider`

You skipped `%Init()`:

```objectscript
set agent = ##class(Workshop.Agent.OnCall).%New()
do agent.%Init()                      // <- this
set session = agent.CreateSession()
```

Note it fires at **`CreateSession()`**, not at `Chat()` — one call earlier than you would expect.

---

## 5. VS Code and Atelier REST

### Check 9 failed once, right after `docker compose up -d`, then passed

A **cold-start race**, not a fault. Immediately after startup the gateway is up but has not finished
establishing its connection pool to IRIS, and the first request can return 401 before settling —
we saw exactly this while the same request from the host succeeded seconds later.

`Workshop.Verify` now retries this check four times over ~12 seconds, so you should not see it. If
it fails *after* the retries, the message says so explicitly and it is a real problem.

### `/api/atelier/` returns **401**

**Without credentials that is correct** — the application is password-protected. Log in as
`_SYSTEM` / `SYS`.

If you get 401 *with* credentials, the password may be expired:

```objectscript
zn "%SYS"
do ##class(Security.Users).Get("_SYSTEM",.p)
zw p("ChangePassword")                      // 1 means expired
do ##class(Security.Users).UnExpireUserPasswords("*")
```

### `/api/atelier/` returns **404**

The path is not being served. First confirm the web server is there at all:

```bash
docker exec aiworkshop-iris wget -qO- --user=_SYSTEM --password=SYS http://localhost:52773/api/atelier/
```

(The container has `wget`, not `curl`.) JSON back from inside the container while the host still
404s means the port mapping, not IRIS. No answer from inside either means the `/api/atelier`
application or `%Service_WebGateway` has been disabled — check both in the Management Portal under
**System Administration → Security**.

**A working Management Portal does not prove Atelier REST works.** `/csp/sys/UtilHome.csp` has a
recognised file extension and `/api/atelier/` does not; the two have failed independently. Always
test the REST path itself.

> If you are running a **non-community** image behind a Web Gateway, a 404 here has four more
> causes, all of which look identical and leave nothing in any log. See
> [APPENDIX-webgateway.md](APPENDIX-webgateway.md) §3.

### VS Code will not connect at all

Check it is using host `localhost`, port **42773**, namespace `IRISAPP`.

> If you have used the InterSystems dev template, you may have `docker-compose` auto-discovery
> settings. **Those will not work here.** The image's web server is on 52773 inside the container,
> but `docker-compose.yml` publishes it on host port 42773 so it cannot collide with another IRIS
> instance. Auto-discovery does not follow the remap. Use the explicit host and port in the repo's
> `.vscode/settings.json`.

### Any `/csp/irisapp/...` page returns 404

This is an IRIS **for Health** image, so a namespace's web application is
**`/csp/healthshare/irisapp/...`**. There is no `/csp/irisapp`.

The portal pages, all verified:

| Page | Path |
|---|---|
| Production config | `/csp/healthshare/irisapp/EnsPortal.ProductionConfig.zen` |
| Message Viewer | `/csp/healthshare/irisapp/EnsPortal.MessageViewer.zen` |
| Visual Trace | `/csp/healthshare/irisapp/EnsPortal.VisualTrace.zen` |
| Event Log | `/csp/healthshare/irisapp/EnsPortal.EventLog.zen` |
| Workflow tasks | `/csp/healthshare/irisapp/EnsPortal.WFTasklist.zen` |

> The Workflow pages are `WFTasklist` and `WFWorklist`. The obvious guesses — `WorkflowTaskList`,
> `WorkflowInbox` — all 404.

---

### Codex does not see the IRIS MCP server

Work through these in order; the first three cover almost everything.

1. **Is the bridge running?** It is not started by `docker compose`:
   ```bash
   docker exec aiworkshop-iris sh -c "ss -lntp | grep 8080"
   ```
   No `LISTEN` line means it is not up. Start it:
   ```bash
   docker exec -d aiworkshop-iris /usr/irissys/bin/iris-mcp-server --config=/home/irisowner/config_http.toml run
   ```
2. **Is the URL right?** `http://localhost:48080/mcp` — port **48080**, path **`/mcp`**. Not
   `/mcp/oncall`: the endpoint path becomes a prefix on tool *names*, not part of the URL.
3. **Did Codex reload?** It reads its configuration at startup. Reload the window after editing
   `.codex/config.toml`.
4. **Is the application registered?** `do ##class(Workshop.MCP.Setup).Report()` should show
   `/mcp/oncall` with `Type=18`, `enabled=1` and `MatchRoles` containing `%All`.
5. **Does the endpoint answer at all?** Take Codex out of the picture with the bundled client, which
   prints the raw protocol:
   ```bash
   python module2-aihub/src/Python/mcp_smoke.py
   ```
   If that lists your tools — four from the start state, six once Exercise B.2.2 has attached the
   Python server — then the problem is in Codex's configuration. If it lists nothing, the problem is
   the bridge or IRIS, and the sections above apply.

### Codex lists only one tool, called iris_status

The MCP application lost `MatchRoles`. See the `tools/list` entry above — the fix is `MatchRoles`
plus a **bridge restart**, because a failed discovery is cached for five minutes.

### Codex uses a tool name that does not exist

It guessed from the server's `initialize` text, which describes the naming convention incorrectly as
`service_tool`. The real names carry the endpoint path: `mcp_oncall_RecentErrors`. Asking it to list
the tools first usually settles it.

## 6. Compiling

### `<CLASS DOES NOT EXIST> … GeneratePolicyGetter`

A ToolSet names a policy class in `<Policies>` that has not compiled yet. The reference is resolved
at **compile** time by a method generator, so **compile policies before ToolSets**:

```objectscript
do ##class(Workshop.Setup.Build).CompileWorkshop()
```

which compiles the whole package in the correct dependency order. A plain "compile everything" can
pass or fail depending on queue order alone.

### `ERROR #5540: SQLCODE: -30 Message: Table 'ENS_UTIL.LOG' not found`

At **compile** time, not runtime. A `<Query>`'s SQL is prepared when the class compiles. Either the
namespace is not interoperability-enabled (§2 check 2) or your SQL names a table that does not exist.

### `<%AICore>QueryArgumentDefaultInvalid: … default '''' must be a quoted string`

An `Arguments` default of `''`. The SDK guide's own example shows this and it does not compile.
Inside an XML attribute you need:

```xml
Arguments="configName As %String = &quot;&quot;"
```

`{expression}` also works.

### `MPP5612: Referenced macro missing right paren`

A `$$$macro` split across two lines. ObjectScript has no statement continuation — macros, `$listbuild`
and everything else must be on one line.

### `<SYNTAX>` on a `Try {` or `For … {` when piping a script into the terminal

`iris session IRIS < script.txt` executes **each line as its own command**, so multi-line `{ }`
blocks cannot work. Keep piped scripts to single-line statements, or put the logic in a compiled
class and call it — which is why `iris.script` is deliberately dumb and
`Workshop.Setup.Build` exists.

### `<SUBSCRIPT>` inside `%AI.ToolSet.Specification.Compiler`

Almost certainly a `<Tool Query="...">` attribute. There is no such attribute — use a separate
`<Query>` element with the SQL as CDATA content.

---

## 7. Tools behaving oddly

### The agent answers but never calls a tool

Check the parameter name. It is **`TOOLSETS`** (plural) on an `%AI.Agent`. `TOOLS` is the parameter
for a *Skill*: on an agent it compiles perfectly and attaches **nothing**, with no warning.

Confirm what the model can see:

```objectscript
do ##class(Workshop.Tools.OnCall).%Dump()
```

### The agent says there are no errors, but the table is full

Two causes, both silent, and the tool "works" either way.

**① Wrong log type.** `Ens.DataType.LogType` is
`1=Assert 2=Error 3=Warning 4=Info 5=Trace 6=Alert`. **Errors are `Type 2`.** Filtering on `3` gets
you warnings.

**② An optional argument bound as NULL.** The documented `OR` guard does not work:

```sql
-- BROKEN: an omitted argument is NULL, so this is NULL, so the row is excluded
AND (:configName = '' OR ConfigName = :configName)

-- CORRECT
AND (COALESCE(:configName, '') = '' OR ConfigName = :configName)
```

Check directly:

```objectscript
write ##class(Workshop.Tools.OnCall).%New().%Invoke("RecentErrors",{}).%Get("row_count")
```

### `<UNDEFINED> *count` when reading a result

```objectscript
write result.row_count      // BROKEN
write result.%Get("row_count")   // correct
```

`_` is ObjectScript's concatenation operator, so `result.row_count` parses as `result.row _ count`.
Any envelope field with an underscore needs `%Get()`.

### `<INVALID OREF>` from `%Invoke()`

`%Invoke()` returns `%Library.Any`, so a mistyped tool name returns `""` and `.%ToJSON()` on it
throws. Guard with `$isobject()`, and check the name against `%Dump()`.

### `%Discover()` says `stateful: false` and you expected true

Only **instance `Method`s** can touch instance properties. `ClassMethod`s and inline `<Query>`
elements are stateless, and the framework works that out for itself.

### Worklist state survives a new session and you expected it not to

**Correct behaviour.** The tool object is created when the **agent** is instantiated and lives as
long as the agent, not the session. State survives `CreateSession()`. Make a new agent to clear it.

### A guarded tool runs when it should have been refused

You called it through `%Invoke()`. **Policies are enforced by `%AI.ToolMgr`, not by the ToolSet** —
`agent.ToolManager.ExecuteTool(...)` is the governed path; `ts.%Invoke(...)` is not, even though the
policy object is attached and `%GetAuthorizationPolicy()` returns it.

This is Module C step 5, and it is a feature of the design rather than a bug: governance is a
property of the execution path.

---

## 8. MCP

### `tools/list` returns only `iris_status`

The commonest MCP failure, and it looks like success: the bridge starts, connects and logs
`discovered 1 endpoint(s)`. Ask the meta tool what went wrong:

```bash
python mcp_smoke.py iris_status
```
```
Discovery failed … HTTP 403 Forbidden: /mcp/oncall/v1/services (empty body)
```

The discovery probe arrives **unauthenticated**, runs as `UnknownUser`, and has no privilege. The fix
is `MatchRoles=":%All"` on the application:

```objectscript
do ##class(Workshop.MCP.Setup).Run("IRISAPP")
```

> `AutheEnabled` is **not** the fix — 64 and 96 both still 403. It is `MatchRoles`.

**Then restart the bridge.** A failed discovery is cached per identity
(`already discovered for this identity — skipping re-discovery`) and auto-discovery is off, so
nothing retries for five minutes.

```bash
docker exec aiworkshop-iris pkill -f iris-mcp-server
docker exec -d aiworkshop-iris /usr/irissys/bin/iris-mcp-server \
    --config=/home/irisowner/config_http.toml run
```

### "I fixed it on the IRIS side and nothing changed"

The cached discovery above. Restart the bridge.

### The bridge will not start

```bash
docker exec aiworkshop-iris cat /tmp/mcp.log
```

```
unknown variant `stdout`, expected `stderr` or `file`
```

`[logging] output` accepts only `stderr` or `file`.

### A tool name is not found

The prefix is the **whole endpoint path** with `/` replaced by `_`: `/mcp/oncall` gives
`mcp_oncall_RecentErrors`, even with a single endpoint.

> The server's own `initialize` response **describes this incorrectly** — it claims the format is
> `service_tool` (e.g. `test_Add`), which would mean `oncall_RecentErrors`. Trust `tools/list`. An
> LLM client reads that description too, so expect it to guess wrong.

### Connection refused on 48080

The bridge is not running. Note also that the URL path is **`/mcp`**, not `/mcp/oncall` — the
endpoint path names the IRIS application and prefixes tool names, but is not in the URL.

### Every `tools/call` fails with `JSON serialization/deserialization error: expected value at line 2 column 1`

A `%AI.Policy.ConsoleAudit` or `ConsoleAuth` policy is attached to a ToolSet exposed over MCP. They
write to the current device, which during an HTTP request **is the response body**. Remove them;
persist audit to a table instead, as `Workshop.Policy.AuditLog` does.

---

## 9. Config Store and the Wallet

### `ERROR #26414: No descriptor found for AI.LLM`

The descriptor registry is not built on a fresh instance, even though
`%AI.ConfigStore.LLMDescriptor` is compiled and present:

```objectscript
do ##class(%ConfigStore.DescriptorManager).RebuildRegistry()
```

`Workshop.Setup.ConfigStore.Run()` does this for you. It is also done at image build time.

### `ERROR #26220: Error using secret … > ERROR #822: Access Denied`

The principal cannot read the Wallet secret. The permission is **`:R` (READ)**, not `:U` (USE) —
`%Wallet.Collection` stores its own requirement:

```objectscript
write ##class(%Wallet.Collection).%OpenId("WorkshopWallet").UseResource
// %Workshop_ConfigUse:READ
```

> Grant `:U` and `$SYSTEM.Security.Check(res,"USE")` returns **1** while every secret resolution
> still fails. A thoroughly misleading pair of signals — check `"READ"`.

### `ERROR #790: Operation requires %Admin_ConfigStore:USE`

Reading the Config Store at all is a separate gate from reading the secret. The principal needs
`%Admin_ConfigStore:U` *and* the Wallet resource.

### `ERROR #5805: ID key not unique for extent '%Wallet.Collection'`

Harmless — it already exists. `Workshop.Setup.ConfigStore` detects this and reports `exists` so
re-running the exercise is safe.

### `ERROR #887: Invalid role name`

Role names cannot start with `%` — that prefix is reserved for system roles.

### My terminal is stuck as another user

You ran `$SYSTEM.Security.Login` into a limited user. It is a **one-way door**: that user has no
privilege to log back in as `_SYSTEM`. Close the terminal and open a new one — nothing is damaged.

This is why `Workshop.Setup.ConfigStore` runs its demonstration read in a **child process**.

### A credential appeared in my terminal

**`CopyDetails()` resolves `secret://` references into plaintext.** It returns the real credential,
which is easy to print by accident. `Workshop.Setup.ConfigStore` redacts by field name for exactly
this reason.

If it happened on a shared screen, **rotate the key.** The config *row* is safe to show; the
resolved details object is not.

---

## 10. The production and Workflow tasks

### Tasks are created but nobody can see them

```
ERROR <EnsWf>ErrNoUsersFound: No Users found to assign Task to
```

The `EnsLib.Workflow.Operation`'s **production item name is the workflow role name**. There is no
`%RoleName` on `TaskRequest` and no role setting on the operation. Name the item `ApprovalDesk` while
your approvers sit in `OnCallApprovers` and tasks are created but silently undeliverable —
`EnsLib_Workflow.TaskResponse` has rows while `EnsLib_Workflow.Worklist` stays empty.

The shipped production names the item `OnCallApprovers` for this reason. Check membership:

```objectscript
do ##class(Workshop.Interop.Setup).EnsureApprover()
do ##class(Workshop.Interop.Setup).Tasks()
```

### `<%AICore>SessionNotAttached: Session is not attached`

A session reopened with `%OpenId()` is **detached**. Attach it to an agent first:

```objectscript
set agent = ##class(Workshop.Agent.OnCall).%New()  do agent.%Init()
set s = ##class(%AI.Agent.Session).%OpenId(3)
write s.IsAttached()          // 0
do agent.ResumeSession(s)     // the missing step
write s.IsAttached()          // 1
zw s.GetContext()
```

### `Cannot create the service — is the production running?`

```objectscript
do ##class(Workshop.Interop.Setup).Start()
do ##class(Workshop.Interop.Setup).Status()
```

### The production is `Troubled`

Open the Event Log page and read the most recent error. Or:

```objectscript
set rs = ##class(%SQL.Statement).%ExecDirect(,"SELECT TOP 10 Type,ConfigName,Text FROM Ens_Util.Log ORDER BY ID DESC")
while rs.%Next() { write rs.%Get("ConfigName"),": ",rs.%Get("Text"),! }
```

### `Host Class … has been recompiled; continuing to run using code from previous version`

A production item's class changed while the production was running. Restart it:

```objectscript
do ##class(Workshop.Interop.Setup).Stop()
do ##class(Workshop.Interop.Setup).Start()
```

### `%AI.Catalog` returns an empty array

Patterns are **SQL-style**: `Workshop.%`, not `Workshop*`.

And `%AI.Catalog.Tools()` legitimately returns nothing here — it lists plain `%AI.Tool` subclasses,
and every tool in this workshop lives inside a `%AI.ToolSet`. Use `ToolSets()` then `%Discover()`.

---

## 11. Starting over

### I am lost — which exercises have I actually done?

```objectscript
do ##class(Workshop.Lab).Status()
```

Reports every exercise as `starter`, `SOLVED` or `MISSING`, read from the live class text rather
than from anything you have to remember.

### I am behind and want to start the next exercise anyway

```objectscript
do ##class(Workshop.Lab).SolveThrough("C.1")   // everything up to and including C.1
```

Later exercises build on earlier ones, so this applies all the prerequisites in dependency order.
Use it to rejoin at any module instead of losing the rest of the session.

### Put one class back the way it started

```objectscript
do ##class(Workshop.Lab).Reset("B1")   // just that exercise's class
do ##class(Workshop.Lab).Reset()       // everything, plus the exercise data
```

> `Reset()` recompiles from pristine copies baked into the image at
> `/opt/workshop/starters/`, not from your `src/` tree — so it works even after you have edited
> your files, and your files are left alone.

### Reset the exercise data, keep everything else

```objectscript
do ##class(Workshop.Data.Approval).Reset()
do ##class(Workshop.Data.AuditEntry).Reset()
do ##class(Workshop.Demo.Seed).Clear()
do ##class(Workshop.Demo.Seed).Run()
```

### Recompile the whole package in the right order

```objectscript
do ##class(Workshop.Setup.Build).CompileWorkshop()
```

### Restart the containers, keeping your work

```bash
docker compose stop
docker compose start
```

### Nuclear option

```bash
docker compose down -v      # DESTROYS the database volume - In the joint workshop environment this deletes the work of ALL THREE modules, not only module 2.
docker compose up -d
```

You get a clean, fully seeded instance: the namespace, the compiled classes, the MCP application and
the demo data are all baked into the image at build time. **You lose only your own edits** — and
since those are in `src/` on your host, you lose nothing you wrote in a file.

Then re-run the gate:

```objectscript
do ##class(Workshop.Verify).Run()
```

---

## Still stuck?

- `REFERENCE.md` explains the concepts behind each failure; this file is organised by symptom.
- **Ask your instructor.** They hold the verification notes for this build: a ranked list of what
  was executed against the real image and what was not. A handful of things in the workshop are
  knowingly unverified, and if you have hit one of those, it may genuinely not work — that is worth
  knowing in thirty seconds rather than debugging for ten minutes.
- Remember this is an Early Access preview. If a class or method behaves differently from the
  workbook, compare `write $zv` with the build named at the top of `WORKBOOK.md`.

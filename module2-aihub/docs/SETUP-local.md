# Setup — your own laptop

**Do this before the workshop, not during it.** It takes about fifteen minutes, most of which is
loading a large image. If you arrive with step 6 passing, you will not lose any of the 120 minutes.

> **Joint workshop day:** the installs, the clone and the image (steps 1-3 below) are done by the main
> README and `check.ps1` of the joint repository. Start at step 4. Run every command from the
> **repository root** (the folder with `compose.yaml`).

---

## 1. What you need installed

| | Version | Check with |
|---|---|---|
| **Docker Desktop** | current, **running** | `docker version` |
| **VS Code** | current | `code --version` |
| **InterSystems ObjectScript** extension | current | VS Code → Extensions → search "InterSystems ObjectScript" |
| **OpenAI Codex** extension | current | the one you used in Part 1 |

Docker Desktop needs roughly **20 GB free** and at least **6 GB of RAM** allocated. The image is
large; IRIS is a database.

Module B.3 uses the **Codex chat as an MCP client**, which is why it is on the list — you point it at
IRIS with two lines of configuration and ask it questions. Nothing to install beyond the extension
you already have.

**Python is optional.** A dependency-free fallback client ships with the workshop for anyone without
Codex, and it is the better tool for diagnosing the bridge. It needs Python 3.10+ and nothing outside
the standard library, so there is nothing to `pip install`.

---

## 2. Get the files

Clone or unzip the workshop repo to a **plain local path**:

```
C:\dev\aihub-workshop          (Windows)
~/dev/aihub-workshop           (macOS)
```

> ### Do not put this inside OneDrive, iCloud Drive, Dropbox or a network share
>
> Docker bind-mounts the source tree into the container, and the database files live in a Docker
> volume that a sync client will fight over. You get file-locking errors and corrupted databases, and
> **the symptoms look nothing like the cause** — you will spend the workshop debugging phantoms.
>
> A plain local folder. Nothing clever.

---

## 3. Load the image

You will have been given a tarball — about **1.9 GB**, expanding to a 12 GB image.

It is a **separate download from this repository**, and deliberately so: a 1.9 GB binary committed
to git would be re-cloned by everyone every time a typo in the workbook was fixed. Put it wherever
you like — nothing but the `docker load` below ever reads it, and you can delete it afterwards.

```bash
# Joint workshop: skip - check.ps1 downloads the joint image.
```

Confirm it landed:

```bash
docker images | grep aihub
```

You want `aihub-workshop   latest`. *(Joint workshop: not needed - `check.ps1` downloads the joint image.)*

> **If you were given the raw InterSystems image instead** of a pre-built one, retag it and build:
>
> ```bash
> docker tag <the tag you loaded> aihub:workshop
> # (joint workshop: not applicable - the image is pulled)
> ```
>
> No licence key is needed — this is the community image. The build takes a few minutes and needs
> internet access, so do it before the day rather than on conference wifi.
>
> One thing you lose this way: the exercise solutions live in the instructor's image, not in this
> repository, so the catch-up commands (`Workshop.Lab.SolveThrough()`) will report a missing file.
> Starting over (`Workshop.Lab.Reset()`) works either way. Ask for the pre-built tarball if you
> think you may want to skip an exercise and keep up.

---

## 4. Your LLM key — and what to do if you do not have one yet

**You do not need a key to complete this setup.** Keys are usually handed out on the day. Do
everything in this guide now, run the checks in step 6, and you will get a clear answer about your
container, IRIS and your network without one. Only the three provider checks wait for the key.

Copy the template either way, because the other settings matter:

```bash
copy .env.example .env      # PowerShell, in the repository root (bash: cp)
```

Then edit `.env`. With a key:

```
AI_PROVIDER=openai
AI_MODEL=gpt-4o
OPENAI_API_KEY=sk-...
```

Without one, leave the key line out and keep the rest. `AI_PROVIDER` still decides **which vendor
the network check tests**, so set it to whatever you expect to use on the day.

`anthropic`, `gemini`, `azureopenai` and `deepseek` are wired by name; any other provider the SDK
supports works too, using `<PROVIDER>_API_KEY` — so `AI_PROVIDER=openrouter` looks for
`OPENROUTER_API_KEY`.

> `.env` is git-ignored. **`.env.example` is not** — it is the committed template, so never put a
> real key in it.

> We verified the workshop end to end against `openai` / `gpt-4o`. Other providers use the same code
> path but have not been exercised; if yours misbehaves, say so early.

### If you want a full end-to-end test before the day

Optional, and entirely up to you. Two routes:

- **Your own key from any provider's free tier.** Several vendors offer one; they need a signup, and
  the terms change, so check for yourself. Set `AI_PROVIDER` and the matching `*_API_KEY` and the
  workshop runs normally. Swap in the workshop key on the day by editing `.env` and running
  `docker compose up -d --force-recreate iris`.
- **Ollama**, which needs no key at all because it runs on your own machine. `.env.example` has the
  settings. It costs a model download of several gigabytes, and ⚠️ **we have not tested this path** —
  so treat it as an experiment, not a fallback.

There is no reputable LLM API that works without an account, so if you want a real model call before
the day, one of those two is the price.

---

## 5. Start it

```bash
docker compose up -d
```

First start takes a minute or two while Docker creates the volume. Then:

```bash
docker compose ps
```

`aiworkshop-iris` should reach `Up (healthy)` within about 15 seconds.

> If it sits at `health: starting` for more than a minute, something is wrong. Read the log:
>
> ```bash
> docker compose logs -f iris
> ```
>
> The usual cause is a repository cloned inside OneDrive or iCloud Drive — see step 2.

---

## 6. Prove it works

```bash
docker exec -it aiworkshop-iris iris session IRIS -U IRISAPP
```

You should land in an `IRISAPP>` prompt. Then:

```objectscript
do ##class(Workshop.Verify).Run()
```

### Without a key — what you should see now

**Seven `OK` and three `WAIT`. No `FAIL`.** That is a pass: your container, IRIS and your network are
ready, and the workshop will run.

```
  OK    namespace is IRISAPP
  OK    interoperability enabled
  OK    AI Hub classes present
  OK    outbound HTTPS reaches openai
  WAIT  provider key configured
          -> OPENAI_API_KEY is not set yet. Expected before the workshop.
  WAIT  provider can be constructed
  WAIT  provider answers a real prompt
  OK    demo event log seeded
  OK    Atelier REST answers on 52773
  OK    MCP Server /mcp/oncall registered
  7 OK   3 WAIT
```

**The fourth check is the important one, and it needs no key.** It asks your chosen vendor to reject
a deliberately invalid key. Being rejected proves DNS, TCP and TLS all work from inside the
container, over exactly the path the real calls will use — which is the single most common thing to
go wrong on an unfamiliar network, and the thing you cannot fix in the first five minutes of a
workshop.

If it says `FAIL`, the message names the cause and the fix. The usual one is Docker's default DNS
resolvers being blocked: set `DNS_SERVER` in `.env` to a resolver your network allows, then
`docker compose up -d --force-recreate iris`.

### On the day, with a key

Put the key in `.env`, then:

```bash
docker compose up -d --force-recreate iris
```

Run the check again. **You want ten `OK`.**

Anything reporting `FAIL`, at either stage: go to [TROUBLESHOOTING.md](TROUBLESHOOTING.md), which has
a section per check. **Do not arrive at the workshop with a failing check.** `WAIT` is fine; `FAIL`
is not.

Type `halt` to leave the terminal.

---

## 7. Connect VS Code

Open the **`module2-aihub`** folder in VS Code (File > Open Folder). The connection is already configured in
`.vscode/settings.json`, so you should simply see it connect — look for the server name in the
bottom status bar, and an **ObjectScript Explorer** view listing the `Workshop` package.

If it does not connect, the settings it is using are:

| | |
|---|---|
| Host | `localhost` |
| Port | **42773** |
| Namespace | `IRISAPP` |
| User / password | `_SYSTEM` / `SYS` |

> **Why an explicit port rather than the usual Docker auto-discovery?** The InterSystems dev template
> connects by naming the compose service and letting the extension find the port. The image does have
> its own web server, on 52773 inside the container — but `docker-compose.yml` publishes it on host
> port **42773**, because 52773 collides with any other IRIS instance you are running. Auto-discovery
> gets confused by the remap, so the connection is written out in full in `.vscode/settings.json`.

**GATE:** you can open `src/Workshop/Agent/OnCall.cls` from the ObjectScript Explorer, edit a
comment, save it, and see it compile in the Output panel.

---

## 8. Your ports

| Host port | Goes to | Used for |
|---|---|---|
| **42773** | the container's web server on 52773 | Management Portal, Atelier REST, interop portal |
| **41972** | IRIS superserver | the MCP bridge |
| **48080** | MCP over HTTP | the Codex chat as an MCP client; `mcp_smoke.py` as a fallback |

Deliberately not 52773 / 1972 / 8080 — those collide with almost everything, including other IRIS
instances you may already be running.

Useful pages (log in as `_SYSTEM` / `SYS`):

| | |
|---|---|
| Management Portal | <http://localhost:42773/csp/sys/UtilHome.csp> |
| Production config | <http://localhost:42773/csp/healthshare/irisapp/EnsPortal.ProductionConfig.zen> |
| Message Viewer | <http://localhost:42773/csp/healthshare/irisapp/EnsPortal.MessageViewer.zen> |
| Workflow tasks | <http://localhost:42773/csp/healthshare/irisapp/EnsPortal.WFTasklist.zen> |

> Note `/csp/healthshare/irisapp`, not `/csp/irisapp`. This is an IRIS **for Health** image, so a
> namespace's web application sits under `/csp/healthshare/<namespace>`. Anything under
> `/csp/irisapp` returns 404.

---

## 9. Stopping and starting

```bash
docker compose stop     # keeps everything
docker compose start    # back where you were
```

> ### `docker compose down -v` destroys your work
>
> In the joint workshop environment this deletes the work of ALL THREE modules, not only module 2.
>
> The `-v` deletes the `iris-durable` volume, which holds the entire IRIS instance — your databases,
> your compiled classes and the instance configuration. Plain `down` is safe; `down -v` is not.
>
> If you do it by accident: `docker compose up -d` gives you a clean, fully seeded instance — the
> namespace, compiled classes, MCP application and demo data are all baked into the image at build
> time. You lose only your own edits. Thirty seconds, not a catastrophe.

---

## 10. Checklist before you walk in

- [ ] `docker compose ps` shows `aiworkshop-iris` as `Up (healthy)`
- [ ] `Workshop.Verify.Run()` prints no `FAIL` — **ten** `OK` with a key, or seven `OK` and three `WAIT` without one
- [ ] VS Code is connected and you can open and save a `Workshop` class
- [ ] You know which provider and model you are using
- [ ] Your clone is **not** in a synced folder

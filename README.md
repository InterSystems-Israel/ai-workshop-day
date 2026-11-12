# AI workshop day - InterSystems IRIS

Three hands-on modules in one day, all on **one IRIS container** on your laptop:

| # | Module | Namespace | Folder |
|---|---|---|---|
| 1 | Agentic development with iris-agentic-dev + Codex, then the Agentic Integration Builder (AIB) | `USER`, then `AI` | [`module1-agentic/`](module1-agentic/) |
| 2 | InterSystems AI Hub: the integration on-call desk | `IRISAPP` | [`module2-aihub/`](module2-aihub/) |
| 3 | Vector search & RAG | `VECTOR` | [`module3-vector/`](module3-vector/) |

The modules are independent: each one has its own namespace and its own data, so you never need to switch
containers or environments during the day.

## Before the workshop day (about 30 minutes, at home - not on the venue's wifi)

**1. Install** (if you don't have them yet):
- [Docker Desktop](https://www.docker.com/products/docker-desktop) - start it and wait until it says *Engine running*.
  Give it at least 8 GB of memory, and have about 40 GB free disk.
- [git](https://git-scm.com)
- [VS Code](https://code.visualstudio.com) with the extensions **InterSystems ObjectScript Extension Pack**,
  **Jupyter** and **OpenAI Codex**

**2. Module 1 prework: iris-agentic-dev on your laptop**

1. Create a new folder `C:\Tools` and add it to the Windows PATH environment variable:
   - Press the Windows key, type environment variables and click Edit the system environment variables.
   - In System Properties, click Environment Variables…
   - Under System variables, scroll to Path, select it and click Edit.
   - Click New, type `C:\Tools` and press Enter.
   - Click OK in every open dialog to save.

2. Download `iris-agentic-dev-windows-x86_64.exe` from the Releases page:
   [Release v1.7.1 · intersystems-community/iris-agentic-dev](https://github.com/intersystems-community/iris-agentic-dev/releases/tag/v1.7.1)

   Save the file in `C:\Tools` and rename it to `iris-agentic-dev.exe`.
   Open a new Command Prompt and check that the PATH works:

   ```
   iris-agentic-dev --version
   ```

   If it shows a version number, the PATH is set correctly.

**3. Get the workshop files** (PowerShell, in a plain local folder - not OneDrive):
```
git clone https://github.com/Ari-Glikman/ai-workshop-day.git
cd ai-workshop-day
```

**4. Run the readiness check:**
```
powershell -ExecutionPolicy Bypass -File .\check.ps1
```
It checks your laptop, downloads the workshop image (many GB - the first time takes a while), starts the container
(`docker compose up -d`) and tests what the three modules need. It ends with **READY**, or tells you what to fix.
It installs nothing on your laptop. If you cannot fix something, bring the message to the workshop.

**5. Stop the container** until the workshop:
```
docker compose down
```
On the day, start it again with `docker compose up -d` (in the same folder) - it takes about a minute.

## On the day

Do the modules in order, each with its own guide:

1. **Module 1** - `module1-agentic/`: `Module 1 - IRIS_Agentic_Development_Workshop_hebrew.pdf`, then
   `Module 1 - AIB_Workshop_hebrew.pdf`. The AIB setup part ("admin") is already done in the container.
2. **Module 2** - `module2-aihub/README.md`, then `WORKBOOK.md`. For the API key: `copy .env.example .env` in
   **this** folder (the repository root), add the key, then `docker compose up -d --force-recreate iris`.
3. **Module 3** - `module3-vector/Workshop Guide.docx` (Hebrew: `Workshop Guide - Hebrew.docx`).

> **Warning - resets.** `docker compose down -v` (and module 2's `reset-lab -Hard`, which runs it) deletes the work
> of **all three modules**, not just one. Module 2's normal `reset-lab` (without `-Hard`) only touches module 2.

| Where | Address | Login |
|---|---|---|
| Management Portal | http://127.0.0.1:42773/csp/sys/UtilHome.csp | `_SYSTEM` / `SYS` |
| IRIS terminal | `docker exec -it aiworkshop-iris iris session IRIS -U <namespace>` | - |
| AIB chat (module 1) | http://127.0.0.1:42773/iris/ai/frontend/index.html | `_SYSTEM` / `SYS` |
| MCP bridge (module 2) | http://127.0.0.1:48080/mcp (after you start it) | - |
| Jupyter (module 3) | http://127.0.0.1:48888/?token=workshop | - |

| File | What it is |
|---|---|
| `compose.yaml` | the one workshop container (`docker compose up -d` / `down`) |
| `check.ps1` | the readiness check |
| `.env.example` | module 2's AI provider settings (copy to `.env`) |

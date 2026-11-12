# InterSystems AI Hub workshop — Part 2 of 3

A 120-minute hands-on workshop on InterSystems AI Hub, for IRIS developers. Part 1 covers IRIS
Agentic Dev; Part 3 covers IRIS Vector Search.

You will build the **integration on-call desk**: an agent that triages errors in an IRIS
interoperability production, drafts incident notes, and can restart a business host only after a
human has approved it.

## Start here

> **Joint workshop day:** Run the commands in this module in a terminal at the **repository root** (the folder with `compose.yaml`) - VS Code's terminal opens in `module2-aihub`, so type `cd ..` there first. Open the `module2-aihub` folder in VS Code for the editor.

| | |
|---|---|
| **Before the session** | [`docs/SETUP-local.md`](docs/SETUP-local.md) — do this at home, not in the room |
| **During the session** | [`WORKBOOK.md`](WORKBOOK.md) — the exercises, and nothing else |
| Wanting the explanation | [`REFERENCE.md`](REFERENCE.md) — the concepts, in text |
| Something is broken | [`docs/TROUBLESHOOTING.md`](docs/TROUBLESHOOTING.md) — one section per failed check |
| Afterwards | [`CAPSTONE.md`](CAPSTONE.md) — five take-home extensions |

## Quick start

The IRIS image is the joint workshop image: the repository's `check.ps1` (see the main README) downloads
and starts it. Run these from the **repository root** (the folder with `compose.yaml`):

```bash
copy .env.example .env   # then add one provider API key (PowerShell; bash: cp)
docker compose up -d --force-recreate iris
docker exec -it aiworkshop-iris iris session IRIS -U IRISAPP
```
```objectscript
do ##class(Workshop.Verify).Run()
```

**Ten `OK` lines is the gate — and `7 OK  3 WAIT` is the correct answer before you have a key.**
Do not arrive at the workshop with a `FAIL`. `WAIT` is fine. One of the checks
makes a real model call, which is the one most likely to need attention.

## The exercises

`src/Workshop/` is where you work. Everything compiles and runs as supplied; six places are left
deliberately incomplete and marked `TODO (Exercise XX)`. No exercise starts from an empty namespace.

```objectscript
do ##class(Workshop.Lab).Status()            // which exercises are done
do ##class(Workshop.Lab).List()              // the exercises, in dependency order
do ##class(Workshop.Lab).SolveThrough("C.1")  // stuck? load everything up to C.1 and carry on
do ##class(Workshop.Lab).Reset()             // back to the beginning
```

Later exercises build on earlier ones, so if you want to skip one and keep up, `SolveThrough` loads
its prerequisites in the right order. Use it — falling behind on C.1 should not cost you C.5, which
is the point the module builds to.

The solutions live inside the container, not in this repository, so a coding assistant pointed at
this folder cannot read them and quietly do the exercise for you.

## Starting over

```bash
./module2-aihub/reset-lab.sh              # namespace back to the start; your files in src/ are untouched
./module2-aihub/reset-lab.sh --status     # where am I?
./module2-aihub/reset-lab.sh --hard       # rebuild the instance from the image, about 20 seconds
```

Windows PowerShell: `.\module2-aihub\reset-lab.ps1`, `.\module2-aihub\reset-lab.ps1 -Status`, `.\module2-aihub\reset-lab.ps1 -Hard`.

> **`docker compose up` is not a reset.** The database lives in a named volume that survives
> `docker compose down`, so a solved namespace stays solved. Use `./module2-aihub/reset-lab.sh` instead.
>
> **`docker compose down -v` destroys your work.** In the joint workshop environment this deletes the work of ALL THREE modules, not only module 2. The `-v` deletes that volume. Plain `down` is
> safe; `down -v` is not. If you do it by accident, `docker compose up -d` gives you a clean, fully
> seeded instance back — you lose only your own edits.

## Your ports

| Host port | Used for |
|---|---|
| **42773** | Management Portal, Atelier REST, interoperability portal |
| **41972** | IRIS superserver — VS Code, the MCP bridge |
| **48080** | MCP over HTTP |

Deliberately not 52773 / 1972 / 8080, which collide with almost anything else you may be running.

## A note on what you are running

AI Hub is an Early Access product. Classes and method signatures have changed between builds and may
change again, and it is not supported for production use. Everything in the workbook was executed
against `irishealth-community:2026.3.0AI.154.0`; where a behaviour was not verified, the workbook
says so rather than assuming.

The setup also uses several deliberate shortcuts that make a classroom work and would be
indefensible in production — unauthenticated MCP access, `MatchRoles=":%All"`, unexpired default
passwords. Each one is labelled where it appears, with the production alternative named, and they
are collected in `WORKBOOK.md` Appendix C. Please read that before copying anything here into a real
system.

## Secrets

`.env` is gitignored and must stay that way. `.env.example` is the template and holds placeholders
only. Your provider key goes in `.env` and nowhere else.

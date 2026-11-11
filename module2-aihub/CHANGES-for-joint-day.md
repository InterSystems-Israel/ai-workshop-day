# Module 2 (AI Hub): changes for the joint workshop day

Copied from Tani's repository (student material only: no `instructor/`, Dockerfile, iris.script, merge.cpf,
docker-compose.yml, webgateway/, SETUP-cloud.md, APPENDIX-webgateway.md, make-student-repo.sh). `src/` is
unchanged (the image has the same classes). Not copied because the joint environment replaces them: the
image tarball, the compose file and the build. Edits:

- `config_http.toml`: `aihub-iris` -> `aiworkshop-iris` (the joint container is called aiworkshop-iris)
- `README.md`: `aihub-iris` -> `aiworkshop-iris` (the joint container is called aiworkshop-iris)
- `README.md`: `./reset-lab.sh` -> `./module2-aihub/reset-lab.sh` (commands are run from the joint repo root)
- `README.md`: `.\reset-lab.ps1` -> `.\module2-aihub\reset-lab.ps1` (commands are run from the joint repo root)
- `reset-lab.ps1`: `aihub-iris` -> `aiworkshop-iris` (the joint container is called aiworkshop-iris)
- `reset-lab.ps1`: `.\reset-lab.ps1` -> `.\module2-aihub\reset-lab.ps1` (commands are run from the joint repo root)
- `reset-lab.ps1`: `git checkout -- src/` -> `git checkout -- module2-aihub/src/` (src/ is now module2-aihub/src/)
- `reset-lab.sh`: `aihub-iris` -> `aiworkshop-iris` (the joint container is called aiworkshop-iris)
- `reset-lab.sh`: `./reset-lab.sh` -> `./module2-aihub/reset-lab.sh` (commands are run from the joint repo root)
- `reset-lab.sh`: `git checkout -- src/` -> `git checkout -- module2-aihub/src/` (src/ is now module2-aihub/src/)
- `WORKBOOK.md`: `aihub-iris` -> `aiworkshop-iris` (the joint container is called aiworkshop-iris)
- `WORKBOOK.md`: `./reset-lab.sh` -> `./module2-aihub/reset-lab.sh` (commands are run from the joint repo root)
- `WORKBOOK.md`: `.\reset-lab.ps1` -> `.\module2-aihub\reset-lab.ps1` (commands are run from the joint repo root)
- `WORKBOOK.md`: `python src/Python/mcp_smoke.py` -> `python module2-aihub/src/Python/mcp_smoke.py` (commands are run from the joint repo root)
- `.vscode/mcp.json`: `aihub-iris` -> `aiworkshop-iris` (the joint container is called aiworkshop-iris)
- `docs/SETUP-local.md`: `aihub-iris` -> `aiworkshop-iris` (the joint container is called aiworkshop-iris)
- `docs/TROUBLESHOOTING.md`: `aihub-iris` -> `aiworkshop-iris` (the joint container is called aiworkshop-iris)
- `docs/TROUBLESHOOTING.md`: `./reset-lab.sh` -> `./module2-aihub/reset-lab.sh` (commands are run from the joint repo root)
- `docs/TROUBLESHOOTING.md`: `python src/Python/mcp_smoke.py` -> `python module2-aihub/src/Python/mcp_smoke.py` (commands are run from the joint repo root)
- `README.md`: the instructor comment of docs/README-student.md
- `README.md`: one joint environment on the laptop; no cloud setup
- `README.md`: commands run from the repository root
- `README.md`: the joint image replaces the tarball
- `README.md`: .env lives in the repository root; recreate so the container reads the key
- `README.md`: no cloud setup
- `README.md`: joint: -v wipes all modules
- `docs/SETUP-local.md`: steps 1-3 are the joint prework
- `docs/SETUP-local.md`: no docker load in the joint environment
- `docs/SETUP-local.md`: no local build in the joint environment
- `docs/SETUP-local.md`: .env lives in the repository root
- `docs/SETUP-local.md`: the module's .vscode is in module2-aihub
- `docs/SETUP-local.md`: joint: -v wipes all modules
- `docs/TROUBLESHOOTING.md`: joint: -Hard wipes all modules
- `docs/TROUBLESHOOTING.md`: the joint compose.yaml sets the ports (no PORT_* in .env)
- `docs/TROUBLESHOOTING.md`: joint: -v wipes all modules
- `WORKBOOK.md`: commands run from the repository root
- `WORKBOOK.md`: joint: -Hard wipes all modules
- `WORKBOOK.md`: joint: -v wipes all modules
- `reset-lab.ps1`: compose.yaml is in the repository root
- `reset-lab.ps1`: .env is in the repository root
- `reset-lab.ps1`: src/ is now module2-aihub/src/
- `reset-lab.ps1`: joint: -Hard wipes all modules
- `reset-lab.ps1`: no local build in the joint environment
- `reset-lab.sh`: compose.yaml is in the repository root
- `reset-lab.sh`: .env is in the repository root
- `reset-lab.sh`: src/ is now module2-aihub/src/
- `reset-lab.sh`: joint: -Hard wipes all modules
- `reset-lab.sh`: no local build in the joint environment
- `reset-lab.ps1`: the volume-vs-image freshness check uses the container's image, not `aihub-workshop:latest`
- `reset-lab.sh`: the volume-vs-image freshness check uses the container's image, not `aihub-workshop:latest`
- `.env.example` (moved to the repository root, where compose.yaml reads `.env`): dropped the BASE_IMAGE and host-port sections (COMPOSE_PROJECT_NAME / CONTAINER_NAME / PORT_*) - the joint compose.yaml does not read them

Open for Tani: `reset-lab -Hard` / `docker compose down -v` now wipes all three modules (only a warning was added; behaviour unchanged). `src/Workshop/Lab.cls` and `Verify.cls` still mention `docker compose build` / APPENDIX-webgateway.md in messages (left as is: they must match the classes in the image).

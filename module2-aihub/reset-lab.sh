#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# Move the lab between exercise states.
#
#   ./module2-aihub/reset-lab.sh                back to the student start, in place (fast)
#   ./module2-aihub/reset-lab.sh --hard         destroy the volume and restore from the image
#                                 (In the joint workshop environment this deletes the work of ALL THREE modules, not only module 2.)
#   ./module2-aihub/reset-lab.sh --status       report where the lab currently is
#   ./module2-aihub/reset-lab.sh --solve C.3     load every solution up to and including C.3
#   ./module2-aihub/reset-lab.sh --solve-all    load all six solutions
#
# Add --container NAME or --namespace NS if you have changed either (several
# students sharing one machine set COMPOSE_PROJECT_NAME, which renames the
# container).
#
# WHY --hard EXISTS, AND WHY IT IS NOT THE DEFAULT
#
# There are two independent copies of the exercise state:
#
#   1. ./src/Workshop/**  on this machine, bind-mounted into the container.
#      This is what you edit, and what a coding assistant reads.
#   2. The compiled classes in the IRISAPP namespace, which live in the
#      iris-durable volume — the Durable %SYS instance, mounted at /durable.
#
# Workshop.Lab only ever loads into (2). It never writes to (1). So the
# default --soft reset returns IRIS to the start state while leaving your own
# edits on disk intact, which is almost always what you want mid-session.
#
# `docker compose up` is NOT a reset: the named volume survives `down`, so a
# solved namespace stays solved. Verified. --hard deletes the volume; IRIS then
# builds a fresh durable instance from the one baked into the image at build
# time, so you get a pristine instance WITHOUT a rebuild. Measured at about 12
# seconds to healthy.
# ---------------------------------------------------------------------------

set -euo pipefail

MODE="soft"
TARGET=""

# Pick CONTAINER_NAME out of .env if it is set there, so students sharing one
# VM do not have to pass --container on every call. Read with grep rather than
# sourced: .env holds an API key, and sourcing it would also execute anything
# else that happens to be in the file.
env_container() {
    local f="$(dirname "$0")/../.env"
    [ -f "$f" ] || return 0
    sed -n 's/^[[:space:]]*CONTAINER_NAME[[:space:]]*=[[:space:]]*//p' "$f" \
        | tail -1 | tr -d '"'"'"'\r' | tr -d ' '
}

CONTAINER="${CONTAINER:-$(env_container)}"
CONTAINER="${CONTAINER:-aiworkshop-iris}"
# Joint workshop: the image is the one the container runs (not aihub-workshop:latest).
WORKSHOP_IMAGE="$(docker inspect -f '{{.Config.Image}}' "$CONTAINER" 2>/dev/null || echo ghcr.io/ari-glikman/ai-workshop-day)"
NAMESPACE="${NAMESPACE:-IRISAPP}"

while [ $# -gt 0 ]; do
    case "$1" in
        --hard)      MODE="hard" ;;
        --soft)      MODE="soft" ;;
        --status)    MODE="status" ;;
        --solve)     MODE="solve"; shift; TARGET="${1:-}" ;;
        --solve-all) MODE="solveall" ;;
        --container) shift; CONTAINER="${1:-}" ;;
        --namespace) shift; NAMESPACE="${1:-}" ;;
        -h|--help)   sed -n '2,30p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *)           echo "unknown option: $1  (try --help)" >&2; exit 2 ;;
    esac
    shift
done

# Joint workshop: compose.yaml and .env are in the repository root, one folder up.
cd "$(dirname "$0")/.."

# Run ObjectScript in the container. Piped in rather than passed as arguments:
# `iris session` takes one command per line, and MSYS on Windows rewrites
# anything that looks like a path in an argument.
run_os() {
    MSYS_NO_PATHCONV=1 docker exec -i "$CONTAINER" iris session IRIS -U "$NAMESPACE"
}

require_running() {
    if ! docker inspect "$CONTAINER" >/dev/null 2>&1; then
        echo "The container '$CONTAINER' does not exist. Start it:  docker compose up -d" >&2
        exit 1
    fi
    if [ "$(docker inspect -f '{{.State.Running}}' "$CONTAINER")" != "true" ]; then
        echo "The container '$CONTAINER' is not running. Start it:  docker compose up -d" >&2
        exit 1
    fi
}

wait_healthy() {
    printf 'waiting for %s to report healthy' "$CONTAINER"
    for _ in $(seq 1 30); do
        if [ "$(docker inspect -f '{{.State.Health.Status}}' "$CONTAINER" 2>/dev/null)" = "healthy" ]; then
            printf ' ok\n'
            return 0
        fi
        printf '.'
        sleep 4
    done
    printf '\n'
    echo "Still not healthy after two minutes. Read the log:  docker compose logs -f iris" >&2
    exit 1
}

# Warn, but do not block, if the editor copy differs from what is committed.
# A dirty src/ is normal while you are working; it matters here only because
# the container is about to go back to the start state and the two will then
# disagree.
check_src_clean() {
    if git rev-parse --git-dir >/dev/null 2>&1; then
        if [ -n "$(git status --porcelain -- module2-aihub/src/ 2>/dev/null)" ]; then
            echo
            echo "NOTE: ./src has uncommitted changes. They are NOT touched by this reset,"
            echo "      so your editor will show your work while IRIS shows the starter code."
            echo "      To make them agree, either compile your edits:"
            echo "        do ##class(Workshop.Setup.Build).CompileWorkshop()"
            echo "      or discard them:  git checkout -- module2-aihub/src/"
            echo
        fi
    fi
}

# The starter code AND the solutions are baked into the IMAGE, at
# /opt/workshop/starters/ and /opt/workshop/solutions/. --hard restores the
# image as it was last built, so editing src/ or instructor/ and then running
# --hard gives you the OLD code back. This cost an afternoon once: a patched
# B1 solution was invisible to Lab.Solve() because the image predated it.
check_image_fresh() {
    local created img_epoch newer
    created="$(docker image inspect "$WORKSHOP_IMAGE" --format '{{.Created}}' 2>/dev/null)" || return 0
    [ -n "$created" ] || return 0
    img_epoch="$(date -d "$created" +%s 2>/dev/null)" || return 0
    # Exclude logs: IRIS writes src/iris-main.log into the bind mount.
    newer="$(find src instructor -type f -newermt "@$img_epoch" -not -name '*.log' 2>/dev/null | head -4)"
    if [ -n "$newer" ]; then
        echo
        echo "NOTE: these files are newer than the image, so --hard will NOT include them:"
        printf '%s
' "$newer" | sed 's/^/    /'
        echo "      (Joint workshop: the image is pulled, not built - this only matters to the instructor.)"
        echo
    fi
}

# THE VOLUME CAN BE OLDER THAN THE IMAGE, and when it is, everything looks
# fine and behaves as though your changes never happened.
#
# /durable holds the Durable %SYS instance. IRIS populates it on the FIRST
# start and never again, so once it exists it is never refreshed from a newer
# image: `docker compose up` on an old volume runs the OLD compiled classes
# against your NEW files. The symptom is Workshop.Lab listing an exercise set
# you have already changed, or a class behaving as it did two rebuilds ago.
# (This was the same trap when the mount was /usr/irissys/mgr; Durable %SYS
# changes which process does the copying, not the staleness.)
#
# This has caught us three times, so it is checked on every invocation.
check_volume_fresh() {
    local vol img_epoch vol_epoch
    vol="$(docker inspect "$CONTAINER"             --format '{{range .Mounts}}{{if eq .Destination "/durable"}}{{.Name}}{{end}}{{end}}'             2>/dev/null)" || return 0
    [ -n "$vol" ] || return 0
    img_epoch="$(date -d "$(docker image inspect "$WORKSHOP_IMAGE" --format '{{.Created}}' 2>/dev/null)" +%s 2>/dev/null)" || return 0
    vol_epoch="$(date -d "$(docker volume inspect "$vol" --format '{{.CreatedAt}}' 2>/dev/null)" +%s 2>/dev/null)" || return 0
    [ -n "$img_epoch" ] && [ -n "$vol_epoch" ] || return 0
    if [ "$vol_epoch" -lt "$img_epoch" ]; then
        echo
        echo "WARNING: the database volume predates the image."
        echo "    volume $vol  $(date -d "@$vol_epoch" '+%Y-%m-%d %H:%M')"
        echo "    image  "$WORKSHOP_IMAGE"  $(date -d "@$img_epoch" '+%Y-%m-%d %H:%M')"
        echo "  Docker only seeds a named volume when it is empty, so this container is"
        echo "  running the compiled classes from the older image. Anything you changed"
        echo "  and rebuilt since then is NOT in here."
        echo "  Fix:  ./module2-aihub/reset-lab.sh --hard        (destroys the volume, reseeds from the image)"
        echo
    fi
}

case "$MODE" in

status)
    require_running
    check_volume_fresh
    printf 'zn "%s"\ndo ##class(Workshop.Lab).Status()\nhalt\n' "$NAMESPACE" | run_os
    ;;

soft)
    require_running
    check_volume_fresh
    check_src_clean
    echo "Resetting the namespace to the student start state (src/ untouched)..."
    printf 'zn "%s"\ndo ##class(Workshop.Lab).Reset()\nhalt\n' "$NAMESPACE" | run_os
    ;;

hard)
    check_src_clean
    check_image_fresh
    echo "Destroying the volume and restoring the start state from the image."
    echo "Anything you saved only inside IRIS will be lost. ./src is not touched."
    echo 'WARNING: In the joint workshop environment this deletes the work of ALL THREE modules, not only module 2.'
    docker compose down -v
    docker compose up -d
    wait_healthy
    printf 'do ##class(Workshop.Verify).Run()\ndo ##class(Workshop.Lab).Status()\nhalt\n' | run_os
    ;;

solve)
    require_running
    check_volume_fresh
    if [ -z "$TARGET" ]; then
        echo "--solve needs an exercise id, e.g. --solve C.3" >&2
        exit 2
    fi
    printf 'zn "%s"\ndo ##class(Workshop.Lab).SolveThrough("%s")\nhalt\n' "$NAMESPACE" "$TARGET" | run_os
    ;;

solveall)
    require_running
    check_volume_fresh
    printf 'zn "%s"\ndo ##class(Workshop.Lab).SolveAll()\nhalt\n' "$NAMESPACE" | run_os
    ;;

esac

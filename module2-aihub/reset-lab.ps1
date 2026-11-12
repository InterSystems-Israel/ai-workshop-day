<#
    Move the lab between exercise states. PowerShell twin of reset-lab.sh.

      .\module2-aihub\reset-lab.ps1                back to the student start, in place (fast)
      .\module2-aihub\reset-lab.ps1 -Hard          destroy the volume and restore from the image
                                     (In the joint workshop environment this deletes the work of ALL THREE modules, not only module 2.)
      .\module2-aihub\reset-lab.ps1 -Status        report where the lab currently is
      .\module2-aihub\reset-lab.ps1 -Solve C4      load every solution up to and including C.3
      .\module2-aihub\reset-lab.ps1 -SolveAll      load all six solutions

    WHY -Hard EXISTS, AND WHY IT IS NOT THE DEFAULT

    There are two independent copies of the exercise state:

      1. .\src\Workshop\**  on this machine, bind-mounted into the container.
         This is what you edit, and what a coding assistant reads.
      2. The compiled classes in the IRISAPP namespace, which live in the
         iris-durable volume - the Durable %SYS instance, mounted at /durable.

    Workshop.Lab only ever loads into (2). It never writes to (1). So the
    default reset returns IRIS to the start state while leaving your own edits
    on disk intact, which is almost always what you want mid-session.

    `docker compose up` is NOT a reset: the named volume survives `down`, so a
    solved namespace stays solved. Verified. -Hard deletes the volume; Docker
    then repopulates it from the databases baked into the image at build time,
    so you get a pristine instance WITHOUT a rebuild, in about 20 seconds.
#>

[CmdletBinding(DefaultParameterSetName = 'Soft')]
param(
    [Parameter(ParameterSetName = 'Hard')]     [switch] $Hard,
    [Parameter(ParameterSetName = 'Status')]   [switch] $Status,
    [Parameter(ParameterSetName = 'Solve')]    [string] $Solve,
    [Parameter(ParameterSetName = 'SolveAll')] [switch] $SolveAll,
    [string] $Container,
    [string] $Namespace = 'IRISAPP'
)

$ErrorActionPreference = 'Stop'
# Joint workshop: compose.yaml and .env are in the repository root, one folder up.
Set-Location -Path (Split-Path -Parent $PSScriptRoot)

# Pick CONTAINER_NAME out of .env if it is set there, so students sharing one
# VM do not have to pass -Container on every call. Parsed, not dot-sourced:
# .env holds an API key and is not PowerShell.
if (-not $Container) {
    $envFile = Join-Path (Split-Path -Parent $PSScriptRoot) '.env'
    if (Test-Path $envFile) {
        $match = Select-String -Path $envFile -Pattern '^\s*CONTAINER_NAME\s*=\s*(.+)$' |
                 Select-Object -Last 1
        if ($match) {
            $Container = $match.Matches[0].Groups[1].Value.Trim().Trim('"').Trim("'")
        }
    }
}
if (-not $Container) { $Container = 'aiworkshop-iris' }
# Joint workshop: the image is the one the container runs (not aihub-workshop:latest).
$WorkshopImage = (& docker inspect -f '{{.Config.Image}}' $Container 2>$null)
if (-not $WorkshopImage) { $WorkshopImage = 'ghcr.io/intersystems-israel/ai-workshop-day' }

# Report our own problems as one readable line and a non-zero exit code,
# rather than a PowerShell error record wrapped around a docker message.
function Stop-WithMessage {
    param([string] $Message)
    Write-Host ''
    Write-Host $Message -ForegroundColor Red
    exit 1
}

# Native commands must not be run under ErrorActionPreference = 'Stop':
# anything docker writes to stderr becomes a NativeCommandError, which both
# hides our own diagnostics and leaves the exit code at 0. So run docker with
# the preference relaxed and inspect $LASTEXITCODE explicitly.
function Invoke-Docker {
    param([Parameter(ValueFromRemainingArguments)] [string[]] $DockerArgs)
    $previous = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $output = & docker @DockerArgs 2>&1
        return [pscustomobject]@{
            Output   = ($output | Out-String).Trim()
            ExitCode = $LASTEXITCODE
        }
    } finally {
        $ErrorActionPreference = $previous
    }
}

# Pipe ObjectScript in rather than passing it as arguments: `iris session`
# reads one command per line.
function Invoke-ObjectScript {
    param([string[]] $Lines)
    $previous = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        ($Lines + 'halt') -join "`n" |
            docker exec -i $Container iris session IRIS -U $Namespace
    } finally {
        $ErrorActionPreference = $previous
    }
}

function Assert-Running {
    if ((Invoke-Docker inspect $Container).ExitCode -ne 0) {
        Stop-WithMessage "The container '$Container' does not exist. Start it:  docker compose up -d"
    }
    if ((Invoke-Docker inspect -f '{{.State.Running}}' $Container).Output -ne 'true') {
        Stop-WithMessage "The container '$Container' is not running. Start it:  docker compose up -d"
    }
}

function Wait-Healthy {
    Write-Host "waiting for $Container to report healthy" -NoNewline
    foreach ($i in 1..30) {
        if ((Invoke-Docker inspect -f '{{.State.Health.Status}}' $Container).Output -eq 'healthy') {
            Write-Host ' ok'
            return
        }
        Write-Host '.' -NoNewline
        Start-Sleep -Seconds 4
    }
    Write-Host ''
    Stop-WithMessage 'Still not healthy after two minutes. Read the log:  docker compose logs -f iris'
}

# Warn, but do not block, if the editor copy differs from what is committed.
function Test-SrcClean {
    $previous = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        & git rev-parse --git-dir 2>&1 | Out-Null
        if ($LASTEXITCODE -ne 0) { return }
        $dirty = & git status --porcelain -- module2-aihub/src/ 2>&1
    } finally {
        $ErrorActionPreference = $previous
    }
    if ($dirty) {
        Write-Host ''
        Write-Host 'NOTE: .\src has uncommitted changes. They are NOT touched by this reset,'
        Write-Host '      so your editor will show your work while IRIS shows the starter code.'
        Write-Host '      To make them agree, either compile your edits:'
        Write-Host '        do ##class(Workshop.Setup.Build).CompileWorkshop()'
        Write-Host '      or discard them:  git checkout -- module2-aihub/src/'
        Write-Host ''
    }
}

# The starter code and the solutions live in the IMAGE, so --hard/-Hard
# restores the image as last built. Editing src/ or instructor/ and then
# running -Hard gives the old code back.
function Test-ImageFresh {
    $created = (Invoke-Docker image inspect $WorkshopImage --format '{{.Created}}').Output
    if (-not $created) { return }
    try { $imgTime = [datetime]::Parse($created) } catch { return }
    $newer = Get-ChildItem -Path src, instructor -Recurse -File -ErrorAction SilentlyContinue |
             Where-Object { $_.LastWriteTime -gt $imgTime -and $_.Extension -ne '.log' } |
             Select-Object -First 4
    if ($newer) {
        Write-Host ''
        Write-Host 'NOTE: these files are newer than the image, so -Hard will NOT include them:'
        $newer | ForEach-Object { Write-Host ('    ' + $_.FullName) }
        Write-Host "      (Joint workshop: the image is pulled, not built - this only matters to the instructor.)"
        Write-Host ''
    }
}

# The volume can be OLDER than the image, and when it is, everything looks
# fine and behaves as though your changes never happened. Docker seeds a named
# instance only on the FIRST start, so an existing volume
# keeps running the old compiled classes against your new files.
function Test-VolumeFresh {
    # Deliberately no quotes inside the Go template: passing a --format
    # containing double quotes through PowerShell to a native command mangles
    # them, and the call then silently returns nothing. List the mounts and
    # match in PowerShell instead.
    $mounts = (Invoke-Docker inspect $Container --format '{{range .Mounts}}{{.Destination}}={{.Name}};{{end}}').Output
    $vol = $null
    foreach ($entry in ($mounts -split ';')) {
        if ($entry -like '/durable=*') { $vol = $entry.Split('=')[1] }
    }
    if (-not $vol) { return }
    $imgRaw = (Invoke-Docker image inspect $WorkshopImage --format '{{.Created}}').Output
    $volRaw = (Invoke-Docker volume inspect $vol --format '{{.CreatedAt}}').Output
    if (-not $imgRaw -or -not $volRaw) { return }
    try { $img = [datetime]::Parse($imgRaw); $v = [datetime]::Parse($volRaw) } catch { return }
    if ($v -lt $img) {
        Write-Host ''
        Write-Host 'WARNING: the database volume predates the image.' -ForegroundColor Yellow
        Write-Host ("    volume {0}  {1:yyyy-MM-dd HH:mm}" -f $vol, $v)
        Write-Host ("    image  $WorkshopImage  {0:yyyy-MM-dd HH:mm}" -f $img)
        Write-Host '  Docker only seeds a named volume when it is empty, so this container is'
        Write-Host '  running the compiled classes from the older image. Anything you changed'
        Write-Host '  and rebuilt since then is NOT in here.'
        Write-Host '  Fix:  .\module2-aihub\reset-lab.ps1 -Hard     (destroys the volume, reseeds from the image)'
        Write-Host ''
    }
}

switch ($PSCmdlet.ParameterSetName) {

    'Status' {
        Assert-Running
        Test-VolumeFresh
        Invoke-ObjectScript @("zn ""$Namespace""", 'do ##class(Workshop.Lab).Status()')
    }

    'Soft' {
        Assert-Running
        Test-VolumeFresh
        Test-SrcClean
        Write-Host 'Resetting the namespace to the student start state (src/ untouched)...'
        Invoke-ObjectScript @("zn ""$Namespace""", 'do ##class(Workshop.Lab).Reset()')
    }

    'Hard' {
        Test-SrcClean
        Test-ImageFresh
        Write-Host 'Destroying the volume and restoring the start state from the image.'
        Write-Host 'Anything you saved only inside IRIS will be lost. .\src is not touched.'
        Write-Host 'WARNING: In the joint workshop environment this deletes the work of ALL THREE modules, not only module 2.' -ForegroundColor Yellow
        $down = Invoke-Docker compose down -v
        Write-Host $down.Output
        if ($down.ExitCode -ne 0) { Stop-WithMessage 'docker compose down -v failed' }
        $up = Invoke-Docker compose up -d
        Write-Host $up.Output
        if ($up.ExitCode -ne 0) { Stop-WithMessage 'docker compose up -d failed' }
        Wait-Healthy
        Invoke-ObjectScript @('do ##class(Workshop.Verify).Run()',
                              'do ##class(Workshop.Lab).Status()')
    }

    'Solve' {
        Assert-Running
        Test-VolumeFresh
        Invoke-ObjectScript @("zn ""$Namespace""",
                              "do ##class(Workshop.Lab).SolveThrough(""$Solve"")")
    }

    'SolveAll' {
        Assert-Running
        Test-VolumeFresh
        Invoke-ObjectScript @("zn ""$Namespace""", 'do ##class(Workshop.Lab).SolveAll()')
    }
}

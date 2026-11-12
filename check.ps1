# AI workshop day - readiness check. Run once after "git clone", before the workshop day:
#     powershell -ExecutionPolicy Bypass -File .\check.ps1
# Checks your laptop (Docker, git, VS Code extensions, ports, your module 1 prework), starts the ONE workshop container
# all three modules use, then checks IRIS, the namespaces of the three modules, the notebook kernel and the internet
# connections the exercises need. Ends with READY or what to fix. It installs nothing and changes nothing on your laptop.
# The container keeps running afterwards; stop it with: docker compose down
$ErrorActionPreference = "Continue"
Set-Location $PSScriptRoot
$script:problems = @()

function Ok([string]$what) { Write-Host "OK   $what" -ForegroundColor Green }
function Fail([string]$what, [string]$fix) { Write-Host "FAIL $what - $fix" -ForegroundColor Red; $script:problems += "$what - $fix" }
function Warn([string]$what) { Write-Host "WARN $what" -ForegroundColor Yellow }
function Have([string]$cmd) { [bool](Get-Command $cmd -ErrorAction SilentlyContinue) }

Write-Host "== Your laptop" -ForegroundColor Cyan
$here = (Get-Location).Path
if ($here -match "(?i)onedrive|dropbox|icloud") { Fail "folder $here" "clone the workshop to a plain local folder (for example C:\workshop), not OneDrive/Dropbox/iCloud" }
if (Have git) { Ok "git $((git --version) -replace 'git version ', '')" } else { Fail "git" "install Git for Windows (https://git-scm.com)" }

$dockerOk = $false
if (-not (Have docker)) {
    Fail "Docker" "install Docker Desktop (https://www.docker.com/products/docker-desktop)"
} else {
    $info = docker info --format "{{.OSType}}|{{.MemTotal}}|{{.NCPU}}" 2>$null
    if ($LASTEXITCODE -ne 0 -or -not $info) {
        Fail "Docker" "Docker Desktop is not running - start it, wait until it says 'Engine running', run check.ps1 again"
    } else {
        $os, $mem, $cpu = $info -split "\|"
        $gb = [math]::Round([double]$mem / 1GB, 1)
        if ($os -ne "linux") { Fail "Docker" "switch Docker Desktop to Linux containers" }
        elseif ($gb -lt 7) { Fail "Docker memory ($gb GB)" "give Docker at least 8 GB (Docker Desktop > Settings > Resources, or .wslconfig)" }
        else { Ok "Docker running (Linux containers, $gb GB memory, $cpu CPUs)"; $dockerOk = $true }
    }
}

if (Have code) {
    $ext = (code --list-extensions 2>$null) -join " "
    if ($ext -match "(?i)intersystems-community\.vscode-objectscript") { Ok "VS Code: InterSystems ObjectScript extension" }
    else { Fail "VS Code: InterSystems ObjectScript extension" "install the 'InterSystems ObjectScript Extension Pack' in VS Code" }
    if ($ext -match "(?i)ms-toolsai\.jupyter") { Ok "VS Code: Jupyter extension" }
    else { Fail "VS Code: Jupyter extension" "install the 'Jupyter' extension (Microsoft) in VS Code" }
    if ($ext -match "(?i)openai\.chatgpt") { Ok "VS Code: OpenAI Codex extension (module 1)" }
    else { Warn "VS Code: the OpenAI Codex extension was not found - module 1 needs it (see module1-agentic, Part 1)" }
} else {
    Warn "VS Code: 'code' is not on the PATH, so the extensions could not be checked - make sure VS Code has the 'InterSystems ObjectScript Extension Pack', 'Jupyter' and 'OpenAI Codex'"
}
# Module 1 prework (you do it yourself, README step 2): iris-agentic-dev.exe in C:\Tools, C:\Tools on the PATH.
if (Have iris-agentic-dev) { Ok "iris-agentic-dev $((iris-agentic-dev --version 2>$null) -join ' ') (module 1)" }
else { Warn "iris-agentic-dev is not on the PATH - do the module 1 prework (download it to C:\Tools and add C:\Tools to the PATH - README step 2), then open a NEW PowerShell" }

if ($dockerOk) {
    $haveImage = [bool](docker images -q (Select-String -Path compose.yaml -Pattern 'image:\s*\$\{IMAGE:-(.+)\}' | ForEach-Object { $_.Matches[0].Groups[1].Value }) 2>$null)
    $freeGb = [math]::Round((Get-PSDrive C).Free / 1GB)
    if (-not $haveImage -and $freeGb -lt 40) { Fail "disk space ($freeGb GB free on C:)" "the workshop image needs about 40 GB free - make room and run check.ps1 again" }
}

if ($dockerOk) {
    $ours = (docker ps --filter "name=^aiworkshop-iris$" --format "{{.Names}}" 2>$null)
    foreach ($port in 42773, 48888, 41972, 48080) {
        $busy = Get-NetTCPConnection -LocalPort $port -State Listen -ErrorAction SilentlyContinue
        if ($busy -and -not $ours) { Fail "port $port" "another program uses it - close it (or ask the instructor)" }
    }

    Write-Host "== The workshop container (the first time this downloads the image, several GB - be patient)" -ForegroundColor Cyan
    $up = docker compose up -d 2>&1 | ForEach-Object { "$_" }
    $up | ForEach-Object { Write-Host $_ }
    if ($LASTEXITCODE -ne 0) {
        if (($up -join " ") -match "(?i)denied|unauthorized|403") {
            Fail "downloading the workshop image" "the image ghcr.io/intersystems-israel/ai-workshop-day could not be downloaded - if you are logged in to ghcr.io with an old token, run  docker logout ghcr.io  and run check.ps1 again; otherwise check VPN/proxy/firewall"
        } else {
            Fail "docker compose up -d" "see the message above"
        }
    } else {
        $healthy = $false
        for ($i = 0; $i -lt 60; $i++) {
            if ((docker inspect -f "{{.State.Health.Status}}" aiworkshop-iris 2>$null) -eq "healthy") { $healthy = $true; break }
            Start-Sleep -Seconds 5
        }
        if (-not $healthy) {
            Fail "container" "not healthy after 5 minutes - run 'docker compose logs iris' and show it to the instructor"
        } else {
            Ok "container aiworkshop-iris is healthy"
            try { $null = Invoke-WebRequest "http://127.0.0.1:42773/csp/sys/UtilHome.csp" -UseBasicParsing -TimeoutSec 15; Ok "Management Portal http://127.0.0.1:42773" }
            catch { Fail "Management Portal" "http://127.0.0.1:42773 does not answer ($($_.Exception.Message))" }
            try { $null = Invoke-WebRequest "http://127.0.0.1:48888/api/status?token=workshop" -UseBasicParsing -TimeoutSec 15; Ok "Jupyter server http://127.0.0.1:48888" }
            catch { Fail "Jupyter server" "http://127.0.0.1:48888 does not answer ($($_.Exception.Message))" }

            try { $null = Invoke-WebRequest "http://127.0.0.1:42773/iris/ai/frontend/index.html" -UseBasicParsing -TimeoutSec 15; Ok "Agentic Integration Builder http://127.0.0.1:42773/iris/ai/frontend/index.html (module 1)" }
            catch { Fail "Agentic Integration Builder" "http://127.0.0.1:42773/iris/ai/frontend/index.html does not answer ($($_.Exception.Message))" }

            Write-Host "== Inside the container" -ForegroundColor Cyan
            $ns = ('for n="USER","AI","IRISAPP","VECTOR" { write "NS ",n," ",##class(%SYS.Namespace).Exists(n),! }' + "`nhalt`n") | docker exec -i aiworkshop-iris iris session IRIS -U %SYS 2>$null | Out-String
            foreach ($n in @(@("USER", "module 1"), @("AI", "module 1"), @("IRISAPP", "module 2"), @("VECTOR", "module 3"))) {
                if ($ns -match "NS $($n[0]) 1") { Ok "namespace $($n[0]) ($($n[1]))" } else { Fail "namespace $($n[0]) ($($n[1]))" "missing - run 'docker compose down -v', then check.ps1 again" }
            }
            docker exec -e IRISNAMESPACE=VECTOR aiworkshop-iris /usr/irissys/bin/irispython /workshop/setup/selfcheck.py 2>$null | ForEach-Object {
                if ($_ -match "^OK ") { Write-Host $_ -ForegroundColor Green }
                else { Write-Host $_ -ForegroundColor Red; $script:problems += ($_ -replace "^FAIL ", "") }
            }
            if ($LASTEXITCODE -ne 0 -and $script:problems.Count -eq 0) { $script:problems += "the check inside the container failed" }
        }
    }
}

Write-Host ""
if ($script:problems.Count -eq 0) {
    Write-Host "READY - everything works. See you at the workshop! (Stop the container for now with: docker compose down)" -ForegroundColor Green
    exit 0
}
Write-Host "NOT READY - fix these, then run check.ps1 again:" -ForegroundColor Red
$script:problems | ForEach-Object { Write-Host "  - $_" -ForegroundColor Red }
exit 1

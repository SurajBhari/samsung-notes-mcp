# ──────────────────────────────────────────────────────────────
# Samsung Notes x Claude — one-click installer
# (install.bat runs this file)
# ──────────────────────────────────────────────────────────────
$ErrorActionPreference = "Stop"
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$serverPy = Join-Path $here "server.py"
$venv = Join-Path $here ".venv"
$venvPy = Join-Path $venv "Scripts\python.exe"

function Step($msg)  { Write-Host ""; Write-Host "> $msg" -ForegroundColor Cyan }
function Ok($msg)    { Write-Host "  [OK] $msg" -ForegroundColor Green }
function Fail($msg)  { Write-Host ""; Write-Host "[FAILED] $msg" -ForegroundColor Red }

Write-Host "=============================================" -ForegroundColor Yellow
Write-Host "   Samsung Notes x Claude — setup"             -ForegroundColor Yellow
Write-Host "=============================================" -ForegroundColor Yellow

# ── 1. Samsung Notes app ─────────────────────────────────────
Step "Checking for the Samsung Notes Windows app"
$pkg = Get-ChildItem "$env:LOCALAPPDATA\Packages" -Directory -Filter "SAMSUNGELECTRONICSCoLtd.SamsungNotes_*" -ErrorAction SilentlyContinue | Select-Object -First 1
if (-not $pkg) {
    Fail "Samsung Notes is not installed."
    Write-Host "   1) Install 'Samsung Notes' from the Microsoft Store"
    Write-Host "   2) Open it, sign in with your Samsung account, and check your notes appear"
    Write-Host "   3) Run this installer again"
    exit 1
}
$db = Join-Path $pkg.FullName "LocalState\Storage.sqlite"
if (-not (Test-Path $db)) {
    Fail "Samsung Notes is installed but has no note data yet."
    Write-Host "   Open Samsung Notes, sign in and let it sync, then run this again."
    exit 1
}
Ok "Samsung Notes data found"

# ── 2. Python (install if missing) ───────────────────────────
Step "Checking for Python 3.10+"
$python = $null
foreach ($cand in @("python", "py")) {
    $cmd = Get-Command $cand -ErrorAction SilentlyContinue
    if ($cmd) {
        try {
            $v = & $cmd.Source --version 2>$null
            if ($v -match "Python 3\.(\d+)") {
                if ([int]$Matches[1] -ge 10) { $python = $cmd.Source; break }
            }
        } catch {}
    }
}
if (-not $python) {
    Write-Host "  Python not found — installing it (1-2 minutes)..."
    $winget = "$env:LOCALAPPDATA\Microsoft\WindowsApps\winget.exe"
    if (-not (Test-Path $winget)) { $winget = "winget" }
    & $winget install --id Python.Python.3.12 --silent --accept-package-agreements --accept-source-agreements
    Write-Host ""
    Write-Host "  Python is installed." -ForegroundColor Yellow
    Write-Host "  Close this window and run install.bat once more (so the new PATH is picked up)." -ForegroundColor Yellow
    exit 0
}
Ok "Python found: $python"

# ── 3. Private environment + packages ────────────────────────
# A project-local venv keeps this server's packages separate from your
# global Python. mcp is pinned below 2.0: server.py uses the v1 FastMCP API,
# which mcp 2.x renamed. av reads voice-recording durations; pymupdf turns
# rendered pages into images.
Step "Installing required packages (mcp<2, pillow, av, pymupdf) into .venv"
if (-not (Test-Path $venvPy)) { & $python -m venv $venv }
& $venvPy -m pip install --quiet --upgrade "mcp[cli]<2" pillow av pymupdf
Ok "Packages installed"

# ── 3b. Handwriting renderer (optional, needs Node.js) ──────
# Draws every page's pen strokes from the note files (sdocx, GPL-3.0, run as
# a separate program). Without it only pages the Samsung Notes app has
# cached can be viewed.
Step "Installing the handwriting page renderer (Node.js)"
$npm = Get-Command npm -ErrorAction SilentlyContinue
if ($npm) {
    Push-Location (Join-Path $here "render")
    & $npm.Source install --silent --no-audit --no-fund
    Pop-Location
    Ok "Renderer installed"
} else {
    Write-Host "  Node.js not found — skipping. Install it (winget install OpenJS.NodeJS.LTS)" -ForegroundColor Yellow
    Write-Host "  and run install.bat again to read every handwritten page." -ForegroundColor Yellow
}

# ── 4. Self-test ─────────────────────────────────────────────
Step "Test: reading your notes"
$env:PYTHONIOENCODING = "utf-8"
$env:SN_HERE = $here
$test = & $venvPy -c "import sys, os, json; sys.path.insert(0, os.environ['SN_HERE']); import server; d = json.loads(server.samsung_notes_list_folders()); print(d['folder_count'])"
if ($LASTEXITCODE -ne 0) {
    Fail "Reading notes failed. Make sure Samsung Notes has finished syncing."
    exit 1
}
Ok "Found $test note folders — working!"

# ── 5. Register with Claude Desktop ──────────────────────────
Step "Registering with Claude Desktop"
if (Test-Path "$env:APPDATA\Claude") {
    $cfgPath = "$env:APPDATA\Claude\claude_desktop_config.json"
    if (Test-Path $cfgPath) { Copy-Item $cfgPath "$cfgPath.bak" -Force }
    $env:SN_SERVER = $serverPy
    $env:SN_PY = $venvPy
    & $venvPy -c @"
import json, os, pathlib
p = pathlib.Path(os.environ['APPDATA']) / 'Claude' / 'claude_desktop_config.json'
cfg = json.loads(p.read_text(encoding='utf-8')) if p.exists() else {}
cfg.setdefault('mcpServers', {})['samsung-notes'] = {
    'command': os.environ['SN_PY'], 'args': [os.environ['SN_SERVER']]}
p.parent.mkdir(parents=True, exist_ok=True)
p.write_text(json.dumps(cfg, ensure_ascii=False, indent=2), encoding='utf-8')
"@
    Ok "Registered with Claude Desktop (restart Claude Desktop). Old config backed up to claude_desktop_config.json.bak"
} else {
    Write-Host "  Claude Desktop not found — skipping. (https://claude.ai/download)"
}

# ── 6. Register with Claude Code ─────────────────────────────
Step "Registering with Claude Code"
$claudeCmd = Get-Command claude -ErrorAction SilentlyContinue
if ($claudeCmd) {
    # PowerShell passes arguments directly, so spaces in paths are safe
    try { & $claudeCmd.Source mcp remove --scope user samsung-notes *> $null } catch {}
    & $claudeCmd.Source mcp add --scope user samsung-notes -- $venvPy $serverPy
    if ($LASTEXITCODE -eq 0) {
        Ok "Registered with Claude Code (available from your next session)"
    } else {
        Write-Host "  Claude Code registration failed. Run this yourself:" -ForegroundColor Yellow
        Write-Host "    claude mcp add --scope user samsung-notes -- `"$venvPy`" `"$serverPy`""
    }
} else {
    Write-Host "  Claude Code not found — skipping."
}

# ── Done ─────────────────────────────────────────────────────
Write-Host ""
Write-Host "=============================================" -ForegroundColor Green
Write-Host "   Setup complete!"                             -ForegroundColor Green
Write-Host "=============================================" -ForegroundColor Green
Write-Host ""
Write-Host "Restart Claude Desktop, then try:"
Write-Host '   "Show my Samsung Notes folders"'
Write-Host '   "Search my Samsung Notes for quadratic equations"'
Write-Host '   "Show me the first page of the <name> note"  (handwriting is visible too)'
Write-Host ""
Write-Host "Note: if you move this folder, run install.bat again to re-register."

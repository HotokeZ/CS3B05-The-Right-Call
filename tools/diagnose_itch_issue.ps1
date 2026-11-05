# Diagnose and fix itch.io export issues

$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$ExportWebDir = Join-Path $RepoRoot "export\web"
$ExportPresetFile = Join-Path $RepoRoot "export_presets.cfg"
$ItchZipPath = Join-Path $RepoRoot "export\itch-web.zip"
$BetaZipPath = Join-Path $RepoRoot "itch upload temporary\Beta0.2.zip"

Write-Host "=== ITCH.IO EXPORT DIAGNOSTIC ===" -ForegroundColor Cyan
Write-Host ""

# Check 1: Verify export preset is set to Web
Write-Host "[1] Checking export_presets.cfg..." -ForegroundColor Yellow
if (Test-Path $ExportPresetFile) {
    $content = Get-Content $ExportPresetFile -Raw
    if ($content -match 'name="Web"') {
        Write-Host "✓ Web preset found" -ForegroundColor Green
    }
    else {
        Write-Host "✗ Web preset NOT found - export_presets.cfg may be misconfigured" -ForegroundColor Red
    }
    if ($content -match 'export_path="export/web/index.html"') {
        Write-Host "✓ Export path set to export/web/index.html" -ForegroundColor Green
    }
    else {
        Write-Host "⚠ Export path is not set to export/web/index.html" -ForegroundColor Yellow
        $match = [regex]::Match($content, 'export_path="([^"]+)"')
        if ($match.Success) {
            Write-Host "  Current path: $($match.Groups[1].Value)" -ForegroundColor Gray
        }
    }
}
else {
    Write-Host "✗ export_presets.cfg not found!" -ForegroundColor Red
}

Write-Host ""

# Check 2: Verify export/web folder status
Write-Host "[2] Checking export/web folder..." -ForegroundColor Yellow
if (Test-Path $ExportWebDir) {
    $files = Get-ChildItem $ExportWebDir -ErrorAction SilentlyContinue
    if ($files.Count -gt 0) {
        Write-Host "✓ export/web folder has files:" -ForegroundColor Green
        $files | ForEach-Object { Write-Host "  - $($_.Name)" -ForegroundColor Green }
        
        if (Test-Path (Join-Path $ExportWebDir "index.html")) {
            Write-Host "✓ index.html found at export/web/index.html" -ForegroundColor Green
        }
        else {
            Write-Host "✗ index.html NOT found - export may have failed" -ForegroundColor Red
        }
    }
    else {
        Write-Host "⚠ export/web folder is EMPTY - you must export from Godot first" -ForegroundColor Yellow
        Write-Host "  NEXT STEP: Open Godot Editor and export using Project → Export..." -ForegroundColor Cyan
    }
}
else {
    Write-Host "⚠ export/web folder does not exist" -ForegroundColor Yellow
    Write-Host "  NEXT STEP: Open Godot Editor and export using Project → Export..." -ForegroundColor Cyan
}

Write-Host ""

# Check 3: Verify current itch ZIP contents
Write-Host "[3] Checking existing itch ZIP files..." -ForegroundColor Yellow
if (Test-Path $BetaZipPath) {
    Write-Host "⚠ Found Beta0.2.zip in itch upload temporary/" -ForegroundColor Yellow
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $entries = [System.IO.Compression.ZipFile]::OpenRead($BetaZipPath).Entries
    if ($entries | Where-Object { $_.Name -eq "index.html" }) {
        Write-Host "✓ Beta0.2.zip contains index.html" -ForegroundColor Green
    }
    else {
        Write-Host "✗ Beta0.2.zip does NOT contain index.html (reason for itch error)" -ForegroundColor Red
        Write-Host "  This ZIP contains project files, not a Web export." -ForegroundColor Red
    }
}

if (Test-Path $ItchZipPath) {
    Write-Host "Found itch-web.zip - checking contents..." -ForegroundColor Yellow
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $entries = [System.IO.Compression.ZipFile]::OpenRead($ItchZipPath).Entries
    if ($entries | Where-Object { $_.FullName -eq "index.html" }) {
        Write-Host "✓ itch-web.zip is properly formatted for itch.io" -ForegroundColor Green
        Write-Host "  NEXT STEP: Upload itch-web.zip to itch.io" -ForegroundColor Cyan
    }
    else {
        Write-Host "✗ itch-web.zip exists but index.html is not at root" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "=== SUMMARY ===" -ForegroundColor Cyan
Write-Host "If export/web is empty:" -ForegroundColor Yellow
Write-Host "  1. Open Godot Editor" -ForegroundColor Gray
Write-Host "  2. Go to Project → Export..." -ForegroundColor Gray
Write-Host "  3. Select 'Web' preset" -ForegroundColor Gray
Write-Host "  4. Click 'Export Project'" -ForegroundColor Gray
Write-Host "  5. After export completes, come back and run:" -ForegroundColor Gray
Write-Host "     $BuildScript = Join-Path `$PSScriptRoot 'build_itch_web.ps1'" -ForegroundColor Gray
Write-Host ""

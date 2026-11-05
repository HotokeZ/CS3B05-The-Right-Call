$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$ExportWebDir = Join-Path $RepoRoot "export\web"
$BetaZipPath = Join-Path $RepoRoot "itch upload temporary\Beta0.2.zip"

Write-Host "=== ITCH EXPORT DIAGNOSTIC ===" -ForegroundColor Cyan

Write-Host "`n[1] Checking export/web folder..." -ForegroundColor Yellow
if (Test-Path $ExportWebDir) {
    $files = Get-ChildItem $ExportWebDir -ErrorAction SilentlyContinue
    if ($files.Count -gt 0) {
        Write-Host "✓ export/web has $($files.Count) files" -ForegroundColor Green
        if (Test-Path (Join-Path $ExportWebDir "index.html")) {
            Write-Host "✓ index.html exists - ready to package" -ForegroundColor Green
        }
    }
    else {
        Write-Host "✗ export/web is EMPTY - need Godot export first" -ForegroundColor Red
    }
}

Write-Host "`n[2] Checking Beta0.2.zip..." -ForegroundColor Yellow
if (Test-Path $BetaZipPath) {
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    try {
        $zip = [System.IO.Compression.ZipFile]::OpenRead($BetaZipPath)
        $hasIndex = $zip.Entries | Where-Object { $_.Name -eq "index.html" }
        if ($hasIndex) {
            Write-Host "✓ Beta0.2.zip contains index.html" -ForegroundColor Green
        }
        else {
            Write-Host "✗ Beta0.2.zip missing index.html - this is why itch failed" -ForegroundColor Red
            Write-Host "  (It contains project files, not Web export)" -ForegroundColor Red
        }
        $zip.Dispose()
    }
    catch {
        Write-Host "Error reading ZIP: $_" -ForegroundColor Red
    }
}

Write-Host "`nSUMMARY:" -ForegroundColor Cyan
Write-Host "If export/web is empty: Open Godot → Project → Export → Web → Export Project" -ForegroundColor Yellow
Write-Host "After Godot export: Run tools/build_itch_web.ps1 to package for itch" -ForegroundColor Yellow

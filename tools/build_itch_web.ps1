param(
    [string]$GodotExe = "godot"
)

$ErrorActionPreference = "Stop"

$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$ExportDir = Join-Path $RepoRoot "export\web"
$ExportHtml = Join-Path $ExportDir "index.html"
$ZipPath = Join-Path $RepoRoot "export\itch-web.zip"

Write-Host "Repo root: $RepoRoot"
Write-Host "Godot executable: $GodotExe"

if (-not (Test-Path $ExportDir)) {
    New-Item -ItemType Directory -Path $ExportDir -Force | Out-Null
}

# Clean previous web export files to avoid stale artifacts.
Get-ChildItem -Path $ExportDir -File -ErrorAction SilentlyContinue | Remove-Item -Force

Write-Host "Exporting Web build..."
& $GodotExe --headless --path $RepoRoot --export-release "Web" $ExportHtml
if ($LASTEXITCODE -ne 0) {
    throw "Godot export failed with exit code $LASTEXITCODE"
}

if (-not (Test-Path $ExportHtml)) {
    throw "Export completed but index.html was not created at $ExportHtml"
}

if (Test-Path $ZipPath) {
    Remove-Item -Path $ZipPath -Force
}

Write-Host "Creating itch-ready ZIP..."
Compress-Archive -Path (Join-Path $ExportDir "*") -DestinationPath $ZipPath -Force

Add-Type -AssemblyName System.IO.Compression.FileSystem
$entries = [System.IO.Compression.ZipFile]::OpenRead($ZipPath).Entries | ForEach-Object { $_.FullName }

if (-not ($entries -contains "index.html")) {
    throw "ZIP was created but does not contain index.html at ZIP root."
}

Write-Host "Success: $ZipPath"
Write-Host "Verified: index.html exists at ZIP root for itch.io"

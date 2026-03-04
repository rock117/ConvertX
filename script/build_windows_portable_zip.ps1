param(
  [string]$Configuration = "Release",
  [string]$AppName = "ConvertX",
  [string]$Version = "",
  [switch]$BuildRust,
  [switch]$SkipFlutterBuild
)

$ErrorActionPreference = "Stop"

function Get-VersionFromPubspec {
  param([string]$PubspecPath)
  if (!(Test-Path $PubspecPath)) {
    throw "pubspec.yaml not found at: $PubspecPath"
  }
  $line = (Get-Content $PubspecPath | Where-Object { $_ -match '^version\s*:\s*' } | Select-Object -First 1)
  if (!$line) {
    throw "version not found in pubspec.yaml"
  }
  return ($line -replace '^version\s*:\s*', '').Trim()
}

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\")).Path
$pubspec = Join-Path $repoRoot "pubspec.yaml"

if ([string]::IsNullOrWhiteSpace($Version)) {
  $Version = Get-VersionFromPubspec -PubspecPath $pubspec
}

if (-not $SkipFlutterBuild) {
  $buildArgs = @("build", "windows", "--$($Configuration.ToLower())")
  Write-Host "==> flutter $($buildArgs -join ' ')" -ForegroundColor Cyan
  flutter @buildArgs
}

if ($BuildRust) {
  $rustDir = Join-Path $repoRoot "rust"
  if (!(Test-Path $rustDir)) {
    throw "rust directory not found at: $rustDir"
  }
  Write-Host "==> cargo build --release" -ForegroundColor Cyan
  cargo build --release --manifest-path (Join-Path $rustDir "Cargo.toml")
}

$releaseDir = Join-Path $repoRoot "build\windows\x64\runner\Release"
if (!(Test-Path $releaseDir)) {
  throw "Flutter Windows release output not found at: $releaseDir"
}

$rustDll = Join-Path $repoRoot "rust\target\release\convertx_core.dll"
if (Test-Path $rustDll) {
  Copy-Item $rustDll (Join-Path $releaseDir "convertx_core.dll") -Force
} else {
  Write-Warning "Rust DLL not found at: $rustDll (skip copy)."
}

$distDir = Join-Path $repoRoot "dist"
New-Item -ItemType Directory -Force -Path $distDir | Out-Null

$zipPath = Join-Path $distDir ("{0}-Portable-{1}-windows-x64.zip" -f $AppName, $Version)
if (Test-Path $zipPath) {
  Remove-Item $zipPath -Force
}

Write-Host "==> Creating portable zip: $zipPath" -ForegroundColor Cyan
Compress-Archive -Path (Join-Path $releaseDir '*') -DestinationPath $zipPath

Write-Host "Done. Output: $zipPath" -ForegroundColor Green

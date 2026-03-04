param(
  [string]$Configuration = "Release",
  [string]$AppName = "ConvertX",
  [string]$Version = "",
  [string]$Publisher = "",
  [string]$IsccPath = "",
  [switch]$BuildRust
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

function Resolve-Iscc {
  param([string]$Provided)
  if ($Provided -and (Test-Path $Provided)) { return $Provided }

  $candidates = @(
    "$env:ProgramFiles(x86)\Inno Setup 6\ISCC.exe",
    "$env:ProgramFiles\Inno Setup 6\ISCC.exe"
  )

  foreach ($c in $candidates) {
    if (Test-Path $c) { return $c }
  }

  $cmd = Get-Command ISCC.exe -ErrorAction SilentlyContinue
  if ($cmd) { return $cmd.Source }

  throw "ISCC.exe not found. Install Inno Setup 6 and/or pass -IsccPath."
}

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\")).Path
$pubspec = Join-Path $repoRoot "pubspec.yaml"

if ([string]::IsNullOrWhiteSpace($Version)) {
  $Version = Get-VersionFromPubspec -PubspecPath $pubspec
}

$buildArgs = @("build", "windows", "--$($Configuration.ToLower())")
Write-Host "==> flutter $($buildArgs -join ' ')" -ForegroundColor Cyan
flutter @buildArgs

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

$iscc = Resolve-Iscc -Provided $IsccPath
$iss = Join-Path $PSScriptRoot "convertx.iss"

if (!(Test-Path $iss)) {
  throw "Inno Setup script not found at: $iss"
}

$distDir = Join-Path $repoRoot "dist"
New-Item -ItemType Directory -Force -Path $distDir | Out-Null

$defines = @(
  "/DMyAppName=$AppName",
  "/DMyAppVersion=$Version",
  "/DMyPublisher=$Publisher",
  "/DMySourceDir=$releaseDir",
  "/DMyOutputDir=$distDir"
)

Write-Host "==> $iscc $($defines -join ' ') $iss" -ForegroundColor Cyan
& $iscc @defines $iss

Write-Host "Done. Output: $distDir" -ForegroundColor Green

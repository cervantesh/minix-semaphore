[CmdletBinding()]
param(
  [string] $Base = "upstream/master",

  [string] $Branch = "portfolio-pm-semaphores",

  [string] $OutputDir = "$(Join-Path (Join-Path $PSScriptRoot '..\..\..') '.artifacts')",

  [string] $PatchDir = ""
)

$ErrorActionPreference = "Stop"

$outputFull = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($OutputDir)
if (-not $PatchDir) {
  $PatchDir = Join-Path $outputFull "patches"
}
$patchFull = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($PatchDir)
$bundle = Join-Path $outputFull "minix-patches.tar.gz"
$commitFile = Join-Path $outputFull "commit-sha"
$baseFile = Join-Path $outputFull "base-sha"

New-Item -ItemType Directory -Force -Path $patchFull | Out-Null
Get-ChildItem -LiteralPath $patchFull -Filter *.patch | Remove-Item -Force

$commitSha = git -c core.protectNTFS=false -c core.protectHFS=false rev-parse $Branch
if ($LASTEXITCODE -ne 0) {
  throw "git rev-parse failed for $Branch."
}

$baseSha = git -c core.protectNTFS=false -c core.protectHFS=false rev-parse $Base
if ($LASTEXITCODE -ne 0) {
  throw "git rev-parse failed for $Base."
}

git -c core.protectNTFS=false -c core.protectHFS=false format-patch "$Base..$Branch" -o $patchFull
if ($LASTEXITCODE -ne 0) {
  throw "git format-patch failed."
}

Set-Content -LiteralPath $commitFile -Value $commitSha -NoNewline
Set-Content -LiteralPath $baseFile -Value $baseSha -NoNewline

tar -czf $bundle -C $patchFull .
if ($LASTEXITCODE -ne 0) {
  throw "tar failed."
}

Get-FileHash -Algorithm SHA256 -LiteralPath $bundle

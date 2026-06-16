[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)]
  [string] $SourceVdi,

  [string] $OutputImage = "$(Join-Path (Join-Path $PSScriptRoot '..\..\..') '.artifacts\minix.img')",

  [switch] $Force
)

$ErrorActionPreference = "Stop"

$vboxManage = (Get-Command VBoxManage -ErrorAction Stop).Source
$sourceFull = (Resolve-Path -LiteralPath $SourceVdi).Path
$outputFull = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($OutputImage)
$outputDir = Split-Path -Parent $outputFull

if (-not (Test-Path -LiteralPath $outputDir)) {
  New-Item -ItemType Directory -Path $outputDir | Out-Null
}

if ((Test-Path -LiteralPath $outputFull) -and -not $Force) {
  throw "Output image already exists: $outputFull. Use -Force to overwrite."
}

if (Test-Path -LiteralPath $outputFull) {
  Remove-Item -LiteralPath $outputFull -Force
}

& $vboxManage clonemedium disk $sourceFull $outputFull --format RAW
if ($LASTEXITCODE -ne 0) {
  throw "VBoxManage clonemedium failed."
}

Get-Item -LiteralPath $outputFull

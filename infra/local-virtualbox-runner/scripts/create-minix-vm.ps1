[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)]
  [string] $IsoPath,

  [string] $VmName = "minix-sem-image",

  [string] $DiskPath = "$(Join-Path (Get-Location) 'minix-sem-image.vdi')",

  [int] $MemoryMB = 1024,

  [int] $DiskMB = 8192
)

$ErrorActionPreference = "Stop"

$vboxManage = (Get-Command VBoxManage -ErrorAction Stop).Source
$isoFull = (Resolve-Path -LiteralPath $IsoPath).Path
$diskFull = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($DiskPath)
$diskDir = Split-Path -Parent $diskFull

if (-not (Test-Path -LiteralPath $diskDir)) {
  New-Item -ItemType Directory -Path $diskDir | Out-Null
}

$existing = & $vboxManage list vms
if ($existing -match [regex]::Escape("`"$VmName`"")) {
  throw "VirtualBox VM '$VmName' already exists."
}

if (Test-Path -LiteralPath $diskFull) {
  throw "Disk already exists: $diskFull"
}

function Invoke-VBox {
  param([Parameter(ValueFromRemainingArguments = $true)][string[]] $Args)

  & $vboxManage @Args
  if ($LASTEXITCODE -ne 0) {
    throw "VBoxManage failed: $($Args -join ' ')"
  }
}

Invoke-VBox createvm --name $VmName --ostype Other --register
Invoke-VBox modifyvm $VmName --memory $MemoryMB --vram 16 --acpi on --ioapic off --rtc-use-utc on
Invoke-VBox modifyvm $VmName --audio-driver none --nic1 nat --boot1 dvd --boot2 disk
Invoke-VBox createmedium disk --filename $diskFull --size $DiskMB --format VDI
Invoke-VBox storagectl $VmName --name "IDE Controller" --add ide --controller PIIX4
Invoke-VBox storageattach $VmName --storagectl "IDE Controller" --port 0 --device 0 --type hdd --medium $diskFull
Invoke-VBox storageattach $VmName --storagectl "IDE Controller" --port 1 --device 0 --type dvddrive --medium $isoFull

Write-Host "Created VirtualBox VM '$VmName'."
Write-Host "Start it with: VBoxManage startvm `"$VmName`""
Write-Host "After installation, power it off and export the disk with export-minix-image.ps1."

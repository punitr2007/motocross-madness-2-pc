#requires -version 3
$here = Split-Path -Parent $MyInvocation.MyCommand.Path

Write-Host "=============================================="
Write-Host "         Motocross Madness 2"
Write-Host "=============================================="
Write-Host ""

# 1) Ensure HKCU paths
$hkcu = "HKCU:\SOFTWARE\Microsoft\Microsoft Games\Motocross Madness 2"
try {
  if (-not (Test-Path $hkcu)) { New-Item -Path $hkcu -Force | Out-Null }
  Set-ItemProperty -Path $hkcu -Name "HardDriveRootPath" -Value $here -ErrorAction SilentlyContinue
  Set-ItemProperty -Path $hkcu -Name "CDPath" -Value ($here.TrimEnd('\') + "\") -ErrorAction SilentlyContinue
  Set-ItemProperty -Path $hkcu -Name "InstallType" -Value "Full" -ErrorAction SilentlyContinue
  Set-ItemProperty -Path $hkcu -Name "Launched" -Value "1" -ErrorAction SilentlyContinue
  Set-ItemProperty -Path $hkcu -Name "VersionType" -Value "RetailVersion" -ErrorAction SilentlyContinue
  Set-ItemProperty -Path $hkcu -Name "InstalledGroup" -Value "3" -ErrorAction SilentlyContinue
  Set-ItemProperty -Path $hkcu -Name "LangID" -Value 9 -ErrorAction SilentlyContinue
  Set-ItemProperty -Path $hkcu -Name "UseLastVideoCard" -Value 1 -Type DWord -ErrorAction SilentlyContinue
  Set-ItemProperty -Path $hkcu -Name "UseVideoCardIdx" -Value 1 -Type DWord -ErrorAction SilentlyContinue
  Set-ItemProperty -Path $hkcu -Name "FIRSTRUN" -Value 0 -Type DWord -ErrorAction SilentlyContinue
} catch {}

# 2) Fallback junction for old Downloads path (in case HKLM was not elevated)
$oldParent = [System.IO.Path]::Combine($env:USERPROFILE, "Downloads\Motocross-Madness-2_Win_EN_Preinstalled-game-Ready-to-play-on-IPX-Web-Lobby")
$oldPath = [System.IO.Path]::Combine($oldParent, "mcm2")
try {
  if (-not (Test-Path $oldParent)) { New-Item -ItemType Directory -Path $oldParent -Force | Out-Null }
  if (-not (Test-Path $oldPath)) { New-Item -ItemType Junction -Path $oldPath -Target $here -Force | Out-Null }
} catch {}

# 3) Ensure Indeo Video 5 (IV50) codec is registered
$indeoDll = Join-Path $here "ir50_32.dll"
if (Test-Path $indeoDll) {
  try { Start-Process "regsvr32.exe" -ArgumentList "/s `"$indeoDll`"" -Wait -WindowStyle Hidden } catch {}
}

Write-Host "Starting MCM2.EXE with CPU Affinity = 1 (Core 0)..." -ForegroundColor Green
$exe = Join-Path $here "MCM2.EXE"
$p = Start-Process -FilePath $exe -WorkingDirectory $here -PassThru
if ($p -and $p.Id) {
  try { $p.ProcessorAffinity = 1 } catch {}
}

Start-Sleep -Seconds 1
exit 0

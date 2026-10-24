#requires -version 3
$here = Split-Path -Parent $MyInvocation.MyCommand.Path

Write-Host "==============================================" -ForegroundColor Cyan
Write-Host "         Motocross Madness 2 Launcher" -ForegroundColor Cyan
Write-Host "==============================================" -ForegroundColor Cyan
Write-Host ""

$exe = Join-Path $here "MCM2.EXE"

# 1) Ensure HKCU paths (both 64-bit and WOW6432Node)
$regKeys = @(
  "HKCU:\SOFTWARE\Microsoft\Microsoft Games\Motocross Madness 2",
  "HKCU:\SOFTWARE\WOW6432Node\Microsoft\Microsoft Games\Motocross Madness 2",
  "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Microsoft Games\Motocross Madness 2"
)

foreach ($key in $regKeys) {
  try {
    if (-not (Test-Path $key)) { New-Item -Path $key -Force | Out-Null }
    Set-ItemProperty -Path $key -Name "HardDriveRootPath" -Value $here -ErrorAction SilentlyContinue
    Set-ItemProperty -Path $key -Name "CDPath" -Value ($here.TrimEnd('\') + "\") -ErrorAction SilentlyContinue
    Set-ItemProperty -Path $key -Name "PID" -Value "52513-442-4255595-96934" -ErrorAction SilentlyContinue
    Set-ItemProperty -Path $key -Name "AllowFreezeCamera" -Value 1 -Type DWord -ErrorAction SilentlyContinue
    Set-ItemProperty -Path $key -Name "InstallType" -Value "Full" -ErrorAction SilentlyContinue
    Set-ItemProperty -Path $key -Name "Launched" -Value "1" -ErrorAction SilentlyContinue
    Set-ItemProperty -Path $key -Name "VersionType" -Value "RetailVersion" -ErrorAction SilentlyContinue
    Set-ItemProperty -Path $key -Name "InstalledGroup" -Value "3" -ErrorAction SilentlyContinue
    Set-ItemProperty -Path $key -Name "LangID" -Value 9 -Type DWord -ErrorAction SilentlyContinue
    Set-ItemProperty -Path $key -Name "UseLastVideoCard" -Value 1 -Type DWord -ErrorAction SilentlyContinue
    Set-ItemProperty -Path $key -Name "UseVideoCardIdx" -Value 1 -Type DWord -ErrorAction SilentlyContinue
    Set-ItemProperty -Path $key -Name "FIRSTRUN" -Value 0 -Type DWord -ErrorAction SilentlyContinue
  } catch {}
}

# 2) Ensure Windows AppCompatibility layer is applied (~ WINXPSP3 HIGHDPIAWARE)
$compatKey = "HKCU:\Software\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Layers"
try {
  if (-not (Test-Path $compatKey)) { New-Item -Path $compatKey -Force | Out-Null }
  Set-ItemProperty -Path $compatKey -Name $exe -Value "~ WINXPSP3 HIGHDPIAWARE" -ErrorAction SilentlyContinue
} catch {}

# 3) Fallback junction for old Downloads path (in case old registry entries lingered)
$oldParent = [System.IO.Path]::Combine($env:USERPROFILE, "Downloads\Motocross-Madness-2_Win_EN_Preinstalled-game-Ready-to-play-on-IPX-Web-Lobby")
$oldPath = [System.IO.Path]::Combine($oldParent, "mcm2")
try {
  if (-not (Test-Path $oldParent)) { New-Item -ItemType Directory -Path $oldParent -Force | Out-Null }
  if (-not (Test-Path $oldPath)) { New-Item -ItemType Junction -Path $oldPath -Target $here -Force | Out-Null }
} catch {}

# 4) Ensure 32-bit Indeo Video 5 (IV50) codec is registered via SysWOW64
$indeoDll = Join-Path $here "ir50_32.dll"
if (Test-Path $indeoDll) {
  $regsvr32 = Join-Path $env:SystemRoot "SysWOW64\regsvr32.exe"
  if (-not (Test-Path $regsvr32)) { $regsvr32 = "regsvr32.exe" }
  try { Start-Process $regsvr32 -ArgumentList "/s `"$indeoDll`"" -Wait -WindowStyle Hidden } catch {}
}

Write-Host "Starting MCM2.EXE with CPU Affinity = 1 (Core 0)..." -ForegroundColor Green
$p = Start-Process -FilePath $exe -WorkingDirectory $here -PassThru
if ($p -and $p.Id) {
  try { $p.ProcessorAffinity = 1 } catch {}
}

Start-Sleep -Seconds 1
exit 0

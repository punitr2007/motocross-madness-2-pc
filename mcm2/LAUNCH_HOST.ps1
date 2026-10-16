#requires -version 3
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName Microsoft.VisualBasic

$here         = Split-Path -Parent $MyInvocation.MyCommand.Path
$savePathFile  = Join-Path $here 'game_path.txt'
$baseUrlFile   = Join-Path $here 'base_url.txt'
$hostRoomFile  = Join-Path $here 'host_room.txt'

function Get-SavedText([string]$path) {
  if (Test-Path $path) { try { return (Get-Content $path -Raw).Trim() } catch { return '' } }
  return ''
}
function Save-Text([string]$path, [string]$value) { try { Set-Content -Path $path -Value $value -Encoding ASCII } catch {} }

# === CHAT OVERLAY HELPERS ===
$nickFile = Join-Path $here 'chat_nick.txt'

function Get-ChatNick {
  $n = Get-SavedText $nickFile
  if (-not $n -or $n.Trim() -eq '') { $n = $env:USERNAME }
  $n = $n.ToString().Trim()
  Save-Text $nickFile $n
  return $n
}

function Start-ChatOverlay([string]$roomCode) {
  $overlayExe = Join-Path $here 'chat-overlay.exe'
  if (-not (Test-Path $overlayExe)) { return $null }
  $nick = Get-ChatNick
  try {
    return Start-Process -FilePath $overlayExe -ArgumentList @("--room=$roomCode","--nick=$nick") -PassThru
  } catch { return $null }
}

function Stop-ChatOverlay($proc) {
  if ($proc -and -not $proc.HasExited) {
    try { Stop-Process -Id $proc.Id -Force } catch {}
  }
}
# ============================

function Pick-GameExe {
  $dlg = New-Object System.Windows.Forms.OpenFileDialog
  $dlg.Filter = "Recommended (MCM2.EXE,MOTOCROSS2.EXE,MCMADNESS2.EXE)|MCM2.EXE,MOTOCROSS2.EXE,MCMADNESS2.EXE|Executable (*.exe)|*.exe"
  $dlg.Title  = "Select Motocross Madness 2 EXE"
  if ($dlg.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) { return $null }
  return $dlg.FileName
}

function Normalize-BaseUrl([string]$base) {
  if ($base -eq $null) { return '' }
  $b = $base.ToString().Trim()
  if ($b -eq '') { return '' }
  if ($b -notmatch '^https?://') { $b = 'https://' + $b }
  try {
    $u = [Uri]$b
    $path = $u.AbsolutePath.TrimEnd('/')
    if ($path -eq '/') { $path = '' }
    return ($u.Scheme + '://' + $u.Host + $path)
  } catch {
    return $b.TrimEnd('/')
  }
}

function HostFromBaseUrl([string]$base) {
  try {
    if ($base -eq $null) { return '' }
    $b = $base.ToString().Trim()
    if ($b -eq '') { return '' }
    if ($b -notmatch '^https?://') { $b = 'https://' + $b }
    $u = [Uri]$b
    if ($u.Host -and $u.Host.Trim() -ne '') { return $u.Host.Trim() }
  } catch {}
  return $base
}

function Get-RelayHostFromBaseUrl([string]$base) {
  try {
    if ($base -eq $null) { return '' }
    $b = $base.ToString().Trim()
    if ($b -eq '') { return '' }
    if ($b -notmatch '^https?://') { $b = 'https://' + $b }
    $u = [Uri]$b
    foreach ($pair in $u.Query.TrimStart('?').Split('&')) {
      if (-not $pair) { continue }
      $kv = $pair.Split('=', 2)
      if ($kv.Count -ne 2) { continue }
      if ($kv[0].ToLowerInvariant() -ne 'relay') { continue }
      $h = [Uri]::UnescapeDataString($kv[1]).Trim().ToLowerInvariant()
      if ($h -match '^(1|true|yes)$') { return '' }
      if ($h -match '^[a-z0-9.-]+$') { return $h }
    }
  } catch {}
  return ''
}

function Ensure-BaseUrl {
  $base = Get-SavedText $baseUrlFile
  if ($base -eq $null -or $base.Trim() -eq '') {
    $base = [Microsoft.VisualBasic.Interaction]::InputBox(
      "Enter your website base URL (example: https://www.siljo-planet.net)",
      "Motocross Madness 2 - Setup",
      "https://www.siljo-planet.net"
    )
    if ($base -eq $null) { $base = '' }
    $base = $base.ToString().Trim()
    if ($base -eq '') { return '' }
    Save-Text $baseUrlFile $base
  }
  return Normalize-BaseUrl $base
}

function Ensure-GameRegistry([string]$dir) {
  $keys = @(
    "HKCU:\SOFTWARE\Microsoft\Microsoft Games\Motocross Madness 2",
    "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Microsoft Games\Motocross Madness 2"
  )
  foreach ($k in $keys) {
    try {
      if (-not (Test-Path $k)) { New-Item -Path $k -Force | Out-Null }
      Set-ItemProperty -Path $k -Name "HardDriveRootPath" -Value $dir -ErrorAction SilentlyContinue
      Set-ItemProperty -Path $k -Name "CDPath" -Value ($dir.TrimEnd('\') + "\") -ErrorAction SilentlyContinue
      Set-ItemProperty -Path $k -Name "InstallType" -Value "Full" -ErrorAction SilentlyContinue
      Set-ItemProperty -Path $k -Name "Launched" -Value "1" -ErrorAction SilentlyContinue
      Set-ItemProperty -Path $k -Name "VersionType" -Value "RetailVersion" -ErrorAction SilentlyContinue
      Set-ItemProperty -Path $k -Name "InstalledGroup" -Value "3" -ErrorAction SilentlyContinue
      Set-ItemProperty -Path $k -Name "LangID" -Value 9 -ErrorAction SilentlyContinue
      Set-ItemProperty -Path $k -Name "UseLastVideoCard" -Value 1 -Type DWord -ErrorAction SilentlyContinue
      Set-ItemProperty -Path $k -Name "UseVideoCardIdx" -Value 1 -Type DWord -ErrorAction SilentlyContinue
      Set-ItemProperty -Path $k -Name "FIRSTRUN" -Value 0 -Type DWord -ErrorAction SilentlyContinue
    } catch {}
  }
  # Fallback junction for old Downloads path
  try {
    $oldParent = [System.IO.Path]::Combine($env:USERPROFILE, "Downloads\Motocross-Madness-2_Win_EN_Preinstalled-game-Ready-to-play-on-IPX-Web-Lobby")
    $oldPath = [System.IO.Path]::Combine($oldParent, "mcm2")
    if (-not (Test-Path $oldParent)) { New-Item -ItemType Directory -Path $oldParent -Force | Out-Null }
    if (-not (Test-Path $oldPath)) { New-Item -ItemType Junction -Path $oldPath -Target $dir -Force | Out-Null }
  } catch {}
  # Ensure Indeo Video 5 codec is registered
  try {
    $indeo = Join-Path $dir "ir50_32.dll"
    if (Test-Path $indeo) { Start-Process "regsvr32.exe" -ArgumentList "/s `"$indeo`"" -Wait -WindowStyle Hidden }
  } catch {}
}

function Write-IpxIni([string]$gameDir, [int]$port, [string]$relayHost) {
  $iniDst = Join-Path $gameDir 'ipxwrapper.ini'
  if (Test-Path $iniDst) {
    try {
      $bak = Join-Path $gameDir ('ipxwrapper.ini.bak_' + (Get-Date -Format 'yyyyMMdd_HHmmss'))
      Copy-Item -Force $iniDst $bak | Out-Null
    } catch {}
  }
  if ($relayHost -and $relayHost.Trim() -ne '') {
    # Official IPXWrapper DOSBox UDP encapsulation settings for Internet relay play.
    $content = "dosbox server address = $($relayHost.Trim())`r`ndosbox server port = $port`r`ncoalesce packets = yes`r`n"
  } else {
    # Valid IPXWrapper global configuration for local LAN / VPN (Radmin/Tailscale) play.
    $content = "[global]`r`nport = $port`r`n"
  }
  try { Set-Content -Path $iniDst -Value $content -Encoding ASCII } catch {}
}

function Get-PublicIP {
  try {
    $r = Invoke-RestMethod "https://api.ipify.org?format=json" -TimeoutSec 5
    if ($r -and $r.ip) { return $r.ip.ToString().Trim() }
  } catch {}
  return $null
}

# 1) Base URL
$baseUrl = Ensure-BaseUrl
if ($baseUrl -eq '') { Write-Host "No base URL. Exiting."; exit 1 }

# 2) Resolve EXE
$exe = Get-SavedText $savePathFile
if ($exe -and -not (Test-Path $exe)) { $exe = '' }

if ($exe -eq $null -or $exe.Trim() -eq '') {
  [System.Windows.Forms.MessageBox]::Show("Please select the Motocross Madness 2 EXE.", "Motocross Madness 2") | Out-Null
  $exe = Pick-GameExe
  if (-not $exe) { Write-Host "Cancelled."; exit 1 }
  Save-Text $savePathFile $exe
}

$gameDir = Split-Path -Parent $exe

# 3) Ask settings
$title = [Microsoft.VisualBasic.Interaction]::InputBox("Room title:", "Motocross Madness 2 - Host", "Motocross Madness 2")
if ($title -eq $null -or $title.ToString().Trim() -eq '') { $title = "Motocross Madness 2" }
$title = $title.ToString().Trim()

$portText = [Microsoft.VisualBasic.Interaction]::InputBox("UDP port (1-65535):", "Motocross Madness 2 - Host", "55240")
$port = 55240
try { $port = [int]$portText } catch { $port = 55240 }
if ($port -lt 1 -or $port -gt 65535) { $port = 55240 }

$mode = [Microsoft.VisualBasic.Interaction]::InputBox("Mode: portforward OR vpn", "Motocross Madness 2 - Host", "portforward")
if ($mode -eq $null -or $mode.ToString().Trim() -eq '') { $mode = "portforward" }
$mode = $mode.ToString().Trim().ToLower()
if ($mode -ne "vpn") { $mode = "portforward" }

$vpnIp = ""
if ($mode -eq "vpn") {
  $vpnIp = [Microsoft.VisualBasic.Interaction]::InputBox("VPN IP (optional):", "Motocross Madness 2 - Host", "")
  if ($vpnIp -eq $null) { $vpnIp = "" }
  $vpnIp = $vpnIp.ToString().Trim()
}

# 4) Create room
$createUrl = $baseUrl + "/ab/api/room_create.php"
$publicIpForCreate = Get-PublicIP

# Hidden IPXWrapper relay mode:
# normal: https://www.siljo-planet.net/
# relay:  https://www.siljo-planet.net/?relay=relay.siljo-planet.net
$rawBaseUrlForRelay = Get-SavedText $baseUrlFile
if (-not $rawBaseUrlForRelay -or $rawBaseUrlForRelay.Trim() -eq '') {
  $rawBaseUrlForRelay = $baseUrl
}

$relayHost = Get-RelayHostFromBaseUrl $rawBaseUrlForRelay
$ipxRelay = "0"
if ($relayHost -and $relayHost.Trim() -ne '') {
  $ipxRelay = "1"
} elseif ($rawBaseUrlForRelay -match '(?i)[?&]relay=(1|true|yes)(&|$)') {
  [System.Windows.Forms.MessageBox]::Show("Old relay format detected.`nUse: https://www.siljo-planet.net/?relay=relay.siljo-planet.net", "Motocross Madness 2") | Out-Null
  exit 1
}

$body = @{ title=$title; port=$port; mode=$mode; vpn_ip=$vpnIp; game_key='motocross2'; public_ip=$publicIpForCreate; ipx_relay=$ipxRelay; relay_host=$relayHost }

try {
  $resp = Invoke-RestMethod -Uri $createUrl -Method POST -Body $body -TimeoutSec 12
} catch {
  [System.Windows.Forms.MessageBox]::Show("Could not create room. Check Base URL / internet.", "Motocross Madness 2") | Out-Null
  exit 1
}

$code     = $resp.code
$secret   = $resp.host_secret
$realPort = [int]$resp.host_port

if ($ipxRelay -eq "1") {
  Save-Text $hostRoomFile ($code + "|" + $secret + "|" + $rawBaseUrlForRelay)
} else {
  Save-Text $hostRoomFile ($code + "|" + $secret)
}


# Start chat overlay (auto-join)
$overlayProcess = Start-ChatOverlay $code
# 5) Write ipxwrapper.ini: direct winsock mode or official DOSBox relay encapsulation mode.
$relayIniHost = ''
if ($ipxRelay -eq "1") {
  try { if ($resp.connect_ip -ne $null -and $resp.connect_ip.ToString().Trim() -ne '') { $relayIniHost = $resp.connect_ip.ToString().Trim() } } catch {}
  if (-not $relayIniHost) { $relayIniHost = $relayHost }
}
Write-IpxIni $gameDir $realPort $relayIniHost

[System.Windows.Forms.MessageBox]::Show(
  ("Room created!`n`nCode: " + $code + "`nPort: " + $realPort + "`n`nStarting game..."),
  "Motocross Madness 2"
) | Out-Null

# 6) Ensure registry points to active game directory and start game
Ensure-GameRegistry $gameDir

$gamePid = 0
try {
  $p = Start-Process -FilePath $exe -WorkingDirectory $gameDir -PassThru
  if ($p -and $p.Id) {
    $gamePid = [int]$p.Id
    try { $p.ProcessorAffinity = 1 } catch {}
  }
} catch {}

function GameRunning {
  param([int]$procId, [string]$exePath)

  # 1) PID check (best effort)
  if ($procId -gt 0) {
    try { $null = Get-Process -Id $procId -ErrorAction Stop; return $true } catch {}
  }

  # 2) Robust by process names (handles PID swap during network init)
  $names = @()
  try {
    $raw = "MCM2.EXE,MOTOCROSS2.EXE,MCMADNESS2.EXE".Split(',')
    foreach ($r in $raw) {
      $r = $r.Trim()
      if ($r.Length -eq 0) { continue }
      $n = [System.IO.Path]::GetFileNameWithoutExtension($r)
      if ($n -and $n.Trim().Length -gt 0) { $names += $n.Trim() }
    }
  } catch {}

  foreach ($n in $names) {
    try {
      $plist = Get-Process -Name $n -ErrorAction SilentlyContinue
      foreach ($p in $plist) {
        if ($p -and $p.MainWindowHandle -ne 0) { return $true }
      }
      if ($plist) { return $true }
    } catch {}
  }

  return $false
}

# 7) Heartbeat loop + auto-close AFTER game exit
$hbUrl    = $baseUrl + "/ab/api/room_heartbeat.php"
$closeUrl = $baseUrl + "/ab/api/room_close.php"

$interval     = 5
$stopGraceSec = 60
$stoppedFor   = 0
$ipRefreshSec = 600
$lastIpCheck  = Get-Date
$publicIp     = Get-PublicIP

while ($true) {
  if (((Get-Date) - $lastIpCheck).TotalSeconds -ge $ipRefreshSec) {
    $tmp = Get-PublicIP
    if ($tmp) { $publicIp = $tmp }
    $lastIpCheck = Get-Date
  }

  $playing = GameRunning -procId $gamePid -exePath $exe
  if ($playing) { $status = "playing" } else { $status = "open" }

  try {
    Invoke-WebRequest -Uri $hbUrl -Method POST -Body @{
      code      = $code
      secret    = $secret
      status    = $status
      public_ip = $publicIp
    } -UseBasicParsing | Out-Null
  } catch {}

  if ($playing) {
    $stoppedFor = 0
  } else {
    $stoppedFor += $interval
    if ($stoppedFor -ge $stopGraceSec) {
      try { Invoke-WebRequest -Uri $closeUrl -Method POST -Body @{ code=$code; secret=$secret } -UseBasicParsing | Out-Null } catch {}
      break
    }
  }

  Start-Sleep -Seconds $interval
}

# Stop chat overlay (best effort)
Stop-ChatOverlay $overlayProcess

Write-Host \"Room closed.\"
exit 0

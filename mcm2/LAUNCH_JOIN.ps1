#requires -version 3
param(
  [string]$Log = ""
)

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName Microsoft.VisualBasic

function Write-Log([string]$msg) {
  if ($Log -and $Log.Trim().Length -gt 0) {
    try { Add-Content -Path $Log -Value $msg } catch {}
  }
}

$here         = Split-Path -Parent $MyInvocation.MyCommand.Path
$savePathFile  = Join-Path $here 'game_path.txt'
$baseUrlFile   = Join-Path $here 'base_url.txt'
$saveRoomFile  = Join-Path $here 'room_code.txt'

Write-Log "==== JOIN PS1 $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') ===="
Write-Log "here=$here"
Write-Log "PSVersion=$($PSVersionTable.PSVersion)"
Write-Log "User=$env:USERNAME PC=$env:COMPUTERNAME"

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

function Is-UsableHostAddress([object]$v) {
  if ($v -eq $null) { return $false }
  $s = $v.ToString().Trim()
  if ($s -eq '') { return $false }
  # IPXWrapper clients must not receive IPv6 here.
  if ($s -match ':') { return $false }
  return $true
}

function Pick-RoomServer($room, [string]$baseUrl) {
  try {
    if ($room.ipx_relay -ne $null -and $room.ipx_relay.ToString() -eq "1") {
      if (Is-UsableHostAddress $room.connect_ip) { return $room.connect_ip.ToString().Trim() }
    }
  } catch {}

  $candidates = @($room.connect_ip, $room.public_ip, $room.vpn_ip, $room.host_ip)
  foreach ($c in $candidates) {
    if (Is-UsableHostAddress $c) { return $c.ToString().Trim() }
  }
  return ''
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
      Write-Log "Backed up ipxwrapper.ini -> $bak"
    } catch {}
  }
  if ($relayHost -and $relayHost.Trim() -ne '') {
    $content = "dosbox server address = $($relayHost.Trim())`r`ndosbox server port = $port`r`ncoalesce packets = yes`r`n"
    $modeNote = "dosbox-server=$relayHost`:$port"
  } else {
    $content = "[global]`r`nport = $port`r`n"
    $modeNote = "global port=$port"
  }
  try {
    Set-Content -Path $iniDst -Value $content -Encoding ASCII
    Write-Log "Wrote ipxwrapper.ini: $iniDst ($modeNote)"
  } catch {
    Write-Log "ERROR writing ipxwrapper.ini: $($_.Exception.Message)"
  }
}

$baseUrl = Ensure-BaseUrl
if ($baseUrl -eq '') {
  Write-Log "No base URL. Exiting."
  Write-Host "No base URL. Exiting."
  exit 1
}

$exe = Get-SavedText $savePathFile
if ($exe -and -not (Test-Path $exe)) {
  Write-Log "Saved EXE path missing: $exe"
  $exe = ''
}

if ($exe -eq $null -or $exe.Trim() -eq '') {
  [System.Windows.Forms.MessageBox]::Show("Please select the Motocross Madness 2 EXE.", "Motocross Madness 2") | Out-Null
  $exe = Pick-GameExe
  if (-not $exe) { Write-Log "Cancelled at EXE picker."; Write-Host "Cancelled."; exit 1 }
  Save-Text $savePathFile $exe
}

$gameDir = Split-Path -Parent $exe
Write-Log "exe=$exe"
Write-Log "gameDir=$gameDir"

$defaultCode = Get-SavedText $saveRoomFile
$code = [Microsoft.VisualBasic.Interaction]::InputBox("Enter Room Code (e.g. ABC123)", "Motocross Madness 2 - Join", $defaultCode)
if ($code -eq $null) { $code = '' }
$code = $code.ToString().Trim().ToUpper()
if ($code -eq '') { Write-Log "No code entered."; Write-Host "No code."; exit 1 }
Save-Text $saveRoomFile $code


# Start chat overlay (auto-join)
$overlayProcess = Start-ChatOverlay $code
$url = $baseUrl + "/ab/api/room_get.php?code=" + [Uri]::EscapeDataString($code)
Write-Log "room_get url=$url"

# --- retry room_get (server not ready / temporary network hiccup) ---
$maxRoomTries = 10
$res = $null
for ($i=1; $i -le $maxRoomTries; $i++) {
  try {
    $res = Invoke-RestMethod -Uri $url -Method GET -TimeoutSec 10
    if ($res -and $res.room) { break }
  } catch {
    Write-Log "room_get try $i failed: $($_.Exception.Message)"
  }
  Start-Sleep -Seconds 1
}

if (-not $res -or -not $res.room) {
  [System.Windows.Forms.MessageBox]::Show("Could not load room. Check code/internet.", "Motocross Madness 2") | Out-Null
  Write-Log "ERROR: could not load room after retries."
  exit 1
}

$room = $res.room
$ip = Pick-RoomServer $room $baseUrl

if (-not $ip -or $ip.Trim() -eq "") {
  [System.Windows.Forms.MessageBox]::Show(
    "Room found, but no usable host address was returned by the lobby.",
    "Motocross Madness 2"
  ) | Out-Null
  Write-Log "ERROR: no usable host IP in room response."
  Stop-ChatOverlay $overlayProcess
  exit 1
}

$port = [int]$room.host_port

Write-Log "Resolved host: ip=$ip port=$port room=$code"

# Optional ping wait (helps when host just started)
if ($ip -and $ip -ne "127.0.0.1" -and $ip -ne "localhost") {
  for ($w=1; $w -le 8; $w++) {
    $ok = $false
    try { $ok = Test-Connection -ComputerName $ip -Count 1 -Quiet -ErrorAction SilentlyContinue } catch {}
    Write-Log "Ping wait $w/8 -> $ok"
    if ($ok) { break }
    Start-Sleep -Seconds 1
  }
}

$relayIniHost = ''
try {
  if ($room.ipx_relay -ne $null -and $room.ipx_relay.ToString() -eq "1") {
    $relayIniHost = $ip
  } elseif ($room.mode -eq "portforward" -and $ip -and $ip -notmatch '^(127\.|192\.168\.|10\.|172\.(1[6-9]|2[0-9]|3[0-1])\.)') {
    $relayIniHost = $ip
  }
} catch {}
Write-IpxIni $gameDir $port $relayIniHost

[System.Windows.Forms.MessageBox]::Show(
  ("Host: " + $ip + ":" + $port + "`nRoom: " + $code + "`n`nStarting game..."),
  "Motocross Madness 2"
) | Out-Null

Ensure-GameRegistry $gameDir

# --- launch with retry if it exits immediately ---
$maxLaunchTries = 6
$minAliveSeconds = 3

for ($t=1; $t -le $maxLaunchTries; $t++) {
  Write-Log "Launch try $t/$maxLaunchTries"

  try {
    $p = Start-Process -FilePath $exe -WorkingDirectory $gameDir -PassThru
    if ($p -and $p.Id) {
      try { $p.ProcessorAffinity = 1 } catch {}
    }
  } catch {
    Write-Log "Start-Process ERROR: $($_.Exception.Message)"
    Start-Sleep -Seconds 1
    continue
  }

  Start-Sleep -Seconds $minAliveSeconds

  if ($p.HasExited) {
    Write-Log "Game exited too fast. ExitCode=$($p.ExitCode)"
    if ($t -lt $maxLaunchTries) { Start-Sleep -Seconds 1; continue }
    [System.Windows.Forms.MessageBox]::Show(
      "Game closed immediately. Check log file and game compatibility/permissions.",
      "Motocross Madness 2 - Join"
    ) | Out-Null
    exit 10
  } else {
    Write-Log "Game still running after ${minAliveSeconds}s -> OK"
    exit 0
  }
}

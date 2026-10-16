#requires -version 3
Add-Type -AssemblyName System.Windows.Forms

$here        = Split-Path -Parent $MyInvocation.MyCommand.Path
$hostRoom    = Join-Path $here 'host_room.txt'
$baseUrlFile = Join-Path $here 'base_url.txt'

function Normalize-BaseUrl([string]$base) {
  if ($base -eq $null) { return '' }
  $b = $base.ToString().Trim()
  if ($b -eq '') { return '' }
  if ($b -notmatch '^https?://') { $b = 'https://' + $b }
  try {
    $u = [Uri]$b
    if (-not $u.Host -or $u.Host.Trim() -eq '') { return '' }
    return ($u.Scheme + '://' + $u.Authority)
  } catch { return $b.TrimEnd('/') }
}

function Get-SavedText([string]$path) {
  if (Test-Path $path) { try { return (Get-Content $path -Raw).Trim() } catch { return '' } }
  return ''
}

$baseUrl = Get-SavedText $baseUrlFile
if ($baseUrl -eq $null -or $baseUrl.Trim() -eq '') {
  [System.Windows.Forms.MessageBox]::Show("Missing base_url.txt (run HOST once first).", "Motocross Madness 2") | Out-Null
  exit 1
}
$baseUrl = Normalize-BaseUrl $baseUrl

if (-not (Test-Path $hostRoom)) {
  [System.Windows.Forms.MessageBox]::Show("No saved host room found (host_room.txt).", "Motocross Madness 2") | Out-Null
  exit 0
}

try { $line = (Get-Content $hostRoom -Raw).Trim() } catch { $line = '' }
if ($line -eq '' -or $line.IndexOf('|') -lt 0) {
  [System.Windows.Forms.MessageBox]::Show("host_room.txt is invalid.", "Motocross Madness 2") | Out-Null
  exit 1
}

$parts  = $line.Split('|')
$code   = $parts[0]
$secret = $parts[1]

$closeUrl = $baseUrl + "/ab/api/room_close.php"

try {
  Invoke-WebRequest -Uri $closeUrl -Method POST -Body @{ code=$code; secret=$secret } -UseBasicParsing | Out-Null
  [System.Windows.Forms.MessageBox]::Show(("Room closed: " + $code), "Motocross Madness 2") | Out-Null
} catch {
  [System.Windows.Forms.MessageBox]::Show("Could not close room (network issue).", "Motocross Madness 2") | Out-Null
}

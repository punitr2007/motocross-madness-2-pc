#requires -version 3
<#{
  IPX Lobby - Unified Firewall Fix

  Downloaded via the web lobby -> it embeds per-game defaults:
  - Game : Motocross Madness 2
  - Port : 55240
  - EXEs : MCM2.EXE,MOTOCROSS2.EXE,MCMADNESS2.EXE

  What it does:
  - Creates/updates inbound+outbound UDP allow rules for the selected PORT
  - Limits RemoteAddress to your LAN/VPN subnet (CIDR) for safety
  - Optional: creates allow rules for the selected game EXE

  Run PowerShell as Administrator.
#}

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName Microsoft.VisualBasic

function Pick-Exe([string]$title, [string]$exeNamesCsv) {
  $dlg = New-Object System.Windows.Forms.OpenFileDialog
  $names = @()
  if ($exeNamesCsv) {
    $names = $exeNamesCsv.Split(',') | ForEach-Object { $_.Trim() } | Where-Object { $_ }
  }
  if ($names.Count -gt 0) {
    $recommended = ($names -join ';')
    $dlg.Filter = "Recommended ($recommended)|$recommended|Executable (*.exe)|*.exe|All files (*.*)|*.*"
  } else {
    $dlg.Filter = "Executable (*.exe)|*.exe|All files (*.*)|*.*"
  }
  $dlg.Title  = $title
  if ($dlg.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) { return $null }
  return $dlg.FileName
}

function Get-LocalSubnetCIDR {
  try {
    $ip = Get-NetIPAddress -AddressFamily IPv4 -ErrorAction Stop |
      Where-Object { $_.IPAddress -match '^\d+\.' -and $_.IPAddress -notlike '169.254*' } |
      Sort-Object -Property InterfaceMetric |
      Select-Object -First 1

    if (-not $ip) { return "192.168.1.0/24" }

    $prefix = [int]$ip.PrefixLength
    $addr = $ip.IPAddress
    if ($prefix -eq 24) {
      $parts = $addr.Split('.')
      return ($parts[0] + "." + $parts[1] + "." + $parts[2] + ".0/24")
    }
    return ($addr + "/" + $prefix)
  } catch {
    return "192.168.1.0/24"
  }
}

$gameNameDefault = "Motocross Madness 2"
$portDefault = 55240
$exeNamesCsv = "MCM2.EXE,MOTOCROSS2.EXE,MCMADNESS2.EXE"

# 1) Game name (for rule titles)
$gameName = [Microsoft.VisualBasic.Interaction]::InputBox(
  "Firewall rule title (game name):",
  "IPX Lobby - Firewall Fix",
  $gameNameDefault
).Trim()
if (-not $gameName) { $gameName = $gameNameDefault }

# 2) Port
$portText = [Microsoft.VisualBasic.Interaction]::InputBox(
  "UDP port to allow (1-65535):",
  "IPX Lobby - Firewall Fix",
  ($portDefault.ToString())
).Trim()

$port = $portDefault
try { $port = [int]$portText } catch { $port = $portDefault }
if ($port -lt 1 -or $port -gt 65535) { $port = $portDefault }

# 3) Remote subnet restriction
$cidrDefault = "Any"
$cidr = [Microsoft.VisualBasic.Interaction]::InputBox(
  "Allowed remote subnet - type 'Any' for Internet play, or specify CIDR (e.g. 192.168.1.0/24 or 100.64.0.0/10):",
  "IPX Lobby - Firewall Fix",
  $cidrDefault
).Trim()
if (-not $cidr) { $cidr = "Any" }

# 4) Optional EXE allow rules
$exe = $null
$wantExe = [System.Windows.Forms.MessageBox]::Show(
  "Also create allow rules for the game EXE? (recommended)",
  "IPX Lobby - Firewall Fix",
  [System.Windows.Forms.MessageBoxButtons]::YesNo
)
if ($wantExe -eq [System.Windows.Forms.DialogResult]::Yes) {
  $exe = Pick-Exe ("Select " + $gameName + " EXE") $exeNamesCsv
}

Write-Host "Game : $gameName"
Write-Host "Port : $port"
Write-Host "CIDR : $cidr"
if ($exe) { Write-Host "EXE  : $exe" } else { Write-Host "EXE  : (skipped)" }
Write-Host ""

# Use stable, non-duplicating names
$prefix = "IPX Lobby - motocross2"
$inName  = "$prefix UDP In $port"
$outName = "$prefix UDP Out $port"

Get-NetFirewallRule -DisplayName $inName  -ErrorAction SilentlyContinue | Remove-NetFirewallRule -ErrorAction SilentlyContinue
Get-NetFirewallRule -DisplayName $outName -ErrorAction SilentlyContinue | Remove-NetFirewallRule -ErrorAction SilentlyContinue

$remoteParam = if ($cidr -eq "Any" -or $cidr -eq "*") { "Any" } else { $cidr }

New-NetFirewallRule -DisplayName $inName `
  -Direction Inbound -Protocol UDP -LocalPort $port `
  -RemoteAddress $remoteParam -Action Allow -Profile Any | Out-Null

Set-NetFirewallRule -DisplayName $inName -EdgeTraversalPolicy Allow | Out-Null

New-NetFirewallRule -DisplayName $outName `
  -Direction Outbound -Protocol UDP -RemotePort $port `
  -RemoteAddress $remoteParam -Action Allow -Profile Any | Out-Null

if ($exe) {
  $exeIn  = "$prefix EXE In"
  $exeOut = "$prefix EXE Out"
  Get-NetFirewallRule -DisplayName $exeIn  -ErrorAction SilentlyContinue | Remove-NetFirewallRule -ErrorAction SilentlyContinue
  Get-NetFirewallRule -DisplayName $exeOut -ErrorAction SilentlyContinue | Remove-NetFirewallRule -ErrorAction SilentlyContinue

  New-NetFirewallRule -DisplayName $exeIn  -Direction Inbound  -Program $exe -Action Allow -Profile Any | Out-Null
  New-NetFirewallRule -DisplayName $exeOut -Direction Outbound -Program $exe -Action Allow -Profile Any | Out-Null
}

Write-Host ""
Write-Host "DONE. Current rules for this lobby/game:" 
Get-NetFirewallRule -DisplayName "$prefix*" -ErrorAction SilentlyContinue |
  Select-Object DisplayName, Direction, Action, Profile, Enabled |
  Format-Table -AutoSize

[System.Windows.Forms.MessageBox]::Show(
  "Firewall rules created/updated.\n\nTip: Set your network profile to Private for LAN games.\n",
  "IPX Lobby - Firewall Fix"
) | Out-Null

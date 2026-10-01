<#
.SYNOPSIS
    Audits a Windows host against a set of baseline security checks and reports
    each as Pass, Fail or Warn.

.DESCRIPTION
    Collects host security posture from a single endpoint: local administrators,
    dormant and non-expiring local accounts, firewall profile state, Defender
    status, BitLocker encryption, SMBv1, RDP exposure, Windows Update recency,
    PowerShell logging and the LAPS / LSA protection settings.

    Read-only. It changes nothing and needs no modules beyond what ships with
    Windows. Non-administrative sessions can still run it, but checks that need
    elevation are reported as Warn rather than silently passing.

    Designed to run across a fleet via Invoke-Command and have the results
    aggregated, which is why it emits objects rather than formatted text.

.PARAMETER StaleAccountDays
    Number of days after which an enabled local account with no logon is
    reported as dormant. Default 90.

.PARAMETER PatchAgeDays
    Number of days after which the most recent installed update is considered
    stale. Default 45.

.PARAMETER AsObject
    Emit result objects only, with no console summary. Use when piping to
    Export-Csv, ConvertTo-Json, or aggregating across many hosts.

.EXAMPLE
    .\Get-LocalSecurityBaseline.ps1

    Runs every check against the local machine and prints a colour-coded summary.

.EXAMPLE
    .\Get-LocalSecurityBaseline.ps1 -AsObject | Export-Csv .\baseline.csv -NoTypeInformation

    Machine-readable output for a single host.

.EXAMPLE
    $hosts = 'WS11-01','WS11-02','FILE01'
    Invoke-Command -ComputerName $hosts -FilePath .\Get-LocalSecurityBaseline.ps1 -ArgumentList $true |
        Where-Object Status -eq 'Fail' |
        Sort-Object PSComputerName, Category

    Fleet sweep, surfacing only failures.

.NOTES
    Author : vampiricbunny
    Lab    : vbunnylab.local
    Tested : Windows 10 22H2, Windows 11 23H2, Windows Server 2022/2025
#>

[CmdletBinding()]
param(
    [ValidateRange(1, 3650)] [int] $StaleAccountDays = 90,
    [ValidateRange(1, 3650)] [int] $PatchAgeDays     = 45,
    [switch] $AsObject
)

Set-StrictMode -Version Latest

$script:Results = New-Object System.Collections.Generic.List[object]

function Add-Result {
    param(
        [Parameter(Mandatory)][string] $Category,
        [Parameter(Mandatory)][string] $Check,
        [Parameter(Mandatory)][ValidateSet('Pass','Fail','Warn','Info')][string] $Status,
        [string] $Detail,
        [string] $Remediation
    )
    $script:Results.Add([pscustomobject]@{
        Computer    = $env:COMPUTERNAME
        Category    = $Category
        Check       = $Check
        Status      = $Status
        Detail      = $Detail
        Remediation = $Remediation
    })
}

function Test-Elevated {
    try {
        $id = [Security.Principal.WindowsIdentity]::GetCurrent()
        (New-Object Security.Principal.WindowsPrincipal $id).IsInRole(
            [Security.Principal.WindowsBuiltInRole]::Administrator)
    } catch { $false }
}

$elevated = Test-Elevated
if (-not $elevated) {
    Write-Warning 'Not running elevated - checks that require administrative rights will report as Warn.'
}

# ---------------------------------------------------------------- accounts ---
function Test-LocalAccounts {
    try {
        $admins = Get-LocalGroupMember -Group 'Administrators' -ErrorAction Stop
        $names  = ($admins | ForEach-Object { $_.Name }) -join ', '
        # Anything beyond the built-in Administrator and the domain admins group is worth a look
        $extra = $admins | Where-Object {
            $_.Name -notmatch '\\(Administrator|Domain Admins|Enterprise Admins)$'
        }
        if ($extra) {
            Add-Result 'Accounts' 'Local Administrators membership' 'Warn' `
                "$($admins.Count) member(s): $names" `
                'Review each. Local admin rights should be exception-based, not default.'
        } else {
            Add-Result 'Accounts' 'Local Administrators membership' 'Pass' "$($admins.Count) member(s): $names"
        }
    } catch {
        Add-Result 'Accounts' 'Local Administrators membership' 'Warn' "Could not enumerate: $($_.Exception.Message)"
    }

    try {
        $builtin = Get-LocalUser -ErrorAction Stop | Where-Object { $_.SID -like 'S-1-5-*-500' }
        if ($builtin) {
            if ($builtin.Enabled) {
                Add-Result 'Accounts' 'Built-in Administrator disabled' 'Fail' `
                    "Account '$($builtin.Name)' is enabled" `
                    'Disable it and use named administrative accounts so actions are attributable.'
            } else {
                Add-Result 'Accounts' 'Built-in Administrator disabled' 'Pass' "Account '$($builtin.Name)' is disabled"
            }
        }
    } catch {
        Add-Result 'Accounts' 'Built-in Administrator disabled' 'Warn' $_.Exception.Message
    }

    try {
        $cutoff = (Get-Date).AddDays(-$StaleAccountDays)
        $users  = Get-LocalUser -ErrorAction Stop | Where-Object Enabled

        $stale = $users | Where-Object {
            $_.LastLogon -ne $null -and $_.LastLogon -lt $cutoff
        }
        if ($stale) {
            Add-Result 'Accounts' "Dormant local accounts (>$StaleAccountDays days)" 'Fail' `
                (($stale | ForEach-Object { "$($_.Name) ($($_.LastLogon.ToString('yyyy-MM-dd')))" }) -join ', ') `
                'Disable accounts that are no longer used. Dormant enabled accounts are a common foothold.'
        } else {
            Add-Result 'Accounts' "Dormant local accounts (>$StaleAccountDays days)" 'Pass' 'None found'
        }

        # Get-LocalUser exposes PasswordExpires (a date) on every build; the
        # PasswordNeverExpires boolean is not present on all of them, so derive it.
        $neverExpires = $users | Where-Object {
            $null -eq $_.PasswordExpires -and $_.Enabled
        }
        if ($neverExpires) {
            Add-Result 'Accounts' 'Passwords set to never expire' 'Warn' `
                (($neverExpires | ForEach-Object Name) -join ', ') `
                'Acceptable for managed service accounts; review anything else.'
        } else {
            Add-Result 'Accounts' 'Passwords set to never expire' 'Pass' 'None found'
        }
    } catch {
        Add-Result 'Accounts' 'Local account review' 'Warn' $_.Exception.Message
    }
}

# ---------------------------------------------------------------- firewall ---
function Test-Firewall {
    try {
        foreach ($p in (Get-NetFirewallProfile -ErrorAction Stop)) {
            if ($p.Enabled) {
                Add-Result 'Firewall' "$($p.Name) profile enabled" 'Pass' `
                    "Inbound: $($p.DefaultInboundAction)"
            } else {
                Add-Result 'Firewall' "$($p.Name) profile enabled" 'Fail' `
                    'Profile is disabled' `
                    'Enable the profile. Disabling the domain profile is a finding in any audit.'
            }
            if ($p.DefaultInboundAction -eq 'Allow') {
                Add-Result 'Firewall' "$($p.Name) default inbound" 'Fail' `
                    'Default inbound action is Allow' `
                    'Set the default inbound action to Block and permit only what is required.'
            }
        }
    } catch {
        Add-Result 'Firewall' 'Firewall profiles' 'Warn' $_.Exception.Message
    }
}

# ---------------------------------------------------------------- defender ---
function Test-Defender {
    try {
        $s = Get-MpComputerStatus -ErrorAction Stop

        if ($s.RealTimeProtectionEnabled) {
            Add-Result 'Defender' 'Real-time protection' 'Pass' 'Enabled'
        } else {
            Add-Result 'Defender' 'Real-time protection' 'Fail' 'Disabled' `
                'Re-enable real-time protection, and establish why it was turned off.'
        }

        $age = $s.AntivirusSignatureAge
        if ($age -le 3) {
            Add-Result 'Defender' 'Signature age' 'Pass' "$age day(s)"
        } elseif ($age -le 7) {
            Add-Result 'Defender' 'Signature age' 'Warn' "$age day(s)" 'Check update connectivity.'
        } else {
            Add-Result 'Defender' 'Signature age' 'Fail' "$age day(s)" `
                'Signatures are stale. Run Update-MpSignature and confirm the update path.'
        }

        if ($s.PSObject.Properties.Name -contains 'IsTamperProtected') {
            if ($s.IsTamperProtected) {
                Add-Result 'Defender' 'Tamper protection' 'Pass' 'Enabled'
            } else {
                Add-Result 'Defender' 'Tamper protection' 'Warn' 'Disabled' `
                    'Tamper protection stops malware disabling Defender. Enable via Intune or Security Center.'
            }
        }
    } catch {
        Add-Result 'Defender' 'Microsoft Defender status' 'Warn' `
            "Unavailable: $($_.Exception.Message)" 'Expected if a third-party AV has replaced Defender.'
    }

    try {
        $ex = Get-MpPreference -ErrorAction Stop
        $count = @($ex.ExclusionPath).Count
        if ($count -gt 0) {
            Add-Result 'Defender' 'Scan exclusions' 'Warn' "$count path exclusion(s) configured" `
                'Review each. Exclusions are a standard persistence trick - malware placed in an excluded path is never scanned.'
        } else {
            Add-Result 'Defender' 'Scan exclusions' 'Pass' 'None configured'
        }
    } catch { }
}

# --------------------------------------------------------------- bitlocker ---
function Test-BitLocker {
    if (-not $elevated) {
        Add-Result 'Encryption' 'BitLocker on system volume' 'Warn' 'Requires elevation'
        return
    }
    try {
        $sys = Get-BitLockerVolume -MountPoint $env:SystemDrive -ErrorAction Stop
        switch ($sys.ProtectionStatus) {
            'On' {
                Add-Result 'Encryption' 'BitLocker on system volume' 'Pass' `
                    "$($sys.VolumeStatus), $($sys.EncryptionMethod)"
            }
            default {
                Add-Result 'Encryption' 'BitLocker on system volume' 'Fail' `
                    "Protection is $($sys.ProtectionStatus)" `
                    'Enable BitLocker and escrow the recovery key to AD or Entra ID.'
            }
        }
    } catch {
        Add-Result 'Encryption' 'BitLocker on system volume' 'Warn' `
            "Unavailable: $($_.Exception.Message)" 'Expected on editions without BitLocker.'
    }
}

# ------------------------------------------------------- legacy protocols ---
function Test-LegacyProtocols {
    try {
        $smb1 = Get-SmbServerConfiguration -ErrorAction Stop
        if ($smb1.EnableSMB1Protocol) {
            Add-Result 'Protocols' 'SMBv1 disabled' 'Fail' 'SMBv1 is enabled' `
                'Disable SMBv1. It has no secure configuration and was the vector for WannaCry and NotPetya.'
        } else {
            Add-Result 'Protocols' 'SMBv1 disabled' 'Pass' 'Not enabled'
        }

        if ($smb1.PSObject.Properties.Name -contains 'RequireSecuritySignature') {
            if ($smb1.RequireSecuritySignature) {
                Add-Result 'Protocols' 'SMB signing required' 'Pass' 'Required'
            } else {
                Add-Result 'Protocols' 'SMB signing required' 'Warn' 'Not required' `
                    'SMB signing prevents relay attacks. Required by default on current builds.'
            }
        }
    } catch {
        Add-Result 'Protocols' 'SMB configuration' 'Warn' $_.Exception.Message
    }

    try {
        $llmnr = Get-ItemProperty 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\DNSClient' `
                    -Name EnableMulticast -ErrorAction Stop
        if ($llmnr.EnableMulticast -eq 0) {
            Add-Result 'Protocols' 'LLMNR disabled' 'Pass' 'Disabled by policy'
        } else {
            Add-Result 'Protocols' 'LLMNR disabled' 'Fail' 'Enabled' `
                'Disable LLMNR. It is the standard path for credential capture with Responder.'
        }
    } catch {
        Add-Result 'Protocols' 'LLMNR disabled' 'Fail' 'Not configured (enabled by default)' `
            'Set Computer Configuration > Administrative Templates > Network > DNS Client > Turn off multicast name resolution.'
    }
}

# -------------------------------------------------------------------- rdp ---
function Test-RemoteDesktop {
    try {
        $deny = (Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server' `
                    -Name fDenyTSConnections -ErrorAction Stop).fDenyTSConnections
        if ($deny -eq 1) {
            Add-Result 'Remote Access' 'RDP disabled' 'Pass' 'Not accepting connections'
            return
        }

        Add-Result 'Remote Access' 'RDP disabled' 'Warn' 'RDP is enabled' `
            'Acceptable for servers and admin hosts. Never expose 3389 to the internet.'

        $nla = (Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp' `
                    -Name UserAuthentication -ErrorAction Stop).UserAuthentication
        if ($nla -eq 1) {
            Add-Result 'Remote Access' 'Network Level Authentication' 'Pass' 'Required'
        } else {
            Add-Result 'Remote Access' 'Network Level Authentication' 'Fail' 'Not required' `
                'Enable NLA so authentication happens before a session is established.'
        }
    } catch {
        Add-Result 'Remote Access' 'RDP configuration' 'Warn' $_.Exception.Message
    }
}

# ------------------------------------------------------------- patch level ---
function Test-PatchLevel {
    try {
        $last = Get-HotFix -ErrorAction Stop |
                Where-Object InstalledOn |
                Sort-Object InstalledOn -Descending |
                Select-Object -First 1
        if (-not $last) {
            Add-Result 'Patching' 'Recent updates installed' 'Warn' 'No update history available'
            return
        }
        $age = [int]((Get-Date) - $last.InstalledOn).TotalDays
        $msg = "$($last.HotFixID) installed $($last.InstalledOn.ToString('yyyy-MM-dd')) ($age days ago)"
        if ($age -le $PatchAgeDays) {
            Add-Result 'Patching' 'Recent updates installed' 'Pass' $msg
        } else {
            Add-Result 'Patching' 'Recent updates installed' 'Fail' $msg `
                'Host is behind on patching. Confirm it is reporting to WSUS/Intune and not failing silently.'
        }
    } catch {
        Add-Result 'Patching' 'Recent updates installed' 'Warn' $_.Exception.Message
    }
}

# ---------------------------------------------------------------- logging ---
function Test-Logging {
    $base = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell'

    try {
        $sb = (Get-ItemProperty "$base\ScriptBlockLogging" -Name EnableScriptBlockLogging -ErrorAction Stop).EnableScriptBlockLogging
        if ($sb -eq 1) {
            Add-Result 'Logging' 'PowerShell script block logging' 'Pass' 'Enabled'
        } else { throw 'disabled' }
    } catch {
        Add-Result 'Logging' 'PowerShell script block logging' 'Fail' 'Not enabled' `
            'Enable it. Event 4104 captures deobfuscated script content and is often the only record of what an attacker ran.'
    }

    try {
        $md = (Get-ItemProperty "$base\ModuleLogging" -Name EnableModuleLogging -ErrorAction Stop).EnableModuleLogging
        if ($md -eq 1) {
            Add-Result 'Logging' 'PowerShell module logging' 'Pass' 'Enabled'
        } else { throw 'disabled' }
    } catch {
        Add-Result 'Logging' 'PowerShell module logging' 'Warn' 'Not enabled' `
            'Complements script block logging with pipeline execution detail.'
    }

    try {
        $sec = Get-WinEvent -ListLog Security -ErrorAction Stop
        $mb  = [math]::Round($sec.MaximumSizeInBytes / 1MB)
        if ($mb -ge 256) {
            Add-Result 'Logging' 'Security log size' 'Pass' "$mb MB"
        } else {
            Add-Result 'Logging' 'Security log size' 'Warn' "$mb MB" `
                'A small Security log rolls over in hours on a busy host, destroying the evidence you need after an incident.'
        }
    } catch {
        Add-Result 'Logging' 'Security log size' 'Warn' $_.Exception.Message
    }
}

# ------------------------------------------------------- credential theft ---
function Test-CredentialProtection {
    try {
        $lsa = Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa' -Name RunAsPPL -ErrorAction Stop
        if ($lsa.RunAsPPL -ge 1) {
            Add-Result 'Credentials' 'LSA protection (RunAsPPL)' 'Pass' 'Enabled'
        } else { throw 'disabled' }
    } catch {
        Add-Result 'Credentials' 'LSA protection (RunAsPPL)' 'Warn' 'Not enabled' `
            'Running LSASS as a protected process blocks the straightforward credential-dumping path.'
    }

    try {
        $wd = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System' `
                -Name LocalAccountTokenFilterPolicy -ErrorAction Stop
        if ($wd.LocalAccountTokenFilterPolicy -eq 1) {
            Add-Result 'Credentials' 'Remote UAC token filtering' 'Fail' 'Disabled (LocalAccountTokenFilterPolicy=1)' `
                'This allows local accounts full admin rights remotely and enables lateral movement between machines sharing a local password.'
        }
    } catch {
        Add-Result 'Credentials' 'Remote UAC token filtering' 'Pass' 'Default (filtering active)'
    }

    try {
        $laps = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Policies\LAPS' -ErrorAction Stop
        Add-Result 'Credentials' 'LAPS configured' 'Pass' 'Windows LAPS policy present'
    } catch {
        Add-Result 'Credentials' 'LAPS configured' 'Warn' 'No LAPS policy detected' `
            'Without LAPS, a shared local admin password means one compromised machine compromises all of them.'
    }
}

# ------------------------------------------------------------------- run ---
Test-LocalAccounts
Test-Firewall
Test-Defender
Test-BitLocker
Test-LegacyProtocols
Test-RemoteDesktop
Test-PatchLevel
Test-Logging
Test-CredentialProtection

if ($AsObject) { $script:Results; return }

# ---------------------------------------------------------------- summary ---
$colour = @{ Pass = 'Green'; Fail = 'Red'; Warn = 'Yellow'; Info = 'Cyan' }

Write-Host ''
Write-Host "  Security baseline - $env:COMPUTERNAME - $(Get-Date -Format 'yyyy-MM-dd HH:mm')" -ForegroundColor White
Write-Host ('  ' + ('-' * 74)) -ForegroundColor DarkGray

foreach ($group in ($script:Results | Group-Object Category)) {
    Write-Host ''
    Write-Host "  $($group.Name)" -ForegroundColor White
    foreach ($r in $group.Group) {
        Write-Host ('    [{0}] ' -f $r.Status.ToUpper().PadRight(4)) -ForegroundColor $colour[$r.Status] -NoNewline
        Write-Host $r.Check -NoNewline
        if ($r.Detail) { Write-Host "  - $($r.Detail)" -ForegroundColor DarkGray } else { Write-Host '' }
    }
}

$pass = @($script:Results | Where-Object Status -eq 'Pass').Count
$fail = @($script:Results | Where-Object Status -eq 'Fail').Count
$warn = @($script:Results | Where-Object Status -eq 'Warn').Count

Write-Host ''
Write-Host ('  ' + ('-' * 74)) -ForegroundColor DarkGray
Write-Host "  $pass pass   " -ForegroundColor Green -NoNewline
Write-Host "$fail fail   "   -ForegroundColor Red   -NoNewline
Write-Host "$warn warn"      -ForegroundColor Yellow

if ($fail -gt 0) {
    Write-Host ''
    Write-Host '  Remediation for failures:' -ForegroundColor White
    foreach ($r in ($script:Results | Where-Object { $_.Status -eq 'Fail' -and $_.Remediation })) {
        Write-Host "    * $($r.Check)" -ForegroundColor Red
        Write-Host "      $($r.Remediation)" -ForegroundColor DarkGray
    }
}
Write-Host ''

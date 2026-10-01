# PowerShell Automation for Active Directory

Bulk operations against Active Directory: provisioning, onboarding from CSV, offboarding, and the reporting queries that answer audit questions.

The GUI is fine for one account. It is the wrong tool for fifty, and it leaves no record of what was done. A script does the work identically every time and can be reviewed before it runs.

Language fundamentals are in [PowerShell Fundamentals](Powershell-Absolute-Fundamentals.md).

---

## Prerequisites

```powershell
# On a domain controller the module is present. On a workstation, install RSAT:
Get-WindowsCapability -Online -Name RSAT.ActiveDirectory* |
    Add-WindowsCapability -Online

Import-Module ActiveDirectory
Get-Command -Module ActiveDirectory | Measure-Object
```

The module name is `ActiveDirectory`, one word, no space.

Lab structure used throughout:

```text
DC=vbunnylab,DC=local
  OU=VBunnyLab
    OU=Accounting
    OU=HR
    OU=IT
    OU=Staff
    OU=Non-Staff
    OU=Servers
    OU=Workstations
```

---

## Single-Object Operations

Worth knowing before scripting them in bulk, because a bulk script is just these in a loop.

### Organisational Units

```powershell
New-ADOrganizationalUnit -Name 'VBunnyLab' -Path 'DC=vbunnylab,DC=local'

New-ADOrganizationalUnit -Name 'Accounting' `
    -Path 'OU=VBunnyLab,DC=vbunnylab,DC=local' `
    -ProtectedFromAccidentalDeletion $true
```

### Users

```powershell
$params = @{
    Name                  = 'Barry Allen'
    GivenName             = 'Barry'
    Surname               = 'Allen'
    SamAccountName        = 'ballen'
    UserPrincipalName     = 'ballen@vbunnylab.local'
    EmailAddress          = 'ballen@vbunnylab.local'
    Path                  = 'OU=IT,OU=VBunnyLab,DC=vbunnylab,DC=local'
    AccountPassword       = (Read-Host 'Temporary password' -AsSecureString)
    Enabled               = $true
    ChangePasswordAtLogon = $true
}
New-ADUser @params
```

Prompting with `Read-Host -AsSecureString` keeps the password out of console history, transcripts and the script file itself.

### Attributes, State and Passwords

```powershell
Set-ADUser -Identity ballen -EmailAddress 'barry.allen@vbunnylab.local' `
    -OfficePhone '555-0137' -Title 'Systems Analyst' -Department 'IT'

Disable-ADAccount -Identity hgranger
Enable-ADAccount  -Identity hgranger
Unlock-ADAccount  -Identity hpotter

Set-ADAccountPassword -Identity hpotter -Reset `
    -NewPassword (Read-Host 'New password' -AsSecureString)
Set-ADUser -Identity hpotter -ChangePasswordAtLogon $true
```

### Groups

```powershell
New-ADGroup -Name 'GG-IT-Staff' -GroupScope Global -GroupCategory Security `
    -Path 'OU=IT,OU=VBunnyLab,DC=vbunnylab,DC=local'

Add-ADGroupMember    -Identity 'GG-IT-Staff' -Members ballen, hpotter
Remove-ADGroupMember -Identity 'GG-IT-Staff' -Members hpotter -Confirm:$false

Get-ADGroupMember -Identity 'GG-IT-Staff' | Select-Object Name, SamAccountName
Get-ADPrincipalGroupMembership -Identity ballen | Select-Object Name
```

---

## Bulk Provisioning

Creates a set of OUs and populates each with users. Idempotent, and safe to re-run, because it checks for existence before creating anything.

Two things make this different from a quick loop: it supports `-WhatIf`, and it generates a **unique random password per account** rather than giving everyone the same one.

```powershell
<#
.SYNOPSIS
    Creates departmental OUs and provisions users into them.
.EXAMPLE
    .\New-BulkADUsers.ps1 -WhatIf
    Dry run. Shows what would be created without touching the directory.
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [string] $BaseOU     = 'OU=VBunnyLab,DC=vbunnylab,DC=local',
    [string] $Domain     = 'vbunnylab.local',
    [string] $ReportPath = ".\provisioning-$(Get-Date -f yyyyMMdd-HHmmss).csv"
)

Import-Module ActiveDirectory -ErrorAction Stop

# Generates a random password meeting complexity requirements.
function New-RandomPassword {
    param([int] $Length = 16)
    $upper = [char[]]'ABCDEFGHJKLMNPQRSTUVWXYZ'      # no I or O
    $lower = [char[]]'abcdefghijkmnopqrstuvwxyz'     # no l
    $digit = [char[]]'23456789'                      # no 0 or 1
    $sym   = [char[]]'!@#$%^&*-_=+'
    $all   = $upper + $lower + $digit + $sym

    # guarantee one of each class, then fill the remainder
    $chars = @(
        $upper | Get-Random
        $lower | Get-Random
        $digit | Get-Random
        $sym   | Get-Random
    )
    $chars += 1..($Length - 4) | ForEach-Object { $all | Get-Random }
    -join ($chars | Sort-Object { Get-Random })
}

$departments = @{
    'Accounting' = @('Barry Allen', 'Diana Prince')
    'HR'         = @('Clark Kent', 'Lois Lane')
    'IT'         = @('Bruce Wayne', 'Selina Kyle')
}

$report = New-Object System.Collections.Generic.List[object]

foreach ($dept in $departments.Keys) {
    $deptOU = "OU=$dept,$BaseOU"

    # --- OU ---
    $exists = Get-ADOrganizationalUnit -Filter "Name -eq '$dept'" -SearchBase $BaseOU -ErrorAction SilentlyContinue
    if (-not $exists) {
        if ($PSCmdlet.ShouldProcess($deptOU, 'Create OU')) {
            New-ADOrganizationalUnit -Name $dept -Path $BaseOU -ProtectedFromAccidentalDeletion $true
            Write-Verbose "Created OU: $dept"
        }
    }

    # --- users ---
    foreach ($fullName in $departments[$dept]) {
        $parts     = $fullName -split ' ', 2
        $givenName = $parts[0]
        $surname   = $parts[1]
        $sam       = ('{0}{1}' -f $givenName.Substring(0,1), $surname).ToLower() -replace '[^a-z0-9]', ''

        # resolve collisions rather than failing partway through the run
        $candidate = $sam
        $suffix    = 1
        while (Get-ADUser -Filter "SamAccountName -eq '$candidate'" -ErrorAction SilentlyContinue) {
            $candidate = "$sam$suffix"
            $suffix++
        }

        if ($candidate -ne $sam) { Write-Warning "$sam taken, using $candidate" }
        $sam = $candidate

        $password   = New-RandomPassword
        $userParams = [ordered]@{
            Name                  = $fullName
            DisplayName           = $fullName
            GivenName             = $givenName
            Surname               = $surname
            SamAccountName        = $sam
            UserPrincipalName     = "$sam@$Domain"
            EmailAddress          = "$sam@$Domain"
            Department            = $dept
            Path                  = $deptOU
            AccountPassword       = (ConvertTo-SecureString $password -AsPlainText -Force)
            Enabled               = $true
            ChangePasswordAtLogon = $true
        }

        if ($PSCmdlet.ShouldProcess($fullName, "Create user in $dept")) {
            try {
                New-ADUser @userParams -ErrorAction Stop
                $report.Add([pscustomobject]@{
                    Name       = $fullName
                    SamAccountName = $sam
                    Department = $dept
                    Password   = $password
                    Status     = 'Created'
                })
                Write-Verbose "Created $sam"
            }
            catch {
                $report.Add([pscustomobject]@{
                    Name       = $fullName
                    SamAccountName = $sam
                    Department = $dept
                    Password   = ''
                    Status     = "Failed: $($_.Exception.Message)"
                })
                Write-Warning "Failed $fullName : $($_.Exception.Message)"
            }
        }
    }
}

if ($report.Count) {
    $report | Export-Csv $ReportPath -NoTypeInformation
    Write-Host "Report written to $ReportPath" -ForegroundColor Green
    Write-Warning 'The report contains initial passwords. Deliver them securely and delete the file.'
}
```

> **Why one password per account.** A shared default like `Welcome123!` means that until every user logs in, one known password opens every new account, and new accounts are exactly the ones nobody is monitoring. Per-account random passwords remove that window entirely.

> **Run `-WhatIf` first, always.** A provisioning script that goes wrong against the wrong OU creates a mess that takes far longer to clean up than the dry run takes to read.

---

## CSV-Driven Onboarding

The realistic version of the above: HR supplies a spreadsheet, the script provisions from it.

**`new-starters.csv`**

```csv
FirstName,LastName,Department,Title,Manager
Barry,Allen,IT,Systems Analyst,bwayne
Diana,Prince,Accounting,Financial Analyst,ckent
Arthur,Curry,HR,HR Coordinator,ckent
```

**No password column.** A CSV of plaintext passwords gets emailed, left on a share and backed up. The script generates them instead and writes them to a separate report that gets deleted after delivery.

```powershell
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)]
    [ValidateScript({ Test-Path $_ })]
    [string] $CsvPath,

    [string] $BaseOU = 'OU=VBunnyLab,DC=vbunnylab,DC=local',
    [string] $Domain = 'vbunnylab.local'
)

Import-Module ActiveDirectory -ErrorAction Stop
$starters = Import-Csv $CsvPath

# --- validate the whole file before creating anything ---
$required = 'FirstName','LastName','Department'
$missing  = $required | Where-Object { $_ -notin $starters[0].PSObject.Properties.Name }
if ($missing) { throw "CSV is missing required column(s): $($missing -join ', ')" }

$problems = foreach ($row in $starters) {
    if (-not $row.FirstName -or -not $row.LastName) {
        "Blank name in row: $($row | ConvertTo-Json -Compress)"
    }
    $ou = "OU=$($row.Department),$BaseOU"
    if (-not (Get-ADOrganizationalUnit -Filter "DistinguishedName -eq '$ou'" -ErrorAction SilentlyContinue)) {
        "No OU for department '$($row.Department)'"
    }
}
if ($problems) {
    $problems | ForEach-Object { Write-Error $_ }
    throw 'Validation failed. Nothing was created.'
}

Write-Host "Validated $($starters.Count) row(s)." -ForegroundColor Green

foreach ($row in $starters) {
    $sam = ('{0}{1}' -f $row.FirstName.Substring(0,1), $row.LastName).ToLower() -replace '[^a-z0-9]',''
    # ... collision handling and New-ADUser as above ...
}
```

Validating the entire file up front is the important part. Failing on row 30 of 50 leaves the directory half-provisioned, and working out which half is manual.

---

## Bulk Offboarding

Disabling in bulk is genuinely dangerous, because the wrong `-SearchBase` disables the wrong department. This version defaults to a dry run and requires an explicit switch to act.

```powershell
[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
param(
    [Parameter(Mandatory)] [string] $SearchBase,
    [switch] $Execute
)

Import-Module ActiveDirectory -ErrorAction Stop

$users = Get-ADUser -Filter { Enabled -eq $true } -SearchBase $SearchBase -Properties LastLogonDate

if (-not $users) { Write-Host 'No enabled users found.' ; return }

Write-Host "`nFound $($users.Count) enabled account(s) in:" -ForegroundColor Yellow
Write-Host "  $SearchBase`n"
$users | Select-Object Name, SamAccountName, LastLogonDate | Format-Table -AutoSize

if (-not $Execute) {
    Write-Host 'Dry run. Re-run with -Execute to disable these accounts.' -ForegroundColor Cyan
    return
}

foreach ($user in $users) {
    if ($PSCmdlet.ShouldProcess($user.SamAccountName, 'Disable account')) {
        try {
            Disable-ADAccount -Identity $user.SamAccountName -ErrorAction Stop
            Set-ADUser -Identity $user.SamAccountName `
                -Description "Disabled $(Get-Date -f yyyy-MM-dd) by $env:USERNAME"
            Write-Host "Disabled: $($user.Name)" -ForegroundColor Yellow
        }
        catch {
            Write-Warning "Failed $($user.SamAccountName): $($_.Exception.Message)"
        }
    }
}
```

Re-enabling:

```powershell
Get-ADUser -Filter { Enabled -eq $false } -SearchBase $SearchBase |
    ForEach-Object {
        Enable-ADAccount -Identity $_.SamAccountName
        Write-Host "Enabled: $($_.Name)" -ForegroundColor Green
    }
```

> **Disable, never delete.** A deleted account takes its SID with it, and every file permission and mailbox reference that pointed at it. Disable, move to a holding OU, and delete only after the retention period.

Stamping the description with who disabled it and when costs nothing and answers the question that always comes later.

---

## Reporting Queries

The queries that answer audit and security questions.

```powershell
# accounts unused for 90+ days; dormant enabled accounts are a common foothold
Search-ADAccount -AccountInactive -TimeSpan 90.00:00:00 -UsersOnly |
    Where-Object Enabled |
    Select-Object Name, SamAccountName, LastLogonDate |
    Sort-Object LastLogonDate

# passwords that never expire
Get-ADUser -Filter { PasswordNeverExpires -eq $true -and Enabled -eq $true } `
    -Properties PasswordNeverExpires, PasswordLastSet |
    Select-Object Name, SamAccountName, PasswordLastSet

# privileged group membership
'Domain Admins','Enterprise Admins','Schema Admins','Account Operators' | ForEach-Object {
    $group = $_
    Get-ADGroupMember -Identity $group -ErrorAction SilentlyContinue |
        Select-Object @{n='Group';e={$group}}, Name, SamAccountName
}

# accounts with an SPN; these are Kerberoastable
Get-ADUser -Filter { ServicePrincipalName -like '*' } -Properties ServicePrincipalName, PasswordLastSet |
    Select-Object Name, SamAccountName, PasswordLastSet, ServicePrincipalName

# Kerberos pre-authentication disabled; AS-REP roastable
Get-ADUser -Filter { DoesNotRequirePreAuth -eq $true } -Properties DoesNotRequirePreAuth |
    Select-Object Name, SamAccountName

# locked out right now
Search-ADAccount -LockedOut | Select-Object Name, SamAccountName, LastLogonDate

# stale computer objects
Get-ADComputer -Filter { Enabled -eq $true } -Properties LastLogonDate, OperatingSystem |
    Where-Object { $_.LastLogonDate -lt (Get-Date).AddDays(-90) } |
    Select-Object Name, OperatingSystem, LastLogonDate

# effective password policy for a specific user
Get-ADUserResultantPasswordPolicy -Identity ballen
```

The SPN and pre-auth queries are the two most directly security-relevant. Any user account with a Service Principal Name can have its Kerberos ticket requested by **any authenticated user** and cracked offline, so a service account with a weak password and an SPN is a standing path to privilege escalation. Accounts with pre-authentication disabled are worse: no credentials are needed at all to request crackable material.

---

## Scheduling

```powershell
$action  = New-ScheduledTaskAction -Execute 'powershell.exe' `
    -Argument '-NoProfile -ExecutionPolicy Bypass -File "C:\Scripts\Get-StaleAccounts.ps1"'
$trigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Monday -At 7am
$principal = New-ScheduledTaskPrincipal -UserId 'VBUNNYLAB\svc-reports' -LogonType Password

Register-ScheduledTask -TaskName 'Weekly AD Hygiene Report' `
    -Action $action -Trigger $trigger -Principal $principal
```

Run scheduled scripts under a dedicated service account with only the rights the task needs, not Domain Admin and not a person's account. A group Managed Service Account (gMSA) is better still, because there is no password to store or rotate.

---

## Practices

- **`-WhatIf` before every bulk run.** Non-negotiable on anything that writes.
- **Validate the whole input first.** Half-provisioned is worse than not started.
- **Never hardcode a password**, and never put one in a CSV.
- **Handle SamAccountName collisions.** Two people called J. Smith will happen.
- **Log what changed**, to a CSV or the object description. "Who disabled this and when" always gets asked.
- **Filter server-side** with `-Filter` and `-SearchBase` rather than pulling the directory and discarding most of it.
- **Test against one object** before the whole OU.
- **`Set-ExecutionPolicy Bypass` is not a security decision.** It is a convenience flag and it protects nothing. Proper controls are script signing, constrained language mode and application control.

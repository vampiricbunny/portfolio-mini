# IT Troubleshooting Runbook

Common tickets and how I work them. Each one covers the symptom, the questions I ask, the fix, and what goes in the notes.

---

## How I Work a Ticket

Five steps. They rarely change.

1. **Get the real symptom.** "It's broken" is not a symptom. I want the exact error text and when it started.
2. **Find out what changed.** New laptop, password change, new network, recent update. Most faults follow a change.
3. **Scope it.** One user or everyone? One machine or all of them? This decides where to look.
4. **Test one thing at a time.** Change three things at once and you learn nothing.
5. **Write it down.** The next person should not have to rediscover it.

I verify identity before any password or MFA reset. Always. That check is the control, not a formality.

---

## Locked Account

**Symptom.** User cannot sign in. Says the account is locked.

**Questions.** When did it start? Any new phone or tablet? Any saved passwords anywhere?

**Fix.**

1. Verify identity first.
2. Open **Active Directory Users and Computers**.
3. Right-click the domain, choose **Find**, search the whole directory.
4. Open the user, go to the **Account** tab, tick **Unlock account**.
5. Apply.

```powershell
Search-ADAccount -LockedOut | Select-Object Name, SamAccountName, LastLogonDate
Unlock-ADAccount -Identity ballen
```

**Do not stop at the unlock.** Find out why it locked. A cached password on a phone or a service running as the user will lock it again in minutes. Event **4740** on the PDC emulator names the source machine.

```powershell
Get-WinEvent -FilterHashtable @{LogName='Security'; ID=4740} -MaxEvents 10 |
    Format-List TimeCreated, Message
```

Repeated lockouts from an outside address are not a forgetful user. That is password spraying. Escalate it.

---

## Password Reset

**Symptom.** User forgot their password.

**Verify identity first.** Call back on the number in the HR record. Never a number the caller gives you. A reset done for the wrong person hands over the account.

**Fix.**

1. Find the user in ADUC.
2. Right-click, **Reset Password**.
3. Set a temporary password.
4. Tick **User must change password at next logon**.
5. Tick **Unlock the user's account** if it is locked.

```powershell
Set-ADAccountPassword -Identity ballen -Reset -NewPassword (Read-Host -AsSecureString 'Temp')
Set-ADUser -Identity ballen -ChangePasswordAtLogon $true
```

Deliver the temporary password over a different channel than the request came in on. Record how you verified identity in the ticket.

A caller who resists verification or pushes for speed is running the standard social engineering play. Pressure means slow down.

---

## Cannot Reach a Shared Folder

**Symptom.** User cannot open a share. Sometimes they had access before.

**Questions.** Which folder exactly? Have you opened it before? What does the error say? Access denied, or path not found?

Those two errors mean different things. Access denied is permissions. Path not found is the mapping or the server.

**Fix for a lost mapping.**

1. Get the UNC path from the file server.
2. Remote in.
3. File Explorer, right-click **This PC**, **Map network drive**.
4. Enter the path, tick **Reconnect at sign-in**.

```powershell
Test-Path '\\FILE01\CompanyData\Finance'
New-PSDrive -Name S -PSProvider FileSystem -Root '\\FILE01\CompanyData\Finance' -Persist
```

If the mapping keeps vanishing, fix it properly with a Group Policy drive map instead of remapping it every month. See [File Server and Permissions](../Windows-Server-2025/File-Server-and-Permissions.md).

**Fix for access denied.**

Get manager approval first. Record it in the ticket. Then add the user to the security group that holds the permission. Do not add the user directly to the folder ACL.

```powershell
Add-ADGroupMember -Identity 'GG-Finance-Staff' -Members ballen
Get-ADPrincipalGroupMembership ballen | Select-Object Name
```

The user must sign out and back in. Group membership is baked into the Kerberos ticket at logon. This is why "I added you but it still says access denied" happens.

---

## Outlook Crashes on Launch

**Symptom.** Desktop Outlook crashes. Webmail works fine.

Webmail working is useful information. The mailbox is healthy. The problem is on the machine.

**Fix.**

1. Start Outlook in safe mode. `Win + R`, then `outlook.exe /safe`.
2. If it opens, the cause is an add-in or the profile.
3. **File**, **Options**, **Add-ins**, **Go**, untick everything.
4. Restart normally.
5. Re-enable add-ins one at a time until it breaks. That names the culprit.

Still crashing?

- Rebuild the profile. **Control Panel**, **Mail**, **Show Profiles**, add a new one.
- Quick Repair on Office. **Settings**, **Apps**, find Microsoft 365, **Modify**.
- Online Repair if Quick Repair fails. This one needs internet and takes a while.
- Microsoft SaRA for anything stubborn.

Send a confirmation email before closing. The user has to agree it is fixed.

---

## Excel Will Not Open

Same shape as Outlook.

**Questions.** One file or all files? Local file or one on a share?

One file means the file. All files means the install.

**Fix.**

1. Safe mode. `Win + R`, then `excel /safe`.
2. **File**, **Options**, **Add-ins**, manage **COM Add-ins**, **Go**, untick all.
3. Restart.
4. Quick Repair, then Online Repair.

If it is one file on a network share, copy it locally and open it. That separates a file problem from a network problem.

---

## Intermittent Internet

**Symptom.** Connection drops at random.

**Questions.** Just you or the whole floor? Wi-Fi or cable? What are you doing when it drops?

One user means the machine. A floor means infrastructure. That answer routes the ticket.

**Fix.**

Start with a reboot if uptime is long. It fixes more than people like to admit, and it costs two minutes.

Then:

```powershell
Get-NetAdapter | Select-Object Name, Status, LinkSpeed
ipconfig /all
pathping 8.8.8.8
```

`pathping` is the one that matters here. `tracert` shows the path. `pathping` samples every hop and reports packet loss. That is how you tell "slow" from "dropping packets".

On Wi-Fi, check signal strength and whether it drops when they move. On cable, check the negotiated link speed. A gigabit port sitting at 100 Mbps usually means a bad cable.

Full detail in [Network Troubleshooting](../Network/Networking-Troubleshooting.md).

---

## Slow Computer

**Symptom.** Everything is slow. Usually marked urgent.

**Fix.** Find the bottleneck before changing anything.

Open Task Manager, go to **Performance**.

| What you see | What it means |
| --- | --- |
| CPU at 100% | A runaway process, or the machine is undersized |
| Memory high and disk at 100% | Paging. It needs more RAM |
| Disk at 100%, CPU low | Failing disk, or a mechanical drive |
| Uptime measured in weeks | Reboot it |

```powershell
Get-Process | Sort-Object CPU -Descending | Select-Object -First 10 Name, CPU, WorkingSet
Get-CimInstance Win32_StartupCommand | Select-Object Name, Command
Get-PhysicalDisk | Select-Object FriendlyName, MediaType, HealthStatus
```

Then:

- Disable startup apps that do not need to run at boot
- Run Disk Cleanup with **Clean up system files**
- Check for pending updates and reboot
- Run a Defender scan

**A mechanical hard drive in a modern Windows install is the most common cause.** No amount of cleanup fixes it. The machine needs an SSD. Say so in the ticket rather than closing it as resolved.

---

## New Hire Setup

HR raises a ticket for someone starting Monday. Do it before Monday.

**Steps.**

1. Create the account in the right OU. Copy from a role template, not from a colleague.
2. Set a temporary password, force a change at first logon.
3. Add to the security groups the role needs. Nothing more.
4. Assign the Microsoft 365 licence, ideally through group-based licensing.
5. Add to the right Teams and distribution lists.
6. Confirm drive mappings arrive through Group Policy.
7. Prepare the machine and check it is domain joined.
8. Enrol MFA.

```powershell
New-ADUser -Name 'Barry Allen' -GivenName Barry -Surname Allen `
    -SamAccountName ballen -UserPrincipalName 'ballen@vbunnylab.local' `
    -Path 'OU=IT,OU=VBunnyLab,DC=vbunnylab,DC=local' `
    -AccountPassword (Read-Host -AsSecureString 'Temp') `
    -ChangePasswordAtLogon $true -Enabled $true

Add-ADGroupMember -Identity 'GG-IT-Staff' -Members ballen
```

**Copy from a maintained template account, not from a real person.** Copying a colleague carries over whatever extra access they picked up over the years. That is how permission creep spreads.

Bulk starters go through a script. See [PowerShell Automation](../PowerShell/Powershell-Automation.md).

---

## Offboarding

Same day the person leaves. Not next week.

1. Disable the account. Do not delete it.
2. Reset the password.
3. Revoke active sessions and tokens.
4. Record group memberships, then remove them.
5. Convert the mailbox to shared, or delegate it to the manager.
6. Move the object to a disabled accounts OU.
7. Note the date and ticket number in the description.
8. Collect the hardware.

```powershell
Disable-ADAccount -Identity ballen
Get-ADPrincipalGroupMembership ballen | Select-Object Name | Export-Csv .\ballen-groups.csv
Set-ADUser -Identity ballen -Description "Offboarded 2026-09-21, ticket INC0042"
```

Delete only after the retention period. A deleted account takes its SID with it, along with every file permission that referenced it.

---

## Quick Commands

```cmd
net user ballen /domain          :: account status, groups, password age
whoami /groups                   :: every group in the current token
gpresult /h report.html /f       :: what policy actually applied
klist                            :: Kerberos tickets
klist purge                      :: drop them and re-request
```

`net user /domain` is fast and answers most account questions in one line. Locked or not, password last set, group membership, expiry.

`whoami /groups` is the direct answer to "why can they do that". It shows the token as it is, with nested groups resolved at logon. A group added after sign-in will not be there.

---

## Writing the Ticket

Write it so the next occurrence takes half the time.

- What the user reported, in their words
- What you checked, including what came back clean
- What the cause turned out to be
- What fixed it
- Confirmation from the user

"Rebooted, works now" is a closed ticket. It is not a resolved fault. If you do not know why it broke, say that in the notes.

Update long-running tickets as you go. Timestamps and specifics. Not "still looking into it".

---

## Escalate When

- The fault is outside the endpoint. Switch, firewall, ISP, a server you do not own
- It affects many users and you have no cause
- It needs rights you do not have
- You have been on it past the SLA threshold
- There are signs of compromise

Hand over the scope, what you tested, the results, and what you ruled out. A good escalation saves the next person from starting over. A bad one just moves the ticket.

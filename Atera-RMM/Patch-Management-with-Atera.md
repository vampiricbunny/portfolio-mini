# Patch Management with Atera

Patching Windows and third-party software across an estate, on a schedule, without interrupting people.

Unpatched software is how most intrusions start. Not zero-days. Known vulnerabilities with patches available that nobody applied. Patch management is unglamorous and it does more for security posture than most things that get more attention.

---

## The Dashboard

**Patch Management** from the main menu.

| View | Shows |
| --- | --- |
| Available patches | Released, not yet installed |
| Missing patches by device | Which machine needs what |
| Patched devices | Up to date |
| Failed installations | Worth reading. These do not fix themselves |
| Requires reboot | Installed, pending restart |

**Failed installations and pending reboots are the two that get ignored.** A patch that installed but needs a reboot is not applied. A machine sitting at "requires reboot" for three weeks is unpatched in practice, whatever the dashboard says.

---

## Patch Categories

| Category | Include? |
| --- | --- |
| **Critical updates** | Yes |
| **Security updates** | Yes |
| **Definition updates** | Yes |
| **Update rollups** | Yes |
| **Service packs** | Yes, with testing |
| **Feature packs** | Test first |
| **Driver updates** | Careful |
| **Optional** | Usually not |

**Driver updates deserve caution.** A driver pushed automatically can break graphics, networking or audio across a fleet, and the fix means visiting every affected machine. Handle drivers separately from security patching, and test them first.

Security and critical updates are the ones that matter. Get those automated and reliable before worrying about anything else.

---

## Automation Profiles

**Admin**, **IT Automation**, create a profile.

A working maintenance profile:

| Setting | Value |
| --- | --- |
| Name | `Weekly-Patch-Workstations` |
| Schedule | Weekly, Saturday 01:00 |
| Categories | Critical, Security, Definition, Rollups |
| Reboot | If required, with user notification |
| Targets | Workstation device group |
| Maintenance window | 2 hours |

Add cleanup tasks to the same profile. Disk cleanup, temp file removal, and a report at the end.

### Separate Profiles for Servers

Servers should not patch on the same schedule as workstations.

| | Workstations | Servers |
| --- | --- | --- |
| Schedule | Weekly, overnight | Monthly, agreed window |
| Reboot | Automatic | Scheduled and announced |
| Categories | Critical, Security | Critical, Security, tested first |
| Grouping | All at once | Staggered, never all together |

**Never patch every domain controller at the same time.** Stagger them. Patching all of them in one window and hitting a bad update means no authentication anywhere.

---

## Staged Rollout

Patch in rings, the same principle as Intune update rings.

| Ring | Who | Delay |
| --- | --- | --- |
| **Pilot** | IT team, volunteers | 0 days |
| **Broad** | Most of the estate | 3 to 7 days |
| **Critical** | Finance, executive, fragile systems | 7 to 14 days |

The pilot ring finds the update that breaks the line-of-business application before it reaches everyone. A week of delay is a reasonable trade for not taking out the whole company on a Monday.

Create device groups per ring and assign a profile to each.

---

## Manual Patching

For a specific fix, or an out-of-cycle emergency.

1. **Patch Management**, **Available patches**.
2. Filter by patch or device.
3. Select the patches and the targets.
4. **Install**.

This is what you use when something is announced and you are not waiting for the weekly window.

---

## Reboots

Patches that need a reboot are not applied until it happens.

Options:

- **Reboot immediately.** Fine overnight, disruptive in hours
- **Prompt the user.** They choose, which means some never will
- **Scheduled reboot.** Announced window, best for servers
- **Defer with deadline.** Let them delay, force after N days

**Give a deadline, not an indefinite prompt.** A notification the user can dismiss forever gets dismissed forever, and the machine stays vulnerable while reporting as patched-but-pending.

Watch the pending reboot list weekly and chase anything sitting there.

---

## Third-Party Patching

Chrome, Firefox, Adobe Reader, Java, Zoom, 7-Zip.

**Third-party software is where a lot of real exposure sits.** Windows patches itself reasonably well by default. A browser three versions behind, or an old Java runtime, usually does not.

Atera handles common applications through its software catalogue. Anything not covered needs a script or a deployment package.

---

## Verify, Do Not Assume

A dashboard saying patched is not the same as patched.

```powershell
# what is actually installed
Get-HotFix | Sort-Object InstalledOn -Descending | Select-Object -First 10

# pending reboot
Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired'

# recent update errors
Get-WinEvent -FilterHashtable @{LogName='System'; ProviderName='Microsoft-Windows-WindowsUpdateClient'} -MaxEvents 20 |
    Where-Object LevelDisplayName -eq 'Error' |
    Select-Object TimeCreated, Message
```

Spot-check a few machines after each cycle rather than trusting the summary. A machine that has quietly failed to check in for two months shows as compliant on its last known state.

---

## When Patching Fails

| Symptom | Cause | Fix |
| --- | --- | --- |
| Patch fails repeatedly | Corrupt update components | Reset them, see below |
| Device never reports | Agent offline, or not checking in | Check the agent service |
| Stuck pending reboot | Nobody rebooted | Force a scheduled restart |
| Update downloads then fails | Disk space | Check free space |
| Fails with 0x80070643 | Common .NET or recovery partition issue | Check the specific KB |
| Machine patched, still flagged | Detection lag | Force a patch scan |

Reset the update components when a machine repeatedly fails:

```powershell
Stop-Service wuauserv, bits, cryptsvc -Force
Rename-Item "$env:SystemRoot\SoftwareDistribution" 'SoftwareDistribution.old'
Rename-Item "$env:SystemRoot\System32\catroot2" 'catroot2.old'
Start-Service wuauserv, bits, cryptsvc
```

Windows rebuilds both folders on the next scan. This fixes a large share of stubborn failures.

Push that as a script from Atera to every machine in the failed list rather than doing it by hand.

---

## Background Management

Patching aside, the agent gives you a lot without ever taking the user's screen.

- Remote task manager. Find and end a runaway process
- Service control. Restart a stopped service
- Command prompt and PowerShell
- Event log access
- File transfer
- Registry access
- Scheduled restart

**Most tickets can be resolved this way without interrupting anyone.** Restarting a print spooler does not need a remote session and a conversation. It needs thirty seconds in the background while the user carries on working.

Use an attended remote session when you need the user to see something, or when they need to walk you through what they did. Use background tools for everything else.

---

## Practices

- Automate security and critical patching. Manual patching does not scale and gets skipped
- Separate profiles for servers and workstations
- Stage rollouts, with a pilot ring
- Stagger domain controllers, always
- Give reboot deadlines rather than dismissible prompts
- Patch third-party software, not just Windows
- Read the failed list weekly and act on it
- Spot-check rather than trusting the dashboard
- Handle drivers separately and test them

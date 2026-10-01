# PDQ Inventory

Scanning Windows machines and keeping a live picture of what is on the estate. Hardware, software, patch level, services, local admins.

The value is not the list. It is being able to answer a question in seconds that otherwise takes a week of asking around.

"Which machines still have Log4j?"
"How many are below the current Windows build?"
"Who has a local admin account we did not create?"

Pairs with [PDQ Deploy](PDQ-Deploy-Automation.md). Inventory finds the machines, Deploy fixes them.

---

## Setup

1. Install on the same server as Deploy. They integrate.
2. Enter the licence key. Choose **Local** database for a small estate, SQL Server for a large one.
3. Add a credential with local admin on the targets. Same service account as Deploy.
4. Connect it to Active Directory.

---

## Adding Machines

**Add Computers**, then:

| Source | Use |
| --- | --- |
| **Active Directory** | Pull a whole OU or domain. The usual choice |
| **Text file** | Import a list |
| **Manual** | One machine |
| **Network scan** | Discover by IP range |

Set AD sync to run on a schedule so new machines appear on their own and decommissioned ones drop off.

---

## Scanning

Scan profiles decide what gets collected. Defaults cover most of it.

| Scanner | Collects |
| --- | --- |
| Applications | Installed software and versions |
| Hardware | CPU, RAM, disk, model, serial |
| Operating System | Version, build, install date |
| Hotfixes | Installed patches |
| Services | Name, state, startup type |
| Local Users and Groups | Accounts, group membership |
| Shares | Shared folders and permissions |
| Registry | Any key you specify |
| Files | Presence and version of a file |

**Add a custom scanner for the questions you keep getting asked.** A registry scanner reading a specific key, or a file scanner checking a version, turns "go and look at each machine" into a saved report.

Schedule scans nightly. Daily is enough for most estates.

---

## Collections

The feature that makes the tool useful.

A **Dynamic Collection** is a saved filter that keeps itself up to date. Membership changes as machines change.

Collections worth building on day one:

| Collection | Filter |
| --- | --- |
| Missing Chrome | Application, Name, does not contain, Chrome |
| Below current build | OS, Build, less than, current |
| Not scanned in 30 days | Computer, Last Scan, older than 30 days |
| Low disk space | Drive, Free Space, less than 10 GB |
| Unexpected local admins | Local group member, Administrators, not in your approved list |
| No antivirus | Service, name, not present |
| Old hardware | Hardware, Model, in a list |

Point a Deploy schedule at a collection and the whole thing becomes self-maintaining. "Machines missing Chrome" empties itself as the deployment runs.

**Not scanned in 30 days** is the collection people forget. Machines that stop reporting are either decommissioned or broken. Both need action.

---

## Reports

Right-click a machine, **Run Report**, or build your own under **Reports**.

Useful ones:

- **Installed applications** across the estate, grouped by version. This is how you find the one machine still on an old release
- **Missing patches**
- **Hardware summary** for a refresh cycle or a budget request
- **Local administrators** per machine
- **Services** not running that should be
- **Disk space**, sorted ascending

Reports export to CSV, Excel and HTML. Schedule them to email.

**The software version report is the one that earns its keep.** When a vulnerability is announced, that report tells you your exposure in about a minute.

---

## Machine Detail

Double-click a machine for everything held about it.

| Tab | Shows |
| --- | --- |
| Overview | Hardware, OS, last scan, last user |
| Applications | Everything installed, with versions |
| Hardware | CPU, memory, disks, serial |
| Hotfixes | Patch history |
| Services | State and startup type |
| Local Users and Groups | Accounts and membership |
| Shares | Shared folders |
| Deployments | What Deploy has sent it |

The serial number is the asset tag on most vendor hardware. Useful for warranty claims without walking to the machine.

---

## Tools

Right-click a machine for a set of actions that save a remote session.

- Remote Desktop
- Computer Management
- Registry Editor, remote
- Event Viewer
- PowerShell, remote session
- Reboot or shutdown
- Wake on LAN
- Rescan
- Deploy a package

```powershell
# what the tools do underneath
Enter-PSSession -ComputerName WS11-01
Get-Service -ComputerName WS11-01
Restart-Computer -ComputerName WS11-01 -Force
```

Being able to check a service or read an event log without disturbing the user is worth a lot on a busy queue.

---

## Where It Helps Most

**Vulnerability response.** Something is announced. Build a collection matching the affected version, see your exposure, point a Deploy schedule at it, watch the collection empty.

**Licence reconciliation.** Software the vendor says you have, against what is actually installed. The gap goes both ways and both directions cost money.

**Audit.** Local administrator accounts, unapproved software, unpatched machines. All standard audit questions, all one report.

**Asset lifecycle.** Machines by age and model, for planning a refresh with numbers rather than a guess.

**Finding shadow IT.** Software nobody approved, installed by users who found a workaround. It shows up in the application report whether anyone declared it or not.

---

## Troubleshooting

| Symptom | Cause | Fix |
| --- | --- | --- |
| Scan fails, machine online | Firewall or admin shares | Test `\\target\admin$` |
| Access denied | Credential lacks local admin | Check the service account |
| Data is stale | Scan schedule not running | Check the schedule and last scan time |
| Machine missing | AD sync not run, or outside scanned OU | Check sync settings |
| Partial data | That scanner failed | Look at the scan detail per scanner |
| Very slow scans | Too many scanners, or too many at once | Reduce concurrency, trim the profile |

```powershell
Test-NetConnection WS11-01 -Port 445
Test-Path '\\WS11-01\admin$'
Get-Service RemoteRegistry -ComputerName WS11-01
```

Remote Registry needs to be running for some scanners. It is disabled by default on newer builds, so set it to start by Group Policy if scans are coming back incomplete.

---

## Practices

- Scan nightly. Weekly data is too old to act on
- Build collections for the questions you get asked repeatedly
- Add custom scanners rather than checking things by hand
- Watch the not-scanned-recently collection
- Keep AD sync on, so the list matches reality
- Export a monthly snapshot. Historical data answers "when did this change"
- Point Deploy schedules at collections, not lists

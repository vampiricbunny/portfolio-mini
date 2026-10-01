# AnyDesk and Background Management

AnyDesk as an alternative remote connection method in Atera, and the background tools that fix most tickets without taking anyone's screen.

The background toolkit is the part worth knowing. A remote session interrupts someone for five minutes. Restarting a service from the console takes thirty seconds and the user never notices.

---

## AnyDesk in Atera

AnyDesk is an integration rather than a bundled tool, so it needs its own licence. Splashtop comes with Atera.

| | Splashtop | AnyDesk |
| --- | --- | --- |
| Licence | Included with Atera | Separate |
| Platforms | Windows, macOS | Windows, macOS, Linux, Android, iOS |
| Performance | Strong | Strong, good on poor links |
| Unattended | Yes | Yes |

**AnyDesk is worth it for mixed estates.** Linux and mobile coverage is better. For a Windows-only environment, bundled Splashtop does the job and costs nothing extra.

### Connecting

1. **Devices**, select the machine.
2. **Connect**, choose **AnyDesk**.
3. Session launches.
4. On attended connections the user approves the request.

---

## Background Management

**Manage** on the device page. This is where most work gets done.

| Tool | Use |
| --- | --- |
| **Task Manager** | See and end processes |
| **Service Manager** | Start, stop, restart services |
| **Command Prompt** | Run cmd remotely |
| **PowerShell** | Run PowerShell remotely |
| **Scripts** | Run a saved script |
| **File Browser** | Browse and transfer files |
| **Software Inventory** | What is installed |
| **Patch Management** | Patch status |
| **Event Viewer** | Read the logs |
| **Registry** | Read and edit |
| **Power actions** | Log off, restart, shut down |

All of it runs without interrupting the user.

---

## Service Manager

The single most used background tool.

**Manage**, **Service Manager**, find the service, Start, Stop or Restart.

The classic case is a stuck print spooler. One user reporting printing failures does not need a remote session and a conversation.

```powershell
Restart-Service Spooler
Get-Service Spooler | Select-Object Name, Status, StartType
```

Services worth knowing:

| Service | Fixes |
| --- | --- |
| `Spooler` | Print queue stuck |
| `wuauserv` | Windows Update not working |
| `WSearch` | Outlook and Windows search broken |
| `Dnscache` | Stale DNS resolution |
| `BITS` | Downloads failing |

---

## Task Manager

**Manage**, **Task Manager**. Processes with CPU and memory, sortable.

For a slow machine, look before you act.

| Reading | Means |
| --- | --- |
| One process pinning CPU | A runaway. End it |
| Memory high, disk at 100% | Paging. The machine needs more RAM |
| Disk 100%, CPU low | Failing disk, or a mechanical drive |
| Nothing obvious, everything slow | Check uptime, then disk health |

End the process, then work out why it happened. A browser at 90% CPU is usually a tab, not a fault.

```powershell
Get-Process | Sort-Object CPU -Descending | Select-Object -First 10 Name, CPU, WorkingSet
Stop-Process -Name chrome -Force
```

**Tell the user before ending anything with unsaved work.** Killing Excel silently loses their spreadsheet, and they will find out before you do.

---

## Command Prompt and PowerShell

Run as **System** or as the **logged-in user**.

That choice matters. System has full rights but no access to the user's mapped drives or profile. Logged-in user sees their environment but is limited by their permissions.

Use System for machine-level work. Use logged-in user for anything involving their profile, drives or per-user settings.

```powershell
# machine level, run as System
Get-Volume | Select-Object DriveLetter, SizeRemaining
Get-HotFix | Sort-Object InstalledOn -Descending | Select-Object -First 5
Get-NetIPConfiguration

# user context, run as logged-in user
net use
whoami /groups
```

---

## Scripts

**Manage**, **Scripts**. Saved scripts run against one device or many.

Worth having ready:

- Clear the print spooler
- Flush DNS and renew the address
- Reset Windows Update components
- Clear temporary files
- Collect diagnostics into a file

The value shows in an emergency. When a vulnerability is announced and no patch exists, pushing a mitigation to every managed endpoint in minutes is a very different response to visiting machines.

```powershell
# clear the spooler
Stop-Service Spooler -Force
Remove-Item "$env:SystemRoot\System32\spool\PRINTERS\*" -Force -ErrorAction SilentlyContinue
Start-Service Spooler
```

**Test on one machine first.** A script runs as SYSTEM across everything you target. A mistake scales instantly.

---

## Worked Example: Slow Machine, No Session Needed

**Reported.** Machine very slow. Marked urgent.

**Diagnosis, entirely in the background.**

Opened the device overview. Disk at 96% used, 4 GB free. Task Manager showed disk at 100% with low CPU, which points at paging or a failing disk.

```powershell
Get-Volume | Select-Object DriveLetter, SizeRemaining, Size
Get-PhysicalDisk | Select-Object FriendlyName, MediaType, HealthStatus
```

`MediaType` returned HDD. A mechanical drive on a current Windows build, nearly full.

**Fix.** Ran a cleanup script to clear temp files and the update cache, which recovered 18 GB. That improved things immediately.

**Real answer.** The machine needs an SSD. Put that in the ticket rather than closing it as resolved, because cleanup buys weeks, not a fix.

The user was never interrupted.

---

## Power Actions

**Log off**, **Restart**, **Shut down**.

Restart fixes more than anyone likes to admit, particularly on machines with weeks of uptime.

**Warn the user first.** Restarting a machine under someone loses their work and it is the fastest way to lose their trust. Schedule it, or ask.

Servers get scheduled restarts in an agreed window, announced in advance.

---

## Session vs Background

| Situation | Approach |
| --- | --- |
| Service needs restarting | Background |
| Check a setting or log | Background |
| Run a script | Background |
| Collect a file | Background |
| User needs to see something | Session |
| Walking a user through a process | Session |
| Reproducing something they describe | Session |
| Training | Session |

Default to background. Move to a session when you need the user's eyes on it.

---

## Practices

- Background first. Sessions when you need them
- Right execution context. System or logged-in user
- Warn before killing processes or restarting
- Test scripts on one machine before the fleet
- Log what you did, whether or not the user saw it
- MFA on the technician account
- Review the audit log. Every background action is logged and should be

# Level RMM

A modern RMM built around automation and browser-based remote control. Cross-platform, covering Windows, macOS, Linux and Raspberry Pi.

Two things set it apart from older RMM platforms. Remote control runs peer to peer in the browser, so no client to install and session traffic does not pass through Level's servers. And automation is the centre of the product rather than something bolted on.

---

## Platform Coverage

| OS | Agent | Remote control |
| --- | --- | --- |
| Windows 10 / 11 | Yes | Yes |
| Windows Server | Yes | Yes |
| macOS | Yes | Yes |
| Linux | Yes | Terminal. Screen control varies by distribution |
| Raspberry Pi | Yes | Terminal |

The Linux and Pi support is the reason to look at Level. Plenty of RMM platforms treat Linux as an afterthought.

---

## Deploying Agents

One line, run as administrator. The command from the console has your API key embedded, so there is nothing to configure on the machine.

**Windows**

```powershell
# from the console, Install New Agent, One-Line Command
# run in an elevated PowerShell session
iwr -useb https://installer.level.io/... | iex
```

**Linux**

```bash
sudo apt update
# paste the one-line command from the console
```

**macOS**

Same approach, a shell command from the console.

Device appears within seconds. Faster than most RMM platforms, because there is no MSI packaging step.

At scale, push the same command through Group Policy, Intune or PDQ rather than running it by hand.

---

## Grouping

Get this right early. Everything else targets groups.

**Create a group**, name it, then assign devices through **Actions**, **Assign to group**.

A structure that works:

```text
All Devices
  Windows
    Workstations
    Servers
  macOS
  Linux
  Pilot
```

Groups drive automation targets, policy assignment, alert thresholds and reporting. Ad hoc device lists do not scale, and they go stale the day you write them.

**Put a Pilot group in from the start.** It is where you test automations before they reach everything.

---

## Device View

Click a device for the full picture.

| Section | Shows |
| --- | --- |
| **Overview** | Security score, CPU, memory, disk, uptime, IP |
| **System** | OS, build, hardware, serial |
| **Manage** | Run commands, file explorer, processes, sensors |
| **Applications** | Installed software |
| **Updates** | Available patches |
| **Monitors** | Active monitors and their state |
| **Activity** | What has been done to this device |

**Uptime is worth watching.** A workstation with 60 days of uptime has pending patches that have never been applied, and it is probably the slow machine somebody is about to raise a ticket about.

The security score gives a quick posture read per device. Useful as a prompt, not as a compliance measure.

---

## Background Management

Under **Manage**, without taking the user's screen.

- Run commands and see the output
- Browse the file system
- View and end processes
- Read sensor data
- Restart, shut down, log off
- Install updates
- Run scripts

```powershell
ipconfig /all
Get-Service Spooler
Get-Volume | Select-Object DriveLetter, SizeRemaining
```

Most tickets are solvable here. A remote session interrupts someone. Checking a service does not need to.

### Bulk Actions

Select multiple devices and act on all of them.

- Install updates
- Restart
- Run a script
- Assign to a group

This is where an RMM stops being a monitoring tool. Pushing a fix to 40 machines in one action is a different job to visiting 40 desks.

---

## Remote Control

1. Open the device.
2. Remote icon, top right.
3. Session connects in the browser.

**Peer to peer, browser based.** No client to install on either end, and the session does not route through Level's infrastructure. That is a genuine privacy and latency advantage.

During a session you get system information, command execution, file access and power actions in a side panel, so you rarely need to leave the session to look something up.

Linux screen control is still developing. The terminal works well, which covers most Linux work anyway.

---

## Monitors

Monitors watch for conditions and can remediate automatically.

Worth setting up:

| Monitor | Trigger |
| --- | --- |
| Disk space | Below 10% free |
| CPU sustained | Above 90% for 15 minutes |
| Memory | Above 90% |
| Uptime | Over 30 days |
| Service stopped | Named service not running |
| BSOD | Crash detected |
| Agent offline | No check-in for 24 hours |

**Automatic remediation is the feature worth using.** A stopped service monitor that restarts the service and only alerts if the restart fails turns a recurring ticket into a non-event.

Tune thresholds early. Alerts nobody reads are worse than no alerts, because they train people to ignore the console.

---

## Reporting

**Reporting** covers:

- Total devices, online and offline
- OS distribution
- Devices flagged for attention
- Patch compliance
- Devices in maintenance

OS distribution is useful for planning. Knowing how many machines are still on an older build tells you the size of an upgrade project without a survey.

---

## Security

Level enforces some of this rather than leaving it optional.

| Control | Notes |
| --- | --- |
| **Mandatory 2FA** | Enforced on all accounts |
| **IP restrictions** | Limit console access by source |
| **Role-based access** | Technicians get only what they need |
| **Audit logging** | Every action recorded |
| **P2P remote control** | Session data does not traverse Level's servers |

**Mandatory 2FA is the right default.** An RMM account has system-level access to every managed endpoint. Platforms that leave MFA optional have been compromised through exactly that gap, and used to push ransomware to every managed device at once.

Review the audit log periodically. Who ran what script, against which devices, and when.

---

## Practices

- Group structure before deploying agents
- A pilot group, and use it
- Tune monitor thresholds in the first month
- Automatic remediation where the fix is reliable
- Background management before remote sessions
- Watch uptime and patch compliance, not just alerts
- Role-based access, not everyone as admin
- Remove technician accounts the day someone leaves

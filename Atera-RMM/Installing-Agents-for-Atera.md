# Deploying Atera Agents

Installing the agent on Windows, Windows Server and Ubuntu, plus the dependency failure that comes up on Linux.

The agent is what does the work. Without it on a machine, that machine is invisible.

---

## Before Deploying

Set the customer and site structure first, and set threshold profiles first. Agents installed against defaults produce an unusable alert queue on day one.

Requirements:

- Outbound HTTPS to Atera. No inbound rules needed
- Local admin to install
- Windows 8.1 or later, Server 2012 R2 or later
- Ubuntu, Debian, CentOS, RHEL on the Linux side

The agent polls out. That means it works on laptops off the corporate network, which is the main reason an RMM beats Group Policy for reaching remote machines.

---

## Windows

### One Machine

1. **Devices**, **Install Agent**, select **Windows**.
2. Assign to a customer and site.
3. Download the installer, or copy the command line.
4. Run it on the target.

The installer is pre-configured with the customer assignment, so there is nothing to type on the machine.

### Command Line

Better for scripted or remote deployment.

```cmd
msiexec /i AteraAgent.msi /qn IntegratorLogin=tech@vbunnylab.com CompanyId=1 AccountId=xxxx
```

The exact string comes from the console with your identifiers already filled in.

### At Scale

| Method | Use |
| --- | --- |
| **Group Policy** | Domain-joined machines. Software installation policy |
| **PDQ Deploy** | Where you already have it. See [PDQ Deploy](../PDQ/PDQ-Deploy-Automation.md) |
| **Intune** | Cloud-managed. Package as Win32 |
| **Login script** | Simple, if the estate is small |
| **Manual** | One-offs and servers |

For a domain, Group Policy or PDQ is the least effort. For anything Entra-joined, package it for Intune. See [App Deployment](../Intune/App-Deployment.md).

### Verify

The device appears in the console within a few minutes.

```powershell
Get-Service AteraAgent | Select-Object Name, Status, StartType
Get-Process AteraAgent -ErrorAction SilentlyContinue
```

Not appearing? Check the service is running, check outbound HTTPS is not blocked, and check the installer had the right account identifiers.

---

## Windows Server

Same installer, same process. Two things to think about.

**Run it as administrator from an elevated command prompt.** A standard shell will fail partway.

**Review the threshold profile.** Server thresholds should differ from workstations. A server at 90% memory may be entirely normal. A workstation at 90% is not.

Once the agent is on, the device page gives you the full picture. Available patches, hardware, disks, connectivity and remote access.

---

## Windows 11 Client

No difference from Windows 10. Install, assign, verify.

Worth noting for a lab: if the VM is on a host-only network with no route out, the agent cannot reach Atera. Switch to NAT for the install and the check-in, then back if you need isolation.

Once managed, the device page gives you Wake on LAN, scheduled restart, remote connect, and live health.

---

## Ubuntu

Linux uses a shell script rather than an MSI.

1. **Devices**, **Install Agent**, select **Linux**.
2. Assign customer and site.
3. Copy the generated command.
4. Run it in a terminal on the target.

```bash
sudo /bin/bash -c "$(curl -L https://atera-agent-repo.s3.amazonaws.com/...)"
```

The exact URL and parameters come from the console.

### The .NET Dependency Failure

This is the one that comes up, and the error does not explain itself.

**Symptom.** The install script runs and appears to complete. The agent never appears in the console. Checking the service:

```bash
systemctl status ateraagent.service
```

Returns `Unit ateraagent.service could not be found`, or the service is inactive.

**Cause.** The Atera agent is built on .NET. The installer does not always pull the runtime, and without it the service file is never registered. The install reports success because the script itself ran.

**Fix.**

Remove the partial install first, or the reinstall inherits the broken state:

```bash
sudo systemctl stop ateraagent.service 2>/dev/null
sudo rm -rf /usr/lib/atera-agent
sudo rm -f /etc/systemd/system/ateraagent.service
sudo systemctl daemon-reload
```

Install the runtime:

```bash
sudo apt update
sudo apt install -y dotnet-runtime-6.0
```

Check which version Atera currently requires. It has moved between releases, and installing the wrong major version leaves you in the same place.

Confirm it is there:

```bash
dotnet --list-runtimes
```

Re-run the Atera install script.

**Verify.**

```bash
systemctl status ateraagent.service
journalctl -u ateraagent.service -n 50 --no-pager
```

The service should be `active (running)`, and the device should appear in the console within a few minutes.

On distributions where the runtime is not in the default repositories, add the Microsoft package repository first.

---

## What Managed Linux Gives You

Less than Windows, but useful.

- Hardware and OS inventory
- Disk, CPU and memory monitoring
- Package updates
- Shell script execution
- Service monitoring

Patch management on Linux works through the native package manager, so apt or yum. It is not the same feature set as Windows Update integration, but it covers keeping packages current.

---

## Troubleshooting

| Symptom | Cause | Fix |
| --- | --- | --- |
| Agent not appearing | Outbound HTTPS blocked | Check the firewall and proxy |
| Installer fails immediately | Not elevated | Run as administrator |
| Wrong customer assigned | Wrong installer used | Move the device in the console |
| Shows offline, machine is on | Service stopped | Restart the AteraAgent service |
| Duplicate device entries | Reinstalled or machine renamed | Delete the stale record |
| Linux service not found | .NET runtime missing | See above |
| Agent installs then disappears | Cloned machine with a duplicate ID | Reinstall on the clone |

```powershell
Restart-Service AteraAgent
Get-EventLog -LogName Application -Source Atera* -Newest 20
```

```bash
sudo systemctl restart ateraagent.service
journalctl -u ateraagent.service -f
```

**Duplicate agent IDs from cloned VMs is a common lab problem.** Install the agent after cloning, not before, or every clone reports as the same device.

---

## Removing an Agent

Uninstall it before decommissioning a machine, and delete the device record in the console.

```powershell
Get-Package -Name "Atera*" | Uninstall-Package
```

```bash
sudo /usr/lib/atera-agent/uninstall.sh
```

An agent left on a disposed or sold machine is a live managed endpoint with system-level access, sitting outside your network. Removing it is part of decommissioning, not an afterthought.

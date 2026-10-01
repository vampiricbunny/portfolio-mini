# PDQ Deploy

Pushing software, patches and scripts to Windows machines from one console instead of walking to each desk.

PDQ Deploy is built for Windows-only environments and it is fast to get running. The Package Library covers most common software already packaged and tested, which removes the part of software deployment that usually takes longest.

---

## What It Does

- Installs applications silently across many machines at once
- Keeps third-party software patched
- Runs PowerShell, batch or VBScript against targets
- Schedules deployments for out of hours
- Retries failures automatically when a machine comes back online

Pairs with [PDQ Inventory](PDQ-Inventory.md). Inventory finds the machines that need something, Deploy sends it.

---

## Setup

Install on a server or an admin workstation that stays on. It needs to reach the targets over SMB and a service account with local admin rights on them.

1. Download from the PDQ site. There is a free tier and a 14-day Enterprise trial.
2. Install and enter the licence key.
3. **Options**, **Preferences**, **Credentials**. Add a domain account with local admin on the targets.
4. Point it at Active Directory under **Options**, **Preferences**, **Active Directory**.

**Use a dedicated service account**, not your own. Deployments run as that account, and it needs local admin on every target. That makes it a high-value credential, so it should be documented, monitored and not reused anywhere else.

> Requirements on the targets: file and printer sharing on, admin shares available, and the firewall permitting SMB from the PDQ server. On a locked-down network, this is the part that needs a firewall rule.

---

## The Console

| Area | Holds |
| --- | --- |
| **Package Library** | Pre-built, pre-tested packages maintained by PDQ |
| **Packages** | Your local copies and anything custom |
| **Schedules** | Recurring and triggered deployments |
| **Deployments** | History, with per-target results |
| **Retry Queue** | Targets that were offline, retried automatically |

**The Retry Queue is the feature that makes this practical.** Laptops are off, asleep or off-network constantly. Instead of the deployment failing, the target sits in the queue and gets picked up when it reappears.

---

## Deploy a Package

1. **Package Library**, find the application.
2. Right-click, **Download Selected**. It copies into your local Packages.
3. Right-click the local package, **Deploy Once**.
4. **Choose Targets**:
   - **Active Directory**, then browse to computers or an OU
   - **PDQ Inventory** collection, which is the better option
   - Type a computer name
   - Import from a text file
5. **Deploy Now**.

Progress shows live. Each target reports success, failure or offline.

**Targeting an Inventory collection beats a static list.** A collection like "Machines without Chrome" stays accurate on its own. A list you typed is out of date the day you write it.

---

## Scheduling

**Schedules**, **New Schedule**.

| Trigger | Fires when |
| --- | --- |
| Interval | Every N hours or days |
| Daily / Weekly | Fixed time |
| Heartbeat | A target comes online |
| Once | One specific time |

**Heartbeat is the one for laptops.** The deployment waits and runs the moment the machine appears on the network, rather than failing because it was closed at 2am.

Under **Options** on a schedule:

- **Stop deploying to targets after success**, so machines are not reinstalled every cycle
- **Only deploy to offline targets when they come online**
- Set a deployment window so nothing installs during the working day

Scheduling patches for 2am with a heartbeat fallback covers desktops and laptops in one schedule.

---

## Custom Packages

For software not in the Library.

1. **New Package**, name it.
2. Add an **Install** step.
3. Point it at the installer file.
4. Set the silent switches:

   ```text
   MSI:  /qn /norestart
   EXE:  varies. Check the vendor
   ```

5. Add conditions under the step if needed, such as architecture or OS.
6. Add further steps for registry changes, files or a post-install script.

Multi-step packages run in order and stop on failure by default, which is usually what you want. Installing an application then applying its configuration is a two-step package.

**Test on one machine before deploying widely.** A silent switch that is subtly wrong installs but leaves the application unconfigured, and you find out from fifty users rather than one.

---

## Deploying Scripts

A PowerShell step turns Deploy into a fleet-wide script runner.

Useful for:

- Clearing a stuck print spooler across a floor
- Applying a registry fix
- Collecting a file or a log from every machine
- Emergency mitigation when a vulnerability is announced and no patch exists yet

That last one is the valuable case. When something like PrintNightmare appears, being able to push a mitigation to the whole estate in minutes is the difference between a controlled response and a long week.

```powershell
# example mitigation step
Stop-Service Spooler -Force
Set-Service Spooler -StartupType Disabled
```

Same rule as always. Test it on one machine first.

---

## Monitoring

**Deployments** shows history with per-target output, including the installer's own exit code.

| Result | Means |
| --- | --- |
| Successful | Exit code 0 |
| Failed | Non-zero exit. Read the output |
| Offline | Unreachable. Goes to the Retry Queue |

Common exit codes:

| Code | Meaning |
| --- | --- |
| 0 | Success |
| 1603 | Generic MSI failure |
| 1618 | Another install already running |
| 1619 | Package could not be opened |
| 3010 | Success, reboot required |

**3010 is a success.** It gets reported as a failure by people who have not seen it before. The install worked, the machine wants a reboot.

---

## Troubleshooting

| Symptom | Cause | Fix |
| --- | --- | --- |
| All targets offline | Firewall, or admin shares disabled | Test `\\target\admin$` from the PDQ server |
| Access denied | Service account lacks local admin | Check the credential and its rights |
| Installs but app missing | Wrong silent switch | Test the command manually |
| 1603 | Generic MSI failure | Enable MSI logging and read it |
| Works on one machine, fails elsewhere | Architecture, OS version, or existing version | Add conditions to the step |
| Deployment hangs | Installer showing a prompt | Wrong silent switch |

```powershell
Test-NetConnection FILE01 -Port 445
Test-Path '\\WS11-01\admin$'
```

A hanging deployment is nearly always an installer waiting on a dialog that nobody can see. The switch is wrong.

---

## Practices

- Dedicated service account, documented and monitored
- Target Inventory collections, not typed lists
- Test on one machine before the fleet
- Schedule outside working hours, with heartbeat for laptops
- Use the Package Library where it covers the software. It is maintained and tested
- Keep custom packages versioned in the name
- Read the Retry Queue. Machines that never come back are usually decommissioned and still in AD
- Get approval before pushing software to user machines, and record it in the ticket

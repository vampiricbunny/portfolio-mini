# Automation with Level

Building automations in Level. Triggers, actions, conditions, and the library of ready-made automations worth starting from.

Automation is the reason to run an RMM. Monitoring tells you something is wrong. Automation fixes it before anyone raises a ticket.

---

## Structure

Every automation has three parts.

| Part | Does |
| --- | --- |
| **Trigger** | What starts it. A tag, a schedule, a monitor, or manual |
| **Conditions** | Which devices qualify. OS, platform, group, installed software |
| **Actions** | What runs, in order |

**Conditions are what stop an automation doing damage.** An action with no condition runs everywhere it is triggered, including the machines it was never meant for.

### Triggers

| Trigger | Use |
| --- | --- |
| **Manual** | Run on demand against selected devices |
| **Tag applied** | Tag a device, automation runs |
| **Schedule** | Recurring maintenance |
| **Monitor** | Fires when a monitor trips. Self-healing |
| **Device onboarded** | New machine setup |

**Tag-based is the most flexible.** Tag a device `setup` and the onboarding automation runs. Remove the tag at the end and it will not run again.

**Monitor-triggered is where the real value is.** A monitor detects a stopped service, the automation restarts it, and the alert only reaches a human if the restart fails.

---

## Building One: Install an Application

Example installing 7-Zip through winget.

1. **Automations**, **Create**, name it `Install-7Zip`.
2. Trigger: **Manual**, or a tag such as `install-7zip`.
3. Add a condition:
   - **Operating System** equals **Windows**
4. Add actions:
   - **App Management**, **Install winget**
   - **App Management**, **Install winget package**, package ID `7zip.7zip`
5. Save.

Test on one machine, then a small group, then broadly.

**Install winget first.** Older Windows builds may not have it, and the package install step fails silently without it.

Winget package IDs come from `winget search`:

```powershell
winget search 7zip
winget install --id 7zip.7zip --silent --accept-package-agreements --accept-source-agreements
```

---

## The Library

Level ships a library of ready-made automations. **Resources**, **Library** on the site, then **Import into Level**.

Worth importing early:

| Automation | Does |
| --- | --- |
| Common Windows applications | Browsers, Zoom, 7-Zip, password managers |
| Windows patching | OS and third-party updates |
| Linux patching | apt or yum updates |
| Prompt user to restart | Notifies, waits, then forces |
| OSQuery monitors | Uptime, disk, process monitoring |
| Disk cleanup | Temp files and update cache |
| BitLocker enablement | Encryption with key escrow |

Imported automations arrive with sensible triggers and conditions already set. **Read them before running.** They are a starting point, not something to fire blind. Check the schedule, the conditions and the actions against your environment.

---

## Worked Example: Application Rollout

**Goal.** Install a standard application set on new machines.

**Setup.** Imported **Common Windows applications** from the library. Reviewed the actions and removed two applications not used here.

**Trigger.** Tag `setup`.

**Condition.** Platform equals Windows.

**Test.** Applied the tag to two machines, one Windows 10 and one Windows 11, and ran it.

**Result.** Both completed. The Windows 10 machine skipped applications already present, which is correct behaviour and worth confirming rather than assuming. One package failed on the Windows 11 machine.

**Diagnosing the failure.** A failed package is normally one of three things:

- The winget ID changed. IDs do get renamed between versions
- The package needs a dependency not present
- The installer needs a different silent switch

Checking the automation log gives the actual exit code, which points at which.

**Worth noting:** a partial success is still a useful result. Nine of ten applications installed unattended across two machines, and the tenth is now a known item rather than an unknown.

---

## Worked Example: Restart Prompt on Linux

Restarting a machine under someone is the fastest way to lose their goodwill. This handles it properly.

**Trigger.** Tag `restart`.

**Condition.** Platform equals Linux.

**Actions.**

1. **Notification**, user approval. Prompts the user to restart.
2. Configuration: 180 minute window, 3 attempts, force restart if no response.
3. **Restart endpoint**.
4. **Remove tag**, so it does not repeat.

**Result.** User was prompted, approved, machine rebooted, tag removed.

**The force-after-deadline is the part that matters.** A prompt the user can dismiss indefinitely gets dismissed indefinitely, and the machine stays unpatched. Three attempts over three hours is reasonable notice, and then it happens anyway.

**Removing the tag at the end** is what stops the automation firing again on the next evaluation. Easy to forget, and it produces a device that reboots repeatedly.

---

## Worked Example: Patching

**Windows Server.**

Imported **Windows patching** from the library. Adjusted before running:

- Turned off the weekly schedule, since this was a one-off run
- Turned off third-party application upgrades for the first run, to isolate OS patching from application changes

Selected the server, **Actions**, **Run automation**, chose Windows patching.

Patching completed and the security score improved substantially. **That score movement is the point of the exercise.** A machine missing months of updates scores poorly, and applying them moves it into a reasonable range. Check the score before and after on your own machines so you know what patching is actually worth in your environment.

**Linux.**

Same approach with the Linux patching automation. Applied package updates and enabled the firewall.

Enabling the firewall as part of the same run is worth noting. Patching closes known vulnerabilities. The firewall reduces what is reachable in the first place. They address different problems and both move the score.

**Stagger servers.** Never run a patching automation against every domain controller at once. A bad update with no staggering means no authentication anywhere.

---

## Self-Healing

The pattern worth building toward.

```text
Monitor: Print Spooler service stopped
   -> Automation: restart the service
   -> Verify: is it running?
   -> If yes: log it, no alert
   -> If no: raise an alert for a human
```

Applies to a lot of recurring issues:

| Condition | Automatic response |
| --- | --- |
| Service stopped | Restart it |
| Disk below 10% | Run cleanup, alert if still low |
| Agent not checked in | Attempt a restart of the agent service |
| Windows Update failing | Reset update components |
| Temp folder oversized | Clear it |

**Only automate remediation you trust.** An automation that fires on a false positive and restarts a production service is worse than the alert it replaced. Start with low-risk actions and watch them for a while before adding anything disruptive.

---

## Testing

Automations run as SYSTEM across every device they match. A mistake scales instantly.

1. Build it with conditions in place from the start
2. Run against **one** device
3. Read the log, confirm the exit codes
4. Run against a pilot group
5. Then broadly

Keep a **Pilot** group permanently. It costs nothing and it catches the automation that works on your machine and fails on everyone else's.

---

## Practices

- Conditions on every automation, without exception
- Read imported library automations before running them
- Test on one device, then a pilot group, then the fleet
- Remove trigger tags at the end of the automation
- Force restarts after a deadline, do not rely on prompts
- Stagger server patching
- Build self-healing for the issues you see repeatedly
- Read the logs. A green result with a non-zero exit code is not a success

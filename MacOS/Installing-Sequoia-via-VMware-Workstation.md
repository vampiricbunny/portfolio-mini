# macOS Sequoia in VMware Workstation

Building a macOS 15 Sequoia VM on Windows hardware for lab work.

Supporting a mixed estate means being able to answer macOS questions without borrowing someone's laptop. A VM gives you somewhere to check where a setting lives before walking a user through it.

---

## Licensing, Stated Plainly

Apple's software licence agreement permits macOS virtualisation **only on Apple-branded hardware**. Running it under VMware on a Windows PC is outside that licence.

Worth knowing and worth saying. In a workplace, the compliant options are a Mac mini as a shared lab machine, a virtualised guest on Apple hardware, or a hosted Mac service. Those are what an employer would expect you to propose.

The rest of this documents the technical process.

---

## Requirements

| | Minimum | Comfortable |
| --- | --- | --- |
| CPU | 4 cores with virtualisation enabled | 6 or more |
| RAM | 8 GB host | 16 GB or more |
| Disk | 80 GB free | 120 GB |
| VMware Workstation | 17 or later | Current |

Intel VT-x or AMD-V must be enabled in firmware. Disabled virtualisation is the most common reason the VM will not start, and the error does not say so clearly.

AMD hosts need extra configuration and are less reliable for this. Intel is smoother.

---

## Prerequisites

| Tool | Purpose |
| --- | --- |
| **VMware Workstation Pro** | The hypervisor |
| **Python 3** | Runs the unlocker |
| **OCVM / Unlocker** | Adds macOS as a guest OS option |
| **macOS Sequoia installer** | The OS image |

**VMware does not offer macOS as a guest type by default.** The unlocker patches that in. Without it, macOS is not in the list at all.

Sources:

- [OCVM releases](https://github.com/DrDonk/OCVM/releases)
- [OpenCorePkg](https://github.com/acidanthera/OpenCorePkg)
- [Python](https://www.python.org)

Read what you are running before running it. These tools modify VMware's installed files and need administrator rights.

---

## Patch VMware

1. Fully close VMware Workstation.
2. Stop the VMware services.

   ```powershell
   Get-Service VMware* | Stop-Service -Force
   Get-Service VMware* | Select-Object Name, Status
   ```

3. Extract the unlocker.
4. Run its installer as administrator.
5. Restart VMware.

Check it worked. **Create a new VM**, and Apple macOS should now appear in the guest OS list.

**Re-run the unlocker after a VMware upgrade.** An upgrade replaces the patched files and macOS disappears from the list again. That catches people out, and it looks like the VM broke.

---

## Create the VM

1. **File**, **New Virtual Machine**, **Custom (advanced)**.
2. Hardware compatibility: latest.
3. **I will install the operating system later**.
4. Guest OS: **Apple Mac OS X**, version **macOS 14** or later.
5. Name it, choose a location.
6. Processors: 2 or 4 cores.
7. Memory: 8192 MB.
8. Network: NAT.
9. SCSI controller and disk type: accept defaults.
10. Disk size: 100 GB, single file.
11. **Finish**.

### Edit the VMX

Close VMware. Open the `.vmx` file in a text editor and add:

```text
smc.version = "0"
```

Without it the VM typically fails to boot on the first attempt.

On an AMD host, additional CPU flags are usually needed. Check current guidance, as it changes with VMware versions.

---

## Install

1. Attach the macOS installer image to the CD/DVD device.
2. Power on.
3. Boot to the installer.
4. **Disk Utility** from the recovery menu.
5. Select the VMware virtual disk, **Erase**.
   - Name: `Macintosh HD`
   - Format: **APFS**
   - Scheme: **GUID Partition Map**
6. Quit Disk Utility.
7. **Install macOS**, select the disk you just formatted.
8. Wait. It reboots several times. That is normal.

**The disk must be erased and formatted first.** The installer will not offer an unformatted virtual disk as a target, and the reason is not obvious from the screen.

Expect 30 to 60 minutes depending on the host.

---

## Setup Assistant

Work through region, keyboard and network.

**Sign in with Apple Account** can be skipped. Choose **Set Up Later**. A lab VM does not need an Apple ID, and using a personal one ties it to hardware Apple does not recognise.

Create a local account and finish.

---

## VMware Tools for macOS

Standard VMware Tools does not cover macOS. It needs **darwin.iso**, which the unlocker package provides.

1. **VM**, **Settings**, **CD/DVD**, point at `darwin.iso`.
2. In macOS, open the mounted disc and run the installer.
3. Approve the system extension when prompted.
4. **System Settings**, **Privacy and Security**, click **Allow** for VMware.
5. Restart.

**The approval step is easy to miss.** macOS blocks third-party system extensions by default, and the prompt is a small banner in Privacy and Security rather than a dialog. Without approving it, display scaling and clipboard sharing do not work and it looks like the install failed.

---

## Common Problems

| Symptom | Cause | Fix |
| --- | --- | --- |
| macOS not in the guest list | Unlocker not applied | Run it as admin, VMware fully closed |
| VM will not boot, restarts in a loop | Missing `smc.version = "0"` | Add it to the `.vmx` |
| Stuck on the Apple logo | Insufficient resources, or CPU flags | Raise RAM, check virtualisation is enabled |
| Very slow | No VMware Tools, or too little RAM | Install darwin.iso, raise memory |
| Resolution stuck small | VMware Tools not installed or not approved | Install and approve the extension |
| No network | Adapter not connected | Check VM settings, NAT |
| Broke after a VMware update | Patch overwritten | Re-run the unlocker |
| Installer will not see the disk | Not formatted | Erase as APFS with GUID in Disk Utility |

---

## What the Lab Is For

Once it runs, it covers most support scenarios you need to be able to answer.

- Where settings live, so you can direct a user accurately
- Activity Monitor, Disk Utility, Console
- Terminal commands, covered in [macOS for IT Support](MacOS-For-IT-Support.md)
- Printer setup
- Network configuration
- Permissions and Privacy prompts, which cause a lot of real tickets
- Installing and removing applications

It does not cover hardware faults, Apple Silicon behaviour, Secure Enclave, Touch ID, or anything requiring real Apple hardware. A VM answers "where is that setting" reliably. It does not answer "why does this specific MacBook behave oddly".

For MDM work, a real enrolled device is required. Apple Business Manager and Automated Device Enrollment need genuine hardware with a serial Apple recognises.

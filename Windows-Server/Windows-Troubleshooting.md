# Windows Troubleshooting

Field runbook for the Windows faults that make up most of a support queue. Organised by symptom, because that is how they arrive.

---

## Method

The technique matters more than any individual command.

1. **Establish what actually happens.** "It's broken" is not a symptom. Get the exact error text, when it started, and whether it affects one user, one machine, or everyone.
2. **Establish what changed.** Updates, a new policy, a password change, new hardware, a move to a different network. Most faults follow a change.
3. **Scope it.** One user on every machine points at the account. Every user on one machine points at the machine. One user on one machine points at the profile.
4. **Form one hypothesis and test it.** Changing several things at once means not knowing which one worked.
5. **Fix the cause, not the symptom.** Clearing a print queue daily is not a fix.
6. **Write it down.** The next person to see it should not have to rediscover it.

---

## Slow Performance

### Identify the Bottleneck First

```powershell
Get-Process | Sort-Object CPU -Descending | Select-Object -First 10 Name, CPU, WorkingSet
Get-Process | Sort-Object WorkingSet -Descending | Select-Object -First 10 Name, WorkingSet
Get-Counter '\Processor(_Total)\% Processor Time','\Memory\Available MBytes'
```

`Ctrl + Shift + Esc` → **Performance** tab. Read it in this order:

| Reading | Indicates |
| --- | --- |
| CPU pinned at 100% | A runaway process, or genuinely undersized |
| Memory high, **disk at 100%** | Paging - the real cause is insufficient RAM |
| Disk at 100% with low CPU | Failing disk, or a mechanical drive under a modern OS |
| Long "Up time" | Uptime of weeks on a workstation is worth a reboot |

**Disk at 100% on a machine with a mechanical drive is the most common cause of "slow" in practice.** An SSD is the fix, and no amount of cleanup substitutes for it.

### Standard Remediations

```powershell
# what starts with Windows
Get-CimInstance Win32_StartupCommand | Select-Object Name, Command, Location

# disk space
Get-Volume | Select-Object DriveLetter, FileSystemLabel,
    @{n='FreeGB';e={[math]::Round($_.SizeRemaining/1GB,1)}},
    @{n='SizeGB';e={[math]::Round($_.Size/1GB,1)}}
```

- **Task Manager** → **Startup apps** - disable what does not need to run at boot.
- **Disk Cleanup** (`cleanmgr`) → **Clean up system files** - removes superseded update files, often several GB.
- **Adjust for best performance**: **Advanced system settings** → **Performance** → **Settings**. Disables visual effects. Helps on genuinely old hardware, negligible on anything modern.
- **Check for pending updates and reboot.** A machine waiting to finish an update is frequently the answer.

> **Virtual memory is not RAM.** Increasing the page file lets a machine avoid out-of-memory errors; it does not make it faster, because the page file lives on disk. If a machine is paging heavily, it needs more RAM.

---

## Boot and Startup Failures

| Symptom | First action |
| --- | --- |
| Stuck on spinning dots | Hard power off, boot again - Windows enters recovery after repeated failures |
| "Preparing Automatic Repair" loop | Recovery → **Startup Repair**, then **Uninstall latest updates** |
| BSOD with a stop code | Record the stop code; check the minidump |
| "No bootable device" | Boot order in firmware; check the disk is detected |
| Boots to a black screen with cursor | `Ctrl+Shift+Esc` → **File** → **Run new task** → `explorer.exe` |

Access recovery: hold **Shift** while clicking **Restart**, or interrupt boot three times.

```powershell
# system file integrity - run DISM first, then SFC
DISM /Online /Cleanup-Image /RestoreHealth
sfc /scannow

# recent unexpected shutdowns and boot errors
Get-WinEvent -FilterHashtable @{LogName='System'; ID=41,6008,1001} -MaxEvents 20 |
    Select-Object TimeCreated, Id, Message
```

The order matters - SFC repairs from the component store, so if that store is itself damaged, SFC fails until DISM has repaired it.

**Safe Mode:** `msconfig` → **Boot** → **Safe boot**, or from the recovery menu. If the fault disappears in Safe Mode, it is a driver or a third-party service - use **Clean Boot** (`msconfig` → **Services** → **Hide all Microsoft services** → **Disable all**) to find which.

---

## Network Connectivity

Work outward from the machine.

```powershell
Get-NetAdapter | Select-Object Name, Status, LinkSpeed
Get-NetIPConfiguration
Test-NetConnection 10.10.10.1                      # gateway
Test-NetConnection 10.10.10.10 -Port 53            # DNS service, not just the host
Test-NetConnection vbunnylab.local -Port 389       # LDAP - domain reachability
Resolve-DnsName vbunnylab.local
```

| Reading | Meaning |
| --- | --- |
| `169.254.x.x` | No DHCP response - see [DHCP](../Network/DHCP.md) |
| No IP at all | Adapter disabled, cable, or driver |
| IP correct, gateway unreachable | Local network or VLAN problem |
| Gateway fine, names fail | DNS - see [DNS](../Network/DNS.md) |
| Works by IP, not by name | DNS, or a stale `hosts` entry |

Standard reset:

```powershell
ipconfig /release
ipconfig /renew
ipconfig /flushdns
netsh winsock reset          # requires a reboot
netsh int ip reset           # requires a reboot
```

### The hosts File

Overrides DNS entirely, and is a common cause of "works everywhere except this machine."

```powershell
Get-Content $env:SystemRoot\System32\drivers\etc\hosts
Start-Process notepad "$env:SystemRoot\System32\drivers\etc\hosts" -Verb RunAs
```

> Unexpected entries here are worth treating as a finding, not just a misconfiguration. Redirecting hostnames via `hosts` is a known malware behaviour - particularly entries pointing security vendors or update servers at `127.0.0.1`.

---

## Printing

See [Printer Issues](../Troubleshooting/Printer-Issues.md) for the full runbook.

Stuck queue:

```powershell
Stop-Service Spooler
Remove-Item "$env:SystemRoot\System32\spool\PRINTERS\*" -Force
Start-Service Spooler

Get-Printer | Select-Object Name, PrinterStatus, PortName
Get-PrintJob -PrinterName 'HP-Accounting'
```

Clearing the spool directory is what actually removes a job that refuses to cancel - the service has to be stopped first or the files are locked.

---

## Disk Health

```powershell
Get-PhysicalDisk | Select-Object FriendlyName, MediaType, HealthStatus, OperationalStatus
Get-Volume | Select-Object DriveLetter, HealthStatus, SizeRemaining

# SMART status
Get-CimInstance -Namespace root\wmi -ClassName MSStorageDriver_FailurePredictStatus
```

```cmd
chkdsk C: /scan          :: online, no reboot
chkdsk C: /f /r          :: schedules a full check at next boot - takes hours
```

`/r` also scans for bad sectors, which on a large mechanical disk can run overnight. Do not start it on a user's machine mid-morning.

> `HealthStatus` anything other than `Healthy`, or a SMART prediction of failure, means back up now and replace the disk. Neither `chkdsk` nor anything else repairs failing hardware.

---

## Windows Update

```powershell
# force a scan (wuauclt is deprecated on current builds)
UsoClient StartScan

# what is installed
Get-HotFix | Sort-Object InstalledOn -Descending | Select-Object -First 10

# failures
Get-WinEvent -FilterHashtable @{LogName='System'; ProviderName='Microsoft-Windows-WindowsUpdateClient'} -MaxEvents 20 |
    Where-Object LevelDisplayName -eq 'Error' | Select-Object TimeCreated, Message
```

Reset the update components when updates fail repeatedly:

```powershell
Stop-Service wuauserv, bits, cryptsvc -Force
Rename-Item "$env:SystemRoot\SoftwareDistribution" "SoftwareDistribution.old"
Rename-Item "$env:SystemRoot\System32\catroot2" "catroot2.old"
Start-Service wuauserv, bits, cryptsvc
```

Windows rebuilds both folders on the next scan.

---

## Applications

```powershell
# installed software - registry is more reliable than Win32_Product
$paths = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
         'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
Get-ItemProperty $paths |
    Where-Object DisplayName |
    Select-Object DisplayName, DisplayVersion, Publisher |
    Sort-Object DisplayName

# kill a hung process
Get-Process -Name excel | Stop-Process -Force
```

> **Avoid `Win32_Product`.** Querying it triggers a consistency check on every installed MSI, which is slow and can reconfigure packages as a side effect. The registry keys above are the safe way to enumerate software. `wmic` itself is deprecated and absent from current Windows builds.

Uninstall via **Settings** → **Apps** → **Installed apps**, or `winget uninstall <id>` where the package is managed by winget.

---

## User Profile and Logon

| Symptom | Cause | Fix |
| --- | --- | --- |
| "We can't sign in to your account" | Corrupt profile - loaded temporary | Rebuild the profile; copy data from `C:\Users\<name>` |
| "Trust relationship failed" | Computer account password out of sync | `Test-ComputerSecureChannel -Repair` |
| "No logon servers available" | Cannot reach a DC - usually DNS | `nltest /dsgetdc:vbunnylab.local` |
| Account locked out repeatedly | Cached credential somewhere | Event 4740 on the PDC emulator |
| Group membership not taking effect | Token cached at logon | Sign out and back in |
| Very slow logon | GPO processing, or roaming profile size | `gpresult /h report.html /f` |

```powershell
Test-ComputerSecureChannel -Repair -Credential (Get-Credential)
whoami /groups
klist                      # Kerberos tickets
klist purge                # discard them; next access re-requests
```

---

## BitLocker

```powershell
Get-BitLockerVolume
manage-bde -status C:
(Get-BitLockerVolume -MountPoint C).KeyProtector
```

Enable with recovery key escrow to Active Directory:

```powershell
Enable-BitLocker -MountPoint 'C:' -EncryptionMethod XtsAes256 -UsedSpaceOnly -TpmProtector
Backup-BitLockerKeyProtector -MountPoint 'C:' -KeyProtectorId (Get-BitLockerVolume -MountPoint C).KeyProtector[1].KeyProtectorId
```

> **Escrow recovery keys centrally** - to Active Directory or Entra ID via Group Policy or Intune, not to a USB stick in a drawer. A recovery key that only exists on the encrypted machine is not a recovery key. In ADUC, keys appear on the computer object's **BitLocker Recovery** tab once **Advanced Features** is enabled.

---

## System Information

```powershell
Get-ComputerInfo | Select-Object CsName, WindowsProductName, OsVersion,
    WindowsVersion, OsArchitecture, CsManufacturer, CsModel,
    @{n='RAM_GB';e={[math]::Round($_.CsTotalPhysicalMemory/1GB,1)}}

winver                     # build number, quickly
systeminfo                 # includes hotfixes and boot time
slmgr /xpr                 # activation status
Get-CimInstance Win32_BIOS | Select-Object SerialNumber
```

The BIOS serial number is the asset tag on most vendor hardware - useful when raising a warranty claim.

---

## Command Reference

| Task | Command |
| --- | --- |
| System file repair | `DISM /Online /Cleanup-Image /RestoreHealth` then `sfc /scannow` |
| Disk check | `chkdsk C: /scan` |
| Network reset | `ipconfig /flushdns`, `netsh winsock reset` |
| Group Policy refresh | `gpupdate /force` |
| Policy report | `gpresult /h report.html /f` |
| Reliability history | `perfmon /rel` |
| Event logs | `eventvwr.msc` |
| Services | `services.msc` |
| Startup config | `msconfig` |
| Defender scan | `Start-MpScan -ScanType QuickScan` |
| Defender signatures | `Update-MpSignature` |
| Kill a process | `Stop-Process -Name <name> -Force` |
| Remote session | `Enter-PSSession -ComputerName <host>` |

**`perfmon /rel`** - the Reliability Monitor - is underused. It presents a timeline of crashes, failed updates and installs, which answers "what changed" faster than reading the event log.

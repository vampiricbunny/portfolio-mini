# macOS for IT Support

Supporting Macs from a Windows background. The tools are different, the diagnostic logic is the same.

Most Windows knowledge transfers. Activity Monitor is Task Manager. Disk Utility is Disk Management. Console is Event Viewer. What changes is where things live and what the permissions model does.

---

## Windows to macOS

| Windows | macOS | Opens with |
| --- | --- | --- |
| Task Manager | Activity Monitor | `Cmd + Space`, type it |
| Control Panel / Settings | System Settings | Apple menu |
| Disk Management | Disk Utility | Spotlight |
| Event Viewer | Console | Spotlight |
| File Explorer | Finder | Dock |
| Command Prompt | Terminal | Spotlight |
| Services | launchd | `launchctl` |
| Registry | plist files | `defaults` command |
| Program Files | /Applications | Finder |
| AppData | ~/Library | `Cmd + Shift + G` |
| Safe Mode | Safe Mode | Hold Shift at boot |

`Cmd + Space` is Spotlight and it is the fastest way to open anything. Learn it first.

**`~/Library` is hidden by default.** Finder, **Go**, **Go to Folder**, then type the path. Or hold `Option` while clicking Go and Library appears in the menu.

---

## Slow Mac

**Open Activity Monitor.** `Cmd + Space`, type Activity Monitor.

### CPU

Sort by **% CPU**, descending. Look for anything consistently above 80%, a stuck system process, or a third-party application misbehaving.

### Memory

The **Memory Pressure** graph at the bottom is the reading that matters, not the numbers above it.

| Colour | Means |
| --- | --- |
| **Green** | Healthy. Plenty of memory available |
| **Yellow** | Under pressure, starting to swap |
| **Red** | Swapping heavily. This is the cause of the slowness |

**Do not diagnose from "memory used".** macOS deliberately uses available RAM for caching, so a machine will always look nearly full. That is by design and is not a problem. Memory pressure is the honest indicator.

Red pressure means the machine needs more RAM, or fewer applications open. On Apple Silicon, RAM is not upgradeable, so this becomes a hardware conversation.

### Fixes

- Quit high-memory applications, or Force Quit if unresponsive
- **System Settings**, **General**, **Login Items and Extensions**, remove what does not need to launch at boot
- Clear user cache. `~/Library/Caches`, delete folder contents, not the folder
- Check free disk space. Under 10% free slows macOS noticeably
- Restart if uptime is long

```bash
top -o cpu
vm_stat
df -h
sudo purge          # force a memory cleanup, mostly diagnostic
```

---

## Battery Draining Fast

1. **Activity Monitor**, **Energy** tab. Sort by **Energy Impact**.
2. Look at **Avg Energy Impact** rather than the instantaneous figure. It reflects sustained use.
3. Check **Preventing Sleep** for anything keeping the machine awake.
4. **System Settings**, **Battery**, check **Battery Health**.

Common culprits: browser tabs with video or heavy scripting, Teams, Zoom, cloud sync clients doing a large initial sync, and Spotlight reindexing after an upgrade.

**Low Power Mode** is under **System Settings**, **Battery**. Reduces performance to extend runtime.

**Check cycle count and condition.** Apple menu, hold Option, **System Information**, **Power**. A battery reporting Service Recommended is a hardware ticket, not a software one.

```bash
pmset -g batt
system_profiler SPPowerDataType | grep -A5 "Health Information"
```

---

## Wi-Fi Dropping

Usually stale network profiles or a saved network conflicting.

**Quick reset without a reboot:**

```bash
sudo ifconfig en0 down && sudo ifconfig en0 up
```

`en0` is normally Wi-Fi on a laptop. Confirm with `networksetup -listallhardwareports`.

**Remove old networks.** **System Settings**, **Wi-Fi**, **Advanced**. Delete networks no longer used, particularly old office or hotel networks.

**Reorder preferred networks.** The Mac joins the highest in the list it can see. A guest network sitting above the corporate one causes exactly the behaviour users describe as random.

**Renew the lease.** **System Settings**, **Wi-Fi**, **Details**, **TCP/IP**, **Renew DHCP Lease**.

```bash
networksetup -listallhardwareports
networksetup -getairportnetwork en0
ipconfig getpacket en0                       # full DHCP detail
sudo dscacheutil -flushcache
sudo killall -HUP mDNSResponder              # flush DNS
```

Those last two together are the macOS equivalent of `ipconfig /flushdns`.

---

## Storage Full

**Apple menu**, **System Settings**, **General**, **Storage**. The breakdown shows what is using space.

Quick wins:

- Empty Trash. Enable **Empty Trash Automatically** for 30 days
- Delete large files from the Documents recommendation
- Remove old iOS backups
- Clear `~/Library/Caches`
- Check `/Library/Application Support` for leftovers from removed applications

`Option + Cmd + Delete` deletes immediately, bypassing Trash. Useful when Trash itself is holding a lot of space.

```bash
du -sh ~/Library/Caches/*
du -sh /Applications/* | sort -h | tail -20
ls -lh ~/Library/Application\ Support/
```

**Purgeable space confuses people.** macOS reports space held by iCloud-offloaded files and snapshots as available, but it is not immediately free. A machine reporting 50 GB free can still refuse a 10 GB file.

```bash
tmutil listlocalsnapshots /
sudo tmutil deletelocalsnapshots <date>
```

Time Machine local snapshots are a frequent cause of storage that will not free up.

---

## External Drive Not Showing

Check in order.

1. **Finder Settings**, **General**, confirm **External disks** is ticked. This is the most common answer and takes five seconds
2. **Finder Settings**, **Sidebar**, confirm external disks show there
3. **Disk Utility**. Is the drive listed but not mounted? Select it, click **Mount**
4. Try a different cable and port. Many USB-C cables are charge-only
5. Check the format. NTFS drives are read-only on macOS without third-party software

```bash
diskutil list
diskutil info disk2
diskutil mount /dev/disk2s1
```

**An NTFS drive from a Windows machine will mount read-only.** The user reports they cannot save to it. That is expected behaviour, not a fault. exFAT works read-write on both platforms and is the right format for a shared drive.

---

## Printing

### Add a Printer

**System Settings**, **Printers and Scanners**, **Add Printer, Scanner or Fax**. Select it, **Add**, print a test page.

### Offline

- Confirm the Mac and printer are on the same network
- `ping` the printer's address
- Restart the printer, then the Mac
- Remove and re-add the printer

### Stuck Queue

**Printers and Scanners**, select the printer, open the queue, cancel the stuck jobs.

```bash
lpstat -p                 # printer status
lpstat -o                 # queued jobs
cancel -a                 # cancel everything
sudo launchctl stop org.cups.cupsd
sudo launchctl start org.cups.cupsd
```

macOS printing runs on CUPS. Restarting `cupsd` is the equivalent of restarting the Windows print spooler.

### Reset the Printing System

The nuclear option, and it works.

**Printers and Scanners**, right-click in the printer list, **Reset printing system**.

This removes every printer and all queues. You re-add from scratch. Warn the user first, because they will lose all their printers.

### Isolate It

Print from TextEdit, Preview and Safari.

One application failing means the problem is that application, not the printer. That one test saves a lot of wasted work.

---

## Useful Terminal Commands

```bash
# system
sw_vers                                   # macOS version
system_profiler SPHardwareDataType        # hardware and serial
uptime

# network
ifconfig
networksetup -listallhardwareports
ping -c 4 8.8.8.8
dig apple.com
netstat -an | grep LISTEN

# disk
diskutil list
df -h
du -sh ~/Downloads

# processes
top -o cpu
ps aux | grep -i teams
killall -9 ProcessName

# services
launchctl list
sudo launchctl stop com.example.service

# logs
log show --last 1h --predicate 'eventMessage contains "error"'
```

The serial number from `system_profiler` is what you need for an AppleCare or warranty claim.

---

## Permissions and Privacy

macOS asks applications to request access to the microphone, camera, screen recording, files and full disk access.

**System Settings**, **Privacy and Security**.

**This is the cause of most "it worked on Windows" tickets.** A remote support tool that cannot see the screen needs **Screen Recording** granted. A backup tool that cannot read files needs **Full Disk Access**. Neither will tell the user clearly what is missing.

Granting these requires an administrator and often a restart of the application.

---

## Safe Mode

**Intel:** hold `Shift` during boot.

**Apple Silicon:** hold the power button until Loading startup options appears, select the disk, hold `Shift`, click Continue in Safe Mode.

Safe Mode disables third-party extensions and clears some caches. If the fault disappears there, it is third-party software.

---

## Escalate When

- Hardware failure is suspected. Battery condition, disk SMART, display
- The machine will not boot after Safe Mode and disk repair
- Multiple users are affected, which points at network or server
- It needs MDM changes you do not control
- The device is supervised and locked by an MDM you do not administer

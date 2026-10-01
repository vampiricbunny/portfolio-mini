# 04 - Hunt Case Files

Six hunts worked end to end. Two found something, four did not, and all six are written up the same way.

This is the file that shows how I think through an open-ended problem. There is no alert telling me where to look. There is a hypothesis and a data set.

---

## H-0001: Beaconing to Command and Control

| | |
| --- | --- |
| **Date** | 2026-09-22 |
| **Type** | Hypothesis-driven |
| **Outcome** | **Compromise found** |

### Hypothesis

```text
IF   a host is beaconing to command and control
THEN there would be repeated outbound connections
IN   the network connection logs
THAT occur at suspiciously regular intervals
```

### Data

Sysmon event 3 in Wazuh, `DeviceNetworkEvents` in Sentinel. 30 days retained. Enough to test this.

### The hunt

Humans browse irregularly. Software beacons on a timer. The signal is the regularity of the gap between connections, not the destination.

```kql
DeviceNetworkEvents
| where TimeGenerated > ago(7d)
| where RemoteIPType == "Public"
| summarize Times = make_list(TimeGenerated), Count = count()
  by DeviceName, RemoteIP, InitiatingProcessFileName
| where Count > 20
| extend Deltas = series_subtract(array_slice(Times,1,-1), array_slice(Times,0,-2))
| extend Stats = series_stats_dynamic(Deltas)
| extend Mean = Stats.avg, StdDev = Stats.stdev
| where Mean > 0
| extend Jitter = StdDev / Mean
| where Jitter < 0.2
| project DeviceName, RemoteIP, InitiatingProcessFileName, Count, Mean, Jitter
| order by Jitter asc
```

**Low jitter is the whole hunt.** A human produces high jitter. A beacon checking in every five minutes produces near-zero. Under 0.2 means the interval barely moves.

### Finding

One result. WS-03, connecting to a public address every 300 seconds, jitter 0.04, from a process named `svchost.exe` running from `C:\Users\Public`.

```text
DeviceName  RemoteIP        Process        Count  Mean   Jitter
WS-03       203.0.113.77    svchost.exe    288    300.1  0.04
```

**`svchost.exe` running from `C:\Users\Public` is the tell.** The real svchost only ever runs from `C:\Windows\System32`. Something copied the name to a folder a normal user can write to.

### Pivots

```text
Pivot: what started it?           -> a scheduled task (persistence)
Pivot: what else did it do?       -> it read files from the Finance share
Pivot: on any other host?         -> no, WS-03 only
Pivot: what account?              -> a local account created 3 days ago
```

### Outcome

Compromise. Escalated to a full incident, handled with the response process from [SOC-02](../SOC-Analyst-1/04-Incident-Investigation.md).

### Detection built

Generalised the query, added the jitter threshold, wrote it as Sigma, deployed it. This beacon would now fire an alert automatically. The hunt closed the loop.

---

## H-0002: Persistence in User-Writable Folders

| | |
| --- | --- |
| **Date** | 2026-09-23 |
| **Type** | Stack counting |
| **Outcome** | **Compromise found** (the same one) |

### Hypothesis

```text
IF   an attacker established persistence
THEN there would be an autorun entry pointing at a user-writable folder
IN   the registry write logs
THAT is not a known application
```

### The hunt

Stack counting. Look at every autorun value across every machine, and sort by how rare each one is.

```kql
DeviceRegistryEvents
| where RegistryKey has_any ("CurrentVersion\\Run","CurrentVersion\\RunOnce")
| summarize Machines = dcount(DeviceName), Hosts = make_set(DeviceName, 5),
    First = min(TimeGenerated) by RegistryValueData
| order by Machines asc
```

### Finding

The common values were Teams, OneDrive and Slack, on many machines. Expected.

At the bottom, on one machine, an entry pointing at `C:\Users\Public\update.vbs`, on WS-03.

**This is the same compromise H-0001 found, reached from a different direction.** That is not wasted work. Two independent hunts converging on the same host raises confidence that the finding is real and not a coincidence.

### Outcome

Confirmed the H-0001 incident from a second angle. Folded into the same incident.

### Detection built

A rule for autorun values pointing at `Public`, `Temp`, `AppData` or `ProgramData`, excluding the known applications by their exact value. Deployed.

---

## H-0003: Kerberoasting Reconnaissance

| | |
| --- | --- |
| **Date** | 2026-09-24 |
| **Type** | Hypothesis-driven |
| **Outcome** | **No compromise** |

### Hypothesis

```text
IF   an attacker enumerated service accounts to Kerberoast
THEN there would be a burst of service ticket requests
IN   the domain controller security log (event 4769)
THAT covers many distinct services from one account quickly
```

### The hunt

```kql
SecurityEvent
| where EventID == 4769
| where TicketEncryptionType == "0x17"     // RC4, the weak type
| summarize Services = dcount(ServiceName), List = make_set(ServiceName, 20)
  by Account, bin(TimeGenerated, 10m)
| where Services >= 5
```

### Finding

Nothing. No account requested tickets for many services in a short window. The only RC4 requests came from a single legacy application, consistently, which is normal for it.

### Outcome

**No compromise.** The hypothesis was tested and held. Kerberoasting reconnaissance is not present in the retained window.

### Detection built

Even though nothing was found, the query became a detection, because Kerberoasting is worth catching automatically if it ever happens. **A clean hunt still improves coverage.** This is the loop working on an empty result.

### Note

I also raised a finding: the legacy application requesting RC4 tickets is a real weakness, because RC4 tickets are crackable. The long-term fix is to enforce AES on that service account. The hunt for an attack surfaced a genuine misconfiguration on the way.

---

## H-0004: Living Off the Land Binaries

| | |
| --- | --- |
| **Date** | 2026-09-25 |
| **Type** | Hypothesis-driven |
| **Outcome** | **No compromise** |

### Hypothesis

```text
IF   an attacker used built-in Windows tools to avoid detection
THEN there would be signed Microsoft binaries doing network or download work
IN   the process creation logs
THAT is unusual for those tools
```

### The hunt

These binaries are signed and trusted, so allowlisting does not stop them. The command line is the only place intent shows.

```kql
let lolbins = dynamic(["certutil.exe","bitsadmin.exe","regsvr32.exe",
    "mshta.exe","rundll32.exe","msbuild.exe","installutil.exe","wmic.exe"]);
DeviceProcessEvents
| where FileName in~ (lolbins)
| where ProcessCommandLine has_any ("http","ftp","\\\\","-urlcache","-decode","scrobj")
| project TimeGenerated, DeviceName, FileName, ProcessCommandLine,
          InitiatingProcessFileName
```

### Finding

A handful of `certutil` uses, all from a software deployment tool downloading legitimate installers from vendor domains. Checked each one. All benign.

### Outcome

**No compromise.** The living-off-the-land activity present was all legitimate deployment tooling.

### Detection built

A rule that catches these binaries doing network work, with the deployment tool excluded as the parent process. **The exclusion came directly from the hunt**, because I had already identified exactly what the benign version looks like. That is a better exclusion than one guessed in advance.

---

## H-0005: New Local Administrators

| | |
| --- | --- |
| **Date** | 2026-09-26 |
| **Type** | Hypothesis-driven |
| **Outcome** | **No compromise** |

### Hypothesis

```text
IF   an attacker created a local admin account for persistence
THEN there would be an account creation followed by an admin group addition
IN   the security logs
THAT was not part of a known IT process
```

### The hunt

```kql
SecurityEvent
| where EventID in (4720, 4732)    // account created, added to a group
| where TimeGenerated > ago(30d)
| summarize Events = make_list(pack("id",EventID,"time",TimeGenerated,"target",TargetAccount))
  by TargetAccount
| where array_length(Events) >= 2
```

### Finding

One new account, `svc_helpdesk`, created and added to a group. Pivoted on it: created by the IT administrator account, during working hours, matching a change ticket for a new help desk tool.

**Legitimate, and confirmed against the change record.** This is the benign-positive distinction from [SOC-02](../SOC-Analyst-1/04-Incident-Investigation.md). The detection would have been right to fire. It was authorised.

### Outcome

**No compromise.** The one new admin account was legitimate and documented.

### Detection built

A rule for account-created-then-elevated within a short window, already existed from SOC-02. The hunt validated it works and produces a checkable result. No new rule needed.

---

## H-0006: Data Staging Before Exfiltration

| | |
| --- | --- |
| **Date** | 2026-09-27 |
| **Type** | Hypothesis-driven |
| **Outcome** | **Inconclusive** |

### Hypothesis

```text
IF   an attacker was preparing to steal data
THEN there would be large archives created in temporary locations
IN   the file creation logs
THAT collect data from multiple sources before sending
```

### The hunt

```kql
DeviceFileEvents
| where FileName endswith ".zip" or FileName endswith ".rar" or FileName endswith ".7z"
| where FolderPath has_any ("Temp","AppData","ProgramData","Users\\Public")
| project TimeGenerated, DeviceName, FileName, FolderPath, FileSize,
          InitiatingProcessFileName
| order by FileSize desc
```

### Finding

A few archives, all small, all from legitimate backup and update processes. Nothing that looked like staging.

**But the hunt could not be completed properly.** `DeviceFileEvents` does not reliably record file size in this environment, and there is no monitoring of what leaves the network, so even if data were staged, I could not confirm whether it was then sent.

### Outcome

**Inconclusive.** Not because of what was found, but because the data to test the hypothesis fully does not exist.

### The real finding

This hunt's value is the gap it exposed. **There is no exfiltration monitoring at all.** No proxy logs, no data-loss tooling, no egress inspection. The Collection and Exfiltration tactics in [module 06](06-Detection-Coverage.md) are marked as having no coverage, and this hunt is why.

An inconclusive hunt that finds a monitoring gap is a productive hunt. It tells the person who decides what to collect exactly what is missing and why it matters.

---

## Summary

| Hunt | Hypothesis | Outcome | Detection built |
| --- | --- | --- | :---: |
| H-0001 | Beaconing | **Compromise** | Yes |
| H-0002 | Registry persistence | **Compromise** (same) | Yes |
| H-0003 | Kerberoasting recon | No compromise | Yes |
| H-0004 | Living off the land | No compromise | Yes |
| H-0005 | New local admins | No compromise | Validated existing |
| H-0006 | Data staging | Inconclusive | Gap reported |

**Two compromises, three clean, one inconclusive.** Both compromises were the same incident found from two directions, which is a good sign, not a redundant one.

### What the six show together

**A clean hunt is not a wasted hunt.** Four of six found no compromise, and four of six produced or validated a detection anyway. The loop closes whether or not there is a finding.

**The inconclusive one was the most useful for the program.** H-0006 found no attack but exposed a whole category of missing visibility. That goes further to improving the SOC than another confirmed beacon would have.

**Rarity and regularity are the two best signals.** H-0001 used regularity, H-0002 used rarity. Between them they cover a large share of what hunting actually looks like: find the thing that repeats too evenly, or the thing that appears too rarely.

---

Next: [05-Adversary-Emulation.md](05-Adversary-Emulation.md)

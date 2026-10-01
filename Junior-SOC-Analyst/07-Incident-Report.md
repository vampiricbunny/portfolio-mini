# Incident Report IR-2026-014

**Classification:** Internal
**Severity:** High
**Status:** Closed
**Analyst:** VBunny, SOC
**Opened:** 2026-08-12 14:09 UTC
**Closed:** 2026-08-14 17:30 UTC

> Exercise conducted in the `vbunnylab.local` lab environment. All accounts and hosts are lab assets.

---

## Executive Summary

A standard user opened a malicious document attached to an email. The document ran PowerShell, which downloaded a script from an external host and established persistence.

The attacker then enumerated the domain, ran a password spray against 24 accounts from inside the network, and recovered the password of a privileged service account. Using that account they moved to a second workstation and attempted to extract credentials from memory.

**The intrusion was detected 2 seconds after the document was opened and contained 13 minutes later.** A domain administrator credential was exposed in the memory of the second workstation, so it was treated as compromised and reset.

Total attacker dwell time was 12 minutes 51 seconds. No data left the environment.

### The three findings that mattered

**A service account password fell to a spray in 36 seconds.** `svc_backup` used `Summer2025!`, which satisfies every complexity requirement Windows can enforce. Complexity policy did not help. Length and a breached-password check would have.

**Alerts were worked by severity, not by position in the attack.** A level 13 Defender tampering alert sat unworked in the queue while the attacker used the exclusion it described. Severity does not tell you where in the kill chain something sits.

**The earliest alert was the most valuable and the least alarming-sounding.** "Office application spawned a shell" at 14:02:13 was the whole incident. Everything else was downstream. Containing at that alert would have prevented stages 4 through 7.

---

## Timeline

All times UTC, 2026-08-12.

| Time | Event | Source |
| --- | --- | --- |
| 13:58:02 | `Q3-Invoice-Review.docm` written to Downloads on WS11-01 by `outlook.exe`. Mark of the Web present | Sysmon 11, 15 |
| 14:02:11 | User `vbunny` opens the document. Macro executes | Sysmon 1 |
| 14:02:11 | `WINWORD.EXE` spawns `powershell.exe` with an encoded command | Sysmon 1 |
| **14:02:13** | **ALERT SOC-1008 level 14.** Office spawned a command interpreter | Wazuh |
| 14:02:14 | ALERT SOC-1003 level 10. Encoded PowerShell | Wazuh |
| 14:02:19 | PowerShell connects to `10.20.99.10:8080`, downloads `u.ps1` | Sysmon 3 |
| 14:02:19 | ALERT SOC-1003 level 10. Download cradle | Wazuh |
| 14:03:41 | `od.ps1` written to `AppData\Roaming\Microsoft\` | Sysmon 11 |
| 14:03:43 | Run key `OneDriveSync` created pointing at `od.ps1` | Sysmon 13 |
| **14:03:45** | **ALERT SOC-1004 level 12.** Autorun value in user-writable path | Wazuh |
| 14:04:00 | Analyst claims ALT-001 and begins triage | Ticket |
| 14:05:02 | Domain enumeration: `net user /domain`, `net group "Domain Admins"`, SPN query | Sysmon 1 |
| 14:05:02 | **No alert.** Detection gap | n/a |
| 14:07:33 | Password spray begins against 24 accounts from WS11-01 | Security 4625 |
| **14:08:11** | `svc_backup` authenticates successfully. Password `Summer2025!` | Security 4624 |
| 14:08:11 | ALERT SOC-1001 level 12. Password spray | Wazuh |
| **14:08:14** | **ALERT SOC-1001 level 14.** Spray followed by success from the same source | Wazuh |
| 14:09:00 | ALT-001 escalated. Incident IR-2026-014 opened | Ticket |
| 14:10:00 | Analyst begins ALT-003 | Ticket |
| 14:11:19 | Lateral movement to WS11-02 as `svc_backup` over SMB | Security 4624 type 3 |
| 14:11:22 | Remote execution service `PSEXESVC` installed on WS11-02 | System 7045 |
| 14:11:26 | ALERT SOC-1006 level 13. Remote execution service | Wazuh |
| 14:13:44 | Defender exclusion added for `C:\Users\Public` on WS11-02 | Sysmon 1 |
| 14:13:47 | ALERT SOC-1009 level 13. Defender configuration modified | Wazuh |
| 14:13:47 | Alert enters the queue and is **not worked** | Ticket |
| 14:14:58 | `rundll32 comsvcs.dll MiniDump 712 C:\Users\Public\o.bin full` | Sysmon 1 |
| 14:15:01 | `o.bin` written, 54 MB | Sysmon 11 |
| **14:15:02** | **ALERT SOC-1007 level 14.** LSASS dump via comsvcs | Wazuh |
| 14:15:03 | ALERT SOC-1007 level 14. LSASS access, CallTrace UNKNOWN | Wazuh |
| 14:15:30 | Analyst begins ALT-004 | Ticket |
| **14:16:00** | **WS11-02 isolated from the network. Not rebooted** | Action |
| 14:18:00 | WS11-01 isolated | Action |
| 14:19:00 | `svc_backup` disabled | Action |
| 14:24:00 | `vampiricbunny` password reset, all sessions revoked | Action |
| 14:31:00 | Confirmed `o.bin` never left the host | Firewall, Sysmon 3 |
| 15:40:00 | Both hosts imaged for analysis | Action |
| 2026-08-13 | Eradication. Both hosts rebuilt | Action |
| 2026-08-14 17:30 | Incident closed | Ticket |

**The critical five minutes are 14:11 to 14:16.** The attacker moved laterally, installed a service, disabled a protection, and dumped credentials. Three alerts fired in that window. One was worked.

---

## Scope

### Hosts

| Host | Status | Basis |
| --- | --- | --- |
| WS11-01 | **Compromised** | Initial access, persistence, spray origin |
| WS11-02 | **Compromised** | Lateral movement, credential dumping |
| DC01 | Not compromised | Authenticated to as `svc_backup`, no code execution, no `ntds.dit` access, no DCSync |
| FS01 | Not compromised | No authentication from either compromised host |
| SIEM01 | Not compromised | Unreachable from CORP by firewall rule |

### Accounts

| Account | Status | Basis |
| --- | --- | --- |
| `vbunny` | **Compromised** | Initial execution ran in this context |
| `svc_backup` | **Compromised** | Password recovered by spray, used for lateral movement |
| `vampiricbunny` | **Exposed** | Had an RDP session to WS11-02 within 30 days. Credential material was in the dumped memory |
| `m.calloway` | Exposed | Interactive logons to WS11-02. Included in the reset |
| All other domain accounts | Not compromised | Targeted by the spray, all failed |

**`vampiricbunny` is the finding that made this a High severity incident.** A domain administrator had used RDP to WS11-02 six days before. Type 10 logons leave credential material in LSASS. The dump captured it.

The attacker never used that credential, because isolation happened 64 seconds after the dump alert. But a dump you do not confirm was unused is a dump you assume was used.

### Data

No data exfiltration. `o.bin` was written but never transferred, confirmed against both Sysmon 3 network events and the firewall connection log for the window between the write at 14:15:01 and isolation at 14:16:00.

---

## MITRE ATT&CK Mapping

| Tactic | Technique | ID | Detected | Detection |
| --- | --- | --- | :---: | --- |
| Initial Access | Spearphishing Attachment | T1566.001 | No | Gap. Detected at execution instead |
| Execution | PowerShell | T1059.001 | Yes | SOC-1003, 3 s |
| Execution | User Execution, Malicious File | T1204.002 | Yes | SOC-1008, 2 s |
| Persistence | Registry Run Key | T1547.001 | Yes | SOC-1004, 5 s |
| Defense Evasion | Obfuscated Files or Information | T1027 | Yes | SOC-1003, 3 s |
| Defense Evasion | Impair Defenses | T1562.001 | Yes | SOC-1009, 3 s |
| Credential Access | Password Spraying | T1110.003 | Yes | SOC-1001, 38 s |
| Credential Access | LSASS Memory | T1003.001 | Yes | SOC-1007, 4 s |
| Discovery | Domain Account Discovery | T1087.002 | No | Gap. No rule existed |
| Discovery | Permission Groups Discovery | T1069.002 | No | Gap. No rule existed |
| Lateral Movement | SMB / Admin Shares | T1021.002 | Yes | SOC-1006, 7 s |
| Command and Control | Ingress Tool Transfer | T1105 | Yes | SOC-1003, 8 s |

**Nine of twelve techniques detected.** The three misses are one delivery technique and two discovery techniques.

---

## Root Cause

Four failures, in order of how much they contributed.

### 1. A weak service account password

`svc_backup` used `Summer2025!`. Twelve characters, four character classes, passes every complexity check. It took 36 seconds to guess.

This was the pivot. Without it the intrusion stops at a single compromised standard user on one workstation. With it the attacker reached a privileged account, moved laterally, and got to a machine where a domain administrator had logged on.

Complexity policy created the illusion of a strong password. The policy was satisfied and the password was trivially guessable, because it follows the pattern every human uses when forced to satisfy a complexity rule.

### 2. Macros executed from an internet-sourced document

The file carried a Mark of the Web. Office should have opened it in Protected View and blocked the macro. It did not, because macro policy was not enforced by Group Policy.

This is a one-setting fix and it would have prevented the entire incident.

### 3. A domain administrator used RDP to a workstation

Type 10 logons leave credential material in LSASS for the life of the session and beyond. A domain administrator RDP session to a standard workstation puts the highest privilege credential in the environment onto the machine most likely to be compromised.

This is what turned a service account compromise into a domain administrator exposure.

### 4. Alerts were worked by severity rather than by chain position

The Defender exclusion alert at 14:13:47 was level 13. It sat in the queue while the analyst worked a level 14 alert. Seventy-one seconds later the attacker used that exclusion to write the LSASS dump.

Working that alert would not have been unreasonable. Severity said the other one mattered more. Severity was wrong, because it describes how bad a thing is rather than what it enables next.

---

## Response

### Containment

| Time | Action |
| --- | --- |
| 14:16 | WS11-02 network isolated. Left running to preserve memory |
| 14:18 | WS11-01 network isolated |
| 14:19 | `svc_backup` disabled |
| 14:24 | `vampiricbunny` password reset, all sessions revoked |
| 14:31 | Confirmed `o.bin` never transferred |
| 14:45 | `10.20.99.10` blocked at the firewall for all segments |
| 15:10 | Estate swept for the Run key, the file hashes, and `PSEXESVC` |

**Neither host was rebooted.** A reboot destroys LSASS memory, which is both the evidence of what was taken and the only way to confirm what was in it.

### Eradication

| Action | Detail |
| --- | --- |
| Rebuild | Both workstations reimaged. Not cleaned |
| Credential reset | `vbunny`, `svc_backup`, `m.calloway`, `vampiricbunny` |
| `krbtgt` | Reset twice with a 12 hour gap between resets |
| Mail | Message trace for the attachment, no other recipients found |
| Verification | Run key, file hashes and service name absent estate-wide |

Rebuilding rather than cleaning was not a close call. Once an attacker has had SYSTEM on a machine, you cannot prove you found everything they left.

The double `krbtgt` reset matters. One reset leaves the previous key valid, which is deliberate so tickets do not all break at once. Two resets with a gap invalidates any golden ticket while letting legitimate tickets renew.

### Recovery

Users back on rebuilt machines 2026-08-13. Monitoring maintained on both accounts and both hosts for 14 days. No further activity.

---

## Recommendations

| # | Recommendation | Priority | Effort | Prevents |
| --- | --- | --- | --- | --- |
| 1 | Block macros in files from the internet by GPO | **Critical** | Low | The entire incident |
| 2 | Service account passwords to 25+ characters, managed in a vault | **Critical** | Medium | The pivot |
| 3 | Convert service accounts to gMSA where supported | High | Medium | Password guessing entirely |
| 4 | Block domain administrator interactive logon to workstations | **Critical** | Medium | Credential exposure |
| 5 | Enable LSA Protection (RunAsPPL) estate-wide | High | Low | The dump itself |
| 6 | Enable Credential Guard on Windows 11 | High | Medium | Credential extraction |
| 7 | Deploy Attack Surface Reduction rules, Office child process blocking | High | Low | Stage 1 execution |
| 8 | Breached password screening at change time | High | Low | Weak but compliant passwords |
| 9 | Alert triage by chain position, not severity alone | **Critical** | Low | The 71 second window |
| 10 | Alert grouping by host and time window in the SIEM | High | Medium | Sequence being unreadable |
| 11 | Detection rules for discovery techniques | Medium | Medium | The two gaps |
| 12 | Time-bound privileged group membership | Medium | Medium | Standing privilege |
| 13 | `msDS-SupportedEncryptionTypes` to AES-only | Medium | Low | Kerberoasting |

### Recommendation 1 is the one

Single Group Policy setting. `Block macros from running in Office files from the Internet`, Enabled, for every Office application.

The document carried a Mark of the Web. That setting would have refused to run the macro. Nothing else in this incident would have happened.

**Low effort, no licensing cost, prevents the whole chain.** Everything else on this list is defence in depth behind it.

### Recommendation 4 needs saying plainly

Blocking domain administrator logon to workstations is a `Deny log on locally` and `Deny log on through Remote Desktop Services` assignment on the workstation OU for the tier 0 group.

It is not technically difficult. It is organisationally difficult, because administrators are used to logging on wherever they need to. It is also the control that separates "a workstation was compromised" from "the domain was compromised", and this incident is a clean demonstration of why.

### Recommendation 9 changes how the queue is worked

Severity says how bad a thing is. Chain position says what it enables next.

The Defender exclusion at 14:13:47 was level 13, below the level 14 alerts around it. It was also the last step before credential theft. An alert that sits immediately before an objective deserves attention out of proportion to its severity.

Proposal: alerts in an active incident on an already-suspect host get promoted regardless of their own level. If a host has fired a high alert in the last 30 minutes, everything else from that host goes to the top of the queue.

---

## What Went Well

**Detection latency was excellent.** Mean 4.4 seconds excluding the frequency-based spray rule. Seven of nine techniques caught.

**Segmentation worked.** The SIEM was unreachable from the compromised segment, so the evidence survived. The corporate-to-red block logged the callback attempt and gave a free indicator.

**The analyst did not reboot.** Under pressure the instinct is to restart the machine. Isolating and leaving it running preserved the memory that answered what was taken.

**Exposure analysis was correct.** Enumerating every account that had logged on to WS11-02 in 30 days is what found the domain administrator RDP session. Without that step the incident would have been closed as a service account compromise and a domain administrator credential would still be live.

---

## What Went Badly

**The Defender alert was not worked.** Seventy-one seconds between that alert and the LSASS dump. The gap was procedural, not technical.

**No detection for discovery.** The attacker enumerated the domain at 14:05 and nothing fired. Three minutes of free reconnaissance.

**Alert ordering obscured the story.** Severity sorting put stage 7 above stage 1 in the dashboard. An analyst opening the queue saw credential dumping first and had to work backwards.

**Nobody asked the user.** `vbunny` opened a document at 14:02. Nobody spoke to them until 14:52, fifty minutes later. They could have identified the email in seconds and would have known immediately whether anything looked wrong. The user is a data source and this incident did not treat them as one.

---

## Evidence Retained

| Item | Location | Retention |
| --- | --- | --- |
| Full disk images, both hosts | Offline evidence store | 12 months |
| Memory capture, WS11-02 | Offline evidence store | 12 months |
| `o.bin` | Offline evidence store | 12 months |
| `Q3-Invoice-Review.docm` | Offline evidence store | 12 months |
| `u.ps1`, `od.ps1` | Offline evidence store | 12 months |
| SIEM events, all hosts, 2026-08-01 to 2026-08-20 | SIEM01, index preserved | 12 months |
| Firewall logs, same window | FW01 export | 12 months |
| Alert tickets ALT-001 to ALT-004 | Ticketing system | Per policy |

### Indicators

```text
Host        10.20.99.10
Port        8080 (payload), 4444 (reverse shell attempt)
File        Q3-Invoice-Review.docm
File        u.ps1, od.ps1, o.bin
Registry    HKCU\...\CurrentVersion\Run\OneDriveSync
Service     PSEXESVC
Exclusion   C:\Users\Public
```

---

## Sign-off

| | |
| --- | --- |
| Prepared by | VBunny, SOC |
| Date | 2026-08-14 |
| Reviewed by | [pending] |
| Distribution | IT Management, Security |

---

Next: [08-Metrics-and-Coverage.md](08-Metrics-and-Coverage.md)

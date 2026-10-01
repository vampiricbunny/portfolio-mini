# 03 - Detection Rules

Ten rules, written as Sigma first, then converted to Wazuh XML so they run. Each one includes the logic, the tuning history, and the false positives it produced before it was usable.

---

## How I Wrote These

Sigma first, every time. Sigma is vendor neutral, so the logic survives a SIEM migration and it is the format a detection engineering team will expect to see. Wazuh XML is the runtime.

The workflow for each rule:

1. Run the attack technique, with `<logall>` on
2. Find the event in `archives.log` and read the actual field names, not the ones I assumed
3. Write the Sigma rule against those fields
4. Convert to Wazuh XML
5. Run it for 48 hours against normal activity and count the false positives
6. Tune, and record what I excluded and why

**Step 5 is the step people skip.** A rule that has never run against normal traffic is not a detection, it is a guess. Four of these ten fired constantly on first deployment and needed real work.

A note on rule levels. Wazuh levels 0 to 15. I used 5 for informational, 10 for investigate, 12 for high, and 14 for critical. Anything at 12 or above should mean a human looks at it the same shift.

---

## SOC-1001: Password Spray

**Technique:** T1110.003 Password Spraying
**Severity:** High
**Data source:** Windows Security 4625

### What it catches

A spray is the inverse of a brute force. Instead of many passwords against one account, it is one password against many accounts. That shape defeats lockout policy, because no single account accumulates enough failures to trip it.

Detecting it means counting across accounts, not per account. Ten failures on one user is a forgotten password. Ten failures across ten users from one source in two minutes is an attack.

### Sigma

```yaml
title: Password Spray Against Multiple Accounts
id: 3a1e5f20-8c44-4d1a-9f0b-2c7e6d4b8a11
status: experimental
description: Detects authentication failures against many distinct accounts from a single source in a short window, which is the shape of a password spray rather than a brute force.
author: VBunny
date: 2026/07/14
references:
  - https://attack.mitre.org/techniques/T1110/003/
logsource:
  product: windows
  service: security
detection:
  selection:
    EventID: 4625
    LogonType:
      - 3
      - 10
  filter_computer_accounts:
    TargetUserName|endswith: '$'
  filter_known_service:
    IpAddress:
      - '10.20.10.20'   # FS01, SMB session churn produces benign 4625
  condition: selection and not 1 of filter_*
  timeframe: 5m
fields:
  - TargetUserName
  - IpAddress
  - WorkstationName
  - SubStatus
falsepositives:
  - A user changing their password while phones and tablets hold the old one
  - A service account whose password rotated but whose consumers were not updated
  - Vulnerability scanners performing authenticated scans
level: high
```

### Wazuh XML

```xml
<group name="windows,authentication,attack.t1110,">

  <rule id="100101" level="5">
    <if_sid>60122</if_sid>
    <field name="win.system.eventID">^4625$</field>
    <description>Windows logon failure on $(win.eventdata.targetUserName)</description>
    <mitre>
      <id>T1110</id>
    </mitre>
  </rule>

  <!-- Machine accounts end in $ and fail constantly during normal operation -->
  <rule id="100102" level="0">
    <if_sid>100101</if_sid>
    <field name="win.eventdata.targetUserName">\$$</field>
    <description>Logon failure for a computer account, ignored</description>
  </rule>

  <!--
    The detection. same_source_ip groups by the originating address,
    different_field on targetUserName is what makes this a spray rather
    than a brute force: 8 distinct accounts, not 8 attempts.
  -->
  <rule id="100103" level="12" frequency="8" timeframe="300">
    <if_matched_sid>100101</if_matched_sid>
    <same_source_ip />
    <different_field>win.eventdata.targetUserName</different_field>
    <description>Password spray: 8 or more distinct accounts failed authentication from $(win.eventdata.ipAddress) within 5 minutes</description>
    <mitre>
      <id>T1110.003</id>
    </mitre>
  </rule>

  <!-- Escalate if a spray is followed by a success from the same source -->
  <rule id="100104" level="14" frequency="1" timeframe="600">
    <if_matched_sid>100103</if_matched_sid>
    <if_sid>60106</if_sid>
    <same_source_ip />
    <description>CRITICAL: successful logon from $(win.eventdata.ipAddress) following a password spray from the same source</description>
    <mitre>
      <id>T1110.003</id>
    </mitre>
  </rule>

</group>
```

### Tuning history

| Version | Threshold | FPs in 48h | Change |
| --- | --- | --- | --- |
| v1 | 3 accounts / 5 min | 34 | Too tight. Machine account failures dominated |
| v2 | 3 accounts / 5 min | 11 | Excluded accounts ending in `$` |
| v3 | 5 accounts / 5 min | 4 | Still catching FS01 SMB session churn |
| v4 | 8 accounts / 5 min | 0 | Excluded FS01 as a source. Current |

Eight is high enough to be quiet and still well under the size of any real spray, which typically walks the whole user list.

**Rule 100104 is the one that matters most.** A spray alone is noise you investigate. A spray followed by a success from the same address is an active compromise, and it should page someone.

---

## SOC-1002: Kerberoasting

**Technique:** T1558.003 Kerberoasting
**Severity:** Medium
**Data source:** Windows Security 4769 on the domain controller

### What it catches

Service tickets are encrypted with the service account's password hash. Request a ticket for a service account, take it offline, crack it. The account never sees a failed logon because nothing failed.

The tell is the encryption type. `0x17` is RC4, which is weak and fast to crack. Modern Windows requests `0x12` (AES256) by default. An RC4 ticket request in a domain where AES is available means something deliberately downgraded it.

### Sigma

```yaml
title: Kerberoasting via RC4 Service Ticket Request
id: 7b2d9e14-5a63-4c88-b1f2-9d3a7c0e4f52
status: experimental
description: Detects service ticket requests using RC4 encryption, which is the signature of a Kerberoasting tool downgrading the encryption to produce a crackable ticket.
author: VBunny
date: 2026/07/16
references:
  - https://attack.mitre.org/techniques/T1558/003/
logsource:
  product: windows
  service: security
detection:
  selection:
    EventID: 4769
    TicketEncryptionType: '0x17'
    TicketOptions: '0x40810000'
  filter_machine:
    ServiceName|endswith: '$'
  filter_krbtgt:
    ServiceName: 'krbtgt'
  condition: selection and not 1 of filter_*
fields:
  - ServiceName
  - TargetUserName
  - IpAddress
falsepositives:
  - Legacy applications and appliances that genuinely only support RC4
  - Older NAS and print devices joined to the domain
level: medium
```

### Wazuh XML

```xml
<group name="windows,kerberos,attack.t1558,">

  <rule id="100201" level="10">
    <if_sid>60103</if_sid>
    <field name="win.system.eventID">^4769$</field>
    <field name="win.eventdata.ticketEncryptionType">^0x17$</field>
    <field name="win.eventdata.ticketOptions">^0x40810000$</field>
    <description>Kerberoasting: RC4 service ticket requested for $(win.eventdata.serviceName) by $(win.eventdata.targetUserName)</description>
    <mitre>
      <id>T1558.003</id>
    </mitre>
  </rule>

  <rule id="100202" level="0">
    <if_sid>100201</if_sid>
    <field name="win.eventdata.serviceName">\$$|^krbtgt$</field>
    <description>RC4 ticket for a machine account or krbtgt, ignored</description>
  </rule>

  <!-- Many distinct services in a short window means enumeration, not one app -->
  <rule id="100203" level="13" frequency="5" timeframe="60">
    <if_matched_sid>100201</if_matched_sid>
    <same_user />
    <different_field>win.eventdata.serviceName</different_field>
    <description>Kerberoasting at scale: $(win.eventdata.targetUserName) requested RC4 tickets for 5 or more distinct services within 60 seconds</description>
    <mitre>
      <id>T1558.003</id>
    </mitre>
  </rule>

</group>
```

### Note

Rule 100201 alone was too chatty in my lab because one legacy test appliance genuinely only speaks RC4. Rule 100203 is the real detection. One RC4 ticket is plausible. Five distinct services in a minute is a tool enumerating SPNs, and no application behaves like that.

**The right long-term fix is not a detection.** It is setting `msDS-SupportedEncryptionTypes` to AES-only on service accounts so RC4 requests fail outright. The detection is what you run until that is done.

---

## SOC-1003: Encoded and Suspicious PowerShell

**Technique:** T1059.001 PowerShell
**Severity:** High
**Data source:** Sysmon 1, PowerShell 4104

### What it catches

Attacker PowerShell has a distinctive shape. It is base64 encoded to defeat command line inspection, it hides its window, it bypasses execution policy, and it downloads something.

None of those flags are malicious alone. Legitimate installers use `-ExecutionPolicy Bypass` constantly. The signal is the combination.

### Sigma

```yaml
title: Suspicious PowerShell Command Line
id: c4f81a37-2b96-4e55-8a10-6f2d9b3c7e48
status: experimental
description: Detects PowerShell invoked with an encoded command, a hidden window, or an inline download cradle. Individually weak signals, strong in combination.
author: VBunny
date: 2026/07/18
references:
  - https://attack.mitre.org/techniques/T1059/001/
logsource:
  category: process_creation
  product: windows
detection:
  selection_image:
    Image|endswith:
      - '\powershell.exe'
      - '\pwsh.exe'
  selection_encoded:
    CommandLine|contains:
      - ' -enc '
      - ' -EncodedCommand'
      - ' -e '
      - ' -ec '
  selection_hidden:
    CommandLine|contains:
      - '-w hidden'
      - '-WindowStyle Hidden'
      - '-nop'
      - '-NoProfile'
  selection_download:
    CommandLine|contains:
      - 'DownloadString'
      - 'DownloadFile'
      - 'Invoke-WebRequest'
      - 'IWR '
      - 'Net.WebClient'
      - 'Start-BitsTransfer'
      - 'FromBase64String'
  filter_sccm:
    ParentImage|endswith: '\CcmExec.exe'
  condition: selection_image and (selection_encoded or selection_download or (selection_hidden and selection_encoded)) and not filter_sccm
fields:
  - CommandLine
  - ParentImage
  - User
falsepositives:
  - Software deployment tooling that wraps encoded PowerShell
  - Vendor installers using download cradles
level: high
```

### Wazuh XML

```xml
<group name="windows,sysmon,powershell,attack.t1059,">

  <rule id="100301" level="10">
    <if_sid>61603</if_sid>
    <field name="win.eventdata.image">powershell\.exe|pwsh\.exe</field>
    <field name="win.eventdata.commandLine">-enc|-EncodedCommand|-ec\s|FromBase64String</field>
    <description>Encoded PowerShell executed by $(win.eventdata.user): $(win.eventdata.commandLine)</description>
    <mitre>
      <id>T1059.001</id>
      <id>T1027</id>
    </mitre>
  </rule>

  <rule id="100302" level="10">
    <if_sid>61603</if_sid>
    <field name="win.eventdata.image">powershell\.exe|pwsh\.exe</field>
    <field name="win.eventdata.commandLine">DownloadString|DownloadFile|Net\.WebClient|Invoke-WebRequest|Start-BitsTransfer</field>
    <description>PowerShell download cradle executed by $(win.eventdata.user): $(win.eventdata.commandLine)</description>
    <mitre>
      <id>T1059.001</id>
      <id>T1105</id>
    </mitre>
  </rule>

  <!-- Encoded and hidden and downloading. Almost no legitimate software does all three -->
  <rule id="100303" level="14">
    <if_sid>61603</if_sid>
    <field name="win.eventdata.image">powershell\.exe|pwsh\.exe</field>
    <field name="win.eventdata.commandLine">(?=.*-w\s+hidden|.*-WindowStyle\s+Hidden)(?=.*-enc|.*-EncodedCommand)</field>
    <description>CRITICAL: hidden-window encoded PowerShell on $(win.system.computer) by $(win.eventdata.user)</description>
    <mitre>
      <id>T1059.001</id>
      <id>T1027</id>
    </mitre>
  </rule>

</group>
```

### Decoding the payload during triage

This is the single most useful thing to know when this alert fires.

```powershell
$b64 = 'JABjACAAPQAgAE4AZQB3AC0ATwBiAGoAZQBjAHQAIAA...'
[System.Text.Encoding]::Unicode.GetString([System.Convert]::FromBase64String($b64))
```

Unicode, not UTF8. PowerShell's `-EncodedCommand` expects UTF-16LE, and decoding as UTF8 gives you garbage with nulls between every character, which sends people down the wrong path.

**Do this in an isolated session and never paste the decoded output into a running shell.** You are reading it, not executing it.

You usually do not need to decode at all. Event 4104 already contains the decoded script block, because PowerShell logs it after deobfuscation. Check 4104 first.

### Tuning history

| Version | FPs in 48h | Change |
| --- | --- | --- |
| v1 | 22 | `-nop` and `-ExecutionPolicy Bypass` alone matched every vendor installer |
| v2 | 6 | Required encoding or a download cradle, not just flags |
| v3 | 1 | Excluded the software deployment parent process |

The remaining one per 48 hours is a scheduled maintenance script I wrote myself. I left it firing deliberately rather than excluding it, because an exclusion by script path is something an attacker can trivially satisfy by naming their payload the same thing.

---

## SOC-1004: Registry Run Key Persistence

**Technique:** T1547.001 Registry Run Keys
**Severity:** High
**Data source:** Sysmon 13

### Sigma

```yaml
title: Persistence via Registry Run Key
id: e91c4b55-7d38-4a02-bc6e-1f8a2d5e93c7
status: experimental
description: Detects a write to an autorun registry location where the value points into a user-writable directory, which is where payloads live and installed software does not.
author: VBunny
date: 2026/07/19
references:
  - https://attack.mitre.org/techniques/T1547/001/
logsource:
  product: windows
  category: registry_set
detection:
  selection_key:
    TargetObject|contains:
      - '\CurrentVersion\Run\'
      - '\CurrentVersion\RunOnce\'
      - '\CurrentVersion\RunServices\'
      - '\CurrentVersion\Explorer\User Shell Folders\Startup'
      - '\Winlogon\Shell'
      - '\Winlogon\Userinit'
  selection_value:
    Details|contains:
      - '\AppData\'
      - '\Temp\'
      - '\ProgramData\'
      - '\Users\Public\'
      - 'powershell'
      - 'cmd.exe'
      - 'wscript'
      - 'mshta'
      - 'rundll32'
  condition: selection_key and selection_value
fields:
  - TargetObject
  - Details
  - Image
  - User
falsepositives:
  - Legitimate per-user applications that install into AppData, notably Teams, Slack and Discord
level: high
```

### Wazuh XML

```xml
<group name="windows,sysmon,persistence,attack.t1547,">

  <rule id="100401" level="5">
    <if_sid>61615</if_sid>
    <field name="win.eventdata.targetObject">CurrentVersion\\\\Run|CurrentVersion\\\\RunOnce|Winlogon\\\\Shell|Winlogon\\\\Userinit</field>
    <description>Autorun registry value written: $(win.eventdata.targetObject)</description>
    <mitre>
      <id>T1547.001</id>
    </mitre>
  </rule>

  <!-- The value matters more than the key. A path into user-writable space is the signal -->
  <rule id="100402" level="12">
    <if_sid>100401</if_sid>
    <field name="win.eventdata.details">AppData|\\\\Temp\\\\|ProgramData|Users\\\\Public|powershell|cmd\.exe|wscript|mshta|rundll32</field>
    <description>Persistence: autorun value pointing at user-writable path or interpreter. Key $(win.eventdata.targetObject), value $(win.eventdata.details), written by $(win.eventdata.image)</description>
    <mitre>
      <id>T1547.001</id>
    </mitre>
  </rule>

  <!-- Known-good per-user applications -->
  <rule id="100403" level="0">
    <if_sid>100402</if_sid>
    <field name="win.eventdata.details">Microsoft\\\\Teams|OneDrive|Discord|slack\.exe</field>
    <description>Known per-user application autorun, ignored</description>
  </rule>

</group>
```

### Why filter on the value and not the key

Every software installation writes Run keys. Filtering on the key alone produces an alert every time anybody installs anything.

The discriminator is where the value points. Installed software runs from `C:\Program Files`. Malware runs from `AppData`, `Temp`, `ProgramData` or `Public`, because those are the directories a standard user can write to without a UAC prompt.

The exceptions are the per-user applications, and they are a short enumerable list. Teams, OneDrive, Discord, Slack. That is a list you can maintain. The list of all software that writes a Run key is not.

---

## SOC-1005: Scheduled Task Persistence

**Technique:** T1053.005 Scheduled Task
**Severity:** Medium to High
**Data source:** Windows Security 4698, Sysmon 1

### Wazuh XML

```xml
<group name="windows,persistence,attack.t1053,">

  <rule id="100501" level="5">
    <if_sid>60103</if_sid>
    <field name="win.system.eventID">^4698$</field>
    <description>Scheduled task created: $(win.eventdata.taskName)</description>
    <mitre>
      <id>T1053.005</id>
    </mitre>
  </rule>

  <rule id="100502" level="12">
    <if_sid>100501</if_sid>
    <field name="win.eventdata.taskContent">powershell|cmd\.exe|wscript|cscript|mshta|rundll32|regsvr32|certutil|bitsadmin|AppData|\\\\Temp\\\\</field>
    <description>Suspicious scheduled task: $(win.eventdata.taskName) executes an interpreter or runs from user-writable space, created by $(win.eventdata.subjectUserName)</description>
    <mitre>
      <id>T1053.005</id>
    </mitre>
  </rule>

  <!-- schtasks.exe run from a shell, rather than through the Task Scheduler UI -->
  <rule id="100503" level="12">
    <if_sid>61603</if_sid>
    <field name="win.eventdata.image">schtasks\.exe</field>
    <field name="win.eventdata.commandLine">/create</field>
    <field name="win.eventdata.parentImage">cmd\.exe|powershell\.exe|wscript\.exe|winword\.exe|excel\.exe</field>
    <description>Scheduled task created from a command shell or Office process. Parent $(win.eventdata.parentImage), command $(win.eventdata.commandLine)</description>
    <mitre>
      <id>T1053.005</id>
    </mitre>
  </rule>

</group>
```

### Note

Rule 100503 catches something 100502 misses. The parent process tells you how the task was created. An administrator using the Task Scheduler UI produces a parent of `mmc.exe` or `explorer.exe`. A script producing a task has a parent of `cmd.exe` or `powershell.exe`. A task created by Word has a parent of `winword.exe`, and there is no legitimate reason for that to ever happen.

**Three fields in 4698 carry the weight.** The task name, which attackers pick to look like Windows (`WindowsUpdateCheck`, `GoogleUpdateTaskMachine`). The author, which should be a service account on a server and rarely a user on a workstation. And the trigger, because `AtLogon` and `AtStartup` are persistence while a one-off time trigger is usually not.

---

## SOC-1006: Service Installation

**Technique:** T1543.003 Windows Service
**Severity:** High
**Data source:** System 7045

### Wazuh XML

```xml
<group name="windows,persistence,attack.t1543,">

  <rule id="100601" level="5">
    <if_sid>60009</if_sid>
    <field name="win.system.eventID">^7045$</field>
    <description>New service installed: $(win.eventdata.serviceName)</description>
    <mitre>
      <id>T1543.003</id>
    </mitre>
  </rule>

  <rule id="100602" level="13">
    <if_sid>100601</if_sid>
    <field name="win.eventdata.imagePath">powershell|cmd\.exe\s+/c|%COMSPEC%|\\\\Temp\\\\|\\\\Users\\\\|AppData|ADMIN\$|\\\\\\\\.*\\\\pipe\\\\</field>
    <description>CRITICAL: service installed with a suspicious image path. Service $(win.eventdata.serviceName), path $(win.eventdata.imagePath)</description>
    <mitre>
      <id>T1543.003</id>
      <id>T1569.002</id>
    </mitre>
  </rule>

  <!-- PsExec and its clones. Named pipe plus a randomly named service -->
  <rule id="100603" level="13">
    <if_sid>100601</if_sid>
    <field name="win.eventdata.serviceName">PSEXESVC|PAExec|RemCom|CSEXECSVC</field>
    <description>CRITICAL: remote execution service installed. $(win.eventdata.serviceName) on $(win.system.computer)</description>
    <mitre>
      <id>T1569.002</id>
      <id>T1021.002</id>
    </mitre>
  </rule>

</group>
```

### Why 7045 is high value

Service installation is rare and it is powerful. A service runs as SYSTEM, survives reboots, and starts before any user logs on. Legitimate service installs happen during software installation and Windows updates, which is a handful of times a month on a workstation.

Anything installing a service whose image path is a PowerShell command line, or a binary in `Temp`, is not installing software.

**Named services are lazy and catching them is free.** PsExec has always created `PSEXESVC`. Its clones mostly did not bother to change the name. Rule 100603 costs nothing and catches a large share of hands-on-keyboard lateral movement.

---

## SOC-1007: LSASS Memory Access

**Technique:** T1003.001 LSASS Memory
**Severity:** Critical
**Data source:** Sysmon 10

### Sigma

```yaml
title: Credential Dumping via LSASS Process Access
id: 5d7f2a89-3e14-4b60-9c25-8a1f6b4d0e73
status: experimental
description: Detects a process opening a handle to LSASS with read access, which is how credential material is extracted from memory.
author: VBunny
date: 2026/07/22
references:
  - https://attack.mitre.org/techniques/T1003/001/
logsource:
  product: windows
  category: process_access
detection:
  selection:
    TargetImage|endswith: '\lsass.exe'
    GrantedAccess:
      - '0x1010'
      - '0x1410'
      - '0x1438'
      - '0x143a'
      - '0x1418'
      - '0x0010'
  filter_system:
    SourceImage|endswith:
      - '\wmiprvse.exe'
      - '\MsMpEng.exe'
      - '\csrss.exe'
      - '\wininit.exe'
      - '\services.exe'
  condition: selection and not filter_system
fields:
  - SourceImage
  - GrantedAccess
  - CallTrace
  - User
falsepositives:
  - Endpoint protection products reading LSASS during a scan
  - Crash dump handlers during a genuine LSASS fault
level: critical
```

### Wazuh XML

```xml
<group name="windows,sysmon,credential_access,attack.t1003,">

  <rule id="100701" level="12">
    <if_sid>61612</if_sid>
    <field name="win.eventdata.targetImage">lsass\.exe</field>
    <field name="win.eventdata.grantedAccess">0x1010|0x1410|0x1438|0x143a|0x1418|0x0010</field>
    <description>LSASS memory access by $(win.eventdata.sourceImage) with access $(win.eventdata.grantedAccess)</description>
    <mitre>
      <id>T1003.001</id>
    </mitre>
  </rule>

  <rule id="100702" level="0">
    <if_sid>100701</if_sid>
    <field name="win.eventdata.sourceImage">wmiprvse\.exe|MsMpEng\.exe|csrss\.exe|wininit\.exe|services\.exe</field>
    <description>LSASS access by a known system process, ignored</description>
  </rule>

  <!-- UNKNOWN in the call stack means the call came from unbacked memory -->
  <rule id="100703" level="14">
    <if_sid>100701</if_sid>
    <field name="win.eventdata.callTrace">UNKNOWN</field>
    <description>CRITICAL: LSASS accessed from unbacked memory. Injected or reflectively loaded code on $(win.system.computer), source $(win.eventdata.sourceImage)</description>
    <mitre>
      <id>T1003.001</id>
      <id>T1055</id>
    </mitre>
  </rule>

  <!-- comsvcs.dll MiniDump, the living-off-the-land route -->
  <rule id="100704" level="14">
    <if_sid>61603</if_sid>
    <field name="win.eventdata.commandLine">comsvcs\.dll.*MiniDump|rundll32.*comsvcs</field>
    <description>CRITICAL: LSASS dump attempt via comsvcs.dll MiniDump on $(win.system.computer)</description>
    <mitre>
      <id>T1003.001</id>
    </mitre>
  </rule>

</group>
```

### Reading GrantedAccess

The access mask tells you intent. These are the ones worth knowing.

| Mask | Rights | Meaning |
| --- | --- | --- |
| `0x1010` | Query limited info, read VM | Reading memory. Mimikatz classic |
| `0x1410` | Query info, read VM | Same intent, different tool |
| `0x1438` | Query, read, write VM, operation | Read and write. More aggressive |
| `0x0010` | Read VM only | Bare minimum read |
| `0x1000` | Query limited info only | Usually benign, process enumeration |
| `0x400` | Query information | Benign |

`0x1000` and `0x400` on their own are enumeration, not dumping. Including them adds noise without adding detections. The mask to care about is anything containing the `VM_READ` bit, which is `0x0010`.

### Why 100703 is the strongest rule here

An attacker can rename their binary, sign it, or use a living-off-the-land binary. All of that defeats a rule that keys on the source image name.

What they cannot easily hide is the call stack. `CallTrace` containing `UNKNOWN` means the call originated from memory that is not backed by a file on disk. That is what reflective DLL loading and most in-memory tooling looks like, and it is true regardless of what the process is called.

**I ran this rule against Defender performing a scan to check.** Defender reads LSASS and it does so from `MsMpEng.exe` with a fully resolved call stack. The exclusion is safe and the `UNKNOWN` variant stayed silent, which is what you want from a critical rule.

---

## SOC-1008: Office Application Spawning a Shell

**Technique:** T1566.001 into T1059
**Severity:** Critical
**Data source:** Sysmon 1

### Sigma

```yaml
title: Office Application Spawning a Command Interpreter
id: 8c3a6e70-4f21-4d93-a8b7-5e2c9f1d6a04
status: stable
description: Detects an Office application creating a shell or scripting process, which is the execution step of a macro-based phishing document.
author: VBunny
date: 2026/07/23
references:
  - https://attack.mitre.org/techniques/T1566/001/
logsource:
  category: process_creation
  product: windows
detection:
  selection:
    ParentImage|endswith:
      - '\winword.exe'
      - '\excel.exe'
      - '\powerpnt.exe'
      - '\outlook.exe'
      - '\msaccess.exe'
      - '\onenote.exe'
      - '\visio.exe'
    Image|endswith:
      - '\cmd.exe'
      - '\powershell.exe'
      - '\pwsh.exe'
      - '\wscript.exe'
      - '\cscript.exe'
      - '\mshta.exe'
      - '\rundll32.exe'
      - '\regsvr32.exe'
      - '\certutil.exe'
      - '\bitsadmin.exe'
      - '\curl.exe'
      - '\schtasks.exe'
  condition: selection
fields:
  - ParentImage
  - Image
  - CommandLine
  - User
falsepositives:
  - Legitimate business macros, which should be enumerated and excluded individually
level: critical
```

### Wazuh XML

```xml
<group name="windows,sysmon,execution,attack.t1566,">

  <rule id="100801" level="14">
    <if_sid>61603</if_sid>
    <field name="win.eventdata.parentImage">winword\.exe|excel\.exe|powerpnt\.exe|outlook\.exe|msaccess\.exe|onenote\.exe|visio\.exe</field>
    <field name="win.eventdata.image">cmd\.exe|powershell\.exe|pwsh\.exe|wscript\.exe|cscript\.exe|mshta\.exe|rundll32\.exe|regsvr32\.exe|certutil\.exe|bitsadmin\.exe|curl\.exe|schtasks\.exe</field>
    <description>CRITICAL: $(win.eventdata.parentImage) spawned $(win.eventdata.image) on $(win.system.computer) as $(win.eventdata.user). Command: $(win.eventdata.commandLine)</description>
    <mitre>
      <id>T1566.001</id>
      <id>T1059</id>
    </mitre>
  </rule>

</group>
```

### Why this one has no exclusions

This is my highest confidence rule and the only one I deployed without a tuning pass.

Word has no legitimate reason to start PowerShell. Excel has no legitimate reason to start `certutil`. In 48 hours of normal use across two workstations this rule fired zero times, and during the simulation it fired within two seconds of the document opening.

If a business genuinely has a macro that does this, the answer is to enumerate that one macro and exclude it by hash, not to soften the rule. A rule this clean is worth protecting.

**Process ancestry is the concept underneath.** It is not that PowerShell is bad. It is that PowerShell under Word is bad. Most high quality detections are about the relationship between processes rather than the processes themselves.

---

## SOC-1009: Defender Tampering

**Technique:** T1562.001 Impair Defenses
**Severity:** Critical
**Data source:** Sysmon 1 and 13, Defender operational log

### Wazuh XML

```xml
<group name="windows,defense_evasion,attack.t1562,">

  <rule id="100901" level="13">
    <if_sid>61603</if_sid>
    <field name="win.eventdata.commandLine">Set-MpPreference.*Disable|Add-MpPreference.*ExclusionPath|Add-MpPreference.*ExclusionProcess|Remove-MpPreference</field>
    <description>CRITICAL: Defender configuration modified from the command line on $(win.system.computer) by $(win.eventdata.user)</description>
    <mitre>
      <id>T1562.001</id>
    </mitre>
  </rule>

  <rule id="100902" level="13">
    <if_sid>61615</if_sid>
    <field name="win.eventdata.targetObject">Windows Defender\\\\(Real-Time Protection|Exclusions|DisableAntiSpyware)</field>
    <description>CRITICAL: Defender registry key modified. $(win.eventdata.targetObject) set to $(win.eventdata.details)</description>
    <mitre>
      <id>T1562.001</id>
    </mitre>
  </rule>

  <rule id="100903" level="13">
    <if_sid>61603</if_sid>
    <field name="win.eventdata.commandLine">wevtutil\s+cl|Clear-EventLog|Remove-EventLog|wevtutil\s+sl.*\/e:false</field>
    <description>CRITICAL: event log cleared or disabled on $(win.system.computer) by $(win.eventdata.user)</description>
    <mitre>
      <id>T1070.001</id>
    </mitre>
  </rule>

</group>
```

### Why defence evasion is high severity even when it fails

An attacker adding a Defender exclusion has already got code execution and is preparing to drop something that Defender would otherwise catch. The exclusion is not the attack. It is the step immediately before the attack.

By the time you see this, assume the host is compromised and work backwards to find how.

Event log clearing, event 1102, is the same. Nobody clears the Security log as part of normal work. It is an anti-forensics step and it means someone is trying to remove a trail that exists.

---

## SOC-1010: Sensitive Group Membership Change

**Technique:** T1098 Account Manipulation
**Severity:** Critical
**Data source:** Windows Security 4728, 4732, 4756

### Wazuh XML

```xml
<group name="windows,privilege_escalation,attack.t1098,">

  <rule id="101001" level="14">
    <if_sid>60103</if_sid>
    <field name="win.system.eventID">^4728$|^4732$|^4756$</field>
    <field name="win.eventdata.targetUserName">Domain Admins|Enterprise Admins|Schema Admins|Administrators|Account Operators|Backup Operators|Server Operators|Group Policy Creator Owners|DnsAdmins</field>
    <description>CRITICAL: $(win.eventdata.memberName) added to privileged group $(win.eventdata.targetUserName) by $(win.eventdata.subjectUserName)</description>
    <mitre>
      <id>T1098</id>
      <id>T1078.002</id>
    </mitre>
  </rule>

  <!-- Group added, then removed shortly after. Temporary elevation to do something -->
  <rule id="101002" level="14" frequency="2" timeframe="3600">
    <if_matched_sid>101001</if_matched_sid>
    <same_field>win.eventdata.memberName</same_field>
    <description>CRITICAL: $(win.eventdata.memberName) added to and removed from a privileged group within one hour. Possible temporary elevation to conceal activity</description>
    <mitre>
      <id>T1098</id>
    </mitre>
  </rule>

</group>
```

### Note

`DnsAdmins` is in that list for a reason people miss. It is not an obviously privileged group, but membership allows loading an arbitrary DLL into the DNS service, which runs as SYSTEM on a domain controller. It is a documented privilege escalation path to Domain Admin and it is routinely left out of monitoring because the name does not sound dangerous.

**Rule 101002 catches the careful attacker.** Adding yourself to Domain Admins and staying there is obvious. Adding yourself, doing one thing, and removing yourself is what someone does when they know group membership is audited. The add-then-remove pattern inside an hour is a stronger signal than the add alone.

---

## Deploying These

```bash
sudo nano /var/ossec/etc/rules/local_rules.xml
sudo /var/ossec/bin/wazuh-logtest -t          # syntax check, no restart
sudo systemctl restart wazuh-manager
```

**Always run `wazuh-logtest -t` first.** A malformed rule file stops the manager from starting, and a manager that will not start is a SIEM that is silently collecting nothing.

Testing a rule against a real event without running the attack again:

```bash
sudo /var/ossec/bin/wazuh-logtest
# paste a raw event from archives.log, it prints which rules matched and why
```

This is the fastest way to work out why a rule did not fire. Nine times out of ten it is a field name. Wazuh lowercases the first letter of Sysmon field names, so `CommandLine` in the raw event becomes `win.eventdata.commandLine` in the rule. That one cost me an afternoon.

---

## Summary

| Rule | Technique | Level | FPs per 48h after tuning |
| --- | --- | :---: | :---: |
| SOC-1001 Password spray | T1110.003 | 12 | 0 |
| SOC-1002 Kerberoasting | T1558.003 | 13 | 1 |
| SOC-1003 Suspicious PowerShell | T1059.001 | 10 to 14 | 1 |
| SOC-1004 Run key persistence | T1547.001 | 12 | 2 |
| SOC-1005 Scheduled task | T1053.005 | 12 | 1 |
| SOC-1006 Service installation | T1543.003 | 13 | 0 |
| SOC-1007 LSASS access | T1003.001 | 12 to 14 | 0 |
| SOC-1008 Office spawning shell | T1566.001 | 14 | 0 |
| SOC-1009 Defender tampering | T1562.001 | 13 | 0 |
| SOC-1010 Privileged group change | T1098 | 14 | 0 |

Five false positives per 48 hours across ten rules. That is a queue a single analyst can actually work.

---

Next: [04-Triage-Playbooks.md](04-Triage-Playbooks.md)

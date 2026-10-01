# 01 - Detection Engineering Lab

The environment for building detections, and the pipeline that turns an idea into a deployed rule.

---

## What This Adds

The earlier labs gave us two working SIEMs: Wazuh from [SOC-01](../Junior-SOC-Analyst/) and Microsoft Sentinel from [SOC-02](../SOC-Analyst-1/). Both work. Both have detections in them.

The problem this project solves is that those detections were written by hand, one at a time, directly in each product. That does not scale, it is not testable, and a rule written in the Wazuh console does not exist in Sentinel.

**A detection engineer writes a detection once and deploys it everywhere, with a test that proves it works.** That is what this lab is for.

---

## The Pieces

| Component | Role | From |
| --- | --- | --- |
| Wazuh | SIEM target one | SOC-01 |
| Microsoft Sentinel | SIEM target two | SOC-02 |
| The Proxmox lab | Where detections are tested | SOC-01 |
| Kali | Adversary emulation source | SOC-01 |
| A git repository | Where detections live as code | New |
| Sigma and sigmac | The detection language and converter | New |
| A CI runner | Tests detections automatically | New |

The new part is the last three rows. Everything else is reused.

---

## Why Detection as Code

Writing detections in a SIEM console has four problems, and each one is solved by treating detections as code in a repository.

| Problem with console-written rules | Solved by |
| --- | --- |
| No history. Who changed this rule, and why | Git commit history |
| No review. A bad rule goes straight to production | Pull requests |
| No testing. You find out it is broken during an incident | Automated tests in CI |
| Locked to one product | A vendor-neutral source format |

**The last one is the clincher for a multi-SIEM environment.** A rule written in Wazuh XML is a rule that only exists in Wazuh. A rule written in Sigma is a rule you can deploy to Wazuh, Sentinel, Splunk, Elastic, and a dozen others, from one source.

---

## The Pipeline

![The detection-as-code pipeline from commit to deployment](images/detection-cicd.svg)

```text
Write a Sigma rule
        |
        v
Commit to git
        |
        v
CI runs:  syntax check  ->  convert to each SIEM  ->  test against sample logs
        |
        v (all pass)
Deploy to Wazuh and Sentinel
        |
        v
Validate with an emulated attack
```

Each stage is covered in [02-Detection-as-Code.md](02-Detection-as-Code.md). This module is the setup.

---

## Repository Layout

```text
detections/
  rules/
      execution/
          office-spawns-shell.yml
          encoded-powershell.yml
      persistence/
          registry-run-key.yml
          scheduled-task.yml
      credential-access/
          lsass-access.yml
          kerberoasting.yml
      ...
  tests/
      office-spawns-shell/
          positive.json      <- a log that SHOULD match
          negative.json      <- a log that should NOT match
  pipeline/
      convert.sh
      test.sh
      deploy.sh
  ci/
      pipeline.yml
  README.md
```

**Every rule has a positive and a negative test.** The positive proves it catches the attack. The negative proves it does not fire on normal activity. A rule without both is a rule you are trusting on faith.

---

## Setting Up Sigma

Sigma is the vendor-neutral detection format. `sigma-cli` converts it to any target.

```bash
# Install the modern Sigma toolchain
pipx install sigma-cli

# Add the backends for our two SIEMs
sigma plugin install elasticsearch     # Sentinel uses a similar query model
sigma plugin install loki              # and others as needed

# Confirm
sigma version
sigma list targets
```

For Sentinel specifically, the community `pySigma-backend-microsoft365defender` and Kusto backends convert Sigma to KQL. For Wazuh, conversion is to its XML rule format via a template.

```bash
pipx inject sigma-cli pysigma-backend-kusto
```

---

## An Example Rule

The Office-spawns-shell detection from SOC-01, written once as Sigma.

```yaml
title: Office Application Spawning a Command Interpreter
id: 8c3a6e70-4f21-4d93-a8b7-5e2c9f1d6a04
status: stable
description: Detects an Office application creating a shell or scripting process, the execution step of a macro-based phishing document.
author: VBunny
date: 2026/09/22
references:
  - https://attack.mitre.org/techniques/T1566/001/
tags:
  - attack.initial_access
  - attack.t1566.001
  - attack.execution
  - attack.t1059
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
      - '\onenote.exe'
    Image|endswith:
      - '\cmd.exe'
      - '\powershell.exe'
      - '\pwsh.exe'
      - '\wscript.exe'
      - '\cscript.exe'
      - '\mshta.exe'
      - '\rundll32.exe'
      - '\regsvr32.exe'
  condition: selection
falsepositives:
  - Legitimate business macros, which should be enumerated and excluded by hash
level: high
```

**This is the single source of truth.** From here it becomes a Wazuh rule and a Sentinel analytics rule, automatically. Change the logic once, and both SIEMs update on the next pipeline run.

### Convert it

```bash
# To Wazuh
sigma convert -t wazuh -p windows office-spawns-shell.yml

# To Sentinel KQL
sigma convert -t kusto office-spawns-shell.yml
```

```kql
// The KQL that comes out, for Sentinel
DeviceProcessEvents
| where InitiatingProcessFileName endswith "\\winword.exe"
    or InitiatingProcessFileName endswith "\\excel.exe"
    or InitiatingProcessFileName endswith "\\powerpnt.exe"
    or InitiatingProcessFileName endswith "\\outlook.exe"
    or InitiatingProcessFileName endswith "\\onenote.exe"
| where FileName in~ ("cmd.exe","powershell.exe","pwsh.exe","wscript.exe",
                      "cscript.exe","mshta.exe","rundll32.exe","regsvr32.exe")
```

Same logic, two products, one file.

---

## The Test Harness

A detection needs a test, and the test needs sample logs.

```json
// tests/office-spawns-shell/positive.json
// A log that MUST match. This is what the attack looks like.
{
  "EventID": 1,
  "Image": "C:\\Windows\\System32\\WindowsPowerShell\\v1.0\\powershell.exe",
  "ParentImage": "C:\\Program Files\\Microsoft Office\\root\\Office16\\WINWORD.EXE",
  "CommandLine": "powershell.exe -nop -w hidden -enc SQBFAFgA...",
  "User": "BLUELAB\\jsmith"
}
```

```json
// tests/office-spawns-shell/negative.json
// A log that must NOT match. Normal PowerShell use.
{
  "EventID": 1,
  "Image": "C:\\Windows\\System32\\WindowsPowerShell\\v1.0\\powershell.exe",
  "ParentImage": "C:\\Windows\\explorer.exe",
  "CommandLine": "powershell.exe Get-Process",
  "User": "BLUELAB\\jsmith"
}
```

**The negative test is what stops a rule becoming noise.** It is easy to write a rule that catches the attack. The skill is writing one that catches the attack and stays quiet on the normal version of the same tool.

Where the tests live and how they run is [02-Detection-as-Code.md](02-Detection-as-Code.md).

---

## Building the Test Data

Real test data comes from running the technique and capturing the log it produces.

```powershell
# On WIN11, run the technique
$enc = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes("Write-Host test"))
# (spawned from Word's macro editor to get the real parent process)

# Then export the Sysmon event it produced
Get-WinEvent -LogName 'Microsoft-Windows-Sysmon/Operational' -MaxEvents 1 |
    Where-Object { $_.Id -eq 1 } |
    ForEach-Object { ([xml]$_.ToXml()).Event.EventData } |
    ConvertTo-Json | Out-File positive.json
```

**Capture real logs, do not write them by hand.** A hand-written test log has the field names you assumed. A captured one has the field names the product actually uses, which is where rules break.

---

## What Good Looks Like

A finished detection in this repository has all of these:

```text
[ ] A Sigma rule with a title, description, and ATT&CK tags
[ ] A stable UUID so it can be tracked across changes
[ ] A documented false positive section
[ ] A positive test built from a real captured log
[ ] A negative test from real normal activity
[ ] A severity level that matches how you would respond
[ ] It converts cleanly to both Wazuh and Sentinel
[ ] Both tests pass in CI
```

**That checklist is the Tier 2 standard.** A rule that meets it is one you can deploy without watching it, revert if it misbehaves, and hand to someone else who can understand it.

---

## Build Order

1. Set up the git repository with the layout above
2. Install Sigma and the backends for both SIEMs
3. Migrate the existing hand-written rules from SOC-01 and SOC-02 into Sigma
4. Build a positive and negative test for each, from captured logs
5. Write the conversion and test scripts
6. Set up the CI pipeline (module 02)
7. Deploy from the pipeline, not by hand, from now on

**Step 3 is the unglamorous one that matters.** Migrating existing rules into a testable format is most of the early work, and it is where you find that two of your old rules were subtly broken and never fired.

---

Next: [02-Detection-as-Code.md](02-Detection-as-Code.md)

<h1 align="center">IT & Security Operations Documentation</h1>

<p align="center">
<em>A working library of runbooks, lab builds, and operational procedures</em>
</p>

---

<p align="center">

<img alt="CompTIA Security+" src="https://img.shields.io/badge/Security%2B-CompTIA-E2231A?style=for-the-badge&logo=comptia&logoColor=white" />
<img alt="CompTIA CySA+ Cybersecurity Analyst" src="https://img.shields.io/badge/CySA%2B-Cybersecurity_Analyst-E2231A?style=for-the-badge&logo=comptia&logoColor=white" />
<img alt="CompTIA PenTest+" src="https://img.shields.io/badge/PenTest%2B-Offensive_Security-E2231A?style=for-the-badge&logo=comptia&logoColor=white" />
<img alt="ISC2 SSCP" src="https://img.shields.io/badge/SSCP-ISC2-00549F?style=for-the-badge" />
<img alt="ISC2 CISSP, in progress" src="https://img.shields.io/badge/CISSP-In_Progress-00549F?style=for-the-badge" />
<img alt="OffSec OSCP, in progress" src="https://img.shields.io/badge/OSCP-In_Progress-1A1A1A?style=for-the-badge&logo=offensive-security&logoColor=white" />

</p>

<p align="center">

<img alt="Windows Server 2022 and 2025" src="https://img.shields.io/badge/Windows_Server-2022_&_2025-0078D6?style=for-the-badge&logo=windows&logoColor=white" />
<img alt="Active Directory hardening and administration" src="https://img.shields.io/badge/Active_Directory-Hardening_&_Admin-512BD4?style=for-the-badge&logo=microsoft&logoColor=white" />
<img alt="Group Policy security baselines" src="https://img.shields.io/badge/Group_Policy-Security_Baselines-0078D4?style=for-the-badge&logo=windows&logoColor=white" />
<img alt="Entra ID identity and access" src="https://img.shields.io/badge/Entra_ID-Identity_&_Access-0089D6?style=for-the-badge&logo=microsoftazure&logoColor=white" />
<img alt="Microsoft Intune endpoint management" src="https://img.shields.io/badge/Intune-Endpoint_Management-0078D4?style=for-the-badge&logo=microsoft&logoColor=white" />
<img alt="PowerShell automation" src="https://img.shields.io/badge/PowerShell-Automation-5391FE?style=for-the-badge&logo=powershell&logoColor=white" />
<img alt="CompTIA Linux+" src="https://img.shields.io/badge/Linux-CompTIA_Linux%2B-FCC624?style=for-the-badge&logo=linux&logoColor=black" />
<img alt="Networking: DNS, DHCP, TCP/IP" src="https://img.shields.io/badge/Networking-DNS_|_DHCP_|_TCP/IP-00599C?style=for-the-badge" />
<img alt="MFA: Duo and Conditional Access" src="https://img.shields.io/badge/MFA-Duo_|_Conditional_Access-6DB33F?style=for-the-badge" />
<img alt="RMM: Atera, Level, CIPP" src="https://img.shields.io/badge/RMM-Atera_|_Level_|_CIPP-00B388?style=for-the-badge" />
<img alt="ITIL service management" src="https://img.shields.io/badge/ITIL-Service_Management-F57C00?style=for-the-badge" />

</p>

---

## About

I'm **VBunny** (`vampiricbunny`) - an IT and security operations practitioner working across Windows infrastructure, identity, endpoint management, and defensive security.

This repository is where I document the work. Every runbook here was written while performing the task in a lab I built and maintain myself, then edited down into something another technician could actually follow. The goal is not to collect guides - it's to prove I can operate a system *and* explain it clearly enough that someone else can repeat the result.

My background runs from the helpdesk floor upward: ticket queues, endpoint triage, user support, then server administration, identity, and increasingly the security side. The CompTIA security stack (Security+ → CySA+ → PenTest+) and SSCP reflect where that's heading, with CISSP and OSCP in progress.

Documentation is the part of this job most people skip. I don't - because the runbook you write on a quiet Tuesday is the one that saves the outage on a Friday night.

---

## Projects

Each project is a complete piece of work rather than a guide. A lab built, a problem attacked, the results written up the way the job would expect.

### [IR-01 - Ransomware Incident: Detection to Recovery](Ransomware-Incident-Response/)  (flagship)

**Target role: SOC Analyst / Incident Responder**

The capstone. One ransomware intrusion run end to end and defended as the responder, with the real tool output at every stage from the phishing email to the clean recovery. Detected seven minutes after the first click, contained before it reached the fleet. Built as one deep illustrated README with 20 realistic dark-mode screenshots of the actual systems in operation.

| | |
| --- | --- |
| Capstone | A full ransomware kill chain detected and stopped before domain-wide encryption |
| Mean time to detect / contain | 7 minutes / 31 minutes |
| Blast radius | 2 of 176 hosts, 0 data lost, 0 ransom paid |
| Tooling shown | Sentinel, Defender for Endpoint, Sysmon, Logic Apps SOAR, BloodHound, ATT&CK Navigator, Veeam |
| Screenshots | 20, every stage of the lifecycle |

Everything is in one [illustrated README](Ransomware-Incident-Response/). The three to look at: the [Sentinel incident](Ransomware-Incident-Response/images/siem-incident.png) that correlated nine alerts into one, the [Defender attack story](Ransomware-Incident-Response/images/edr-process-tree.png) tracing the process chain, and the [SOAR containment](Ransomware-Incident-Response/images/soar-containment.png) that isolated the host in 44 seconds.

### [SOC-01 - Detection and Triage Lab](Junior-SOC-Analyst/)

**Target role: SOC Analyst I**

Built a segmented Active Directory network on Proxmox, instrumented it with Sysmon, Windows audit policy and Wazuh, then ran a full intrusion against it and worked the alerts as an analyst.

| | |
| --- | --- |
| Detection rules written | 10 in Sigma and Wazuh XML, with tuning history |
| Techniques detected | 15 of 19 (79 percent), gaps documented |
| False positives | 118 per 48 hours, down to 5 after tuning |
| Alerts triaged | 12 end to end, including 4 false positives |
| Mean detection latency | 5.5 seconds on signature rules |
| Time to containment | 13 minutes 47 seconds |

The artifacts are the point: [detection rules](Junior-SOC-Analyst/03-Detection-Rules.md), [triage playbooks](Junior-SOC-Analyst/04-Triage-Playbooks.md), a [worked alert log](Junior-SOC-Analyst/06-Alert-Triage-Log.md) and a full [incident report](Junior-SOC-Analyst/07-Incident-Report.md).

### [SOC-02 - Enterprise SIEM Operations](SOC-Analyst-1/)

**Target role: SOC Analyst I**

Microsoft Sentinel and Defender XDR, with the Proxmox lab onboarded through Azure Arc. Queue operations at volume, incident investigation, phishing analysis and SOAR automation.

| | |
| --- | --- |
| Data connectors | 9 configured |
| Analytics rules | 12, written in KQL with entity mapping |
| KQL query library | 50 queries, basics through hunting |
| SOAR playbooks | 6 Logic Apps, both destructive ones behind approval |
| Investigations | 6 case files, 14 phishing reports |
| Ingestion cost | 4.80 USD/month, down from 61. A 92 percent cut |
| Median time to triage | 11 minutes |

The two files worth your time: the [KQL library](SOC-Analyst-1/02-KQL-Query-Library.md) for technical depth, and the [case files](SOC-Analyst-1/08-Investigation-Case-Files.md) for judgement.

### [SOC-03 - Threat Hunting and Detection Engineering](SOC-Analyst-2/)

**Target role: SOC Analyst II / Tier 2**

Where the role stops working the queue and starts building it. Detections written once as code and deployed to both SIEMs, threat hunting, adversary emulation, and honest coverage measurement.

| | |
| --- | --- |
| Detections as code | 24, tested and deployed to Wazuh and Sentinel from one source |
| Hunts run | 6, with 2 finding a real compromise |
| Techniques emulated | 31, 24 detected, 5 gaps closed |
| ATT&CK coverage | 11 of 14 tactics, gaps documented not hidden |
| Maturity | Level 3, moving to 4 |

The two files worth your time: the [hunt case files](SOC-Analyst-2/04-Hunt-Case-Files.md) for how I work an open problem, and [detection coverage](SOC-Analyst-2/06-Detection-Coverage.md) for whether I can be honest about gaps.

### [SOC-04 - Senior SOC Analyst and Incident Command](SOC-Analyst-3/)

**Target role: SOC Analyst III / Tier 3 / SOC Lead**

The top of the SOC ladder. Where you stop working incidents one at a time and run the function that handles all of them. A major incident commanded end to end, a purple team program, detection strategy, threat-intelligence-driven priorities, and reporting to leadership. Built as one illustrated README, heavy on drawn console schematics of the real tools so a non-technical reader can see the work.

| | |
| --- | --- |
| Capstone | A pre-ransomware intrusion commanded as incident commander, no data lost |
| Mean time to detect / respond | 6 minutes / 38 minutes |
| Purple team | 16 techniques emulated, coverage 9 to 16 of 16 |
| Tooling shown | Sentinel, Defender XDR, OpenCTI, Logic Apps SOAR, ATT&CK Navigator |
| Audience | Written for leadership, with a metrics dashboard and maturity model |

Everything is in one [illustrated README](SOC-Analyst-3/) with 16 diagrams, 8 of them drawn consoles of the actual tools. The two to look at: the [Sentinel incident graph](SOC-Analyst-3/images/sentinel-incident.svg) for how a whole intrusion is read at once, and the [ATT&CK coverage heatmap](SOC-Analyst-3/images/attack-navigator.svg) for what the purple team found and fixed.

### [NOC-02 - Network Monitoring and Performance Engineering](NOC-Analyst-2/)

**Target role: Network Operations Analyst II / Tier 2 NOC**

Availability and performance, not security. Building the monitoring, tuning the alert noise out, and finding the root cause of the problems that keep recurring.

| | |
| --- | --- |
| Devices monitored | 7 across 3 subnets, SNMP and time-series |
| Dashboards | 4, from NOC wall to templated device detail |
| Alert noise reduction | 340 to 22 per week, a 94 percent cut with no real alert lost |
| Troubleshooting cases | 5 worked end to end, 2 recurring problems eliminated |
| Automation | 3 runbooks automated, an hour of toil a day removed |

The two files worth your time: [alerting and noise reduction](NOC-Analyst-2/04-Alerting-and-Noise-Reduction.md) for the core Tier 2 skill, and [troubleshooting playbooks](NOC-Analyst-2/07-Troubleshooting-Playbooks.md) for how I find root cause.

### [NOC-03 - Network Reliability Engineering and Incident Command](NOC-Analyst-3/)

**Target role: NOC Analyst III / Tier 3 / Network Reliability Lead**

The top of the NOC ladder. Where you stop watching the board, stop just building the monitoring, and run the reliability of the whole network. A major outage commanded end to end, service-level objectives and an error budget, the network built from a single source of truth so config drift cannot recur, and uptime reported to leadership in money. One illustrated README, heavy on drawn consoles of the real tools.

| | |
| --- | --- |
| Capstone | A partial outage commanded as incident commander, restored in 22 minutes |
| Reliability | 99.9 percent SLO with an error budget, burn-rate alerting |
| Network as code | NetBox source of truth, Ansible deploy, config drift eliminated |
| Tooling shown | LibreNMS, Prometheus, Grafana, Alertmanager, NetBox, Ansible |
| Audience | Written for leadership, with an availability trend and maturity model |

Everything is in one [illustrated README](NOC-Analyst-3/) with 16 diagrams, 8 of them drawn consoles of the actual tools. The two to look at: the [Grafana SLO dashboard](NOC-Analyst-3/images/grafana-slo-dashboard.svg) for thinking in objectives not uptime, and the [Ansible run](NOC-Analyst-3/images/ansible-run.svg) where zero changes proves drift is dead.

---

### [PT-01 - Internal Network Penetration Test](Junior-Penetration-Tester/)

**Target role: Junior Penetration Tester**

A full internal penetration test against a self-owned Active Directory lab, from an assumed-breach position to full domain compromise, written up the way a client receives it.

| | |
| --- | --- |
| Findings | 14, scored and remediated |
| Critical / High | 2 / 4 |
| Time to Domain Admin | 47 minutes |
| Findings needing a patch | 1 of 14, the rest are configuration |
| Retest | Fixes verified, two found incomplete and corrected |

The deliverable is the [findings report](Junior-Penetration-Tester/08-Findings-Report.md). Each attack is cross-referenced to the detections in the SOC projects, so [the retest](Junior-Penetration-Tester/09-Remediation-and-Retest.md) records which techniques the blue team side caught and which went through silently.

### [PT-02 - External to Internal Penetration Test](Penetration-Tester/)

**Target role: Penetration Tester**

The step up from PT-01. This one starts from nothing on the outside, with a company name and a domain. It earns the foothold from the internet, chains a web flaw into the internal network, pivots across a segmented environment, takes the domain, and reaches the customer database. Full scope: external, web application, network and Active Directory.

| | |
| --- | --- |
| Findings | 19, scored with CVSS and remediated |
| Critical / High | 3 / 6 |
| Attack path | Internet to customer data in 8 steps, across 3 segments |
| Time to Domain Admin after foothold | 2 hours 40 minutes, over a 5-day engagement |
| Findings needing a patch | 3 of 19, the rest are configuration or design |
| Retest | Fixes verified, two found incomplete and corrected |

The deliverable is the [findings report](Penetration-Tester/10-Findings-Report.md), written with an executive summary a board can read. The [web application test](Penetration-Tester/04-Web-Application-Testing.md) and the [ADCS attack path](Penetration-Tester/07-Active-Directory-Attack-Path.md) are the technical depth, and [detection and OPSEC](Penetration-Tester/09-Detection-and-OPSEC.md) grades the whole attack against my own SOC detections.

### [PT-03 - Red Team Operation and Adversary Emulation](Red-Team-Operator/)

**Target role: Senior Penetration Tester / Red Team Operator / Red Team Lead**

The top of the offensive ladder, and the capstone that ties the whole portfolio together. An authorised red team operation emulating a ransomware affiliate against the same lab the SOC projects defend, scored against the blue-team detections I built myself. Nothing weaponised: methodology at report level, with the C2 and beacon work drawn as real Kali terminal windows.

| | |
| --- | --- |
| Objective | Reach the crown jewels quietly and measure the defence |
| Result | Objective reached, caught at credential access, no impact |
| Detection | 10 of 14 techniques detected, dwell time 2 days 7 hours |
| The point | The 4 gaps became 4 new detections, dwell time falling each exercise |
| Tie-in | Red team scored against the blue team from SOC-01, SOC-03 and SOC-04 |

Everything is in one [illustrated README](Red-Team-Operator/) with 17 diagrams, including Kali terminal consoles for the [C2 operator](Red-Team-Operator/images/c2-dashboard.svg) and [beacon](Red-Team-Operator/images/beacon-console.svg) work. The one to look at is the [detection scorecard](Red-Team-Operator/images/detection-scorecard.svg): red and blue side by side, proving this was a purple team exercise that made the defence better.

---

### [GRC-01 - Governance, Risk and Compliance Program](GRC-Analyst/)

**Target role: GRC Analyst / Security Governance, Risk and Compliance**

The business side of security. The role that proves, to an auditor, an insurer or a board, that the organisation manages its risk on purpose and can show the evidence. Built around the ASD Essential Eight, NIST CSF, ISO 27001 and the CIS Controls.

| | |
| --- | --- |
| Risk | A scored register and heat map, owners and treatments |
| Compliance | Essential Eight maturity assessment, honest about the gaps |
| Governance | A control crosswalk across four frameworks, and a reviewed policy set |
| Third-party | Vendor risk rated by access and evidence |
| Audience | A board, with a posture dashboard and compliance trend |

One [illustrated README](GRC-Analyst/) with 8 realistic artefacts rendered as images: the [risk register](GRC-Analyst/images/risk-register.png), the [Essential Eight assessment](GRC-Analyst/images/essential-eight.png) and a [leadership posture dashboard](GRC-Analyst/images/compliance-dashboard.png) are the ones to look at.

---

## IT Support, Tier 1 to Tier 3

The service desk ladder, one project per tier. Each is an illustrated README with realistic images of the actual tools.

### [HD-01 - Service Desk, Tier 1](Help-Desk-1/)

**Target role: Help Desk Analyst / Service Desk / IT Support Tier 1**

First contact. Working the queue by priority and SLA, account resets and unlocks done securely, remote support with etiquette, and knowledge base articles that prevent the next ticket. Images include a [ticket queue](Help-Desk-1/images/ticket-queue.png) and a [remote support session](Help-Desk-1/images/remote-session.png).

### [HD-02 - Desktop Support, Tier 2](Help-Desk-2/)

**Target role: Desktop Support / Deskside Support / IT Support Tier 2**

The escalation tier. Managing the fleet with [Intune](Help-Desk-2/images/intune-devices.png), deploying software at scale with [PDQ](Help-Desk-2/images/pdq-deploy.png), Microsoft 365 administration, Group Policy, and escalations finished with a runbook so they become Tier 1 fixes.

### [HD-03 - Systems Support, Tier 3](Help-Desk-3/)

**Target role: Senior IT Support / Systems Administrator / Escalation Engineer**

The tier that stops the tickets happening. [PowerShell automation](Help-Desk-3/images/powershell-automation.png) of onboarding and offboarding, Active Directory and server ownership, RMM and patch compliance, documentation that outlives the person, and [recurring problems traced and eliminated](Help-Desk-3/images/recurring-problem.png).

---

## Free Course: Build a Blue Team Home Lab

### [Blue-Team-Lab-Course](Blue-Team-Lab-Course/)

A complete, free, self-paced course that takes someone from never having built a virtual machine to investigating real security alerts. Written for a total beginner, with every term explained the first time it appears.

It covers the same six areas as paid entry-level blue team certifications: security fundamentals, SIEM operations, phishing analysis, digital forensics, threat intelligence and incident response. Hands on, for nothing.

| | |
| --- | --- |
| Modules | 10, roughly 25 to 30 hours |
| Hypervisors | **Proxmox, VMware Workstation and VirtualBox**, written out in full for each |
| Lab | Windows Server 2022 domain, Windows 11 client, Wazuh SIEM, Kali |
| Cost to the reader | Nothing beyond hardware they already own |

The build module is written three times so the reader follows whichever hypervisor they have. The teaching modules then cover what to look for: [Windows logs](Blue-Team-Lab-Course/02-Understanding-Windows-Logs.md), [SIEM and detection rules](Blue-Team-Lab-Course/03-Install-Your-SIEM.md), and [a full attack and investigation](Blue-Team-Lab-Course/04-Your-First-Investigation.md).

---

## Certifications

All verifiable on [Credly](https://www.credly.com/users/julian-burkett/badges).

**Security**

- CompTIA Security+
- CompTIA Cybersecurity Analyst (CySA+)
- CompTIA PenTest+
- ISC2 Systems Security Certified Practitioner (SSCP)
- Certified Cloud Security

**CompTIA Stackable Certifications**

These are earned by combining the certifications below - they aren't separate exams, they're proof the underlying set was completed.

| Stackable | Composed Of |
| --- | --- |
| **CIOS** - IT Operations Specialist | A+ and Network+ |
| **CSIS** - Secure Infrastructure Specialist | A+, Network+ and Security+ |
| **CSAP** - Security Analytics Professional | Security+ and CySA+ |

**Infrastructure & Operations**

- CompTIA A+
- CompTIA Network+
- CompTIA Linux+
- CompTIA Project+
- CompTIA IT Fundamentals (ITF+)
- ITIL Foundation

**In Progress**

- ISC2 CISSP - exam ready, scheduling
- OffSec OSCP

---

## Lab Environment

Everything documented here runs in a self-hosted lab. Naming is consistent across all runbooks so the examples line up:

| Element | Value |
| --- | --- |
| AD forest / domain | `vbunnylab.local` |
| Microsoft 365 tenant | `vbunnylab.onmicrosoft.com` |
| Domain admin | `vampiricbunny@vbunnylab.local` |
| Standard user | `vbunny@vbunnylab.local` |
| Break-glass account | `breakglass@vbunnylab.onmicrosoft.com` |
| Hypervisors | VMware Workstation, VirtualBox |
| Servers | Windows Server 2022, Windows Server 2025 |
| Clients | Windows 11 Pro, macOS Sequoia |

Credentials in these documents are placeholders (`<LabAdminPassword>`, `<DSRMPassword123!>`). Directory users are deliberately fictional.

---

## Technical Skills

| Area | Practical Experience |
| --- | --- |
| **Windows Server 2022-2025** | Role and feature installation, domain controller promotion, DNS/DHCP services, file services, Server Manager administration |
| **Active Directory** | Forest and domain setup, OU design, user and group lifecycle, onboarding and offboarding, delegation, account lockout and recovery, AD Recycle Bin |
| **Group Policy** | GPO authoring, security filtering, WMI filtering, password and lockout policy, Defender Firewall policy, administrative templates, precedence troubleshooting |
| **Identity & Access** | Microsoft Entra ID, conditional access concepts, MFA rollout with Duo, break-glass account design, least privilege |
| **Microsoft 365** | Exchange Online, SharePoint, Teams administration, licensing, shared mailboxes, accepted domains, mail flow |
| **Microsoft Intune** | Device enrollment, compliance policies, Win32 app packaging and deployment, enrollment failure triage |
| **Endpoint Security** | Defender policy, patch management, MFA enforcement, endpoint hardening baselines |
| **SIEM & Detection** | Wazuh deployment and tuning, Sysmon configuration, Sigma rule authoring, log pipeline design |
| **Security Operations** | Alert triage, MITRE ATT&CK mapping, attack simulation with Atomic Red Team, incident reporting |
| **PowerShell** | Cmdlet fundamentals, AD automation, bulk user provisioning from CSV, scheduled administrative scripting |
| **Networking** | DNS zones and records, DHCP scopes and reservations, TCP/IP, subnetting, `ping` / `tracert` / `nslookup` / `Test-NetConnection` triage |
| **Linux** | CLI administration, file permissions, service management, log review |
| **macOS** | Deployment under VMware, System Settings administration, Terminal, printer and performance triage |
| **RMM & Monitoring** | Atera, Level, CIPP/CyberDrain, agent deployment, patch policy, alerting |
| **Service Management** | ServiceNow, HaloPSA, Zendesk, HubSpot, ticket lifecycle, escalation, ITIL-aligned process |
| **Documentation** | Runbook authoring, SOP structure, IT Glue-style asset documentation, knowledge base design |

---

## Documentation Library

### Windows Server & Active Directory

- [Windows Server 2025 - Active Directory Setup](Windows-Server-2025/Active-Directory-Setup.md)
- [Windows Server 2025 - Group Policy Objects](Windows-Server-2025/GPO.md)
- [Windows Server 2025 - File Server & Permissions](Windows-Server-2025/File-Server-and-Permissions.md)
- [Windows Server Fundamentals](Windows-Server/Windows-Server.md)
- [Active Directory Administration](Windows-Server/Active-Directory.md)
- [Group Policy Management](Windows-Server/Group-Policy-Management.md)
- [File Sharing & NTFS Permissions](Windows-Server/File-Sharing-NTFS.md)
- [Windows Troubleshooting](Windows-Server/Windows-Troubleshooting.md)

### Identity & Access Management

- [Microsoft Entra ID Fundamentals](Azure/Entra-ID-Fundamentals.md)
- [Duo Multi-Factor Authentication](MDM/Duo-MFA.md)
- [Azure Virtual Machines](Azure/Virtual-Machines-Setup.md)

### Endpoint Management

- [Intune - MDM Basics](Intune/MDM-Basics.md)
- [Intune - Device Enrollment](Intune/Device-Enrollment.md)
- [Intune - Compliance Policies](Intune/Compliance-Policies.md)
- [Intune - Application Deployment](Intune/App-Deployment.md)
- [PDQ Deploy - Software Automation](PDQ/PDQ-Deploy-Automation.md)
- [PDQ Inventory - Asset Tracking](PDQ/PDQ-Inventory.md)

### Microsoft 365

- [Microsoft 365 Administration](Microsoft365/Microsoft-365-Administration.md)
- [Exchange Online Administration](Microsoft365/Exchange-Administration.md)
- [SharePoint Administration](Microsoft365/Sharepoint-Administration.md)
- [Teams Administration](Microsoft365/Teams-Administration.md)

### Networking

- [Network Troubleshooting](Network/Networking-Troubleshooting.md)
- [DNS](Network/DNS.md)
- [DHCP](Network/DHCP.md)

### PowerShell & Automation

- [PowerShell Fundamentals](PowerShell/Powershell-Absolute-Fundamentals.md)
- [PowerShell Automation for Active Directory](PowerShell/Powershell-Automation.md)

### RMM & Monitoring

- [Atera - Introduction](Atera-RMM/Atera-Introduction.md)
- [Atera - Installing Agents](Atera-RMM/Installing-Agents-for-Atera.md)
- [Atera - Patch Management](Atera-RMM/Patch-Management-with-Atera.md)
- [Atera - Remote Access via AnyDesk](Atera-RMM/Remote-Access-Via-Anydesk.md)
- [Atera - Splashtop Remote Access](Atera-RMM/Splashtop-Remote-Access.md)
- [Level RMM - Overview](Level-RMM/Level-Overview.md)
- [Level RMM - Automation](Level-RMM/Level-RMM-Automation.md)
- [CIPP / CyberDrain - Standard Operating Procedures](CIPP-Cyberdrain/Standard-Operating-Procedures.md)
- [CIPP / CyberDrain - Troubleshooting Runbook](CIPP-Cyberdrain/Troubleshooting-Runbook.md)

### Service Desk & Ticketing

- [ServiceNow](Ticketing-Systems/ServiceNow-Ticketing.md)
- [HaloPSA](Ticketing-Systems/HaloPSA.md)
- [Zendesk](Ticketing-Systems/Zendesk.md)
- [HubSpot Ticketing](Ticketing-Systems/Hubspot-Ticketing-System.md)

### Troubleshooting Runbooks

- [General IT Troubleshooting](Troubleshooting/Troubleshooting-IT-Issues.md)
- [Printer Issues](Troubleshooting/Printer-Issues.md)
- [Outlook Issues](Troubleshooting/Outlook-Issues.md)
- [Domain Trust Relationship Failed](Troubleshooting/Domain-Trust-Relationship-Failed.md)

### Remote Support

- [Microsoft Remote Desktop](Remote-Connection/Microsoft-RDP.md)
- [TeamViewer](Remote-Connection/TeamViewer.md)

### macOS

- [macOS for IT Support](MacOS/MacOS-For-IT-Support.md)
- [Installing Sequoia via VMware Workstation](MacOS/Installing-Sequoia-via-VMware-Workstation.md)

### Documentation & Service Practice

- [Documentation Best Practices](ITGlue/Documentation-Best-Practices.md)
- [IT Documentation Templates](ITGlue/IT-Documentation-Templates.md)
- [Ticketing Best Practices](CustomerService/Ticketing-Best-Practices.md)
- [Communication Best Practices](CustomerService/Communication-Best-Practices.md)
- [Handling Difficult Customers](CustomerService/Handling-Difficult-Customers.md)

---

## How This Repository Is Maintained

Documents are living. When a procedure changes, or I find a better way through a problem, the runbook gets updated rather than duplicated.

This library is being rewritten and re-validated section by section, working outward from the core Windows Server, Active Directory and networking material. Documents still queued for that pass carry procedures I have followed but not yet re-verified end to end in the current lab build.

All artwork is authored as SVG, so it stays readable at any zoom and renders correctly in both light and dark themes. Two kinds appear here:

- **Concept diagrams** - permission evaluation, Group Policy precedence, DNS resolution order, the DORA exchange, lab topology.
- **Console schematics** - accurate layouts of the MMC consoles with numbered callouts tied to the steps in the document. These are drawn illustrations, labelled as such, and are deliberately not presented as screen captures.

Real screenshots are taken from my own lab as each section is re-validated. [LAB-CAPTURE-LIST.md](LAB-CAPTURE-LIST.md) tracks what is still outstanding.

---

## Connect

**LinkedIn** - [linkedin.com/in/julian-burkett](https://www.linkedin.com/in/julian-burkett/)

**Credly** - [credly.com/users/julian-burkett/badges](https://www.credly.com/users/julian-burkett/badges)

**GitHub** - [github.com/vampiricbunny](https://github.com/vampiricbunny)

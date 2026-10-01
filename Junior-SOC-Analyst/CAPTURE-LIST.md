# Capture List

Screenshots to take from the lab as each section is validated. Diagrams already in the folder are authored SVG and are labelled as illustrations, not screen captures.

## Conventions

- Save as `images/<short-descriptive-name>.png`
- Crop to the relevant window, not the whole desktop
- Domain must read `vbunnylab.local`, admin `vampiricbunny`, user `vbunny`
- Blur anything that is not lab data
- Reference from the document with a Markdown image link and descriptive alt text

---

## 01-Lab-Build.md

| Capture | File | Done |
| --- | --- | :---: |
| Proxmox datacenter view, all 7 VMs listed | `pve-vm-list.png` | [ ] |
| Proxmox network tab showing `vmbr1` VLAN aware | `pve-vmbr1.png` | [ ] |
| VM hardware tab for WS11-01 showing the VLAN tag | `pve-vlan-tag.png` | [ ] |
| OPNsense interface assignments, all five | `opnsense-interfaces.png` | [ ] |
| OPNsense CORP firewall rules, in order | `opnsense-corp-rules.png` | [ ] |
| Firewall log showing a blocked CORP to RED attempt | `opnsense-blocked-red.png` | [ ] |
| Proxmox snapshot list for a victim VM | `pve-snapshots.png` | [ ] |

---

## 02-Telemetry-and-Logging.md

| Capture | File | Done |
| --- | --- | :---: |
| GPMC showing the audit policy GPO linked to Corp | `gpmc-audit-gpo.png` | [ ] |
| Advanced Audit Policy Configuration, subcategories set | `gpo-advanced-audit.png` | [ ] |
| `auditpol /get /category:*` output | `auditpol-effective.png` | [ ] |
| Sysmon service running, `Sysmon64 -c` config summary | `sysmon-config.png` | [ ] |
| Sysmon operational log with event 1 selected | `sysmon-event1.png` | [ ] |
| PowerShell 4104 event showing a deobfuscated script block | `ps-4104.png` | [ ] |
| Wazuh agents page, all five Active | `wazuh-agents-active.png` | [ ] |
| Wazuh dashboard overview with event volume | `wazuh-overview.png` | [ ] |

---

## 03-Detection-Rules.md

| Capture | File | Done |
| --- | --- | :---: |
| `wazuh-logtest` output matching rule 100801 | `logtest-100801.png` | [ ] |
| `local_rules.xml` open in an editor | `local-rules-xml.png` | [ ] |
| Rules management view with the SOC-1000 series listed | `wazuh-rules-list.png` | [ ] |
| A single alert expanded showing the MITRE mapping | `wazuh-alert-mitre.png` | [ ] |

---

## 05-Attack-Simulation.md

| Capture | File | Done |
| --- | --- | :---: |
| `Invoke-AtomicTest T1003.001 -ShowDetailsBrief` output | `atomic-details.png` | [ ] |
| Atomic test running and the alert appearing within seconds | `atomic-fired.png` | [ ] |
| Wazuh alert timeline for the full chain, 14:02 to 14:15 | `chain-timeline.png` | [ ] |
| Kali terminal, netexec spray with one success highlighted | `netexec-spray.png` | [ ] |

---

## 06-Alert-Triage-Log.md

| Capture | File | Done |
| --- | --- | :---: |
| ALT-001 raw Sysmon event 1 with the Word parent visible | `alt001-raw-event.png` | [ ] |
| Decoded base64 payload in an isolated session | `alt001-decoded.png` | [ ] |
| ALT-003 4625 events grouped by account | `alt003-spray-counts.png` | [ ] |
| ALT-004 Sysmon event 10 showing GrantedAccess and CallTrace | `alt004-lsass.png` | [ ] |
| Wazuh alert queue as the analyst sees it | `alert-queue.png` | [ ] |

---

## 07-Incident-Report.md

| Capture | File | Done |
| --- | --- | :---: |
| Process tree from Word down to the Run key write | `ir014-process-tree.png` | [ ] |
| 4624 logon history for WS11-02 showing the admin RDP session | `ir014-exposure.png` | [ ] |
| Host isolation confirmed, network unreachable | `ir014-isolated.png` | [ ] |

---

## 08-Metrics-and-Coverage.md

| Capture | File | Done |
| --- | --- | :---: |
| Wazuh MITRE ATT&CK dashboard for the simulation window | `wazuh-mitre-dashboard.png` | [ ] |
| Alert volume before and after tuning, side by side | `tuning-before-after.png` | [ ] |

---

## Already Complete

Authored SVG, verified in light and dark themes.

| Diagram | Used in |
| --- | --- |
| `soc-lab-topology.svg` | README, 01 |
| `log-pipeline.svg` | 02 |
| `triage-decision-tree.svg` | 04 |
| `attack-chain.svg` | README, 05 |
| `attack-coverage-matrix.svg` | README, 08 |

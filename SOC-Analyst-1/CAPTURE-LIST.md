# Capture List

Real screenshots to take from the lab as each section is validated. The diagrams already in `images/` are authored SVG, and the console ones are labelled as drawn illustrations rather than captures.

## Conventions

- Save as `images/<short-descriptive-name>.png`
- Crop to the relevant blade or pane, not the whole browser
- Tenant must read `vbunnylab.onmicrosoft.com`, workspace `law-vbunnylab-soc`
- Blur subscription GUIDs, tenant IDs and anything that is not lab data
- Reference from the document with a Markdown image link and descriptive alt text
- Prefer dark theme in the Azure portal so captures sit well beside the SVGs

---

## 01-Sentinel-Workspace-Build.md

| Capture | File | Done |
| --- | --- | :---: |
| Log Analytics workspace overview, retention and SKU visible | `law-overview.png` | [ ] |
| Sentinel data connectors page, all 9 showing Connected | `connectors-connected.png` | [ ] |
| Azure Arc machines blade, 4 servers Connected | `arc-machines.png` | [ ] |
| `azcmagent show` output on a host | `azcmagent-show.png` | [ ] |
| Data collection rule, the 9 XPath expressions | `dcr-xpath.png` | [ ] |
| DCR resource associations, all 4 machines attached | `dcr-associations.png` | [ ] |
| `Usage` query result before tuning, 7.2 GB/day | `cost-before.png` | [ ] |
| `Usage` query result after tuning, 0.58 GB/day | `cost-after.png` | [ ] |
| Daily cap and budget alert configuration | `cost-controls.png` | [ ] |

**The two cost captures are the most valuable pair in this project.** Side by side they prove the 92 percent reduction rather than asserting it.

---

## 02-KQL-Query-Library.md

| Capture | File | Done |
| --- | --- | :---: |
| Logs blade with Q22 running, spray detection result set | `kql-spray-result.png` | [ ] |
| Q44 anomaly detection rendered as a timechart | `kql-anomaly-chart.png` | [ ] |
| Q43 beaconing query result, low jitter rows | `kql-beacon-jitter.png` | [ ] |
| A saved function in the workspace function list | `kql-saved-function.png` | [ ] |
| Query performance comparison, time filter first vs third | `kql-perf-compare.png` | [ ] |

---

## 03-Analytics-Rules.md

| Capture | File | Done |
| --- | --- | :---: |
| Analytics rules list, all 12 enabled | `rules-list.png` | [ ] |
| SEN-001 rule wizard, entity mapping tab | `rule-entity-mapping.png` | [ ] |
| SEN-001 alert details override, dynamic title | `rule-alert-details.png` | [ ] |
| Incident grouping configuration | `rule-grouping.png` | [ ] |
| NRT rule configuration, showing the 1 minute cadence | `rule-nrt.png` | [ ] |
| Rule health blade, last run and failures | `rule-health.png` | [ ] |

---

## 04-Incident-Investigation.md

| Capture | File | Done |
| --- | --- | :---: |
| Incidents blade, the queue as an analyst sees it | `incidents-queue.png` | [ ] |
| One incident open, detail pane with entities | `incident-detail.png` | [ ] |
| Investigation graph, expanded one hop | `investigation-graph.png` | [ ] |
| Account entity page, timeline and insights | `entity-page-account.png` | [ ] |
| Host entity page, accounts that logged on | `entity-page-host.png` | [ ] |
| Incident tasks checklist, partly complete | `incident-tasks.png` | [ ] |

**`entity-page-host.png` should show the accounts list**, because that is the exposure question and it is the step people miss.

---

## 05-Phishing-Analysis.md

| Capture | File | Done |
| --- | --- | :---: |
| Raw headers with Authentication-Results highlighted | `phish-headers.png` | [ ] |
| WHOIS output showing a domain days old | `phish-domain-age.png` | [ ] |
| `EmailEvents` blast radius result | `phish-blast-radius.png` | [ ] |
| `UrlClickEvents` result showing who clicked | `phish-clicks.png` | [ ] |
| Compliance search item count before purge | `phish-purge-count.png` | [ ] |
| Tenant Allow/Block List entry added | `phish-block-list.png` | [ ] |

**Capture the search item count before the purge, every time.** It is the check that stops a broad query deleting legitimate mail, and having the capture makes the habit visible.

---

## 06-SOAR-Automation.md

| Capture | File | Done |
| --- | --- | :---: |
| Logic App designer, PB-01 enrichment flow | `playbook-designer.png` | [ ] |
| Managed identity configuration on the Logic App | `playbook-identity.png` | [ ] |
| Role assignment, Sentinel Responder scoped to the RG | `playbook-rbac.png` | [ ] |
| Teams approval card as it appears to the approver | `playbook-approval-card.png` | [ ] |
| Incident comment posted by PB-01 | `playbook-comment.png` | [ ] |
| Automation rules list, showing trigger conditions | `automation-rules.png` | [ ] |
| Logic App run history, a successful and a rejected run | `playbook-runs.png` | [ ] |

---

## 07-Shift-Operations.md

| Capture | File | Done |
| --- | --- | :---: |
| Queue health query result at shift start | `shift-queue-health.png` | [ ] |
| SLA measurement query result, median and P90 by severity | `shift-sla.png` | [ ] |
| Ageing incidents query, anything stalled | `shift-ageing.png` | [ ] |

---

## 08-Investigation-Case-Files.md

| Capture | File | Done |
| --- | --- | :---: |
| CF-01 raw `DeviceProcessEvents` row, Word parent visible | `cf01-raw-event.png` | [ ] |
| CF-02 `ResultType` breakdown from the spray | `cf02-resulttype.png` | [ ] |
| CF-03 sign-in table showing the IMAP4 entry from NL | `cf03-legacy-auth.png` | [ ] |
| CF-03 the inbox rule named `..` before deletion | `cf03-inbox-rule.png` | [ ] |
| CF-04 both sign-ins showing the same `DeviceId` | `cf04-deviceid.png` | [ ] |
| CF-06 `SecurityEvent` timechart with FS01 flat at zero | `cf06-volume-drop.png` | [ ] |
| CF-06 `Heartbeat` still green during the outage | `cf06-heartbeat-green.png` | [ ] |

**The CF-06 pair is the best single pair of captures in this project.** One shows the data stopped, the other shows agent health reporting fine at the same moment. Together they make the point that a SIEM that has stopped receiving data looks exactly like a quiet day.

---

## 09-Workbooks-and-Reporting.md

| Capture | File | Done |
| --- | --- | :---: |
| SOC Shift View workbook, full | `workbook-shift.png` | [ ] |
| Detection Health workbook, full | `workbook-health.png` | [ ] |
| Security Posture workbook, management view | `workbook-posture.png` | [ ] |
| Weekly tuning summary posted to Teams | `weekly-summary-teams.png` | [ ] |

---

## Already Complete

Authored SVG, verified in light and dark themes.

| Diagram | Kind | Used in |
| --- | --- | --- |
| `sentinel-architecture.svg` | Concept | README, 01 |
| `sentinel-incidents-schematic.svg` | **Console schematic** | README, 04 |
| `kql-anatomy.svg` | Concept | 02 |
| `entity-mapping.svg` | Concept | 03 |
| `incident-lifecycle.svg` | Concept | 04 |
| `investigation-graph-schematic.svg` | **Console schematic** | 04 |
| `phishing-analysis-flow.svg` | Concept | 05 |
| `soar-playbook-flow.svg` | Concept | 06 |
| `shift-queue-board.svg` | Concept | 07 |
| `workbook-schematic.svg` | **Console schematic** | 09 |

The three console schematics are drawn layouts with numbered callouts tied to the steps in the text. Each carries a footer stating it is an illustration. When the matching real capture is taken, the schematic stays as the annotated version and the capture goes beside it.

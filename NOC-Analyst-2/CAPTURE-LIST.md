# Capture List

Screenshots worth taking as the monitoring is built. These turn the write-ups into a portfolio.

## Rules

- Save as `images/<short-descriptive-name>.png`
- Crop to the relevant panel, not the whole screen
- Blur any real addresses, hostnames or data that is not lab
- Name by what it shows, not by date
- Capture the state that makes the point: a real spike, a real alert, a real fix

---

## 01 and 02 - Build and Metrics

| Capture | File | Done |
| --- | --- | :---: |
| LibreNMS device list, all devices up | `librenms-devices.png` | [ ] |
| A device page showing interface graphs | `librenms-device.png` | [ ] |
| Prometheus targets, all healthy | `prometheus-targets.png` | [ ] |
| `snmpwalk` returning interface data | `snmpwalk.png` | [ ] |
| A counter graph, before and after fixing 32-bit wrap | `counter-fix.png` | [ ] |

**`counter-fix.png` is a good story.** The impossible spikes from a 32-bit counter, then the clean graph after switching to 64-bit. It shows you understand the tool, not just run it.

---

## 03 - Dashboards

| Capture | File | Done |
| --- | --- | :---: |
| The NOC wall dashboard, one tile red | `dashboard-wall.png` | [ ] |
| A service overview with the SLA line drawn on it | `dashboard-service.png` | [ ] |
| The templated device-detail dashboard with its dropdown | `dashboard-templated.png` | [ ] |
| An annotation on a graph marking a deployment | `dashboard-annotation.png` | [ ] |

**`dashboard-wall.png` with a single red tile is the best portfolio image here.** It shows a dashboard that makes a problem obvious, which is the whole skill.

---

## 04 - Alerting and Noise Reduction

| Capture | File | Done |
| --- | --- | :---: |
| The alert volume before tuning | `alerts-before.png` | [ ] |
| The alert volume after tuning | `alerts-after.png` | [ ] |
| A dependency-suppression rule in config | `alert-inhibit.png` | [ ] |
| A flap-detection alert (one, not 118) | `alert-flap.png` | [ ] |

**`alerts-before.png` and `alerts-after.png` side by side are the most valuable pair in the project.** 340 down to 22 in one image pair proves the core Tier 2 skill.

---

## 05 - Traffic Analysis

| Capture | File | Done |
| --- | --- | :---: |
| ntopng top talkers on a saturated link | `flow-top-talkers.png` | [ ] |
| The protocol breakdown of the traffic | `flow-protocols.png` | [ ] |
| A saturation event tied to a single host | `flow-saturation.png` | [ ] |

---

## 06 and 07 - Incident and Troubleshooting

| Capture | File | Done |
| --- | --- | :---: |
| An incident timeline, written live | `incident-timeline.png` | [ ] |
| An `mtr` run showing loss at one hop | `mtr-loss.png` | [ ] |
| The continuous latency graph showing a periodic spike | `latency-spike.png` | [ ] |
| Syslog showing the 118 flap events | `syslog-flap.png` | [ ] |
| A rising interface error counter | `interface-errors.png` | [ ] |

**`latency-spike.png` from Case 5 is the instructive one.** The periodic spike a spot check would miss, caused by the monitoring itself. It shows you diagnose properly and will suspect your own tools.

---

## 08 and 09 - Capacity and Automation

| Capture | File | Done |
| --- | --- | :---: |
| A `predict_linear` forecast crossing the ceiling | `capacity-forecast.png` | [ ] |
| An availability report against an SLA target | `sla-report.png` | [ ] |
| The self-healing automation resolving and notifying | `auto-heal.png` | [ ] |
| The daily health check output | `daily-check.png` | [ ] |

---

## The Seven That Matter Most

For a Tier 2 NOC portfolio, these tell the whole story.

```text
1. dashboard-wall.png       you build dashboards that surface problems
2. alerts-before.png        the noise you started with
3. alerts-after.png         the noise you removed
4. flow-top-talkers.png     you find what fills a link
5. latency-spike.png        you diagnose the hard, intermittent problems
6. capacity-forecast.png    you see problems coming before they happen
7. auto-heal.png            you automate the toil away
```

Numbers 2 and 3 together are the single strongest thing in the project. A 94 percent noise reduction, shown not claimed.

---

## Already Complete

Authored SVG, verified in light and dark themes.

| Diagram | Kind | Used in |
| --- | --- | --- |
| `noc-lab-topology.svg` | Concept | README, 01 |
| `monitoring-stack.svg` | Concept | README, 01 |
| `snmp-polling.svg` | Concept | 02 |
| `golden-signals.svg` | Concept | 02 |
| `dashboard-layers.svg` | Concept | 03 |
| `noc-wall-schematic.svg` | **Console schematic** | 03 |
| `alert-anatomy.svg` | Concept | 04 |
| `alert-routing.svg` | Concept | 04 |
| `netflow-flow.svg` | Concept | 05 |
| `top-talkers.svg` | Data | 05 |
| `incident-lifecycle.svg` | Concept | 06 |
| `troubleshooting-layers.svg` | Concept | 07 |
| `capacity-trend.svg` | Data | 08 |
| `automation-ladder.svg` | Concept | 09 |

Fourteen diagrams, one a console schematic. Your own screenshots from the running lab are the real evidence, tracked above.

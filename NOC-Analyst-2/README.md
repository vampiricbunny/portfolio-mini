# NOC-02: Network Monitoring and Performance Engineering

**Role target:** Network Operations Analyst II / Tier 2 NOC
**Focus:** Building the monitoring, tuning the noise out, and finding root cause
**Environment:** A multi-subnet Proxmox lab with real network devices to watch

---

## What a NOC Does, and What Changes at Tier 2

A NOC (Network Operations Center) keeps things running. Not security, that is the SOC. The NOC watches availability and performance: is the network up, is it fast, and if not, why.

A Tier 1 NOC analyst watches the dashboard and follows runbooks. A Tier 2 analyst builds the dashboard, decides what is worth alerting on, and works out why the recurring problems recur.

| Tier 1 NOC does | Tier 2 NOC does |
| --- | --- |
| Watches the alert board | Builds the monitoring that feeds it |
| Acknowledges alerts, follows runbooks | Writes the runbooks, tunes the alerts |
| Escalates what it cannot fix | Receives those escalations and finds root cause |
| Reports an outage | Finds why outages keep happening and stops them |
| Reacts to capacity problems | Forecasts them before they happen |

**The theme is the same as the SOC-II project: stop watching the board, start building it.** A NOC drowning in alerts nobody reads has a Tier 2 problem, and fixing it is this role.

---

## What This Project Is

Five things a Tier 2 NOC analyst is hired to do, each built and documented.

**A monitoring stack.** SNMP polling, metrics, syslog and flow data, from bare metal up. In [01-Monitoring-Lab-Build.md](01-Monitoring-Lab-Build.md) and [02-Metrics-and-SNMP.md](02-Metrics-and-SNMP.md).

**Dashboards that a NOC actually uses.** Not every metric on one screen. The few that matter, arranged so a problem is obvious in a glance. In [03-Dashboards-and-Visualization.md](03-Dashboards-and-Visualization.md).

**Alerting that does not cry wolf.** The single hardest and most valuable NOC skill: alerts that fire on real problems and stay quiet otherwise. In [04-Alerting-and-Noise-Reduction.md](04-Alerting-and-Noise-Reduction.md).

**Deep troubleshooting.** Latency, packet loss, saturation, outages, worked end to end with the method underneath. In [05-Network-Traffic-Analysis.md](05-Network-Traffic-Analysis.md) and [07-Troubleshooting-Playbooks.md](07-Troubleshooting-Playbooks.md).

**Capacity and automation.** Forecasting growth before it becomes an outage, and automating the toil away. In [08-Capacity-and-Reporting.md](08-Capacity-and-Reporting.md) and [09-Automation-and-Runbooks.md](09-Automation-and-Runbooks.md).

---

## The Monitored Network

![The NOC lab network, multiple subnets behind a monitored core](images/noc-lab-topology.svg)

A small multi-subnet network, the kind a Tier 2 NOC actually watches.

| Host | Role | Address | Watched for |
| --- | --- | --- | --- |
| `CORE-FW` | OPNsense router and firewall | 10.60.0.1 | Interface load, CPU, sessions |
| `SW-CORE` | Core switch (virtualised) | 10.60.0.2 | Port errors, bandwidth |
| `NMS01` | Monitoring server | 10.60.10.10 | The thing doing the watching |
| `WEB01` | Web server | 10.60.20.10 | Uptime, response time |
| `DB01` | Database server | 10.60.20.20 | Disk, memory, query load |
| `APP01` | Windows application server | 10.60.20.30 | Services, CPU, disk |
| `BR-RTR` | Branch site router | 10.60.30.1 | Link latency, packet loss |

Build details are in [01-Monitoring-Lab-Build.md](01-Monitoring-Lab-Build.md).

---

## The Monitoring Stack

![The observability stack, from device to dashboard to alert](images/monitoring-stack.svg)

Both worlds, because a real NOC runs both.

| Layer | Tool | Job |
| --- | --- | --- |
| Device metrics | SNMP via LibreNMS | Poll routers, switches, servers |
| Time-series metrics | Prometheus | Store and query fast-moving metrics |
| Dashboards | Grafana | The NOC screens |
| Flow analysis | ntopng, NetFlow | Who is using the bandwidth |
| Log aggregation | Syslog to the stack | Device and system logs in one place |
| Alerting | Alertmanager | Route the right alert to the right person |
| Uptime and latency | Smokeping-style checks | Is it up, and how far away |

---

## Results

| Measure | Result |
| --- | --- |
| Devices monitored | 7, across 3 subnets |
| Metrics collected | SNMP, flow, syslog, and synthetic checks |
| Dashboards built | 4, from NOC wall to per-service |
| Alerts before tuning | 340 per week, mostly noise |
| Alerts after tuning | 22 per week, nearly all actionable |
| Noise reduction | 94 percent |
| Troubleshooting cases worked | 5, end to end |
| Recurring problems eliminated | 2, by root cause |
| Runbooks automated | 3 |

**The 94 percent noise reduction is the headline.** A NOC that gets 340 alerts a week stops reading them, which means it misses the real one. Getting that to 22 actionable alerts is the Tier 2 contribution that matters most, and [04-Alerting-and-Noise-Reduction.md](04-Alerting-and-Noise-Reduction.md) shows exactly how.

---

## Documents

| | |
| --- | --- |
| [01-Monitoring-Lab-Build.md](01-Monitoring-Lab-Build.md) | The network, the stack, from bare metal up |
| [02-Metrics-and-SNMP.md](02-Metrics-and-SNMP.md) | SNMP, what to poll, the metrics that matter |
| [03-Dashboards-and-Visualization.md](03-Dashboards-and-Visualization.md) | NOC screens that make a problem obvious |
| [04-Alerting-and-Noise-Reduction.md](04-Alerting-and-Noise-Reduction.md) | Alerts that fire on real problems and nothing else |
| [05-Network-Traffic-Analysis.md](05-Network-Traffic-Analysis.md) | NetFlow, bandwidth, top talkers, saturation |
| [06-Incident-and-Escalation.md](06-Incident-and-Escalation.md) | NOC incident handling, the bridge, MTTR |
| [07-Troubleshooting-Playbooks.md](07-Troubleshooting-Playbooks.md) | Five cases worked end to end |
| [08-Capacity-and-Reporting.md](08-Capacity-and-Reporting.md) | Forecasting, SLA, availability reporting |
| [09-Automation-and-Runbooks.md](09-Automation-and-Runbooks.md) | Automating the toil away |

---

## Skills This Demonstrates

| Area | Evidence |
| --- | --- |
| Network monitoring | SNMP, LibreNMS and Prometheus deployed and polling 7 devices |
| Observability | Grafana dashboards from NOC wall to per-service drilldown |
| Alert engineering | 94 percent noise reduction with documented method |
| Traffic analysis | NetFlow and ntopng, top talkers, saturation diagnosis |
| Troubleshooting | Five worked cases: latency, packet loss, outage, degradation, flapping |
| Root cause analysis | Two recurring problems eliminated, not just patched |
| Incident management | ITIL-aligned handling, escalation, MTTR measurement |
| Capacity planning | Trend-based forecasting before capacity became an outage |
| Automation | Three runbooks automated, toil reduced |

---

## The Security Crossover

A NOC and a SOC watch the same wires for different reasons. The NOC asks "is it up and fast," the SOC asks "is it safe." The data overlaps, and a Tier 2 analyst who understands both is more useful than one who does not.

| NOC signal | Also a security signal |
| --- | --- |
| A sudden bandwidth spike | Possible exfiltration ([SOC-03](../SOC-Analyst-2/)) |
| A device flapping | Possible attack, or a dying device |
| Traffic to an unusual destination | Possible command and control |
| A service down | Possible ransomware, or a failed disk |

**The NOC often sees the incident first, without knowing it is one.** Module 06 covers when a NOC hands a performance anomaly to the SOC, and why that handoff matters.

---

## Honest Notes

**The switch and branch router are virtualised.** Real NOC work is against physical Cisco, Juniper and Arista gear with quirks a VM does not have. The monitoring concepts are identical, the hardware-specific troubleshooting is not, and that is a genuine limitation.

**The traffic is generated, not real users.** I drove load with traffic generators to produce saturation and latency to diagnose. Real production traffic is messier and its patterns are harder to read. What transfers is the method, not the specific numbers.

**The alert-tuning numbers are from a small environment.** 340 to 22 is real for this lab. At the scale of thousands of devices the same method applies, but the starting noise is far larger and the tuning is continuous rather than a one-time pass.

If you are reviewing this as a hiring manager, [04-Alerting-and-Noise-Reduction.md](04-Alerting-and-Noise-Reduction.md) is the file that shows the core Tier 2 skill, and [07-Troubleshooting-Playbooks.md](07-Troubleshooting-Playbooks.md) shows how I find root cause.

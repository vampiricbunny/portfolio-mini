# Capture List

Screenshots worth taking as the engagement runs. These turn the write-ups into evidence, which is what a penetration test report is made of.

## Rules

- Save as `images/<short-descriptive-name>.png`
- Crop to the relevant panel, not the whole screen
- Redact anything that looks like real data. In this lab the data is generated, but treat it as though it were real, because that is the habit the job requires
- Redact the sensitive fields in any record you show. Prove access, do not expose data
- Name by what it shows, not by date
- Capture the state that makes the point: the request that worked, the shell that returned, the finding that landed

---

## 02 - External Reconnaissance

| Capture | File | Done |
| --- | --- | :---: |
| Certificate transparency results showing the dev subdomain | `recon-ct-logs.png` | [ ] |
| The nmap service scan of the perimeter | `recon-nmap.png` | [ ] |
| Directory enumeration finding the uploads and admin paths | `recon-ffuf.png` | [ ] |

**`recon-nmap.png` and `recon-ffuf.png` are the pair that show method.** Recon is where the engagement is decided, and these prove it was done properly rather than skipped.

---

## 03 and 04 - Perimeter and Web

| Capture | File | Done |
| --- | --- | :---: |
| The VPN portal with no MFA prompt | `vpn-portal.png` | [ ] |
| The reused credential authenticating to the VPN | `vpn-login-success.png` | [ ] |
| The SQL injection error that revealed the flaw | `web-sqli-error.png` | [ ] |
| The IDOR returning another customer's order, fields redacted | `web-idor.png` | [ ] |
| The file upload request in Burp Repeater | `web-upload-burp.png` | [ ] |
| The uploaded script executing on the server | `web-rce-shell.png` | [ ] |

**`web-upload-burp.png` and `web-rce-shell.png` are the money shots of the web test.** The request that smuggled the script, and the shell it produced. That pair is the whole of the critical finding.

---

## 05 and 06 - Pivot and Internal Enumeration

| Capture | File | Done |
| --- | --- | :---: |
| The web server reaching the internal LAN | `pivot-reach-internal.png` | [ ] |
| The SOCKS tunnel established | `pivot-tunnel-up.png` | [ ] |
| A captured hash from LLMNR poisoning | `enum-llmnr-capture.png` | [ ] |
| The BloodHound graph showing the path to Domain Admin | `bloodhound-path.png` | [ ] |

**`bloodhound-path.png` is the best single internal image.** The graph that turns a list of accounts into a route to the top of the domain, with the path highlighted.

---

## 07 - Active Directory

| Capture | File | Done |
| --- | --- | :---: |
| The Kerberoast ticket request and the cracked password | `ad-kerberoast.png` | [ ] |
| Certipy finding the vulnerable template | `ad-esc1-find.png` | [ ] |
| The certificate requested as a domain administrator | `ad-esc1-request.png` | [ ] |
| DCSync retrieving domain hashes | `ad-dcsync.png` | [ ] |

**`ad-esc1-request.png` is the one that took the domain.** A low-privileged user requesting a certificate that names them a domain administrator, and the CA issuing it.

---

## 08 - Impact

| Capture | File | Done |
| --- | --- | :---: |
| Reaching the server VLAN from a workstation | `impact-reach-sql.png` | [ ] |
| One customer record, sensitive fields redacted | `impact-single-record.png` | [ ] |
| The row count of the customer table | `impact-row-count.png` | [ ] |

**`impact-single-record.png` and `impact-row-count.png` together are the proof of business impact.** One record and a count. That is how you prove access without dumping the data, and doing it that way is itself a demonstration of professional conduct.

---

## The Seven That Matter Most

For a mid-level penetration test portfolio, these tell the whole story.

```text
1. recon-nmap.png            you map before you attack
2. web-upload-burp.png       you exploit web apps by hand, not just with tools
3. web-rce-shell.png         you earned the foothold from outside
4. bloodhound-path.png       you find the route through a domain
5. ad-esc1-request.png       you know the modern AD escalation paths
6. impact-single-record.png  you prove impact without causing it
7. bloodhound-path.png       the map that made it all deliberate
```

The pair that carries the report is `web-rce-shell.png` and `impact-single-record.png`: the way in from the internet, and the customer data at the end, proven safely.

---

## Already Complete

Authored SVG, verified in light and dark themes. Four of these are console schematics, drawn simulations of the real tool interfaces with numbered callouts, each labelled as an illustration and not a screen capture.

| Diagram | Kind | Used in |
| --- | --- | --- |
| `pentest-lab-topology.svg` | Concept | README, 01 |
| `engagement-scope.svg` | Concept | README, 01 |
| `methodology-phases.svg` | Concept | 01 |
| `recon-surface.svg` | Concept | 02 |
| `terminal-recon-schematic.svg` | **Console schematic** | 02 |
| `web-attack-chain.svg` | Concept | 04 |
| `burp-schematic.svg` | **Console schematic** | 04 |
| `network-segmentation.svg` | Concept | 05 |
| `pivot-tunnel.svg` | Concept | 05 |
| `bloodhound-schematic.svg` | **Console schematic** | 06 |
| `kerberoast-flow.svg` | Concept | 07 |
| `adcs-esc1.svg` | Concept | 07 |
| `terminal-adcs-schematic.svg` | **Console schematic** | 07 |
| `attack-path.svg` | Concept | README |
| `detection-timeline.svg` | Concept | 09 |
| `risk-matrix.svg` | Data | README, 10 |

Sixteen diagrams, four of them console schematics. Your own screenshots from the running lab are the real evidence, tracked above.

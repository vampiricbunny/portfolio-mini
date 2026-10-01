# Capture List

Screenshots worth taking from the engagement. On a penetration test these are your evidence, so they matter more than on most projects.

## Rules

- **Redact before saving.** Real hashes, tokens and personal data do not belong in a report. Show enough to prove the finding, no more
- **Capture the command and the result together.** The command proves what you did, the output proves it worked
- **Timestamp them.** Clients correlate your evidence against their own logs
- **Crop to the relevant lines.** A full terminal of scrollback hides the point
- **Name them by finding.** `PT-01-spray-success.png`

---

## 02 - Reconnaissance

| Capture | File | Done |
| --- | --- | :---: |
| Nmap host discovery, all hosts found | `recon-hosts.png` | [ ] |
| Nmap service scan of DC01, the AD ports | `recon-dc01-ports.png` | [ ] |
| The attack surface summary you wrote | `recon-summary.png` | [ ] |

---

## 03 - Enumeration

| Capture | File | Done |
| --- | --- | :---: |
| Null session listing shares (PT-06) | `PT-06-null-session.png` | [ ] |
| Anonymous LDAP returning users (PT-05) | `PT-05-ldap-anon.png` | [ ] |
| The user list you built | `enum-userlist.png` | [ ] |
| SMB signing status showing False (PT-07) | `PT-07-signing.png` | [ ] |
| BloodHound path to Domain Admins | `enum-bloodhound-path.png` | [ ] |
| The passwords.xlsx discovery (PT-09) | `PT-09-share-creds.png` | [ ] |

---

## 04 - Initial Access

| Capture | File | Done |
| --- | --- | :---: |
| Password spray success (PT-01) | `PT-01-spray-success.png` | [ ] |
| Responder capturing a hash (PT-08) | `PT-08-responder.png` | [ ] |
| Hashcat cracking the captured hash | `access-hashcat.png` | [ ] |
| Local admin reuse across machines (PT-03) | `PT-03-reuse.png` | [ ] |

---

## 05 - Privilege Escalation

| Capture | File | Done |
| --- | --- | :---: |
| `whoami /priv` showing SeImpersonate | `privesc-priv.png` | [ ] |
| PrintSpoofer giving SYSTEM | `privesc-system.png` | [ ] |
| `sudo -l` on the Linux host | `privesc-sudo.png` | [ ] |
| Root shell on SRV-WEB01 | `privesc-root.png` | [ ] |

---

## 06 - Active Directory Attacks

| Capture | File | Done |
| --- | --- | :---: |
| Kerberoast ticket requested (PT-02) | `PT-02-kerberoast.png` | [ ] |
| Hashcat cracking the service ticket | `PT-02-crack.png` | [ ] |
| Rubeus capturing the DC ticket (PT-04) | `PT-04-delegation.png` | [ ] |
| secretsdump dumping domain hashes | `ad-dcsync.png` | [ ] |
| Domain admin access proven | `ad-domain-owned.png` | [ ] |

---

## 07 - Lateral Movement

| Capture | File | Done |
| --- | --- | :---: |
| PsExec giving SYSTEM on a target | `lateral-psexec.png` | [ ] |
| Pass the hash across workstations | `lateral-pth.png` | [ ] |
| Logged-on users query finding an admin session | `lateral-loggedon.png` | [ ] |

---

## 09 - Remediation and Retest

| Capture | File | Done |
| --- | --- | :---: |
| The spray now failing and locking out | `retest-spray-blocked.png` | [ ] |
| Anonymous enumeration now denied | `retest-anon-blocked.png` | [ ] |
| The LLMNR fix that did not apply at first | `retest-llmnr-gap.png` | [ ] |
| Delegation removed, no ticket captured | `retest-delegation-gone.png` | [ ] |

---

## The Six That Matter Most

For a pentest portfolio, these tell the whole story.

```text
1. PT-01-spray-success.png     first credential from a weak password
2. enum-bloodhound-path.png    the path to Domain Admin, mapped
3. PT-04-delegation.png        the step that took the domain
4. ad-dcsync.png               every hash in the domain
5. retest-spray-blocked.png    proof the fix worked
6. retest-llmnr-gap.png        proof you actually retest properly
```

Number 6 matters more than it looks. Showing a fix that did not work the first time proves you verify rather than assume.

---

## Already Complete

Authored SVG, verified in light and dark themes.

| Diagram | Used in |
| --- | --- |
| `pentest-lab-topology.svg` | README, 01 |
| `attack-path.svg` | README, 06 |
| `risk-matrix.svg` | README, 08 |
| `methodology-phases.svg` | 01 |
| `bloodhound-path.svg` | 03 |
| `lateral-movement.svg` | 07 |

The BloodHound and topology diagrams are drawn illustrations, labelled as such. Your own screenshots from the engagement are the real evidence.

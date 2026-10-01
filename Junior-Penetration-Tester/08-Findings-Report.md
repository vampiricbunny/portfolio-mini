# 08 - Findings Report

The deliverable. This is what a client pays for.

> Assessment of the `ptlab.local` lab environment, a network owned and built by the author. No third-party system was in scope or touched.

---

## Executive Summary

An internal penetration test was carried out against the `ptlab.local` environment from an assumed-breach position: network access, no credentials, as if an attacker had already got a foothold through a phishing email or a rogue device.

**Full control of the domain was achieved in 47 minutes.**

The path required no software exploit. Every step used a misconfiguration, a weak password, or a default setting that had never been changed. Thirteen of the fourteen findings are fixed by configuration or policy alone, at no licensing cost.

The two most serious findings are both weak service account passwords, which fell to guessing and to offline cracking within minutes. The single most effective fix is unrelated to any of the individual findings: preventing domain administrators from logging on to ordinary workstations would have broken the attack chain regardless of the other weaknesses.

### For the reader who is not technical

An attacker who got onto this network with no starting access would, within an hour, be able to read every file, access every computer, and control every user account in the business. They would do it not by breaking software, but by using passwords that were easy to guess and settings that were left at their insecure defaults. Almost every fix is a decision rather than a purchase.

---

## Risk Overview

![Risk matrix, findings by likelihood and impact](images/risk-matrix.svg)

| Severity | Count |
| --- | --- |
| Critical | 2 |
| High | 4 |
| Medium | 5 |
| Low | 2 |
| Informational | 1 |

| Metric | Result |
| --- | --- |
| Domain compromise achieved | Yes |
| Time to Domain Admin | 47 minutes |
| Findings needing a software patch | 1 |
| Findings fixed by configuration or policy | 13 |

---

## How to Read a Finding

Each finding has the same parts, because a report the client can act on needs them all.

| Part | Answers |
| --- | --- |
| **Severity and CVSS** | How bad, on a standard scale |
| **Description** | What the weakness is |
| **Impact** | What an attacker gains |
| **Evidence** | Proof it is real |
| **Affected** | Which systems |
| **Remediation** | Exactly what to change |
| **References** | Where to read more |

**The remediation is the part that matters most.** A finding without a clear, specific fix is a complaint, not a finding.

---

## PT-01: Weak Service Account Password Recovered by Spraying

| | |
| --- | --- |
| **Severity** | Critical |
| **CVSS 3.1** | 9.8 |
| **Affected** | `svc_sql`, domain-wide |

**Description.** The service account `svc_sql` used the password `Autumn2024!`. It was recovered by trying one common password against every account (a password spray). The domain has no account lockout, so this could be attempted without limit.

**Impact.** This credential was the entry point to the entire domain compromise. A service account is a valid domain login, and this one also had the rights that led, through later findings, to full control.

**Evidence.**
```text
netexec smb 10.50.10.10 -u users.txt -p 'Autumn2024!' --continue-on-success
SMB  10.50.10.10  DC01  [+] ptlab.local\svc_sql:Autumn2024!
```

**Remediation.**
1. Set service account passwords to 25 or more random characters, stored in a password manager
2. Better, convert service accounts to Group Managed Service Accounts (gMSA), where Windows manages a long random password automatically
3. Enable an account lockout policy, or better, deploy a banned-password list that blocks seasonal and breached passwords
4. `Autumn2024!` satisfies complexity rules and is trivially guessable. Complexity rules do not produce strong passwords. Length and breach-checking do

**References.** MITRE ATT&CK T1110.003. Microsoft gMSA documentation.

---

## PT-02: Kerberoastable Service Account With a Crackable Password

| | |
| --- | --- |
| **Severity** | Critical |
| **CVSS 3.1** | 9.0 |
| **Affected** | `svc_sql` |

**Description.** `svc_sql` has a Service Principal Name, which allows any authenticated domain user to request a service ticket for it. That ticket is encrypted with the account's password and can be cracked offline (Kerberoasting). The password cracked in seconds.

**Impact.** Any domain user, however low-privileged, could recover this service account's password without triggering a single failed login.

**Evidence.**
```text
impacket-GetUserSPNs ptlab.local/svc_sql:'***' -request
$krb5tgs$23$*svc_sql$PTLAB.LOCAL$MSSQLSvc/srv-file01...
hashcat -m 13100 tickets.txt rockyou.txt  ->  cracked
```

**Remediation.**
1. Set a 25-plus character random password, which makes the ticket uncrackable in practice
2. Convert to a gMSA
3. Set `msDS-SupportedEncryptionTypes` to AES only, so weak RC4 tickets cannot be requested
4. Monitor event 4769 for large numbers of ticket requests

**References.** MITRE ATT&CK T1558.003.

---

## PT-03: Local Administrator Password Reused Across Workstations

| | |
| --- | --- |
| **Severity** | High |
| **CVSS 3.1** | 8.8 |
| **Affected** | WS-01, WS-02, all workstations |

**Description.** Every workstation shares the same local administrator password. Recovering it from one machine (or from the file share, PT-09) grants administrator access to all of them.

**Impact.** One compromised workstation becomes all of them. Combined with pass-the-hash, no password even needs to be typed.

**Evidence.**
```text
netexec smb 10.50.10.101 -u LocalAdmin -p '***' --local-auth   [+] (Pwn3d!)
netexec smb 10.50.10.102 -u LocalAdmin -p '***' --local-auth   [+] (Pwn3d!)
```

**Remediation.**
1. Deploy Microsoft LAPS (Local Administrator Password Solution). It gives every machine a unique, automatically rotating local admin password, at no cost
2. This single change breaks lateral movement between workstations completely

**References.** MITRE ATT&CK T1078. Microsoft LAPS.

---

## PT-04: Unconstrained Delegation on a Non-Domain-Controller

| | |
| --- | --- |
| **Severity** | High |
| **CVSS 3.1** | 8.1 |
| **Affected** | SRV-FILE01 |

**Description.** SRV-FILE01 is configured for unconstrained delegation. Any account that authenticates to it leaves its full Kerberos ticket in the server's memory. An attacker with control of the server can capture those tickets, including the domain controller's.

**Impact.** This was the final step to domain compromise. By coercing the domain controller to authenticate to SRV-FILE01, its ticket was captured and used to dump every password in the domain.

**Evidence.**
```text
Rubeus monitor  +  printerbug coercion  ->  DC01$ TGT captured
secretsdump -just-dc  ->  all domain hashes including krbtgt
```

**Remediation.**
1. Remove unconstrained delegation from SRV-FILE01. It is almost never needed and never on a file server
2. Where delegation is genuinely required, use constrained delegation, limited to specific services
3. Add privileged and service accounts to the Protected Users group, which blocks their delegation
4. Mark sensitive accounts as "cannot be delegated"

**References.** MITRE ATT&CK T1187, T1558.

---

## PT-05: Anonymous LDAP Bind Permits Directory Enumeration

| | |
| --- | --- |
| **Severity** | High |
| **CVSS 3.1** | 7.5 |
| **Affected** | DC01 |

**Description.** The domain controller allows anonymous LDAP binds, so anyone on the network can read the directory without credentials: every user, group, computer, and any passwords left in description fields.

**Impact.** Provided the complete user list that made the password spray (PT-01) possible.

**Evidence.**
```text
ldapsearch -x -H ldap://10.50.10.10 -b "DC=ptlab,DC=local" "(objectClass=user)"
(returned all users with no credentials)
```

**Remediation.**
1. Disable anonymous LDAP binds by setting `dSHeuristics` correctly on the directory service object
2. Require LDAP signing and channel binding
3. Audit description and comment fields for stored passwords

**References.** MITRE ATT&CK T1087.002.

---

## PT-06: SMB Null Sessions Permitted on the Domain Controller

| | |
| --- | --- |
| **Severity** | High |
| **CVSS 3.1** | 7.5 |
| **Affected** | DC01 |

**Description.** The domain controller permits null sessions, an SMB connection with no username or password, exposing shares and account information.

**Impact.** A second no-credential route to the user list, reinforcing PT-05.

**Evidence.**
```text
netexec smb 10.50.10.10 -u '' -p '' --shares   [+] (Guest) READ on NETLOGON, SYSVOL
impacket-lookupsid ... -no-pass   ->  full account list
```

**Remediation.**
1. Set `RestrictAnonymous` and `RestrictAnonymousSAM` to restrict anonymous access
2. Review `RestrictNullSessAccess`
3. Apply the Microsoft security baseline for domain controllers, which sets these correctly

**References.** MITRE ATT&CK T1087.

---

## PT-07: SMB Signing Not Required

| | |
| --- | --- |
| **Severity** | Medium |
| **CVSS 3.1** | 6.5 |
| **Affected** | SRV-FILE01, WS-01, WS-02 |

**Description.** SMB signing is not required on member servers and workstations, which allows captured authentication to be relayed to them (NTLM relay).

**Impact.** Combined with PT-08, an attacker can capture authentication and relay it to these hosts without cracking any password.

**Evidence.** `netexec smb` reported `signing:False` on all member hosts.

**Remediation.**
1. Require SMB signing on all systems via Group Policy: "Microsoft network server: Digitally sign communications (always)"
2. Roll out in monitor mode first to catch legacy clients

**References.** MITRE ATT&CK T1557.001.

---

## PT-08: LLMNR and NBT-NS Enabled

| | |
| --- | --- |
| **Severity** | Medium |
| **CVSS 3.1** | 6.5 |
| **Affected** | Network-wide |

**Description.** LLMNR and NBT-NS are legacy name-resolution protocols that broadcast name lookups to the whole local network. An attacker answers them and captures authentication hashes.

**Impact.** Captured a domain user's hash with no credentials. The hash was crackable offline, or relayable via PT-07.

**Evidence.**
```text
responder -I eth0 -wf  ->  [SMB] NTLMv2-SSP Hash captured from 10.50.10.101
```

**Remediation.**
1. Disable LLMNR via Group Policy: "Turn off multicast name resolution"
2. Disable NBT-NS on all adapters
3. Neither is needed on a network with working DNS

**References.** MITRE ATT&CK T1557.001.

---

## PT-09: Sensitive Data Readable on an Open File Share

| | |
| --- | --- |
| **Severity** | Medium |
| **CVSS 3.1** | 6.5 |
| **Affected** | SRV-FILE01, IT share |

**Description.** A spreadsheet named `passwords.xlsx`, containing the local administrator credentials, was readable by any authenticated user on the IT share. It was found while reviewing shares for something else.

**Impact.** Directly provided the reused local admin password behind PT-03.

**Evidence.** File located via share spidering; contents confirmed the local admin credential.

**Remediation.**
1. Remove the file. Never store passwords in shared documents
2. Use a password manager for shared credentials
3. Review share permissions against least privilege
4. Deploy data discovery to find credentials stored in files

**References.** MITRE ATT&CK T1552.001.

---

## PT-10: Domain Users Can Add Computers to the Domain

| | |
| --- | --- |
| **Severity** | Medium |
| **CVSS 3.1** | 5.3 |
| **Affected** | Domain-wide |

**Description.** The `MachineAccountQuota` is at its default of 10, letting any domain user add computer accounts. This enables attacks such as resource-based constrained delegation abuse.

**Remediation.** Set `MachineAccountQuota` to 0 and delegate machine joins to a specific administrative group.

**References.** MITRE ATT&CK T1136.

---

## PT-11: Weak Password Policy

| | |
| --- | --- |
| **Severity** | Medium |
| **CVSS 3.1** | 5.3 |
| **Affected** | Domain-wide |

**Description.** Minimum password length is 7 and there is no account lockout, which makes password spraying (PT-01) practical and unlimited.

**Remediation.**
1. Minimum length of 14 or more
2. Enable account lockout, or a smart lockout that resists spraying
3. Deploy a banned-password list covering seasonal and breached passwords

**References.** MITRE ATT&CK T1110.

---

## PT-12: Web Application Discloses Version Information

| | |
| --- | --- |
| **Severity** | Low |
| **CVSS 3.1** | 3.7 |
| **Affected** | SRV-WEB01 |

**Description.** The web server returns its exact software version (`nginx/1.18.0`), helping an attacker match known vulnerabilities.

**Remediation.** Set `server_tokens off;` in the nginx configuration.

---

## PT-13: Legacy TLS Versions Enabled

| | |
| --- | --- |
| **Severity** | Low |
| **CVSS 3.1** | 3.7 |
| **Affected** | SRV-WEB01 |

**Description.** TLS 1.0 and 1.1 are enabled. Both are deprecated and have known weaknesses.

**Remediation.** Disable TLS 1.0 and 1.1. Allow only TLS 1.2 and 1.3.

---

## PT-14: Domain Administrators Log On to Workstations

| | |
| --- | --- |
| **Severity** | Informational |
| **CVSS 3.1** | n/a |
| **Affected** | Practice, domain-wide |

**Description.** Domain administrator accounts are used to log on interactively to ordinary workstations. This is a practice, not a software flaw, which is why it has no CVSS score.

**Impact.** This is the single most important item in the report. A domain admin logon leaves that account's credentials in the workstation's memory. Any compromise of that workstation then hands over the entire domain. **This practice is what turns every other finding from serious into fatal.**

**Remediation.**
1. Domain admins never log on to anything except domain controllers and dedicated admin workstations
2. Implement tiered administration: separate accounts for workstation, server, and domain administration
3. Deny domain admin interactive and remote logon to workstations via Group Policy
4. Add admins to the Protected Users group

**References.** Microsoft tiered administration model. MITRE ATT&CK T1078.002.

---

## Remediation Priority

Fix in this order. It maximises risk reduction per unit of effort.

| Priority | Finding | Effort | Breaks |
| --- | --- | --- | --- |
| 1 | PT-14 admin logon practice | Medium | The whole chain |
| 2 | PT-01, PT-02 service account passwords | Medium | The entry point |
| 3 | PT-04 unconstrained delegation | Low | The final step |
| 4 | PT-03 reused local admin (LAPS) | Medium | Lateral movement |
| 5 | PT-05, PT-06 anonymous enumeration | Low | Reconnaissance |
| 6 | PT-08, PT-07 LLMNR and signing | Low | No-credential access |
| 7 | Everything else | Low | Hardening |

**The top three are the whole engagement.** Any one of them, fixed, would have stopped the attack at a different point. All three fixed, and the 47-minute path does not exist.

---

Next: [09-Remediation-and-Retest.md](09-Remediation-and-Retest.md)

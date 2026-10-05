# 10 - Findings Report

This is the deliverable. Everything in the other documents exists to produce this. It is written to be read on two levels: an executive summary for the people who decide, and a technical findings section for the people who fix.

---

## Executive Summary

Harbor Retail Group commissioned a full-scope penetration test to answer three questions: can an attacker reach us from the internet, can they reach our customer database, and would we see it happen.

The answer to the first two is yes. The answer to the third is: about half of it.

Starting from nothing but the company name, a tester reached the customer database in five days. The path ran through a flaw in the customer web application, across an internal network boundary that was supposed to stop it, through the Windows domain by way of a misconfigured certificate service, across a second boundary, to the database holding customer records. At no point did the attack need an unknown vulnerability or specialist tooling. It needed patience and a series of common misconfigurations.

**The three most important things to fix:**

1. **The customer web application can be made to run an attacker's code.** This is the way in, and it is a critical priority. It is caused by an out-of-date application accepting file uploads without checking them properly.
2. **The network boundaries do not hold.** The public-facing web server can reach the internal network, and internal workstations can reach the protected database network. Both were supposed to be blocked. Either one turns a small problem into a large one.
3. **The Windows certificate service can be used to become a full administrator.** Any staff member's account, or any account an attacker steals, can request a certificate that makes them a domain administrator. This is invisible with the current logging.

**The good news.** Sixteen of the nineteen findings are fixed by configuration, policy or design decisions, not by buying anything. The most damaging findings are also the cheapest to fix. Tightening the network boundaries and the certificate template costs decisions and an afternoon, not budget.

**What you would have seen.** Two of the nine attack steps were caught by existing monitoring. The rest went through quietly, most notably the certificate abuse that granted full control. The report includes defensive recommendations that mostly involve pointing tools you already own at questions you are not yet asking them.

**Overall risk rating: Critical.** An attacker on the internet can reach your customer data through a chain of common weaknesses, and would likely do so undetected.

---

## Risk At A Glance

![Findings by likelihood and impact](images/risk-matrix.svg)

| Severity | Count |
| --- | --- |
| Critical | 3 |
| High | 6 |
| Medium | 7 |
| Low | 2 |
| Informational | 1 |
| **Total** | **19** |

---

## How To Read A Finding

Each finding below has the same shape:

- **What it is**, in one plain sentence.
- **Impact**, what an attacker gains.
- **Evidence**, how it was proven, with supporting screenshots.
- **Remediation**, what to change, and roughly how much effort it is.

CVSS scores use version 3.1. They are a guide to priority, not a substitute for judgement about your own business.

---

## Critical Findings

### PT2-01: Unauthenticated file upload leads to remote code execution
**CVSS 9.8.** The customer web application accepts uploaded files without verifying what they actually are, and stores them where the server will execute them.

- **Impact.** An attacker with an ordinary customer account, or in some cases none at all, can run their own code on the web server. This is the initial foothold for the entire attack path.
- **Evidence.** A script was uploaded disguised as an image and executed by requesting it. See [04-Web-Application-Testing.md](04-Web-Application-Testing.md).
- **Remediation.** Validate uploads by content, not by the declared type or extension. Store uploads outside the web root and serve them through a handler that never executes them. Update the web framework, see PT2-16. **Effort: medium, and urgent.**

### PT2-02: Certificate template permits escalation to Domain Admin (ESC1)
**CVSS 9.1.** A certificate template on the enterprise certificate authority lets low-privileged users request a certificate that identifies them as any account, including a domain administrator.

- **Impact.** Any domain account, or any account an attacker obtains, can become a full domain administrator. This is the step that gave complete control of the Windows environment.
- **Evidence.** A certificate was requested as a domain administrator using a low-privileged user and used to authenticate. See [07-Active-Directory-Attack-Path.md](07-Active-Directory-Attack-Path.md).
- **Remediation.** Remove the ability for the requester to supply the subject on this template, or restrict enrolment to a trusted group and require manager approval. Enable issuance auditing on the certificate authority. **Effort: low. This is an afternoon and it closes the path to domain takeover.**

### PT2-03: Perimeter web server can reach the internal domain
**CVSS 9.0.** A firewall rule, most likely left over from a deployment, allows the public-facing web server to open connections into the internal corporate network.

- **Impact.** A compromise of the web server, which sits on the internet, becomes a route into the internal network. Without this rule, PT2-01 would have been contained to the perimeter.
- **Evidence.** The internal network answered from a shell on the web server. See [05-Pivoting-and-Tunneling.md](05-Pivoting-and-Tunneling.md).
- **Remediation.** Remove the rule. The perimeter should not initiate connections to the corporate LAN. Review the firewall rule base for other temporary rules that became permanent. **Effort: low.**

---

## High Findings

### PT2-04: Breach-exposed password reused for staff VPN access
**CVSS 8.8.** A staff member's password, exposed in an unrelated third-party breach, was reused for their work VPN account, which has no second factor.

- **Impact.** A second, independent route onto the internal network, requiring no exploitation at all.
- **Remediation.** Enforce multi-factor authentication on the VPN, see PT2-10. Check staff credentials against known breach data and force resets on matches. **Effort: medium.**

### PT2-05: Kerberoastable service account with a crackable password
**CVSS 8.1.** The SQL service account has a Kerberos service principal name and a weak password, so any domain user can request its ticket and crack it offline.

- **Impact.** A privileged service account, with rights into the database network, recovered by any authenticated user.
- **Remediation.** Give service accounts long random passwords, 25 characters or more, or move to group-managed service accounts. Remove unnecessary service principal names. **Effort: medium.**

### PT2-06: Insecure direct object reference exposes other customers' data
**CVSS 8.2.** A logged-in customer can view any other customer's orders by changing the order number in the address bar, with no check that the order belongs to them.

- **Impact.** Every customer's order history, including personal and partial payment data, readable one record at a time by any account.
- **Remediation.** Enforce an ownership check on every record access. Do not rely on the identifier being hard to guess. **Effort: medium.**

### PT2-07: SQL injection in the product search endpoint
**CVSS 8.1.** The product search places user input directly into a database query, allowing an attacker to read from other tables.

- **Impact.** Database contents, including the customer table, readable through the search box. Contained by correctly limited database permissions, which prevented code execution.
- **Remediation.** Use parameterised queries everywhere. Keep the database account's permissions minimal, which here downgraded the severity and was done right. **Effort: medium.**

### PT2-08: Crown-jewel server VLAN reachable from a corporate workstation
**CVSS 7.5.** An ordinary corporate workstation can open connections to the customer database server, when only a short list of application servers should.

- **Impact.** The final boundary protecting customer data does not hold, so any compromised workstation is one step from the database.
- **Remediation.** Restrict the server VLAN to the specific hosts and ports that need it. Default deny between segments. **Effort: low to medium.**

### PT2-09: Local administrator password reused across servers
**CVSS 8.0.** The same local administrator password is used on at least three servers.

- **Impact.** Recovering it once allows administrative access to all of them, including the database server.
- **Remediation.** Deploy Windows LAPS so every machine has a unique, rotated local administrator password. **Effort: low.**

---

## Medium Findings

### PT2-10: SSL VPN permits unlimited login attempts and has no MFA
**CVSS 6.5.** The VPN portal has no lockout and no second factor, so it can be attacked with leaked or guessed credentials at leisure.
- **Remediation.** Enforce MFA and account lockout. **Effort: medium.**

### PT2-11: Web session tokens do not expire or rotate
**CVSS 6.1.** A session token, once issued, works indefinitely and is not invalidated on logout.
- **Remediation.** Set idle and absolute session timeouts. Invalidate on logout and rotate on privilege change. **Effort: low.**

### PT2-12: SMB signing not required
**CVSS 6.5.** SMB signing is not enforced, enabling relay attacks on the internal network.
- **Remediation.** Require SMB signing by group policy. **Effort: low.**

### PT2-13: LLMNR and NBT-NS enabled, permitting credential interception
**CVSS 6.5.** Legacy name-resolution protocols allow an attacker on the LAN to capture authentication.
- **Remediation.** Disable LLMNR and NBT-NS by group policy. **Effort: low.**

### PT2-14: Sensitive data readable on an open internal file share
**CVSS 6.5.** A file share allows broad read access to documents that include credentials and internal procedures. Found by accident during enumeration.
- **Remediation.** Review share permissions against least privilege. Remove stored credentials from documents. **Effort: medium.**

### PT2-15: Password policy permits short and predictable passwords
**CVSS 5.3.** The domain policy allows passwords short and simple enough to crack quickly, which is what made PT2-05 fast.
- **Remediation.** Raise the minimum length to 14 characters and screen against common and breached passwords. **Effort: low.**

### PT2-16: Outdated web framework with known vulnerabilities
**CVSS 5.9.** The web application runs a framework two versions behind, with published advisories, including the class of upload weakness in PT2-01.
- **Remediation.** Update the framework and establish a routine patch cycle for it. **Effort: medium.**

---

## Low Findings

### PT2-17: Verbose errors disclose stack traces and internal paths
**CVSS 3.7.** Application errors return stack traces and internal file paths, and a staff portal was publicly indexed, leaking valid usernames.
- **Remediation.** Return generic errors to users, log detail server side. Remove internal portals from public indexing. **Effort: low.**

### PT2-18: Legacy TLS and weak ciphers on the perimeter
**CVSS 3.7.** Perimeter services accept outdated TLS versions and weak ciphers.
- **Remediation.** Restrict to TLS 1.2 and 1.3 with modern ciphers. **Effort: low.**

---

## Informational

### PT2-19: Domain administrators authenticate to lower-tier hosts
**No CVSS score.** Domain administrators log on interactively to ordinary workstations and servers, exposing their credentials on machines that do not need them.

- **Why it is here and why I would fix it first.** It is not a vulnerability, it is a practice, which is why it has no score. It is also the single change that would have blunted the back half of the attack path. When high-privilege credentials are exposed on lower-tier machines, one compromised machine becomes a compromised domain. A tiered administration model, where domain admin credentials never touch a workstation, is the highest-leverage change on this list.
- **Remediation.** Adopt a tiered administration model. Use separate administrative accounts that are barred from logging on to lower tiers. **Effort: high, and worth it.**

---

## Prioritised Remediation Plan

Fix in this order. It follows impact and effort, not the finding numbers.

| Priority | Findings | Rationale |
| --- | --- | --- |
| Now | PT2-03, PT2-08 | Close the two broken network boundaries. Cheap, and they contain everything else |
| Now | PT2-02 | Close the certificate path to domain admin. An afternoon |
| This week | PT2-01, PT2-16 | Fix and update the web application. The way in |
| This week | PT2-09, PT2-05 | Kill password reuse and weak service accounts |
| This month | PT2-04, PT2-10, PT2-06, PT2-07 | Harden authentication and the application |
| This month | PT2-12, PT2-13, PT2-15 | Standard internal hardening, all low effort |
| Planned | PT2-19 | Tiered administration. Largest effort, largest long-term payoff |
| Cleanup | PT2-11, PT2-14, PT2-17, PT2-18 | Lower risk, fold into routine work |

The retest of these fixes is in [11-Remediation-and-Retest.md](11-Remediation-and-Retest.md).

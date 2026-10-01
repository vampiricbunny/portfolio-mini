# 11 - Remediation and Retest

A finding is not closed because someone says they fixed it. It is closed when the tester tries the attack again and it fails. This document is the retest: the fixes Harbor applied, and the result of running each attack a second time.

The retest is where a report earns trust. It is also where you find out that some fixes do not work, and reporting those honestly is more valuable than a clean sheet, because a fix that looks done but is not leaves the client exposed while believing they are safe.

---

## The Retest

Harbor applied the remediation over three weeks and asked for a retest of the critical and high findings, plus a sample of the mediums. The attack path was run again, step by step.

| Finding | Fix applied | Retest result |
| --- | --- | --- |
| PT2-01 file upload RCE | Upload validation rewritten, uploads moved out of web root | **Closed** |
| PT2-02 ADCS ESC1 | Template locked down, subject supply removed, auditing enabled | **Closed** |
| PT2-03 perimeter to corporate | Firewall rule removed | **Closed** |
| PT2-04 VPN credential reuse | MFA enforced, breached password reset | **Closed** |
| PT2-05 Kerberoastable service account | Moved to a group-managed service account | **Closed** |
| PT2-06 IDOR | Ownership check added | Partially fixed, see below |
| PT2-07 SQL injection | Queries parameterised | **Closed** |
| PT2-08 server VLAN reachable | Segmentation tightened | Partially fixed, see below |
| PT2-09 local admin reuse | LAPS deployed | **Closed** |
| PT2-05, PT2-15 password policy | Minimum length raised, breach screening added | **Closed** |
| PT2-12, PT2-13 SMB signing, LLMNR | Enforced and disabled by policy | **Closed** |

Most fixes held. Two did not fully, and those are the two worth the most words.

---

## The Two Incomplete Fixes

### PT2-06: The ownership check that missed an endpoint

Harbor added an ownership check to the order-viewing page, and it worked. The retest could no longer read another customer's orders through that page.

But the application had a second endpoint, the order-printing view, that reached the same data by a different path. The fix was applied to the page that was reported, not to the underlying access-control gap, so the print endpoint still returned any customer's order.

**This is the most common way a fix fails: it addresses the instance in the report rather than the class of problem.** The finding was IDOR, an access-control flaw. The fix treated it as a bug on one page. The retest found the second door, and the corrected remediation was to enforce the ownership check in one place that every access to an order passes through, rather than page by page.

After the second fix, both endpoints were checked and the finding closed.

### PT2-08: Segmentation tightened, but not enough

Harbor restricted the server VLAN so that corporate workstations could no longer reach the database server. The retest confirmed a workstation could no longer open the database port.

However, the file server on the corporate LAN had been left with broad access to the server VLAN, and the file server was reachable from a workstation. So the path still existed, one hop longer: workstation to file server, file server to database. The boundary was tighter, but not default-deny, and the attack path routed around the new rule.

**The corrected remediation was default-deny between segments, with an explicit allow list of the exact hosts and ports that need to cross.** After that change, the workstation-to-database path was gone by every route tested, and the finding closed.

---

## What The Retest Says About The Fixes

Nine of the eleven retested findings closed on the first attempt. Two needed a second pass because the first fix addressed the symptom in the report rather than the underlying weakness. That is a good outcome and a normal one.

The pattern in both failures is the same and it is worth stating for Harbor: fix the class, not the instance. An IDOR is not a bug on one page, it is a missing access-control pattern. A segmentation gap is not one rule, it is an absence of default-deny. Fixes that target the exact thing in the report and nothing else tend to leave a second door, and the second door is exactly where the attacker who read the same report will go.

---

## Residual Risk

After the full remediation and the corrected second-pass fixes:

- The attack path from the internet to the customer database is broken in multiple places. No single reproduced step now succeeds end to end.
- PT2-19, the tiered administration finding, remains open by agreement. It is a larger project and Harbor has scheduled it. Until it is done, a compromised workstation with a logged-on administrator remains a real risk, so it is carried as a known, accepted, tracked item rather than silently dropped.
- The lower-severity findings folded into routine hardening work are on Harbor's backlog with dates.

**The overall risk rating after remediation moved from Critical to Low**, with the one accepted item, PT2-19, noted as the reason it is not Minimal. That is an honest place to leave it. The environment is meaningfully safer, the crown-jewel path is closed, and the one remaining structural risk is named, understood and scheduled rather than hidden.

---

## Closing Note

The value of this engagement was not the shells. It was the map: a single, proven path from the internet to the customer data, built from ordinary misconfigurations, and then broken. The retest proves the breaking, including the two places where the first attempt was not enough.

A client who reads this report knows three things they did not know before. How an attacker would actually reach their customers. What their monitoring would and would not see while it happened. And, after the retest, that the path is genuinely closed and not just reported as closed. That is the whole job.

Back to the [README](README.md).

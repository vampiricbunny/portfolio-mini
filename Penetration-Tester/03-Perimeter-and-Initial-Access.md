# 03 - Perimeter and Initial Access

Recon produced two candidate ways in: the dev web application and credential reuse on the VPN. This document works the VPN path and the wider perimeter. The web application path is large enough to deserve its own document, so it is in [04-Web-Application-Testing.md](04-Web-Application-Testing.md).

Both paths were confirmed. That matters for the report. A client who fixes the web app and believes they are safe has missed the VPN, and a good external test proves there is more than one door.

---

## The Principle: More Than One Door

An external test is not finished when you find one way in. It is finished when you have found the ways in that a real attacker would find, so the client can close all of them. Reporting a single critical and stopping is a disservice, because the attacker who reads the same perimeter will not stop at the first door either.

So the web RCE became the primary foothold for the attack path, and the VPN path was confirmed, documented and then set aside. Two independent routes through the perimeter is a stronger and more honest finding than one.

---

## The Staff VPN

`VPN01` on 172.16.5.10 presented an SSL VPN login portal on 443. Two things about it were wrong before a single credential was tried.

**There was no multi-factor prompt.** A remote access portal exposed to the internet with a password as the only factor is a standing invitation. Passwords leak. That is a fact of the modern internet, not a hypothetical, and the passive recon in [02](02-External-Reconnaissance.md) already had a candidate.

**There was no lockout.** Repeated failed logins produced no throttling, no lockout and no delay. That turns the portal into something an attacker can spray at their leisure.

### Credential Reuse

The passive recon phase surfaced a staff email and password pair from an old third-party breach. The question an external tester always asks: did the person reuse that password on their work account.

They had.

The breached credential authenticated to the VPN on the first attempt. In a real engagement this is the most common way in that exists, and it is nobody's software vulnerability. It is a human reusing a password across a personal service and their employer, and an employer who allowed a single factor to be enough.

That is finding **PT2-04**, and the missing MFA and lockout are **PT2-10**.

### What The VPN Gave Up

The VPN placed the tester on the internal corporate network as an authenticated standard user. In the attack path this is a second route to the same place the web RCE reaches by pivoting. Because the web path demonstrates a more interesting chain, that is the one the rest of the report follows. The VPN path is noted as confirmed and equally serious.

---

## The Webmail Portal

`MAIL01` on 172.16.5.30 was the staff webmail portal that turned up in a search engine, indexed by accident. It was current and patched, and it did not fall. It is recorded here anyway for two reasons.

First, a portal that should not be publicly indexed being publicly indexed is an information-exposure issue worth a low-severity note. It tells an attacker where to spray credentials and gives them a list of valid usernames through its behaviour on login.

Second, honesty. Not every service falls, and a report that only lists the wins is a sales brochure, not an assessment. The webmail portal held, and saying so makes the findings that did land more credible.

---

## Perimeter Hardening Observations

While working the perimeter, a few lower-severity issues were confirmed and are carried into the report:

| Observation | Finding |
| --- | --- |
| Legacy TLS versions and weak ciphers accepted on all three hosts | PT2-18 |
| Verbose application errors on the dev web app disclosing stack traces and internal paths | PT2-17 |
| The staff portal indexed publicly, leaking valid usernames | Folded into PT2-17 |

These are not the way in. They are the kind of finding that fills out the middle of a report and, taken together, describe a perimeter that has not been reviewed in a while. That pattern is itself worth telling the client.

---

## Two Confirmed Footholds

At the end of this phase there were two independent, confirmed ways onto the internal network:

1. **Web application to RCE** on `WWW01`, worked in [04](04-Web-Application-Testing.md). This becomes the primary attack path.
2. **Credential reuse on the VPN**, giving an authenticated position as a standard user.

Either one is a critical finding on its own. Together they say something the client needs to hear: the perimeter is not one wall with one gate, it is several services each maintained by a stretched team, and the attacker only has to win once.

Next: [04-Web-Application-Testing.md](04-Web-Application-Testing.md).

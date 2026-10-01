# 09 - Remediation and Retest

Applying the fixes, then proving they work. The part most people skip, and the part that closes an engagement.

---

## Why Retest

A finding is not fixed until it is proven fixed.

Clients apply remediations and assume they worked. Sometimes they did not: the setting did not apply, a Group Policy did not reach a machine, a change was reverted by another. **The retest is what turns "we fixed it" into "it is verified fixed."**

This is also a strong thing to show an employer, because it demonstrates that you finish the job rather than stopping at the exciting part.

---

## The Fixes Applied

Each fix maps to a finding. This is what was changed.

### The top three, which break the chain

**PT-14, admin logon.** Group Policy now denies domain admins interactive and remote logon to workstations.

```powershell
# Deny logon rights to the Domain Admins group on the workstation OU
# via a GPO linked to the Workstations OU:
#   Deny log on locally
#   Deny log on through Remote Desktop Services
# plus adding admins to Protected Users
Add-ADGroupMember -Identity "Protected Users" -Members "itsupport"
```

**PT-01 and PT-02, service accounts.** Passwords reset to 30 random characters, and AES enforced.

```powershell
$new = ConvertTo-SecureString ([System.Web.Security.Membership]::GeneratePassword(30,8)) -AsPlainText -Force
Set-ADAccountPassword -Identity svc_sql -NewPassword $new -Reset
Set-ADUser svc_sql -Replace @{'msDS-SupportedEncryptionTypes'=24}   # AES only
```

**PT-04, delegation.** Removed from SRV-FILE01.

```powershell
Set-ADComputer -Identity "SRV-FILE01" -TrustedForDelegation $false
```

### The rest

```powershell
# PT-03: deploy LAPS (unique local admin password per machine)
# Installed the LAPS GPO and set the policy on the Workstations OU

# PT-05, PT-06: stop anonymous enumeration
New-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa' `
    -Name 'RestrictAnonymous' -Value 1 -PropertyType DWord -Force
# and set dSHeuristics back to deny anonymous LDAP

# PT-07: require SMB signing (GPO)
#   Microsoft network server: Digitally sign communications (always) = Enabled

# PT-08: disable LLMNR and NBT-NS (GPO)
#   Turn off multicast name resolution = Enabled

# PT-10: machine account quota
Set-ADDomain -Identity ptlab.local -Replace @{"ms-DS-MachineAccountQuota"="0"}

# PT-11: password policy
Set-ADDefaultDomainPasswordPolicy -Identity ptlab.local `
    -MinPasswordLength 14 -LockoutThreshold 5 -LockoutDuration 00:15:00

# PT-12: hide nginx version
#   server_tokens off; in nginx.conf

# PT-13: disable legacy TLS
#   ssl_protocols TLSv1.2 TLSv1.3; in nginx.conf

# PT-09: removed passwords.xlsx, tightened share permissions
```

---

## The Retest

Run the original attack path again, step by step, and record what now fails.

| Step | Original attack | Retest result |
| --- | --- | --- |
| 1 | Null session enumeration | **Blocked.** Anonymous access denied |
| 2 | Anonymous LDAP bind | **Blocked.** Bind requires credentials |
| 3 | Password spray on `svc_sql` | **Blocked.** New password not guessable, and lockout now triggers |
| 4 | Kerberoast `svc_sql` | Ticket still requestable, but **uncrackable** with a 30-char password |
| 5 | Local admin reuse | **Blocked.** LAPS gives each machine a unique password |
| 6 | Unconstrained delegation | **Blocked.** Delegation removed, no ticket to capture |

### Verification commands

```bash
# Step 1 and 2: anonymous enumeration now fails
netexec smb 10.50.10.10 -u '' -p '' --shares
#  ->  STATUS_ACCESS_DENIED

ldapsearch -x -H ldap://10.50.10.10 -b "DC=ptlab,DC=local"
#  ->  operations error, bind required

# Step 3: spray now fails and locks
netexec smb 10.50.10.10 -u users.txt -p 'Autumn2024!' --continue-on-success
#  ->  all STATUS_LOGON_FAILURE, then STATUS_ACCOUNT_LOCKED_OUT

# Step 4: ticket still comes, but does not crack
impacket-GetUserSPNs ptlab.local/arivera:'***' -request
hashcat -m 13100 tickets.txt rockyou.txt
#  ->  Exhausted. Not cracked

# Step 5: local admin reuse fails
netexec smb 10.50.10.102 -u LocalAdmin -H <old_hash> --local-auth
#  ->  STATUS_LOGON_FAILURE on the second machine

# Step 6: delegation gone
netexec ldap 10.50.10.10 -u arivera -p '***' --trusted-for-delegation
#  ->  no non-DC hosts returned
```

**The 47-minute path no longer exists.** Every step that led to domain compromise now fails.

---

## What the Retest Found

A retest that finds everything perfect is a retest that was not done properly. This one found two things.

### One fix did not apply

The LLMNR Group Policy (PT-08) showed as configured but had not reached WS-02, because that machine had not refreshed policy. Responder still captured a hash from it.

```bash
# On WS-02
gpupdate /force
```

After a forced policy update, the retest passed. **This is exactly why you retest.** The change was made correctly and still did not take effect everywhere. Without the retest, the client would believe LLMNR was disabled while one machine was still vulnerable.

### One fix was incomplete

SMB signing (PT-07) was required on servers but the GPO scope missed the workstations. Relaying to WS-01 still worked. The GPO scope was corrected to cover the Workstations OU.

**Both of these are more valuable in the report than the clean passes.** They show the difference between "changed" and "effective," which is the entire reason the retest phase exists.

---

## Residual Risk

What remains after remediation, stated honestly.

| Item | Residual risk | Note |
| --- | --- | --- |
| Kerberoasting still possible | Low | Ticket requestable, but uncrackable. Monitor event 4769 |
| Phishing as initial access | Medium | Out of scope here, but the likely real entry point |
| Insider with valid credentials | Medium | Reduced by tiering, not eliminated |
| Unknown service accounts | Low | Recommend a full service account audit |

**No environment reaches zero risk.** The job is to reduce it to a level the business accepts, and to state clearly what is left.

---

## The Blue Team Crossover

This is the section that makes the project more than a pentest, and it ties directly to [SOC-01](../Junior-SOC-Analyst/) and [SOC-02](../SOC-Analyst-1/).

Each attack was replayed against the same detection rules those projects built. Here is what the defender would have seen.

| Attack | Detection | Caught | Notes |
| --- | --- | --- | :---: |
| Password spray | SOC-01 rule 100103 | Yes | Fired in 38 seconds |
| Kerberoasting | SOC-01 rule 100203 | Yes | 5-plus ticket requests flagged |
| PsExec lateral movement | SOC-01 rule 100603 | Yes | Service creation caught |
| Pass the hash | Logon type 3 anomaly | Partial | Needs baseline of normal |
| LLMNR poisoning | None | **No** | No detection existed |
| Anonymous LDAP enumeration | None | **No** | Not logged at all |
| DCSync | None | **No** | Needs directory service auditing |

**Three of seven went undetected.** Those are real gaps, and naming them is the point.

- **LLMNR poisoning** is silent because it happens on the network, not on a host. Detecting it needs network monitoring, which the SOC labs did not have.
- **Anonymous LDAP enumeration** produced no security log at all, because anonymous reads are not audited by default.
- **DCSync** needs directory service access auditing (event 4662 with replication GUIDs), which was never enabled.

Each gap now has a recommended detection, written back into the roadmap for the SOC projects. **The attack found the detection gaps, and the detection work will close them. That loop is the whole value of building both sides.**

---

## Final Statement

The environment moved from full domain compromise in 47 minutes to no viable path in the same test. Two remediations that appeared complete were found incomplete on retest and corrected. Three attack techniques remain undetectable with the current monitoring, and detections have been recommended for each.

The most important single change was not technical. It was the decision that domain administrators do not log on to workstations. That one practice, more than any individual patch, is what turns this network from fragile to defensible.

---

Back to [README.md](README.md)

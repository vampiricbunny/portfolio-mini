# Multi-Factor Authentication with Duo

Deploying Cisco Duo to protect Windows logon, RDP and application access, plus the operational side that matters more than the deployment: enrollment, recovery, and the attacks that target MFA itself rather than trying to defeat it.

MFA is the single highest-value control against credential theft. Passwords get phished, reused and cracked; a second factor makes a stolen password insufficient on its own. That is also precisely why attackers stopped attacking the password and started attacking the *enrollment and recovery process* around the second factor.

---

## What MFA Does and Does Not Stop

| Attack | MFA helps? | Notes |
| --- | --- | --- |
| Password spraying | **Yes** | Valid password alone gets nowhere |
| Credential stuffing from a breach dump | **Yes** | Same reason |
| Basic phishing for a password | **Yes** | The password is no longer sufficient |
| Adversary-in-the-middle phishing | **Partly** | Evilginx-style proxies relay the MFA prompt and steal the *session token*. Only phishing-resistant factors stop this |
| MFA fatigue / push bombing | **No** | Attacker has the password and spams prompts until someone taps Approve |
| SIM swap | **No** | Why SMS is the weakest factor |
| Helpdesk social engineering | **No** | Attacker calls IT and has the factor reset for them |
| Token theft / session hijack | **No** | The session is already authenticated |

The last three are not theoretical. **Several high-profile 2023 intrusions began with a phone call to a service desk** that resulted in an MFA factor being reset for an attacker. The control that stops that is identity verification at the desk, not the MFA product.

### Factor Strength

| Factor | Strength | Notes |
| --- | --- | --- |
| SMS / voice call | Weakest | SIM swap, SS7 interception. Better than nothing, deprecated by NIST |
| TOTP code | Moderate | Phishable, since the user can be induced to read it out |
| Push approval | Moderate | Phishable via fatigue unless number matching is on |
| **Push plus number matching** | Good | Blunts fatigue attacks; the user must read a number from the login screen |
| **FIDO2 / WebAuthn / hardware key** | Strongest | Cryptographically bound to the origin, therefore **phishing-resistant** |

Where the option exists, push with number matching is the practical baseline and FIDO2 the target for privileged accounts.

---

## Deployment

### Tenant Setup

1. Sign up at [signup.duo.com](https://signup.duo.com) with a work email.
2. Verify the email address and phone number.
3. Install **Duo Mobile** on a phone and enrol it as the administrator device.
4. Record the recovery details somewhere that does not depend on the account you just protected.

> **Protect the admin account first, and enrol a second administrator.** A single admin with a single enrolled device is a lockout waiting to happen. If that phone is lost, nobody can administer the tenant.

### Admin Panel

| Section | Purpose |
| --- | --- |
| **Users** | Accounts, enrollment state, device assignment |
| **Devices** | Enrolled phones, hardware tokens, WebAuthn keys |
| **Groups** | Bulk policy and application assignment |
| **Applications** | Each protected service and its policy |
| **Policies** | Global and per-application authentication rules |
| **Reports** | Authentication log, the security-relevant view |
| **Administrators** | Who can administer Duo, and at what level |

### Users and Groups

```text
Users > Add User > username and email > Add User
Users > Groups > Add Group > name and description
```

Assign policy and applications to **groups**, never individuals. Access changes then become group membership changes, and the policy stays auditable.

A workable group structure:

| Group | Policy |
| --- | --- |
| `Duo-Standard-Users` | Push with number matching |
| `Duo-Privileged` | FIDO2 required, no push, shorter remembered-device window |
| `Duo-Service-Exempt` | Documented exceptions, reviewed monthly |

### Enrollment

Duo emails the user a self-enrollment link. They install Duo Mobile, scan the QR code, and the device binds to their account.

**The enrollment link is a credential.** Anyone who receives it can bind *their* device to that user's account. Send it to a verified address, keep the expiry short, and treat an unexpected enrollment email as a reportable event.

---

## Protecting Windows Logon and RDP

This is the deployment that matters most in a Windows environment, because RDP with a stolen password is one of the most common footholds there is.

### Add the Application

1. **Applications** then **Protect an Application**.
2. Search for **Microsoft RDP** and select **Protect**.
3. Record the three values Duo generates:
   - **Integration key**
   - **Secret key**
   - **API hostname**

> These three values together are equivalent to full control of that integration. Treat the secret key like a password: it belongs in a secrets manager, not in a ticket, a text file, or a screenshot.

### Install the Authentication Proxy

1. Download **Duo Authentication for Windows Logon** onto the target server.
2. Run the installer and supply the integration key, secret key and API hostname.
3. Configure the options deliberately:

| Option | Setting | Reasoning |
| --- | --- | --- |
| Bypass Duo when offline | **Disabled** for servers | "Fail open" means an attacker who blocks outbound traffic to Duo removes MFA entirely |
| Only prompt for RDP | Depends | Enabling for console logon too closes a local-access gap |
| Enable UAC elevation protection | **Enabled** | Requires a second factor for privilege elevation |
| Smart card support | As required | |

Finally, restart and test **from a second session** before closing the one you are working in.

> **Always keep a working session open when deploying MFA to a server.** A misconfigured integration locks everyone out, including you, and the fix requires console or recovery access. This is the most common self-inflicted incident in an MFA rollout.

### Verify

- Connect via RDP with a valid password, and a Duo prompt should appear.
- Approve, and the session establishes.
- Deny, and access is refused, with the denial appearing in the Duo authentication log.
- Confirm the event is logged with the correct source IP and user.

---

## Policy Configuration

Global policy sets the floor; application policy overrides it.

| Setting | Recommended | Reasoning |
| --- | --- | --- |
| **New user policy** | Deny access | "Allow without MFA" means an unenrolled account has no second factor at all |
| **Authentication methods** | Push with number matching; FIDO2 for privileged | Disable SMS where it can be avoided |
| **Remembered devices** | Short, or off for privileged | Trades convenience against the window a stolen session is useful |
| **User location** | Alert or block unexpected countries | Cheap, high-signal detection |
| **Anomalous push detection** | Enabled | Duo flags rapid repeated pushes, the fatigue-attack signature |
| **Authorized networks** | Reduced prompting on trusted networks only | Never *skip* MFA for external addresses |

---

## Service Desk Runbook

### Identity Verification, Before Anything Else

**This is the control, not a formality.** An MFA reset performed for the wrong person hands over an account completely.

Before resetting, re-enrolling or bypassing any factor:

- Call back on the number in the HR record, **never** a number the caller supplies
- Or verify through the user's manager
- Or verify in person or on video
- Confirm details the caller would not obtain from a public profile
- Record in the ticket **how** identity was verified, not just that it was

A caller who resists verification, applies time pressure, or claims to be an executive in a hurry is displaying the standard social-engineering pattern. Pressure is a reason to slow down.

### New Phone

1. Verify identity as above.
2. Go to **Users** and locate the user.
3. Confirm whether the old device is still accessible.
4. Remove the old device, then add the new one.
5. Send an enrollment link, or generate a one-time bypass code valid for a single use and a short window.
6. Confirm successful authentication before closing the ticket.
7. Note the device change in the ticket.

### Lost or Stolen Device

1. Verify identity.
2. **Remove the device immediately.** Do not wait for the replacement.
3. Reset the user's password as well. A lost phone often means saved passwords went with it.
4. Review the authentication log for approvals after the reported loss time.
5. Issue a temporary factor or hardware token.

### Bypass Codes

Bypass disables the second factor for that user. It is occasionally necessary and frequently abused.

- Single use and short expiry, never open-ended
- Requires documented approval from management, recorded in the ticket
- Never for privileged accounts
- Review active bypasses weekly

```text
Users > select user > Add Bypass Code > set use count and expiry
```

A permanent bypass on an account is the same as that account having no MFA, and it will not be visible to anyone who only reads the policy.

---

## Monitoring

The authentication log is the security-relevant part of Duo, and it is routinely ignored.

Worth reviewing, and worth alerting on:

- **Repeated denials for one user.** Someone has the password and is being refused. That is an active intrusion attempt, not a user problem.
- **Rapid successive pushes.** Fatigue attack in progress.
- **Approval from an unexpected country**, particularly shortly after a normal login elsewhere. Two logins geographically impossible to reconcile is high-confidence compromise.
- **New device enrollments**, especially outside working hours.
- **Bypass codes issued or used.**
- **Administrator changes**, such as policy edits, application changes and admin additions.

Forward the log to a SIEM where one exists. Correlating a Duo denial with a Windows 4625 failed logon from the same source turns two weak signals into one strong one.

> **A user reporting "I keep getting Duo prompts I didn't ask for" is reporting a security incident.** Their password is already compromised. The correct response is a password reset and a session review, not an explanation of how to dismiss the prompt.

---

## Operational Notes

- **MFA everything that faces outward**, including VPN, RDP, webmail and admin portals. Partial coverage means attackers use whatever was missed.
- **Privileged accounts get phishing-resistant factors.** Push is acceptable for standard users; domain admins should use FIDO2.
- **Do not let MFA fail open.** Offline bypass on a server means blocking outbound traffic to Duo disables the control.
- **Enrol a break-glass path** and store it offline. MFA lockouts are the most common way to lose access to your own environment.
- **Review exceptions monthly.** Temporary exemptions become permanent unless somebody looks.
- **Log the reset, not just the outcome.** After an incident, "who re-enrolled this factor, when, and on whose authority" is the first question asked.

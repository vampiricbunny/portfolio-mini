# Group Policy - Hands-On Labs

Practical Group Policy work in `vbunnylab.local`: building GPOs, scoping them, testing them against a real client, and diagnosing the cases where they silently do not apply.

For the conceptual side - processing order, precedence, Policies vs Preferences - see [Group Policy Management](../Windows-Server/Group-Policy-Management.md). This document is the lab log.

---

## Prerequisites

- AD DS operational on `DC01` - see [Building the Lab](Active-Directory-Setup.md)
- Domain admin or delegated rights
- `WS11-01` joined to the domain, sitting in `OU=Workstations,OU=VBunnyLab`
- A test user: `ballen` in `OU=IT,OU=VBunnyLab`

---

## Opening the Console

`Win + R` → `gpmc.msc`, or **Server Manager** → **Tools** → **Group Policy Management**.

**Create unlinked, then link deliberately.** Right-click **Group Policy Objects** → **New** builds the GPO without attaching it to anything. You then link it where you want it. Creating directly on an OU links it immediately, which means a half-configured policy starts applying while you are still editing it.

---

## Lab 1 - Security Filtering, and the Trap In It

**Goal:** link a GPO at a broad OU but have it apply to one object only.

1. **Group Policy Objects** → **New** → name it `TEST-Scoped-Policy` → **OK**.
2. Select the GPO → **Scope** tab → **Security Filtering**.
3. **Add** → enter `ballen` → **Check Names** → **OK**.
4. Select **Authenticated Users** → **Remove** → confirm.
5. Link it: right-click `OU=VBunnyLab` → **Link an Existing GPO** → `TEST-Scoped-Policy`.

The GPO is now linked to the whole branch, but only `ballen` is in the filter.

### Why It Won't Work Yet

Run `gpupdate /force` on the client and the policy does not apply. Nothing in the UI explains why.

**Cause: MS16-072.** Since that 2016 update, Group Policy for *users* is retrieved in the security context of the **computer**, not the user. Removing **Authenticated Users** also removed the computer's ability to read the GPO - so the client cannot fetch it to evaluate whether the user qualifies.

**The fix** is to restore read access for computers without granting apply:

1. **Delegation** tab → **Add**.
2. **Object Types** → tick **Computers** → enter `Domain Computers` → **Check Names** → **OK**.
3. Permission: **Read** - deliberately *not* "Read and Apply Group Policy".

`Domain Computers` can now read the GPO; only `ballen` has **Apply group policy**, so only `ballen` receives it.

> This is the single most common cause of "the GPO is linked, the filter is right, and nothing happens." It is worth recognising on sight. The symptom in `gpresult` is the GPO appearing under **Denied - Inaccessible** rather than **Denied - Access Denied (Security Filtering)**.

**Alternative:** leave **Authenticated Users** in Security Filtering and use a **WMI filter** or **Item-level targeting** instead. Fewer moving parts, and no MS16-072 exposure.

### The Delegation Tab

Separate from filtering. Delegation controls who can *administer* the GPO:

| Permission | Grants |
| --- | --- |
| Read | View settings |
| Edit settings | Modify the GPO |
| Edit, delete, modify security | Full control short of ownership |

Useful for letting a desktop team manage workstation GPOs without touching anything else.

---

## Lab 2 - Windows Defender Firewall Baseline

The original version of this lab disabled the domain firewall. That works as a demonstration of "did my GPO apply", but it is the wrong thing to practise - the domain profile is the one profile that should stay on, and turning it off centrally is a finding in any audit.

This version configures it properly instead.

1. **Group Policy Objects** → **New** → `VBunnyLab-Firewall-Baseline`.
2. Right-click → **Edit**.
3. Navigate to:

   ```text
   Computer Configuration
   └── Policies
       └── Windows Settings
           └── Security Settings
               └── Windows Defender Firewall with Advanced Security
   ```

4. Right-click the node → **Properties**.

Configure each profile:

| Profile | Firewall state | Inbound | Outbound |
| --- | --- | --- | --- |
| **Domain** | On | Block (default) | Allow (default) |
| **Private** | On | Block (default) | Allow (default) |
| **Public** | On | Block all connections | Allow (default) |

Then enable logging on each profile - **Logging** → **Customize**:

- Log dropped packets: **Yes**
- Log successful connections: **Yes**
- Size limit: 16384 KB

Firewall logs are one of the few host-level sources that show blocked inbound attempts. Enabling them costs nothing and they are unavailable retrospectively.

Finally, link the GPO to `OU=Workstations,OU=VBunnyLab`.

> This is a **Computer Configuration** setting. The firewall belongs to the machine, not the signed-in user - configuring it under User Configuration does nothing.

### Testing

On `WS11-01`:

```cmd
gpupdate /force
gpresult /r /scope:computer
```

Confirm `VBunnyLab-Firewall-Baseline` appears under *Applied Group Policy Objects*, then check the state:

```powershell
Get-NetFirewallProfile | Select-Object Name, Enabled, DefaultInboundAction, LogAllowed, LogBlocked
```

**Start** → **Firewall & network protection** should show the settings greyed out - managed by the administrator, which is the visible signature of an enforced policy rather than a local one.

---

## Lab 3 - Password Policy (Domain Root)

**This is the lab where the obvious approach is wrong**, and it is worth doing deliberately to see the failure.

### The Mistake

Create a `Password Policy` GPO, configure password settings, link it to `OU=VBunnyLab`. Run `gpupdate /force` and `gpresult` - the GPO reports as **applied**. Everything looks correct.

It does nothing to domain accounts.

**Why:** password and lockout policy for domain users is read from the GPO linked at the **domain root**, resolved by the PDC emulator. A password policy linked to an OU only affects the **local SAM database** of the computers in that OU - local accounts, not domain accounts. The policy genuinely applied; it just governed something other than what was intended.

This is a misconfiguration that survives in production for years, because it tests as "applied."

### The Correct Configuration

1. In GPMC, edit the GPO linked at **`vbunnylab.local`** itself - the domain root.
2. Navigate to:

   ```text
   Computer Configuration
   └── Policies
       └── Windows Settings
           └── Security Settings
               └── Account Policies
                   └── Password Policy
   ```

3. Configure:

   | Setting | Value |
   | --- | --- |
   | Enforce password history | 24 passwords remembered |
   | Maximum password age | 365 days |
   | Minimum password age | 1 day |
   | Minimum password length | 14 characters |
   | Password must meet complexity requirements | Enabled |
   | Store passwords using reversible encryption | Disabled |

> **Minimum password age matters more than it looks.** Without it, a user prompted to change their password can cycle through 24 changes in two minutes and land back on the original. Set to 1 day, history actually holds.

> **On maximum password age:** current NIST guidance (SP 800-63B) advises against routine expiry - it produces predictable increments like `Autumn2026!` → `Winter2026!`. Rotate on evidence of compromise instead. Many organisations still mandate 90 days for compliance reasons; know both positions and which one applies where you work.

### Testing

On `WS11-01`, signed in as `ballen`, press `Ctrl+Alt+Del` → **Change a password** and try to reuse a recent one. Windows refuses, citing the history requirement.

```powershell
Get-ADDefaultDomainPasswordPolicy
```

### Different Rules for Different Groups

You cannot do this with a second GPO. Use **Fine-Grained Password Policies**:

1. **Active Directory Administrative Center** (`dsac.exe`).
2. `vbunnylab.local` → **System** → **Password Settings Container**.
3. **New** → **Password Settings**.
4. Name it, set a **Precedence** (lower number wins), configure the settings, and add the group it applies to.

```powershell
New-ADFineGrainedPasswordPolicy -Name 'PSO-Admins' -Precedence 10 `
  -MinPasswordLength 20 -PasswordHistoryCount 24 `
  -ComplexityEnabled $true -LockoutThreshold 5

Add-ADFineGrainedPasswordPolicySubject -Identity 'PSO-Admins' -Subjects 'Domain Admins'
Get-ADUserResultantPasswordPolicy -Identity vampiricbunny
```

That last cmdlet shows which policy actually governs a given user - the direct answer to "which rules apply to this account."

---

## Lab 4 - Account Lockout Policy

Same rule as above: **domain root, not an OU.**

1. Edit the GPO linked at `vbunnylab.local`.
2. Navigate to **Account Policies** → **Account Lockout Policy**.
3. Configure:

   | Setting | Value | Reasoning |
   | --- | --- | --- |
   | Account lockout threshold | 10 invalid attempts | Blunts password spraying without locking out ordinary typos |
   | Account lockout duration | 15 minutes | Self-clearing; avoids a helpdesk queue |
   | Reset account lockout counter after | 15 minutes | |
   | Allow Administrator account lockout | Enabled | New in current builds - closes the gap where the built-in Administrator could be sprayed indefinitely |

> **A threshold of 3-5 is a self-inflicted denial of service.** A stale credential on a phone or a service account with an old password will lock the account repeatedly. Ten attempts still stops spraying, because spraying tries a handful of passwords across thousands of accounts rather than thousands against one.

### Testing

Deliberately fail sign-in as `ballen` past the threshold, then on DC01:

```powershell
Search-ADAccount -LockedOut | Select-Object Name, SamAccountName, LastLogonDate
Unlock-ADAccount -Identity ballen
```

Find the *source* of a real lockout - event 4740 on the PDC emulator names the machine it came from:

```powershell
Get-WinEvent -FilterHashtable @{LogName='Security'; ID=4740} -MaxEvents 20 |
    Format-List TimeCreated, Message
```

---

## Lab 5 - Hide Control Panel (User Policy)

1. **Group Policy Objects** → **New** → `VBunnyLab-Restrict-ControlPanel` → **Edit**.
2. Navigate to:

   ```text
   User Configuration
   └── Policies
       └── Administrative Templates
           └── Control Panel
   ```

3. Open **Prohibit access to Control Panel and PC settings** → **Enabled** → **Apply** → **OK**.
4. Link to `OU=IT,OU=VBunnyLab`.

If you scope it with security filtering, apply the MS16-072 fix from Lab 1 - this is a **User Configuration** policy, so it is exactly the case that breaks.

### Testing

```cmd
gpupdate /force
gpresult /r /scope:user
```

Then try to open Control Panel as `ballen`. It should refuse with a restriction message.

---

## Verification Toolkit

```cmd
gpupdate /force                          :: refresh both halves now
gpupdate /force /logoff                  :: for settings needing a new logon
gpresult /r                              :: summary
gpresult /r /scope:computer              :: computer half only
gpresult /h C:\gpreport.html /f          :: full HTML report - the useful one
```

The HTML report lists applied GPOs, denied GPOs, and the reason for each denial.

```powershell
Get-GPO -All | Select-Object DisplayName, GpoStatus, ModificationTime
Get-GPInheritance -Target 'OU=Workstations,OU=VBunnyLab,DC=vbunnylab,DC=local'
Get-GPOReport -Name 'VBunnyLab-Firewall-Baseline' -ReportType Html -Path C:\gpo.html
Backup-GPO -All -Path D:\GPOBackups
```

---

## Cleaning Up After Testing

Scoped test GPOs are the ones that get forgotten and cause confusion months later.

1. Restore **Authenticated Users** to Security Filtering, or unlink the GPO.
2. Remove test computers and users from the scope.
3. Delete anything genuinely temporary - an unlinked GPO still consumes SYSVOL and still shows in reports.
4. Record what changed in the GPO's **Comment** field.

---

## Lessons From These Labs

- **Password and lockout policy belong at the domain root.** Anywhere else applies to local accounts and reports as a success.
- **Security filtering needs `Domain Computers` to have Read**, or user policies silently fail. MS16-072.
- **"Applied" is not "working."** `gpresult` confirms the GPO was processed, not that it did what you intended. Verify the actual setting on the endpoint.
- **Back up before editing.** `Backup-GPO -All` takes a minute.
- **Name GPOs so the target is obvious.** `VBunnyLab-Workstations-Firewall-Baseline` beats `New Group Policy Object`.

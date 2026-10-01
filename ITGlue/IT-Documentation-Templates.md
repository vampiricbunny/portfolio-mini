# IT Documentation Templates

Fill-in templates for the things that need documenting. Use them in IT Glue, Hudu, SharePoint, a wiki, or anywhere else. The structure is what matters.

Sample values throughout use the lab environment from this repository so the fields make sense in context.

For the reasoning behind these, see [IT Documentation Standards](Documentation-Best-Practices.md).

---

## Server

```text
# Server: DC01

## Identification
Hostname            DC01
FQDN                dc01.vbunnylab.local
IP address          10.10.10.10 (static)
Location            Rack A2, server room
Make / model        Dell PowerEdge R450
Serial              [serial]
Warranty expires    [date]

## Configuration
Operating system    Windows Server 2025 Standard
Roles               AD DS, DNS, DHCP
CPU / RAM / Disk    4 vCPU / 16 GB / 200 GB
Virtual or physical Virtual (VMware)
Host                ESX01

## Purpose
Primary domain controller. Authentication, DNS and DHCP for the site.

## Dependencies
Depends on          ESX01, core switch, UPS-A
Depended on by      Every domain-joined device. Authentication fails without it.

## Access
Admin group         Domain Admins
Remote access       RDP via jump host only
Credentials         Stored in [vault reference]

## Backup
Method              Veeam, system state plus full VM
Schedule            Daily 22:00, weekly full Sunday
Retention           30 daily, 12 weekly
Last restore test   [date]

## Maintenance
Patch window        Second Sunday, 02:00 to 04:00
Reboot required     Yes, coordinate with the second DC
Notes               Never patch both DCs in the same window.

## Change history
[date] [who] [what changed and why]
```

**Dependencies and the restore test date are the two fields that get skipped and matter most.** One tells you what breaks. The other tells you whether the backup is real.

---

## Network Device

```text
# Firewall: FW-MAIN

## Identification
Hostname            FW-MAIN
Management IP       10.10.10.1
Make / model        Fortinet FortiGate 60F
Firmware            [version]
Serial              [serial]
Support expires     [date]
Location            Comms cabinet, ground floor

## Configuration
WAN                 [ISP], [circuit reference]
LAN                 10.10.10.0/24
VLANs               10 Data, 20 Voice, 30 Guest, 99 Management
DHCP                Relayed to DC01
VPN                 SSL VPN, [user group]

## Access
Management          HTTPS from management VLAN only
Admin accounts      [who]
MFA                 Enabled
Credentials         [vault reference]

## Key rules
Rule    Source      Destination   Service   Reason
1       LAN         WAN           Any       General outbound
2       Guest       WAN           HTTP/S    Guest internet, no LAN access
3       VPN         LAN           Any       Remote worker access

## Backup
Config backup       Weekly to [location]
Last backup         [date]

## Change history
[date] [who] [what and why]
```

**Record the reason for every firewall rule.** A rule with no explanation gets removed in a future cleanup and something breaks that nobody connects to it.

---

## Microsoft 365 Tenant

```text
# Tenant: vbunnylab.onmicrosoft.com

## Identification
Primary domain      vbunnylab.com
Onmicrosoft domain  vbunnylab.onmicrosoft.com
Tenant ID           [guid]
Admin portal        admin.microsoft.com

## Licensing
Subscription        Microsoft 365 Business Premium
Seats purchased     50
Seats assigned      43
Renewal date        [date]

## Administration
Global admins       [names, keep this short]
Break-glass         breakglass@vbunnylab.onmicrosoft.com
                    Excluded from all CA policies. Credentials in [physical location].
                    Sign-in alerting enabled.

## Identity
MFA                 Conditional access, not Security Defaults
CA policies         CA001 Require MFA all users
                    CA002 Block legacy authentication
                    CA003 Require compliant device
SSPR                Enabled, two methods, writeback on
Hybrid              Entra Connect, password hash sync
Connect server      [hostname]

## Mail
SPF                 v=spf1 include:spf.protection.outlook.com -all
DKIM                Enabled
DMARC               v=DMARC1; p=quarantine; rua=mailto:dmarc@vbunnylab.com
Connectors          [any]
Key transport rules [list with reasons]

## Shared mailboxes
support@vbunnylab.com       Members: [who]
accounts@vbunnylab.com      Members: [who]

## Notes
[anything unusual about this tenant]
```

**Break-glass detail belongs here, visible.** Exclusions from conditional access are the thing that saves the tenant when a policy locks everyone out, and nobody remembers them under pressure.

---

## Standard Operating Procedure

```text
# SOP: New Starter Onboarding

Owner           IT Service Desk
Last reviewed   [date]
Reviewed by     [who]

## When to use
HR raises a new starter ticket. Complete before the start date.

## Prerequisites
- Approved request with start date, job title and department
- Manager confirmed
- Hardware allocated

## Steps

1. Create the AD account
   - Copy from the role template, not from a colleague
   - OU matching the department
   - Temporary password, change at first logon

2. Group membership
   - Add to the department global group
   - Add role-specific groups per the access matrix
   - Nothing beyond what the role requires

3. Licensing
   - Add to the licensing group
   - Confirm the licence applied

4. Mailbox
   - Confirm it provisioned
   - Add to relevant distribution lists

5. Device
   - Confirm Autopilot enrollment
   - Confirm policies applied

6. MFA
   - Send the enrollment link
   - Confirm completion before the start date

## Verification
- Sign in as the user on a test device
- Confirm mail, drives and applications
- Confirm MFA prompts

## Rollback
Disable the account and remove group memberships.

## Escalate if
Licence unavailable, hardware not delivered, or access requested beyond the role matrix.
```

---

## Knowledge Article

```text
# Outlook crashes on launch, webmail works

Applies to      Windows, Outlook desktop
Last verified   [date]
Verified by     [who]

## Symptom
Outlook crashes immediately on launch. Outlook on the web works normally.

## Cause
Usually a third-party COM add-in. Occasionally a corrupt profile.

## Diagnosis
1. Win + R, run: outlook.exe /safe
2. Opens in safe mode means an add-in
3. Crashes in safe mode too means the profile or the install

## Resolution, add-in
1. File, Options, Add-ins
2. Manage: COM Add-ins, Go
3. Untick all, restart Outlook
4. Re-enable one at a time to identify which
5. Leave the culprit disabled, raise a ticket with the vendor

## Resolution, profile
1. Control Panel, Mail, Show Profiles
2. Add a new profile, configure the account
3. Set as default
4. Keep the old profile until confirmed working

## Verify
Outlook opens normally and sends a test message.

## Related
[link to Office repair article]
```

---

## Change Record

```text
# Change: Enable SMB signing on FILE01

Requested by    [who]
Approved by     [who]
Date            [date]
Risk            Medium
Ticket          CHG0042

## What
Enforce SMB signing on FILE01 via Group Policy.

## Why
Prevents SMB relay attacks. Security review finding.

## Impact
Older clients not supporting SMB2 signing will fail to connect.
Estate scanned. No affected clients found.

## Plan
1. Apply to a pilot group, verify
2. Apply to all workstations
3. Apply to servers during the maintenance window

## Rollback
Set the GPO setting to Not Configured and run gpupdate /force.

## Verification
Get-SmbServerConfiguration on FILE01, confirm RequireSecuritySignature is True.
Confirm clients still connect.

## Outcome
[what actually happened, including anything unexpected]
```

**The outcome field is the one people leave blank.** It is also the only part that helps next time. Record what actually happened, especially if it differed from the plan.

---

## Using These

- Fill in every field, or write "not applicable" and say why. A blank field is ambiguous
- Date and attribute everything
- Link related documents to each other
- Review on a schedule
- Update as part of doing the work, not afterwards

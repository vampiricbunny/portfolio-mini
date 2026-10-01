# HaloPSA

Working tickets in HaloPSA, the PSA platform used by a lot of Managed Service Providers.

The difference from a pure ticketing tool is scope. HaloPSA carries ticketing, asset management, time tracking, contracts and billing in one place. In an MSP, the time you log against a ticket is what gets invoiced, so the ticket is a billing record as well as a work record.

---

## MSP vs Internal IT

Working a queue at an MSP differs from internal IT in ways that change how you work.

| | Internal IT | MSP |
| --- | --- | --- |
| Users | One organisation | Many clients |
| Context | You know the environment | You need to check which client first |
| Time tracking | Rarely enforced | Billable, so it is mandatory |
| SLA | Internal target | Contractual, with penalties |
| Documentation | Helpful | Essential. You will not remember 40 environments |

**Always confirm which client the ticket belongs to before you touch anything.** Applying a fix to the wrong client's environment is the one mistake with real consequences. Client names look similar, and tabs get mixed up.

---

## The Dashboard

| Area | Holds |
| --- | --- |
| **Service Desk** | Ticket queues and views |
| **Assets** | Client hardware and software |
| **Clients** | Sites, contacts, contracts |
| **Knowledge Base** | Articles, per client and global |
| **Reporting** | SLA, time, ticket volume |
| **Quotes and Invoices** | Commercial side |

Filter the queue by team first. On a busy MSP board the unfiltered view is unusable.

---

## Ticket Structure

| Field | Purpose |
| --- | --- |
| **Client** | Which organisation. Check this first |
| **Site** | Which location |
| **User** | Who reported it |
| **Ticket type** | Incident, request, change, project |
| **Category** | Drives routing and reporting |
| **Priority** | From impact and urgency, against the SLA |
| **Agent** | Who owns it |
| **Team** | Which queue |
| **Asset** | Which device, if known |

**Linking the asset matters.** It builds a history against that machine. A laptop with five tickets in three months is a replacement candidate, and the asset record is what proves it.

---

## Working a Ticket

### Pick It Up

Assign to yourself. Set status to In Progress.

Check the client's contract and SLA before you start. MSP SLAs vary by client, so a P2 for one may be a four hour target and eight for another.

### Acknowledge

Respond quickly. In most configurations this stops the response clock, and where the SLA is contractual that clock has money attached.

```text
Hi Sarah,

Thanks for getting in touch. I've picked up your ticket about the shared
calendar and I'm looking at it now. I'll come back to you shortly.

Barry
Service Desk
```

### Check History First

**Search before you troubleshoot.** Someone has probably seen it before, possibly at this client.

Check:

- Previous tickets for this client
- Previous tickets against this asset
- Client-specific knowledge base articles
- Global knowledge base

At an MSP this is the single biggest time saver. Forty environments means you cannot hold the detail, and the documentation is what replaces memory.

### Log Time As You Go

Time entries are billable. Log as you work, not at the end of the day from memory.

Each entry needs:

- Duration
- What you did
- Billable or not

Reconstructed timesheets are inaccurate in both directions. Under-logging loses revenue, over-logging is a conversation with the client nobody wants.

### Notes

| Field | Who sees it |
| --- | --- |
| **Public note** | The end user |
| **Private note** | Agents only |

Same rule as any ticketing system. Check which one you are in.

Private notes carry the technical detail. Public notes stay in plain language.

---

## Worked Examples

### Shared Calendar Not Visible

**Reported:** Cannot see a colleague's shared calendar.

**Checked:** Previous tickets for this client. Nothing similar.

**Actions:** Remote session with permission. The calendar had been shared with the wrong permission level, set to Availability only rather than Details.

**Fix:** Owner reshared with the right level. Walked the user through it so they can do it next time.

**Close:** Private note with the cause. Public note with the steps. Time logged, 15 minutes billable. Resolved.

### Outlook Not Opening, Password Expired

**Reported:** Outlook will not open. Pre-assigned by another agent.

**Diagnosis:** Domain password had expired. Outlook was failing on authentication rather than crashing.

**Fix:** Verified identity. Reset the password, set change at next logon. User signed in and Outlook connected.

**Close:** Public note explaining the cause, since "Outlook is broken" and "your password expired" look identical to a user. Private note with the reset. Time logged. Resolved.

### Cannot Reach the H: Drive

**Reported:** Phoned in. No shared folder on H:.

Phoned-in tickets still get raised. Nothing untracked.

**Diagnosis:** The drive map had not applied. The user had been moved to a different OU during a restructure and the GPO targeted the old one.

**Fix:** Corrected the item-level targeting on the drive map GPO, which fixed everyone affected rather than just the caller.

**Close:** Raised a problem ticket, because others in that OU would hit the same thing. Private note with the GPO detail and a link to the client's documentation. Resolved.

### Printer Stopped Printing

**Reported:** Printer not printing.

**Diagnosis:** Remote session. Jobs queued and not clearing. Spooler stuck.

**Fix:**

```powershell
Stop-Service Spooler
Remove-Item "$env:SystemRoot\System32\spool\PRINTERS\*" -Force
Start-Service Spooler
```

Also corrected the default tray, which had been set to a tray with no paper.

**Close:** Emailed the user with what caused it and what to try first next time. Private note with timestamps. Time logged. Resolved.

---

## Assets

HaloPSA holds client hardware and software, usually fed from an RMM.

Useful because:

- Ticket history per device shows what should be replaced
- Warranty dates are on the record
- Specifications are there without asking the user
- Software inventory answers licensing questions

Link the asset on every ticket where a specific device is involved. It takes two seconds and it builds the history that makes the next decision easy.

---

## Knowledge Base

Two levels, and both matter.

**Client-specific.** How that client's environment is set up. Server names, share paths, quirks, who authorises what.

**Global.** Generic fixes that apply anywhere.

At an MSP the client-specific documentation is what makes the service desk work. Nobody remembers that one client's file server is called something unexpected and their VPN needs a particular setting. Write it down and everyone benefits.

Write the article the second time you see an issue.

---

## SLA and Escalation

SLAs are contractual. Breaching them can cost the business money or a client.

Escalate on:

- Approaching the SLA threshold with no progress
- Needing rights you do not have
- Anything outside your tier
- Anything affecting multiple users at a client

Include in the handover: client, what was reported, what you tested, what you ruled out, and where it stands.

---

## Practices

- Confirm the client before doing anything
- Search history before troubleshooting
- Log time as you work
- Link the asset
- Private notes technical, public notes plain
- Check the client's specific SLA, not a general one
- Write client documentation as you learn it
- Raise a problem ticket when the same issue recurs across users
- Confirm with the user before resolving

# Ticketing Best Practices

How to write and work a ticket so it holds up. Applies to ServiceNow, Zendesk, HaloPSA, HubSpot or anything else.

One rule underneath all of it. **A ticket is a technical timeline, not a receipt.** Someone reading it six months later, with no context, should be able to follow what happened and why.

---

## Opening

Capture these before you start work.

| Field | Detail |
| --- | --- |
| **Reported issue** | Their words, not your interpretation |
| **Exact error** | Verbatim, including the code |
| **When it started** | Date and time if known |
| **Scope** | One user, one machine, or many |
| **What changed** | New device, password change, recent update |
| **Business impact** | Blocked completely, or working around it |

**Record their words first, then your interpretation.** "Email is broken" and "Outlook desktop crashes on launch, webmail works" are different tickets. Overwriting what they said loses information you may need later.

**Scope decides everything.** One user on one machine is local. Everyone on one floor is infrastructure. That question routes the ticket correctly and saves an hour of looking in the wrong place.

---

## Writing Notes

### Timestamp Everything

```text
09:14  Ticket received. User reports Outlook crashes on launch,
       webmail confirmed working.
09:18  Acknowledged, offered webmail as an interim workaround.
09:25  Remote session started with permission.
09:27  outlook.exe /safe opens successfully. Points to an add-in.
09:31  Disabled all COM add-ins. Outlook opens normally.
09:38  Re-enabled individually. Adobe Acrobat add-in reproduces the crash.
09:41  Left disabled. Confirmed working with user.
09:44  User confirmed. Resolution notes added, resolving.
```

Anyone can follow that. They can see what was tested, in what order, and how the conclusion was reached.

### Record What Passed

This is the habit that separates a useful ticket from a thin one.

```text
09:52  DNS resolves correctly from the client (tested).
09:53  Gateway reachable, 0% loss (tested).
09:55  Port 445 open to FILE01 (tested).
09:58  Fault is permissions, not connectivity.
```

Somebody picking this up later does not repeat that work. Notes that only list what failed make the next person start from nothing.

### Be Specific

| Instead of | Write |
| --- | --- |
| Still troubleshooting | Checking Exchange message trace for the last 48 hours |
| Tried a few things | Cleared DNS cache, renewed DHCP lease, restarted adapter. No change |
| User issue | User was entering the old password. Confirmed by checking pwdLastSet |
| Fixed | Restarted the spooler and cleared the spool directory. Test page printed |
| Will look into it | Will check the firewall logs after 14:00 when I have access |

### Update As You Go

For anything long-running, every 15 to 30 minutes. Timestamps and specifics.

Write notes at the time, not at the end of the day from memory. Reconstructed notes are wrong in ways you cannot detect afterwards.

---

## Internal vs Customer-Visible

Every ticketing system has both. They look similar and it is easy to type in the wrong one.

| | Use for |
| --- | --- |
| **Internal** | Commands, output, what you ruled out, reasoning |
| **Customer-visible** | Plain language, what it means for them, what you need |

**Check which field you are in before typing.** Technical detail, or frustration, pasted into a customer-visible field goes straight to their inbox.

---

## Status

Use them honestly.

| Status | Means |
| --- | --- |
| **New** | Nobody has picked it up |
| **In Progress** | Actively being worked |
| **Awaiting User** | Genuinely waiting on them |
| **Awaiting Third Party** | Waiting on a vendor or another team |
| **Resolved** | Fixed, user confirmed |
| **Closed** | Archived |

**Awaiting User means waiting on the user.** Most systems pause the SLA clock on that status. Using it while you are the blocker inflates your numbers, and it is visible to anyone who reads the ticket.

Review your Awaiting User queue weekly. Tickets parked waiting on someone who never replied sit there forever otherwise.

---

## Priority

Set from impact and urgency, honestly.

| | High | Medium | Low |
| --- | --- | --- | --- |
| **High impact** | P1 | P2 | P3 |
| **Medium impact** | P2 | P3 | P4 |
| **Low impact** | P3 | P4 | P5 |

Every user believes their issue is urgent. One person unable to print is not the same as a department unable to work.

**Marking everything high means nothing is high.** The queue stops meaning anything and real P1s get lost in it.

---

## Closing

Before you resolve:

1. **Confirm with the user.** Ask. Do not assume
2. **Write resolution notes** that would help a stranger
3. **Set the resolution code** correctly, since reporting depends on it
4. **Consider a knowledge article** if it will recur
5. **Raise a problem ticket** if this is the same issue again

### Resolution Notes

**Bad:** "Fixed."

**Also bad:** "Restarted it and it works now."

**Good:**

```text
Cause: Adobe Acrobat COM add-in conflicting with Outlook after the
December Office update.

Diagnosis: outlook.exe /safe opened successfully, confirming an add-in
rather than a profile fault. Disabled all COM add-ins, re-enabled
individually to identify.

Fix: Acrobat add-in disabled. Raised CHG0088 to test the updated
version before re-enabling estate-wide.

Verified: User confirmed Outlook opens and sends normally at 09:44.
```

Cause, diagnosis, fix, verification. That is the shape.

---

## Escalation

Escalate when it needs rights you do not have, it is outside your team, you have hit the SLA threshold, or it affects many users and you have no cause.

Include:

- What the user reported
- What you tested, **including what passed**
- What you ruled out and why
- Current status and your best guess at the next step
- Anything the user has been told

**A good escalation means the next person does not start over.** A bad one just moves the ticket and restarts the clock, and the user repeats their whole story.

Stay on tickets you escalated. They are still yours until somebody else picks them up properly.

---

## Why This Matters

Beyond doing the job well.

- **Reporting depends on it.** Ticket data is what justifies headcount and tooling
- **Problem management needs it.** You cannot spot a pattern in vague notes
- **Audits ask for it.** Access changes and security events need a record
- **Handover depends on it.** Holiday, illness, leaving
- **It is evidence.** After an incident, the ticket record is what gets examined

And practically: managers read tickets. Clear, specific, well-timestamped notes are one of the most visible signals of how someone works.

---

## Checklist

- [ ] Their words captured before your interpretation
- [ ] Exact error text recorded
- [ ] Scope established
- [ ] Assigned to yourself before starting
- [ ] Acknowledged quickly
- [ ] Timestamped updates as you work
- [ ] What passed recorded, not just what failed
- [ ] Internal and customer-visible used correctly
- [ ] Status honest
- [ ] User confirmed before resolving
- [ ] Resolution notes: cause, diagnosis, fix, verification
- [ ] Knowledge article if it will recur
- [ ] Problem ticket if it already has

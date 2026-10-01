# Zendesk

Working a queue in Zendesk. Ticket structure, views, macros, triggers and automations.

Zendesk started as a customer support platform and is widely used for internal IT. It is lighter than ServiceNow and quicker to configure, which suits smaller teams.

---

## Ticket Anatomy

| Field | Purpose |
| --- | --- |
| **Requester** | Who raised it |
| **Assignee** | Who owns it |
| **Group** | Which team |
| **Type** | Question, Incident, Problem, Task |
| **Priority** | Low, Normal, High, Urgent |
| **Tags** | Free-form labels, used heavily for reporting and automation |
| **Status** | New, Open, Pending, On-hold, Solved, Closed |

### Types

| Type | Use |
| --- | --- |
| **Question** | User wants to know something |
| **Incident** | Something broken. Can be linked to a Problem |
| **Problem** | Underlying cause of several incidents |
| **Task** | Work with a due date, such as onboarding |

**Linking incidents to a problem is the feature worth using.** Solve the problem and every linked incident closes with a notification. Fifteen tickets about the same outage become one fix.

### Status

| Status | Means | Clock |
| --- | --- | --- |
| **New** | Not picked up | Running |
| **Open** | Being worked | Running |
| **Pending** | Waiting on the requester | Paused |
| **On-hold** | Waiting on a third party | Usually paused |
| **Solved** | Fixed, awaiting closure | Stopped |
| **Closed** | Archived. Cannot be reopened | Stopped |

**Pending means waiting on the user.** Not waiting on you. Using it to stop the SLA clock while you are still the blocker is obvious in reporting and it distorts the numbers everyone relies on.

**Closed is permanent.** Once closed, a ticket cannot be reopened. A follow-up creates a linked ticket instead. Most teams let Zendesk auto-close solved tickets after a few days.

---

## Public Reply vs Internal Note

The most important distinction in the interface.

| | Who sees it |
| --- | --- |
| **Public reply** | The requester, by email |
| **Internal note** | Agents only |

They look almost identical and the internal note is a different colour. **Check before you type.** Technical notes or frustration pasted into a public reply goes straight to the user's inbox.

Internal notes are for what you tried, what you found, and why you did what you did. Public replies are plain language for the user.

---

## Views

Views are saved filters and they are what makes a queue manageable.

Worth having:

| View | Filter |
| --- | --- |
| My open tickets | Assignee is me, status Open |
| Unassigned in my group | Group is mine, no assignee |
| Overdue | SLA breached |
| Pending too long | Pending, updated over 3 days ago |
| Recently solved | Solved in the last 7 days |

**"Pending too long" is the one people skip.** Tickets parked awaiting a user reply sit there forever if nobody looks. A weekly sweep either nudges them or closes them.

---

## Macros

Predefined responses that can also set fields. Your biggest time saver.

A macro can write a reply, set type and priority, add tags, assign a group and change status in one click.

Useful macros:

- Acknowledgement, "I've picked this up and I'm looking into it"
- Password reset completed, with instructions
- Awaiting user response, with status set to Pending
- Escalation to Tier 2, with group reassignment
- Solved, with a closing message

**Write macros as a starting point, not a finished reply.** A macro fired verbatim with no personalisation reads like a bot, and users can tell. Fire the macro, then add a line specific to their issue.

---

## Triggers and Automations

| | Fires when |
| --- | --- |
| **Trigger** | A ticket is created or updated. Immediate |
| **Automation** | Time passes. Runs hourly |

Triggers handle routing and notification. Automations handle chasing and cleanup.

Worth having:

**Triggers**

- Auto-acknowledge new tickets
- Route by tag or requester group
- Notify the assignee on a public reply
- Escalate urgent tickets to a group immediately

**Automations**

- Nudge after 3 days in Pending
- Close after 7 days in Pending with no reply
- Alert on tickets approaching SLA breach
- Auto-close solved tickets after 4 days

**Automations run hourly, not instantly.** Anything that must happen immediately needs a trigger.

---

## Worked Examples

### Account Lockout

**Reported:** Locked out after too many attempts.

**Actions:** Assigned to self, acknowledged via public reply. Verified identity. Unlocked in ADUC.

```powershell
Search-ADAccount -LockedOut | Select-Object Name, SamAccountName
Unlock-ADAccount -Identity ballen
```

**Root cause:** Event 4740 on the PDC emulator pointed to a phone with a saved old password. Told the user to update it, or it locks again within the hour.

**Close:** Internal note with the source machine. Public reply explaining the cause. Solved.

Unlocking without finding the source just means the same ticket tomorrow.

### Machine Off the Domain

**Reported:** Cannot sign in. Trust relationship error.

**Actions:** Set type Task, priority High. Remoted in with a local admin account.

```powershell
Test-ComputerSecureChannel -Repair -Credential (Get-Credential)
```

Repaired without rejoining, which kept the computer object and its group memberships.

**Close:** Confirmed the user could sign in. Internal note recording that the machine had been restored from an old image, which is why it happened. Solved.

### Printer Not Printing

**Reported:** Printer stopped working.

**Actions:** Acknowledged. Checked whether it was one user or everyone, which decides where to work. One user, so it was client-side.

```powershell
Stop-Service Spooler
Remove-Item "$env:SystemRoot\System32\spool\PRINTERS\*" -Force
Start-Service Spooler
```

Tested a print job with the user watching.

**Close:** User confirmed. Internal note with the steps. Public reply explaining what happened in plain terms. Solved.

### Onboarding Task

**Reported:** Manager raised a task for a new starter beginning in a week.

Type Task, priority Low, due date set to the day before they start. Low priority because nothing is broken, but the due date is real.

**Actions:** Created the account, added to groups, assigned the licence, set up the mailbox, prepared the machine.

**Close:** Emailed the manager to confirm. Internal note listing exactly what was created, which matters later for offboarding. Solved.

---

## Knowledge Base

**Guide** is the knowledge base. Articles can be internal-only or published for self-service.

Write an article whenever you solve something for the second time.

Structure:

- Title using the words a user would search for
- The symptom
- The cause
- The steps
- How to confirm it worked

Link the article from the macro that handles that issue. The user gets the answer and the article gets used.

---

## Reporting

**Explore** holds the reporting.

Worth watching:

- First reply time against SLA
- Full resolution time
- Ticket volume by type and tag
- Reopen rate
- Backlog trend

**Reopen rate is the honest metric.** A fast resolution time with a high reopen rate means tickets are being closed before they are fixed.

Tags are what make reporting useful. Tag consistently, or the data is noise.

---

## Practices

- Assign to yourself before starting
- Acknowledge quickly, even with a macro
- Check public reply against internal note before typing
- Pending only when genuinely waiting on the user
- Link incidents to a problem when the same thing keeps arriving
- Tag consistently
- Confirm with the user before solving
- Internal note explaining the cause, not just the fix
- Write the article the second time you see something
- Review your Pending queue weekly

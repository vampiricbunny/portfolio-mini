# HubSpot Service Hub

Ticketing in HubSpot. Pipelines, views, SLAs and the workflows that do the routing for you.

HubSpot is a CRM first. The ticketing sits inside Service Hub, and its advantage is context. Open a ticket and the full history with that person is on the right of the screen. Past conversations, previous tickets, which company they belong to.

That suits a support desk with external customers more than an internal IT team, though plenty of small companies run internal support on it.

---

## Pipelines and Stages

A pipeline is the path a ticket takes. The default is simple.

| Stage | Means |
| --- | --- |
| **New** | Arrived, unassigned |
| **Waiting on contact** | Waiting on the customer |
| **Waiting on us** | Our turn |
| **Closed** | Done |

Most teams add stages. A workable set:

```text
New -> In Progress -> Waiting on Contact -> Escalated -> Resolved -> Closed
```

**Keep pipelines short.** A twelve stage pipeline sounds precise and in practice nobody moves tickets through it accurately, so the reporting is fiction.

Separate pipelines for genuinely different work. One for IT support, one for onboarding requests, if the steps differ.

---

## Views

Views are saved filters. Build these first.

| View | Filter |
| --- | --- |
| **Unassigned** | No owner. Check this constantly |
| **Assigned to me** | Owner is me, not closed |
| **Overdue** | SLA breached |
| **Waiting on contact, stale** | That status, last activity over 3 days |
| **High priority open** | Priority High, not closed |

**The unassigned view is the one that matters.** A ticket nobody has claimed is a ticket nobody is working, and the SLA clock is running on it.

The stale view catches tickets parked waiting on a customer who never replied. They sit indefinitely otherwise.

---

## Working a Ticket

### Claim It

Set **Ticket owner** to yourself. That moves it out of Unassigned and stops two people working the same thing.

### Read the Context First

The CRM panel on the right shows the contact, their company, past tickets and previous conversations.

**Check it before replying.** Someone reporting the same problem for the third time should not be asked the same opening questions. It is also the fastest way to spot that an issue is recurring rather than new.

### Reply

The editor handles email, notes and calls.

| Tab | Who sees it |
| --- | --- |
| **Email** | The contact |
| **Note** | Internal only |
| **Call** | Log a phone conversation |

**Snippets** are short reusable blocks, inserted with a shortcut. Good for standard paragraphs.

**Templates** are full emails. Good for acknowledgements and standard responses.

Acknowledge quickly. A template does it in one click and it stops the first response clock.

```text
Hi {{contact.firstname}},

Thanks for getting in touch. I've picked up your ticket and I'm looking
into it now. Your reference is #{{ticket.id}}.

I'll update you shortly.
```

Personalise after inserting. A template sent untouched reads like an autoresponder.

### Status Honestly

**Waiting on contact** means you are genuinely waiting on them. **Waiting on us** means it is your turn.

Most SLA configurations pause on "Waiting on contact". Using it while you are actually the blocker inflates your numbers and everyone can see it in the reporting.

### Escalate

1. Add an internal **Note** covering what you tried, what you found, what you ruled out.
2. Change **Ticket owner** to the Tier 2 agent.
3. Move the stage to Escalated.

The note is the important part. Reassigning a ticket with no notes means the next person starts from nothing and the customer repeats themselves.

### Close

1. Confirm with the customer that it is fixed.
2. Fill in the closing properties. Resolution type, root cause.
3. Move to Closed.

Those closing properties are what make reporting useful later. Skipping them means you cannot answer "what are we spending most of our time on".

---

## Ticket Sources

| Source | How |
| --- | --- |
| **Email** | Mail to the connected support address creates a ticket |
| **Forms** | A support form on the website |
| **Live chat** | Conversation converts to a ticket |
| **Manual** | Phone call or walk-up, created by the agent |
| **API** | From another system |

**Log phone calls and walk-ups as tickets.** Untracked work is invisible. It does not appear in volume reporting, which means the team looks less busy than it is when headcount is being discussed.

---

## Automation

**Workflows** are HubSpot's automation. They fire on ticket creation or property changes.

Worth building:

- Auto-acknowledge on creation
- Route by category, so hardware goes to one owner and access requests to another
- Notify the owner when a customer replies
- Escalate when priority is set to High
- Nudge the owner when a ticket sits in Waiting on us
- Close automatically after 5 days in Waiting on contact with no reply

That last one keeps the board honest. Tickets waiting on a customer who has moved on otherwise accumulate forever.

---

## SLAs

Service Hub tracks two targets.

| Target | Measures |
| --- | --- |
| **Time to first response** | How long until the customer hears back |
| **Time to close** | How long until resolved |

Configure per priority. High priority gets a shorter target.

The SLA timer shows on the ticket. Acknowledging early is the easiest way to keep first response healthy, which is why the acknowledgement template earns its keep.

---

## Knowledge Base

Service Hub includes a knowledge base that can be public or private.

Link articles directly into replies. The customer gets the answer and the article gets traffic, which shows you which ones are actually useful.

Write an article the second time you answer the same question.

---

## Reporting

Service Hub reporting covers:

- Ticket volume by source, category and owner
- Average first response and resolution time
- SLA attainment
- Reopened tickets
- Customer satisfaction, where surveys are enabled

**Reopen rate is the metric that tells the truth.** Fast closure with frequent reopens means tickets are being closed before they are fixed.

Accurate closing properties are what make any of this meaningful. Garbage in the fields means garbage in the reports.

---

## Practices

- Claim the ticket before starting
- Read the CRM history first
- Acknowledge with a template, then personalise
- Status honestly. Waiting on contact means waiting on them
- Notes before reassigning, always
- Log phone and walk-up work as tickets
- Fill in closing properties
- Keep the pipeline short enough that people actually use it
- Review the unassigned and stale views daily

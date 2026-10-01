# IT Documentation Standards

How to structure IT documentation so it is worth having. Written around the IT Glue model, because it is the structure most MSPs converge on, but the principles apply to any platform including a well-organised SharePoint site or a wiki.

**Scope note.** This covers documentation structure and practice rather than a walkthrough of a specific product's interface. The structure is the transferable part. Every documentation platform does the same job with different menus.

---

## Why It Matters

Documentation is the difference between a team and a set of individuals who each know different things.

- A ticket that took two hours the first time takes ten minutes the second
- Someone on holiday is not a blocker
- Staff leaving does not take the environment's knowledge with them
- Onboarding a new technician takes days rather than months
- Audit questions have answers

The failure mode is documentation that exists but is out of date. That is worse than none, because people trust it and act on it.

---

## Structure

Four categories cover most of what needs documenting.

### 1. Assets

**Network devices**

- Firewalls, with model, firmware and management address
- Switches, with VLAN configuration
- Routers and VPN appliances
- Wireless access points and controllers

**Servers**

- Domain controllers
- File servers
- Application and database servers
- Virtualisation hosts
- Backup servers

**Endpoints**

- Workstations and laptops, usually synced from an RMM
- Mobile devices
- Printers and scanners

For each asset, record what somebody would need at 2am:

| Field | Why |
| --- | --- |
| Hostname and IP | Finding it |
| Make, model, serial | Warranty and support calls |
| Location | Physical access |
| Purpose | Whether it can be restarted |
| Owner | Who authorises changes |
| Warranty expiry | Budget and support eligibility |
| Dependencies | What breaks if it goes down |

**Dependencies are the field people skip and later wish they had.** Knowing that the accounting application depends on a specific server changes how you handle a restart request.

### 2. Configurations

How things are set up, and why.

- Network topology and addressing plan
- VLANs and their purpose
- Firewall rules and the reason each exists
- DNS zones and key records
- DHCP scopes, reservations, exclusions
- Backup jobs, schedules and retention
- Group Policy, what applies where
- Microsoft 365 tenant configuration

**Record the reason, not just the setting.** A firewall rule with no explanation gets removed during a cleanup two years later, and something breaks that nobody connects to it.

### 3. Procedures

Step-by-step for anything done more than once.

- New starter onboarding
- Leaver offboarding
- Password and MFA reset, including identity verification
- Backup restore, tested
- Server patching
- Disaster recovery
- Escalation paths and contacts

Write for someone who has not done it before. A procedure that only makes sense to the person who wrote it is a personal note, not documentation.

### 4. Knowledge

Solutions to problems that recurred.

- The symptom, in the words a user would use
- The cause
- The steps
- How to confirm it worked

Write it the second time you see something. The first time you might not need it again. The second time means you will.

---

## Credentials

Documentation platforms store passwords. That makes them high-value targets.

| Practice | Why |
| --- | --- |
| MFA on every account | The platform holds keys to everything |
| Role-based access | Not everyone needs every client's credentials |
| Audit logging on | Who viewed what, and when |
| Rotate on staff departure | Anything they could see is compromised |
| Never store in plain text fields | Use the credential vault, not a note |
| Link credentials to assets | So the relationship is clear |

**A documentation platform with weak access control is a single point of total compromise.** Everything needed to administer the environment, in one place, behind one login.

Some credentials should not be in there at all. Domain admin and break-glass accounts belong in a sealed physical envelope or a dedicated privileged access system, not in general documentation.

---

## Keeping It Current

The hard part. Documentation decays quietly.

**Document as you work.** Changing a firewall rule and updating the documentation is one task. Coming back to it later is two, and the second never happens.

**Make it part of the change process.** A change is not complete until the documentation reflects it.

**Automate what you can.** Assets synced from an RMM stay accurate without effort. Manual asset lists are wrong within months.

**Review on a schedule.** Quarterly for critical documentation. Check what has changed, remove what is gone, flag what is unverified.

**Date and attribute everything.** Who wrote it, when, and when it was last verified. A procedure with no date carries no signal about whether to trust it.

**Test the procedures.** A restore procedure nobody has run is a theory. Run it.

---

## Writing It

A few things that make documentation usable.

**Write for the next person, not for yourself.** Assume no context. The reader is stressed, it is out of hours, and they have never seen this system.

**Use the words users use.** An article titled "Outlook won't open" gets found. "MAPI profile corruption remediation" does not.

**Screenshots where the interface is not obvious**, but be aware they age badly. Interfaces change and a screenshot from two versions ago is confusing rather than helpful. Text instructions age better.

**Link related documents.** A server record should link to its backup job, its restore procedure and its dependencies.

**Say what you do not know.** Marking something unverified is more useful than implying it is confirmed.

**Keep one source of truth.** The same information in three places means two of them are wrong and nobody knows which.

---

## What Good Looks Like

A new technician should be able to:

- Find any managed asset in under a minute
- Understand what it does and what depends on it
- Follow a procedure without asking anyone
- See when the information was last verified
- Know who to escalate to

If any of those fail, the documentation is not doing its job yet.

---

## Common Failures

| Problem | Result |
| --- | --- |
| Out of date | Worse than none. People act on it |
| Written for the author | Unusable by anyone else |
| No dates or ownership | No way to judge whether to trust it |
| Credentials in plain text | One compromise reaches everything |
| Duplicated across systems | Nobody knows which copy is right |
| Never tested | Procedures that do not work when needed |
| No structure | Information exists but cannot be found |

---

## Related

- [IT Documentation Templates](IT-Documentation-Templates.md) for the structures to fill in
- [Ticketing Best Practices](../CustomerService/Ticketing-Best-Practices.md) for ticket-level documentation

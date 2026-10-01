# Communicating With Users

How to talk to people about technical problems. Templates, tone, and the security rules that apply to support communication.

Technical skill gets the ticket fixed. Communication decides whether the user feels helped or handled. Both get noticed.

---

## The Basics

**Identify yourself.** Name, team, ticket reference. Every time.

**Say what you are doing and why.** In plain language. "I'm checking whether your account is locked" beats "I'm querying AD".

**Set expectations.** If it will take an hour, say an hour. Silence is worse than bad news.

**Never blame the user.** Even when they caused it. "Let's get that sorted" works. "You shouldn't have clicked that" does not, and it guarantees they will not report the next one.

**Confirm before closing.** Ask them. Do not assume.

---

## Jargon

The single biggest improvement most technicians can make.

| Instead of | Say |
| --- | --- |
| Your AD account is locked | Your account is locked after too many sign-in attempts |
| The GPO didn't apply | The setting didn't reach your machine |
| DNS isn't resolving | Your computer can't find the server by name |
| Your profile is corrupt | Your Windows settings need rebuilding |
| I'll escalate to L2 | I'm passing this to a specialist who can go further |
| It's a known issue | Microsoft has confirmed this affects several customers |

Explaining in plain terms is not talking down. It is the harder skill, and it is the one users notice.

---

## Email Templates

### Acknowledgement

```text
Subject: Re: [their subject] [#INC0042]

Hi Sarah,

Thanks for getting in touch. I've picked up your ticket about Outlook
not opening and I'm looking into it now.

I'll come back to you within the hour with an update.

Barry
IT Service Desk
```

Two lines. Send it immediately. It stops the SLA clock and it stops the user wondering whether anyone saw their message.

### Account Unlocked

```text
Hi James,

Your account is unlocked and you should be able to sign in with your
usual password.

Worth knowing: this can happen when a phone or tablet still has an old
password saved. If it locks again shortly, that's usually the cause and
I can help you track it down.

Let me know how you get on.

Barry
IT Service Desk
```

Explaining the likely cause prevents the repeat ticket.

### Password Reset

```text
Hi Lisa,

I've reset your password as requested. I'll call you on the number we
have on file to pass it across.

You'll be asked to change it when you first sign in.

Barry
IT Service Desk
```

**Never put a password in an email.** It sits in their inbox, their sent items, the mail server, and any backup of all three. Pass it by phone, in person, through a secure channel, or use a one-time link that expires.

That single habit is one of the clearest signals of whether someone has been trained properly.

### Waiting on the User

```text
Hi Sarah,

I've tried the steps on my side and I need a bit more from you to
continue.

Could you let me know:
- The exact wording of the error message
- Roughly when it started
- Whether it happens on other machines

Once I have that I can pick it straight back up.

Barry
```

Specific questions get specific answers. "Can you give me more detail" gets nothing useful.

### Escalating

```text
Hi Sarah,

I've passed your ticket to our infrastructure team. They have access
to the server side, which is where this needs to be looked at.

Everything I've tested so far is on the ticket so you won't need to
repeat yourself.

They'll be in touch. Your reference is still #INC0042.

Barry
```

Telling them they will not have to repeat themselves matters. Repeating the whole story to a second person is the most common support complaint there is.

### Resolved

```text
Hi Sarah,

Outlook should be working now. The cause was an add-in conflicting with
it after a recent update, so I've disabled that one.

Everything else is unaffected and you shouldn't notice any difference.

Could you confirm it's working before I close the ticket?

Barry
```

Ask for confirmation. Do not close and hope.

---

## Chat and Ticket Comments

Shorter, faster, same principles.

```text
Hi John, this is Barry from IT Support. I've picked up your ticket and
I'm looking at it now.

Checking your account, one moment.

I can see the issue. Your account locked at 09:14 after several
failed sign-ins. Unlocking it now.

Done. Can you try signing in?
```

**Update every few minutes on anything long-running.** Silence reads as nothing happening, even when you are working hard.

Break instructions into single steps and wait for each. A wall of eight steps produces a reply saying it did not work, with no way to know which step failed.

---

## Difficult Moments

### They Are Frustrated

Acknowledge it once, then move to the fix. Do not over-apologise, and do not get defensive.

```text
That sounds genuinely frustrating, especially with a deadline today.
Let me get straight into it.
```

Covered further in [Handling Difficult Situations](Handling-Difficult-Customers.md).

### You Do Not Know

Say so. Then say what you will do.

```text
I'm not certain what's causing that yet. Give me fifteen minutes to
check a couple of things and I'll come back either with an answer or
with who can help.
```

Users respect honesty. They do not respect confident guessing that turns out wrong.

### They Caused It

Never say so.

```text
That's a common one, easily sorted.
```

Fix it. If it is a pattern, address it through training, not through the ticket.

### You Have To Say No

Explain, then offer what you can.

```text
I'm not able to give admin rights on the laptop, that's set by policy
across the organisation.

What I can do is install the software for you, or raise a request with
your manager if there's an ongoing need.
```

---

## Security in Support Communication

This is where communication and security overlap, and it is worth knowing well.

**Verify identity before any reset.** Call back on the number in the HR record. Never a number the caller provides. A reset done for the wrong person hands over the account.

**Never send credentials by email.**

**Never ask a user for their password.** You do not need it. Asking teaches them it is normal, which is exactly what phishing relies on.

**Be predictable.** Users should be able to tell a real support contact from a fake one. That means consistent channels, ticket references, and never cold-calling to ask someone to install remote access software.

**Support a suspicious user.** Someone who refuses to act until they have verified you is doing the right thing. Encourage the callback. Never make them feel awkward about it.

**Pressure is a signal.** A caller who resists verification, invokes urgency, or claims to be an executive in a hurry is running the standard social engineering pattern. Slow down rather than speed up.

**Record how identity was verified**, not just that it was.

---

## Before You Send

- Right person, right ticket
- Are you in the customer-visible field or the internal one
- No credentials in the message
- No jargon left unexplained
- Clear next step, or a clear ask
- Read it back. Would you want to receive it

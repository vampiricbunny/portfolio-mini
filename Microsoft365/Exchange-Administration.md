# Exchange Online Administration

Mailboxes, mail flow, message tracing and the security settings that decide whether your domain can be spoofed.

Most email tickets come down to one question. Did the message reach the tenant? Message trace answers it in about thirty seconds and ends most arguments.

---

## Recipient Types

| Type | Licence | Use |
| --- | --- | --- |
| **User mailbox** | Yes | A person |
| **Shared mailbox** | No, under 50 GB | `support@`, `info@` |
| **Room mailbox** | No | Meeting rooms |
| **Equipment mailbox** | No | Projectors, vehicles, kit |
| **Distribution list** | No | Email to many |
| **Mail-enabled security group** | No | Permissions and email |
| **Mail contact** | No | External person in the address book |

---

## Shared Mailboxes

**Recipients**, **Mailboxes**, **Add a shared mailbox**. Name, address, then members.

Permissions matter here and people get them wrong.

| Permission | Result |
| --- | --- |
| **Full Access** | Open and read the mailbox |
| **Send As** | Message appears to come from the mailbox |
| **Send on Behalf** | Shows "user on behalf of mailbox" |

Full Access does not include the ability to send. Grant **Send As** as well, or users will report that replies fail.

```powershell
Connect-ExchangeOnline

Add-MailboxPermission -Identity 'support@vbunnylab.com' -User ballen `
    -AccessRights FullAccess -InheritanceType All
Add-RecipientPermission -Identity 'support@vbunnylab.com' -Trustee ballen `
    -AccessRights SendAs -Confirm:$false

Get-MailboxPermission -Identity 'support@vbunnylab.com' |
    Where-Object {$_.User -notlike 'NT AUTHORITY*'}
```

**Send As for anything customer-facing.** A reply from `support@` that says "Barry Allen on behalf of Support" looks wrong to the customer.

Changes can take up to an hour to appear in Outlook. Closing and reopening Outlook usually speeds it up.

---

## Resource Mailboxes

**Recipients**, **Resources**, **Add a resource**. Room or Equipment.

Booking options are what make it usable:

| Setting | Typical |
| --- | --- |
| Allow repeating meetings | Yes |
| Booking window | 180 days |
| Maximum duration | 24 hours |
| Auto accept | Yes for most rooms |
| Delegates | Required where approval is needed |

```powershell
Set-CalendarProcessing -Identity 'ConfRoomA@vbunnylab.com' `
    -AutomateProcessing AutoAccept -AllowConflicts $false `
    -BookingWindowInDays 180 -MaximumDurationInMinutes 1440
```

A room showing as free when it is booked is nearly always `AutomateProcessing` left on `AutoUpdate` instead of `AutoAccept`.

---

## Message Trace

The single most useful tool in Exchange Online.

**Mail flow**, **Message trace**, **Start a trace**. Sender or recipient, date range, search.

| Status | Means |
| --- | --- |
| Delivered | Reached the mailbox |
| Failed | Rejected. The detail gives the reason |
| Pending | Still in transit or being retried |
| Quarantined | Held by a threat policy |
| Filtered as spam | In Junk or quarantine |
| Expanded | Sent to a distribution list |

```powershell
Get-MessageTrace -RecipientAddress ballen@vbunnylab.com `
    -StartDate (Get-Date).AddDays(-2) -EndDate (Get-Date) |
    Select-Object Received, SenderAddress, Subject, Status

# full detail on one message
Get-MessageTraceDetail -MessageTraceId <id> -RecipientAddress ballen@vbunnylab.com
```

**This settles the "we never got your email" conversation.** Either the message reached the tenant and you can say what happened to it, or it never arrived and the problem is at the sender's end. Trace before troubleshooting anything else.

Message trace covers 10 days interactively. Older than that needs the extended report.

---

## Mail Flow Rules

Transport rules act on messages in transit. Conditions, then actions.

**Mail flow**, **Rules**, **Add a rule**.

Useful ones:

| Rule | Does |
| --- | --- |
| External sender warning | Prepends a banner to messages from outside |
| Block risky attachments | Rejects executable types |
| Route by keyword | Sends invoices to a shared mailbox |
| Encrypt on keyword | Applies encryption when the subject says confidential |
| Block auto-forwarding | Stops mail leaving the tenant automatically |

**The external sender banner is worth having.** It is a one-line rule and it reduces phishing clicks, because a message claiming to be from the CEO carries a visible external tag.

**Blocking auto-forwarding is worth more.** A standard step after a mailbox compromise is a forwarding rule sending everything to an external address. The user notices nothing. Blocking external auto-forward closes that off, and Microsoft now blocks it by default in the outbound spam policy.

```powershell
# find mailboxes forwarding externally, worth running periodically
Get-Mailbox -ResultSize Unlimited |
    Where-Object { $_.ForwardingSmtpAddress -ne $null } |
    Select-Object DisplayName, ForwardingSmtpAddress, DeliverToMailboxAndForward

# and inbox rules that forward or delete
Get-Mailbox -ResultSize Unlimited | ForEach-Object {
    Get-InboxRule -Mailbox $_.Identity |
        Where-Object { $_.ForwardTo -or $_.RedirectTo -or $_.DeleteMessage } |
        Select-Object @{n='Mailbox';e={$_.MailboxOwnerId}}, Name, ForwardTo, RedirectTo
}
```

Run those two after any suspected account compromise. A rule that forwards everything to an external address and deletes the copy is the classic sign.

---

## Email Forwarding

**Recipients**, **Mailboxes**, select, **Mail flow settings**, **Email forwarding**.

Tick **Keep a copy of forwarded messages** unless there is a reason not to.

Forwarding is legitimate for cover and role changes. It is also how data leaves an organisation. Anything forwarding externally should be approved, documented and reviewed.

---

## Accepted and Remote Domains

**Accepted domains** are the domains your tenant handles mail for.

| Type | Behaviour |
| --- | --- |
| **Authoritative** | You hold every mailbox for this domain |
| **Internal relay** | Some mailboxes are elsewhere. Unknown recipients get relayed |

Setting a domain as authoritative when some mailboxes still sit on another system means mail to those users bounces. That happens during migrations.

**Remote domains** control how you send outbound to specific domains. Out of office behaviour, read receipts, message format.

---

## Email Authentication

The part that decides whether anyone can spoof your domain. Three DNS records.

| Record | Does |
| --- | --- |
| **SPF** | Lists who may send for your domain |
| **DKIM** | Signs outbound mail cryptographically |
| **DMARC** | Tells receivers what to do when SPF and DKIM fail, and where to report |

**SPF** is one TXT record:

```text
v=spf1 include:spf.protection.outlook.com -all
```

`-all` is a hard fail. `~all` is a soft fail. Start with `~all`, confirm nothing legitimate breaks, then move to `-all`.

**DKIM** is enabled per domain in **security.microsoft.com**, **Policies**, **Email authentication settings**, **DKIM**. It needs two CNAME records first.

**DMARC** is another TXT record at `_dmarc.yourdomain.com`:

```text
v=DMARC1; p=none; rua=mailto:dmarc@vbunnylab.com
```

Start at `p=none`, which only reports. Read the reports for a few weeks, fix anything legitimate that fails, then move to `p=quarantine` and eventually `p=reject`.

**Without DMARC at enforcement, anyone can send mail appearing to come from your domain.** That is the mechanism behind most business email compromise. Setting it up costs three DNS records and it is one of the highest-value things you can do for a tenant.

---

## Admin Roles

**Roles**, **Admin roles**.

| Role group | Scope |
| --- | --- |
| Organization Management | Everything in Exchange |
| Recipient Management | Mailboxes and recipients |
| Help Desk | Password reset, basic recipient tasks |
| View-Only Organization Management | Read everything, change nothing |
| Compliance Management | Retention, eDiscovery, audit |

View-Only is the right role for most investigation work. Give it out freely and reserve the write roles.

---

## Common Tickets

| Symptom | Cause | Fix |
| --- | --- | --- |
| "I never got the email" | Filtered, quarantined, or never sent | Message trace first |
| Cannot send as shared mailbox | Missing Send As | Add the permission |
| Room shows free when booked | `AutomateProcessing` wrong | Set to AutoAccept |
| External mail bouncing | SPF, MX, or accepted domain | Check DNS and the NDR code |
| Forwarding not working | Conflicting rule, or forwarding blocked | Check transport rules and outbound policy |
| Mailbox full | Quota | Archive or raise the quota |
| Delegate access not applying | Sync delay | Up to an hour. Restart Outlook |
| Mail going to Junk | Spam filter, or authentication failing | Check SPF, DKIM, DMARC |

```powershell
Get-MailboxStatistics -Identity ballen | Select-Object DisplayName, TotalItemSize, ItemCount
Get-Mailbox -Identity ballen | Select-Object ProhibitSendQuota, IssueWarningQuota
Get-AcceptedDomain
Get-TransportRule | Select-Object Name, State, Priority
```

---

## Practices

- Message trace before anything else on a mail ticket
- Send As, not Send on Behalf, for shared customer-facing mailboxes
- SPF, DKIM and DMARC configured, with DMARC moving toward enforcement
- Block external auto-forwarding
- Audit forwarding rules regularly. It is where exfiltration hides
- External sender banner on inbound mail
- Keep transport rules few and named clearly. A tangle of rules is impossible to debug
- View-only roles for anyone who only needs to look

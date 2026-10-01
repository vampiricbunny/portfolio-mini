# Microsoft Teams Administration

Teams, channels, policies, guest access and the meeting settings that decide who can join.

Worth knowing before anything else: **a Team is a Microsoft 365 group with a front end.** Creating one also creates a SharePoint site, a shared mailbox, a Planner and a OneNote. Files in a channel live in SharePoint. Chat files live in OneDrive.

That is why a Teams permissions problem is often a SharePoint problem, and why deleting a Team takes a lot with it.

---

## Teams and Channels

### Creating a Team

Users usually create their own. Admins can from **Teams**, **Manage teams**, **Add**.

| Type | Who can join |
| --- | --- |
| **Private** | Invitation only |
| **Public** | Anyone in the organisation |
| **Org-wide** | Everyone, automatically. Capped at 10,000 |

**Private is the right default.** Public teams are discoverable by everyone, which is fine for a community and wrong for a project.

### Channel Types

| Channel | Access | Files stored |
| --- | --- | --- |
| **Standard** | Everyone in the team | Team SharePoint site |
| **Private** | Selected members only | Its own SharePoint site |
| **Shared** | People outside the team, no guest account needed | Its own site |

**Private channels create a separate SharePoint site.** That has real consequences for retention, eDiscovery and backup, and it surprises people during a compliance review.

**Shared channels** are the better option for working with another department or an external organisation, because nobody needs a guest account or a team switch.

### Should Users Create Teams?

Left open, you get sprawl. Dozens of abandoned teams, each with a SharePoint site and a mailbox.

Two options. Restrict group creation to a security group, or allow it and apply an **expiration policy** so unused teams are renewed or archived automatically.

Expiration is usually better. Restricting creation just pushes people to a workaround.

---

## Guest and External Access

Two different things, constantly confused.

| | Guest access | External access (federation) |
| --- | --- | --- |
| Purpose | Bring someone into your team | Chat and call across organisations |
| Account created | Yes, guest in Entra ID | No |
| Can join teams | Yes | No |
| Scope | Per team | Domain level |

**Guest access** is for a contractor who needs to be in your team. **External access** is for chatting with someone at another company without adding them to anything.

### Guest Access

**Users**, **Guest access**, toggle on, then set what guests can do.

Guests appear in your directory. Review them.

```powershell
Connect-MgGraph -Scopes 'User.Read.All'
Get-MgUser -Filter "userType eq 'Guest'" -All |
    Select-Object DisplayName, Mail, CreatedDateTime |
    Sort-Object CreatedDateTime
```

Guest accounts from projects that ended years ago are a standard audit finding. They still hold access to whatever they were added to.

### External Access

**Users**, **External access**. Either allow all domains, or allowlist specific ones.

An allowlist is the safer setting where you only work with a handful of partners.

---

## Policies

Policies control what users can do. There is a Global policy that applies to everyone, and you create others and assign them to groups.

| Policy | Controls |
| --- | --- |
| **Teams** | Creating teams, private channels, discovery |
| **Meeting** | Recording, lobby, who can present |
| **Messaging** | Editing, deleting, chat availability |
| **App permission** | Which apps are allowed |
| **Calling** | Call forwarding, voicemail |
| **Live events** | Who can run them |

Assign to groups rather than individuals. **Policy packages** bundle related policies for a role, such as Education Teacher or Healthcare Clinical Worker.

### Meeting Policy Settings That Matter

| Setting | Recommended | Reason |
| --- | --- | --- |
| Who can bypass the lobby | People in my org | Stops uninvited joiners going straight in |
| Allow anonymous users to start | Off | Prevents a meeting running with no host |
| Who can present | Organizers and co-organizers | Stops accidental or deliberate screen hijacking |
| Allow recording | On, with policy | People expect it to work |
| Automatically record | Off | Consent and storage |

**Lobby settings are the important ones.** A meeting link that anyone can join, with anyone able to present, is how meeting bombing happens. Setting the lobby to "People in my org" and presenters to "Organizers only" closes both.

---

## Apps

**Teams apps**, **Manage apps** lists everything available.

Three levels of control: org-wide app settings, app permission policies assigned to users, and app setup policies deciding what is pinned.

**Review third-party apps before allowing them.** A Teams app can request access to files, chat and calendar. Users can install them unless you block it. An allowlist is worth the effort in a security-conscious environment.

---

## Common Tickets

| Symptom | Cause | Fix |
| --- | --- | --- |
| Teams will not load or sign in | Cached credentials | Clear the cache, see below |
| Cannot find a team | Private, and not a member | Ask an owner to add them |
| Cannot access channel files | SharePoint permissions | Check the underlying site |
| Guest cannot join | Guest access off, or invite not accepted | Check settings and the invite |
| No audio or video | Device or permissions | Check Teams device settings, then Windows privacy |
| Meeting recording missing | Policy, or still processing | Check the policy, then OneDrive or SharePoint |
| Cannot create a team | Group creation restricted | Check the restriction group |
| Chat history gone | New device, or retention policy | Check retention |

### Clearing the Cache

Fixes a large share of Teams problems.

**New Teams:**

```powershell
Get-Process ms-teams -ErrorAction SilentlyContinue | Stop-Process -Force
Remove-Item "$env:LOCALAPPDATA\Packages\MSTeams_8wekyb3d8bbwe\LocalCache\*" -Recurse -Force
```

**Classic Teams:**

```powershell
Get-Process Teams -ErrorAction SilentlyContinue | Stop-Process -Force
Remove-Item "$env:APPDATA\Microsoft\Teams\*" -Recurse -Force
```

Sign back in afterwards. It re-downloads, so it takes a minute on first launch.

**Check service health before troubleshooting a widespread Teams issue.** Teams outages happen and they are visible in the admin center.

---

## Monitoring

**Analytics and reports** covers usage, device breakdown and meeting quality.

**Call Quality Dashboard** is the one for "meetings keep dropping". It shows packet loss and jitter per call, which usually points at a specific network rather than at Teams.

Worth reviewing:

- Inactive teams, for cleanup
- Guest count over time
- App usage, to catch anything unexpected
- Call quality trends by site

---

## Practices

- Private teams by default
- Expiration policy rather than blocking team creation
- Lobby set to People in my org, presenters set to Organizers
- Guest access reviewed quarterly
- External access allowlisted where the partner set is small
- Third-party apps reviewed before enabling
- Shared channels instead of guest accounts where they fit
- Naming convention on teams, or the list becomes unusable
- Retention policies set deliberately, since chat is discoverable

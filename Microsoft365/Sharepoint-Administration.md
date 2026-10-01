# SharePoint Online Administration

Sites, permissions, external sharing and OneDrive sync.

The thing to understand first: SharePoint holds most of the files in a Microsoft 365 tenant, including everything shared in Teams. Every Team has a SharePoint site behind it. Change sharing policy in SharePoint and you change how files behave in Teams too.

---

## Site Types

| Type | Use | Comes with |
| --- | --- | --- |
| **Team site** | A group collaborating | Microsoft 365 group, shared mailbox, Planner |
| **Communication site** | Publishing to many readers | No group. Permissions set directly |
| **Hub site** | Ties related sites together | Shared navigation and search |
| **OneDrive** | One person's files | Created per user |

**Team site for collaboration, communication site for broadcast.** An intranet page or a policy library is a communication site. A project workspace is a team site.

---

## Creating a Site

1. **SharePoint admin center**, **Sites**, **Active sites**, **Create**.
2. Pick the type.
3. Name it, set the owner, language, time zone.
4. **Create**.

Most team sites get created by users making a Team rather than by an admin. That is normal and usually fine. What it means is that site sprawl builds up quietly, so a review schedule matters.

---

## Permissions

Three default groups on every site.

| Group | Can |
| --- | --- |
| **Owners** | Full control, including permissions |
| **Members** | Add, edit and delete content |
| **Visitors** | Read only |

**Put people in groups, not in individual permissions.** Item-level permissions are possible and they make a site unmaintainable within a year. Nobody can answer who has access without clicking through every folder.

For a group-connected team site, membership is managed through the Microsoft 365 group, not in SharePoint. Adding someone in SharePoint on a group-connected site creates exactly the kind of exception that causes confusion later.

### Broken Inheritance

Subsites and libraries inherit from the parent by default. You can break that, and sometimes you need to.

Every break is a place where permissions can drift. Keep them few and write down why.

```powershell
Connect-SPOService -Url https://vbunnylab-admin.sharepoint.com
Get-SPOSite | Select-Object Url, Owner, StorageUsageCurrent, SharingCapability
Get-SPOUser -Site https://vbunnylab.sharepoint.com/sites/Finance
```

---

## External Sharing

The setting that matters most from a security point of view.

**Policies**, **Sharing**. There is a tenant-level setting and a per-site setting. The per-site setting cannot be more permissive than the tenant.

| Level | Means |
| --- | --- |
| **Anyone** | Anonymous links. No sign-in |
| **New and existing guests** | Guest must authenticate |
| **Existing guests only** | Already in the directory |
| **Only people in your organization** | No external sharing |

**"Anyone" links are the risk.** They work for whoever holds the URL. Forwarded, pasted into a ticket, indexed if it leaks. No sign-in, no audit trail of who opened it.

If you allow them, constrain them:

- Set an expiry, 30 days is reasonable
- Set link permissions to View, not Edit
- Default new links to "Specific people" rather than "Anyone"

Sensible starting point: tenant set to **New and existing guests**, with **Anyone** allowed only on specific sites that genuinely need it.

```powershell
Set-SPOTenant -SharingCapability ExternalUserSharingOnly
Set-SPOSite -Identity https://vbunnylab.sharepoint.com/sites/Finance -SharingCapability Disabled
```

Review guest access periodically. External users accumulate. A contractor added to a site two years ago is still in the directory unless someone removed them.

---

## Storage

**Sites**, **Active sites**, sort by **Storage used**.

Tenant storage is pooled, 1 TB plus 10 GB per licence. Individual sites have a quota you can adjust.

Sites near their limit stop accepting uploads, and the error the user sees is not clear about why.

Common causes of unexpected growth:

- Version history. SharePoint keeps 500 versions by default
- Recycle bins. Two stages, 93 days total
- Large media nobody has looked at since upload

Reducing version limits on a large library reclaims a surprising amount of space.

---

## OneDrive Sync

The most common SharePoint ticket by a wide margin.

**Work through these in order.**

1. **Check the icon.** Blue is syncing, green is synced, red is a problem, grey means not signed in.
2. **Restart OneDrive.** Right-click the icon, Quit, then reopen it. Fixes most cases.
3. **Check the account.** Signed into the right work account? Personal and work OneDrive both show an icon and people sign into the wrong one.
4. **Look at the errors.** Click the icon. It lists the specific files that failed and why.
5. **Check the path length.** Windows has a 260 character limit. Deep folder structures inside a synced library hit it. The file that will not sync is usually the one with the longest path.
6. **Check for invalid characters.** `" * : < > ? / \ |` in a filename break sync.
7. **Check storage.** Both the local disk and the OneDrive quota.
8. **Unlink and relink.** Settings, Account, Unlink this PC, then set it up again. This re-downloads, so warn the user.

```powershell
Get-Process OneDrive | Select-Object Name, StartTime
Stop-Process -Name OneDrive -Force
Start-Process "$env:LOCALAPPDATA\Microsoft\OneDrive\OneDrive.exe"
```

**Turn on Files On-Demand.** Files appear in Explorer but download only when opened. Without it, syncing a large library fills the disk.

**Known Folder Move** redirects Desktop, Documents and Pictures into OneDrive. Deploy it through Intune or Group Policy. It is the single best protection against a user losing everything when a laptop dies, and it costs nothing.

---

## Recovering Files

Three places to look, in order.

1. **Recycle bin** on the site. 93 days.
2. **Second-stage recycle bin**, admin only, within the same 93 days.
3. **Version history**. Right-click the file, Version history. Restore any earlier version.

Version history also covers the case where a file was overwritten rather than deleted, which is more common than people expect.

**Site collection restore** recovers a whole library after a bulk deletion or ransomware. **Settings**, **Restore this library**, pick a point in time.

---

## Common Tickets

| Symptom | Cause | Fix |
| --- | --- | --- |
| Cannot access a site | Permissions, or the site was deleted | Check membership and Active sites |
| File missing | Deleted or moved | Recycle bin, then version history |
| Sync stopped | Path length, invalid characters, quota | Read the OneDrive error list |
| Cannot upload | Site quota full | Check storage |
| External user cannot open a link | Sharing policy blocked it | Check tenant and site sharing settings |
| File locked by another user | Checked out, or open elsewhere | Check in, or force check-in as admin |
| Search not returning a file | Index still catching up | Wait, then re-index |

---

## Security Settings Worth Applying

- External sharing at the least permissive level that still works
- Expiry on Anyone links, if allowed at all
- Default link type set to Specific people
- Conditional access requiring a compliant or managed device for SharePoint
- Restrict downloads on sensitive sites, so files open in the browser only
- Idle session timeout for unmanaged devices
- Sensitivity labels on sites holding regulated data
- Audit guest access quarterly

```powershell
Set-SPOTenant -RequireAnonymousLinksExpireInDays 30
Set-SPOTenant -DefaultSharingLinkType Direct
Set-SPOTenant -FileAnonymousLinkType View
```

Those three commands remove a lot of accidental exposure and take a minute to run.

# Outlook Issues

Outlook faults sorted by symptom. Start with the two questions that split the problem in half.

**Does webmail work?** If yes, the mailbox is fine. The fault is on the machine.

**One user or several?** One user is local. Several means the server or the service.

Those two answers decide everything that follows.

---

## Safe Mode First

Safe mode loads Outlook with no add-ins and no customisation. It is the fastest way to tell an add-in problem from a profile problem.

```text
Win + R  ->  outlook.exe /safe
```

Or hold `Ctrl` while launching.

Opens in safe mode but not normally? It is an add-in. Crashes in safe mode too? It is the profile or the install.

---

## Will Not Open

1. Safe mode. See above.
2. Kill any stuck process.

   ```powershell
   Get-Process outlook -ErrorAction SilentlyContinue | Stop-Process -Force
   ```

3. Update Office. **File**, **Office Account**, **Update Options**, **Update Now**.
4. Quick Repair. **Settings**, **Apps**, Microsoft 365, **Modify**, **Quick Repair**.
5. Online Repair if Quick Repair does nothing. Takes longer and needs internet.

---

## Crashes or Freezes

**Disable add-ins.**

**File**, **Options**, **Add-ins**. At the bottom set Manage to **COM Add-ins**, click **Go**, untick everything. Restart.

Working now? Re-enable one at a time until it breaks. That names the culprit. Skipping this step means you never find out.

**Rebuild the profile.**

1. **Control Panel**, **Mail (Microsoft Outlook)**.
2. **Show Profiles**, **Add**.
3. Name it, set the account up again.
4. Set **Always use this profile** to the new one.

Keep the old profile until the new one is confirmed working. Do not delete it first.

**Turn off hardware graphics acceleration.**

**File**, **Options**, **Advanced**, **Display**, tick **Disable hardware graphics acceleration**. Fixes a lot of freezing on older graphics drivers.

---

## Not Syncing

1. Check **Work Offline** is not enabled. **Send / Receive** tab. It gets clicked by accident constantly.
2. Check connectivity.

   ```powershell
   Test-NetConnection outlook.office365.com -Port 443
   ```

3. Repair the account. **File**, **Account Settings**, **Account Settings**, select the account, **Repair**.
4. Check the connection status. `Ctrl` + right-click the Outlook icon in the system tray, **Connection Status**.

For a Microsoft 365 mailbox, confirm the licence is still assigned. An expired or removed licence looks exactly like a sync failure.

---

## Stuck in the Outbox

Usually one of three things.

- **Large attachment.** Most tenants cap around 25 MB. The message sits there.
- **Outlook is offline.** Check **Work Offline**.
- **The message is open.** Outlook will not send a message that is open in a window.

Fix it:

1. Go offline. **Send / Receive**, **Work Offline**.
2. Open the Outbox and delete the stuck message.
3. Go back online.
4. Resend with the attachment as a link rather than a file.

If nothing deletes, close Outlook, end the process, and reopen.

---

## Search Not Working

Almost always the index.

1. **Control Panel**, **Indexing Options**.
2. Confirm Outlook is in the indexed locations. **Modify** if not.
3. **Advanced**, **Rebuild**.

Rebuilding takes hours on a large mailbox. Tell the user that up front or they will raise a second ticket.

```powershell
Get-Service WSearch | Select-Object Name, Status, StartType
Restart-Service WSearch
```

Search in a Microsoft 365 mailbox with cached mode off runs server side, so a local index rebuild will not help. Check which mode the profile is in first.

---

## Not Receiving Mail

Work through these in order.

1. **Junk folder.** Check it first. It is the answer more often than anything else.
2. **Rules.** **File**, **Manage Rules and Alerts**. A rule filing messages into a folder nobody opens is common.
3. **Blocked senders.** **Home**, **Junk**, **Junk Email Options**, **Blocked Senders**.
4. **Mailbox full.** Check the quota.
5. **Message trace.** In Exchange admin, trace the message. That tells you whether it ever arrived at the tenant.

Message trace is the one that settles the argument. If the message never reached the tenant, the problem is the sender or the sending domain, not Outlook.

---

## Slow

- Disable unused add-ins
- Reduce the cached mail window. **File**, **Account Settings**, **Account Settings**, **Change**, drag the slider down to 3 or 6 months
- Check the OST size. A very large OST slows everything
- Archive old mail
- Confirm the profile is in cached mode

Very large mailboxes with many folders slow Outlook regardless of the machine. Archiving is the fix, not more RAM.

---

## Calendar Problems

| Symptom | Cause | Fix |
| --- | --- | --- |
| Cannot see a shared calendar | Permissions | Owner shares it again with the right level |
| Duplicate appointments | Sync conflict or two profiles | Rebuild the profile |
| Meeting updates not arriving | Delegate settings | Check **File**, **Account Settings**, **Delegate Access** |
| Room shows free when booked | Resource mailbox settings | Check the booking policy in Exchange admin |

---

## Quick Reference

| Command | Does |
| --- | --- |
| `outlook.exe /safe` | Safe mode |
| `outlook.exe /resetnavpane` | Fix a broken folder pane |
| `outlook.exe /cleanviews` | Reset custom views |
| `outlook.exe /cleanrules` | Delete all client and server rules |
| `outlook.exe /resetfolders` | Restore missing default folders |
| `outlook.exe /profiles` | Force the profile picker at startup |

`/cleanrules` deletes every rule. Export them first if the user wants them back.

---

## Before Closing

Confirm with the user that it is fixed. Do not close on the assumption.

Note what actually fixed it. "Reinstalled Office" is not useful next time. "Disabled the Acrobat COM add-in, crash stopped" is.

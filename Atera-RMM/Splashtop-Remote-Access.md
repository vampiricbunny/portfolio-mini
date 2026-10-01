# Remote Sessions with Splashtop

Taking a remote session on a managed device through Atera. Splashtop is bundled with Atera, so there is no separate licence.

This covers attended and unattended screen control. For fixing things without taking the user's screen, see [background management](Remote-Access-Via-Anydesk.md), which is usually the better option.

---

## Prerequisites

- Atera agent installed and reporting
- Device online
- Splashtop streamer deployed, which Atera handles automatically
- Remote access enabled on your technician account

If Connect is greyed out, the device is offline or the streamer has not finished deploying.

---

## Connecting

1. **Devices**, select the machine.
2. **Connect**.
3. Choose **Splashtop**.
4. Session opens in the Splashtop client.

First use downloads the client. After that it launches directly.

**Unattended works on any managed device.** No approval prompt, no code to read out. That is what you want for servers and after-hours work, and it is exactly why the account needs MFA.

---

## In the Session

| Feature | Use |
| --- | --- |
| **File transfer** | Move files both ways |
| **Chat** | Talk to the user without a phone call |
| **Multi-monitor** | Switch or view all |
| **Blank screen** | Hide your work from the local display |
| **Lock keyboard** | Stop the user typing mid-fix |
| **Clipboard sync** | Copy and paste across |
| **Session recording** | Where policy requires it |

**Blank screen and lock keyboard matter on servers.** Working on a machine where someone may be at the console means you can be interrupted mid-change. Locking input prevents that.

On a user's workstation, leave the screen visible. They should see what you are doing.

---

## Working With the User Present

The tool is easy. The handling is what makes the session go well.

**Before connecting**

- Say who you are and reference the ticket
- Ask permission explicitly
- Give them a moment to close anything personal

**During**

- Narrate what you are doing, in plain language
- Ask before taking the keyboard
- Do not open files or email unless the ticket requires it
- Blank the screen before typing any credential

**After**

- End the session properly and confirm it closed on both sides
- Tell them what you did and whether anything changes for them
- Write it up while it is fresh

Full detail in [Attended Remote Support](../Remote-Connection/TeamViewer.md).

---

## File Transfer

1. Open the session.
2. **File Transfer** from the toolbar.
3. Local on one side, remote on the other.
4. Select and transfer.

Useful for installers, drivers, diagnostic tools and collecting logs.

Atera also has file browsing **without** a full session, under **Manage** on the device page. Faster when you only need to grab a log file, and it does not interrupt anyone.

---

## Worked Example: Shared Folder Access

**Reported.** Cannot reach a shared work folder needed daily.

**Before connecting.** Raised the ticket. Asked two questions that shape everything after:

- Have you been able to open it before?
- Which folder exactly?

Previously working means something changed. Never worked means it is a permissions request, which needs approval first.

**In session.** Connected via Splashtop with the user watching.

```powershell
Test-Path '\\FILE01\CompanyData\Finance'
whoami /groups
Test-NetConnection FILE01 -Port 445
```

`whoami /groups` showed the user was not in the group holding the permission. They had moved department and nobody updated their membership.

**Fix.** Got manager approval, recorded it in the ticket, added them to the correct security group.

```powershell
Add-ADGroupMember -Identity 'GG-Finance-Staff' -Members ballen
```

Signed the user out and back in. Group membership is written into the Kerberos ticket at logon, so without that step it still fails and looks like the fix did not work.

**Verify.** Opened the folder with the user watching. Confirmed the drive mapping reconnects at sign-in.

**Close.** Internal note with the cause. Public note in plain language. Resolved.

---

## Worked Example: Password Reset on a Server

**Reported.** User cannot sign in, needs a reset.

1. Verified identity through a callback to the number in the HR record.
2. Connected to the domain controller via Splashtop.
3. Opened Active Directory Users and Computers.
4. Found the user, right-click, **Reset Password**.
5. Set a temporary password, ticked **User must change password at next logon**.
6. Ticked **Unlock the user's account**.
7. Delivered the password on a different channel than the request arrived on.

```powershell
Set-ADAccountPassword -Identity ballen -Reset -NewPassword (Read-Host -AsSecureString 'Temp')
Set-ADUser -Identity ballen -ChangePasswordAtLogon $true
Unlock-ADAccount -Identity ballen
```

**Verify identity before any reset.** A reset performed for the wrong caller hands over the account completely. Several significant breaches started with a convincing phone call to a service desk.

---

## When Not to Use a Remote Session

Most tickets do not need one.

| Task | Better option |
| --- | --- |
| Restart a service | Service Manager, background |
| Check disk space | Device overview page |
| Run a script | Script runner, background |
| Read an event log | Event viewer, background |
| Kill a process | Remote task manager |
| Grab a log file | File browser, background |
| Install software | Software deployment |

A remote session interrupts someone. Background tools do not. Use the session when you need to see what they see, or when they need to watch you.

---

## Security

Unattended access to every managed machine is a significant capability.

- **MFA on every technician account.** An RMM account reaches every endpoint
- **Review the session audit log.** Who connected to what, when, for how long
- **Least privilege on roles.** Not every technician needs unattended access to servers
- **Record sessions** where policy or regulation requires it
- **End sessions properly.** Leaving one open leaves a live connection
- **Remove departing technicians immediately.** Their access does not expire on its own

RMM platforms have been attacked directly, because compromising one reaches every managed endpoint at once. Treat the console with the same care as a domain controller.

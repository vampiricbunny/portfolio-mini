# Attended Remote Support

Connecting to a user's machine while they watch, using TeamViewer, AnyDesk, Splashtop or Quick Assist.

Different job to [RDP](Microsoft-RDP.md). RDP takes over the machine and locks the local user out. Attended tools share the screen, so the user sees everything you do. For helping someone with a problem on their screen, that is what you want.

---

## Attended or Unattended

**Attended.** The user is there. They start the session, or approve it. Session ends when either side disconnects. Right for helpdesk work.

**Unattended.** Agent installed, connect any time, no approval needed. Right for servers and for fixing a machine out of hours. Usually part of an RMM.

Most tools do both. Which one you deploy changes the security conversation entirely.

---

## Tools

| Tool | Cost | Notes |
| --- | --- | --- |
| **Quick Assist** | Free, in Windows | No install. Good for one-offs |
| **TeamViewer** | Paid for commercial | Feature-heavy, widely known |
| **AnyDesk** | Paid for commercial | Light and fast, good on poor links |
| **Splashtop** | Paid | Strong on performance, common in MSPs |
| **RMM built-in** | With the RMM | Unattended, already deployed |

**Quick Assist is underused.** It ships with Windows 10 and 11, needs no install, and needs no licence. For a one-off session with a user who has nothing installed, it is the fastest option available.

```text
Helper:  open Quick Assist, choose Help someone, sign in, read out the code
User:    open Quick Assist, enter the code, approve the request
```

---

## Running a Session

The tool is the easy part. The handling is what separates a good session from a bad one.

### Before Connecting

**Say who you are and why you are calling.** Name, team, and the ticket number. The user should be able to verify you independently.

**Ask permission explicitly.** "Can I connect to your screen to take a look?" Not "I'm going to connect now."

**Tell them what you are about to do**, in plain language. No jargon. "I'm going to look at your printer settings" is fine. "I'm going to check the spooler service state" is not.

**Ask them to close anything private.** They may have personal banking or a payslip open. Giving them ten seconds to close it is basic courtesy and keeps you out of a difficult conversation later.

### During

**Narrate.** Say what you are clicking and why. Silence while their mouse moves on its own is unsettling.

**Do not take the keyboard without warning.** Ask first.

**Do not read files or email** unless the ticket requires it and you have said so.

**Watch what you type.** Passwords typed in a shared session are visible. Blank the screen first if the tool supports it, or ask them to look away.

### After

**End the session properly.** Do not leave it open. Confirm on both sides that it has closed.

**Tell them what you did** and whether anything will change for them.

**Write it up** while it is fresh. Steps, results, and outcome.

---

## What You Can Do in a Session

- Walk through a fault while the user watches
- Transfer files both ways
- Run diagnostics with the user watching, which is good for teaching them
- Restart services, check settings, install software
- Reboot, then reconnect once the machine is back

Basic checks worth running on the remote machine:

```powershell
ipconfig /all
Test-NetConnection 8.8.8.8
Get-Service Spooler
Get-EventLog -LogName System -Newest 20
```

Doing this while the user watches has a side benefit. They often learn enough to fix it themselves next time, which is one fewer ticket.

---

## File Transfer

Every tool has it, usually behind a File Transfer or Files menu.

Use it for logs, drivers and installers. Check what you are sending. A file transfer window is visible to the user, and sending something with a revealing filename is avoidable.

---

## The Security Side

This matters more than the feature list, and it is worth being able to talk about in an interview.

**These tools are the number one vector for tech support scams.** Someone calls claiming to be from Microsoft or your bank, talks the victim into installing AnyDesk or TeamViewer, and walks them through handing over access to their online banking. It happens at volume, every day.

That has two consequences for anyone working a service desk.

### Establish Legitimacy Every Time

Users who have been trained to be suspicious of remote support requests are doing the right thing. Work with it.

- Call from a number they can verify, or have them call the published helpdesk number back
- Reference a ticket they raised
- Never cold-call and ask someone to install remote access software
- If they want to hang up and call back, encourage it

A user who refuses is not being difficult. They are following exactly the advice they should be following.

### Recognise a Victim

Sometimes a ticket comes in that is actually a scam in progress or just finished.

Signs:

- AnyDesk, TeamViewer or UltraViewer installed and the user cannot say why
- "Someone from Microsoft called about a virus"
- A remote session running right now that the user did not initiate
- Bank or payment sites open alongside a support session
- Requests to buy gift cards

If you see this, act immediately:

1. Disconnect the machine from the network
2. End any active remote session
3. Tell the user to call their bank straight away
4. Change passwords from a **different** device, not that one
5. Escalate as a security incident
6. Treat the machine as compromised. Rebuild it

```powershell
# what is connected right now
Get-NetTCPConnection -State Established |
    Select-Object LocalPort, RemoteAddress, RemotePort, OwningProcess

# remote access software present
Get-Process | Where-Object { $_.Name -match 'teamviewer|anydesk|ultraviewer|supremo|logmein' }
```

### Deployment Controls

If your organisation uses these tools:

- Deploy one, and block the rest with application control
- Turn on MFA for the vendor account
- Use a business licence with access control and audit logging
- Restrict unattended access to machines that need it
- Review the connection log. Who connected to what, and when
- Remove the agent when a machine is decommissioned

Unattended remote access to every workstation, with a shared account and no MFA, is a serious risk. It is also common.

---

## Choosing One

For a service desk, the deciding factors are usually:

- **Attended or unattended**, which you need
- **Platform coverage**, particularly macOS and mobile
- **Cost per technician**, since most licence by concurrent tech
- **Audit logging**, which matters for compliance
- **Performance on poor connections**
- **Whether it integrates with your RMM or PSA**

Bundled RMM remote access often removes the need for a separate tool entirely. Check what you already have before buying something.

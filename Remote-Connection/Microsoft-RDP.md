# Remote Desktop

Connecting to Windows machines over RDP, and locking it down so it does not become the way into your network.

RDP is built into Windows and does the job well. It is also one of the most attacked services on the internet. Ransomware operators scan for exposed 3389 constantly, and an exposed RDP host with a weak password is a standing invitation.

Everything below assumes internal use only.

---

## Before You Connect

- Both machines reachable on the network
- Remote Desktop enabled on the target
- Your account has rights to connect
- Target is Windows **Pro, Enterprise or Server**. Home cannot host RDP

```powershell
Test-NetConnection ws11-01.vbunnylab.local -Port 3389
```

Port 3389 open is the check that matters. A plain ping only proves the host is up.

---

## Enable It

**Settings**, **System**, **Remote Desktop**, toggle on. Leave **Require devices to use Network Level Authentication** ticked.

```powershell
Set-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server' -Name fDenyTSConnections -Value 0
Set-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp' -Name UserAuthentication -Value 1
Enable-NetFirewallRule -DisplayGroup 'Remote Desktop'
```

> **Network Level Authentication stays on.** It makes the user authenticate before a session is created. Without it, anyone who can reach port 3389 gets a logon screen and a session allocated to them, which is both an attack surface and a denial of service vector.

At scale, push this with Group Policy rather than per machine.

---

## Connect

```text
Win + R  ->  mstsc
```

Enter the hostname. Use the name, not the IP, where DNS works. Names survive an address change.

Useful options before connecting, under **Show Options**:

| Tab | Worth setting |
| --- | --- |
| **Display** | Lower resolution and colour depth on a slow link |
| **Local Resources** | Clipboard, drives, printers to pass through |
| **Experience** | Set the connection speed so Windows drops visual effects |
| **Advanced** | Server authentication behaviour |

From the command line:

```cmd
mstsc /v:ws11-01.vbunnylab.local
mstsc /v:ws11-01 /f                   :: fullscreen
mstsc /v:ws11-01 /multimon            :: span monitors
mstsc /admin                          :: console session on a server
```

> **Be careful with drive redirection.** Mapping your local drives into a remote session means malware on that machine can reach your files. Leave it off unless you need it for that specific job.

---

## Who Can Connect

Administrators can by default. Everyone else needs adding to **Remote Desktop Users**.

```powershell
Add-LocalGroupMember -Group 'Remote Desktop Users' -Member 'VBUNNYLAB\ballen'
Get-LocalGroupMember -Group 'Remote Desktop Users'
```

For a fleet, use a Group Policy restricted group so the membership is defined centrally and cannot drift.

---

## Sessions

```powershell
query user                              # who is signed in
query user /server:FILE01
logoff 2 /server:FILE01                 # sign out session ID 2
```

```powershell
Get-CimInstance Win32_LogonSession | Select-Object LogonId, LogonType, StartTime
```

**Disconnecting is not signing out.** A disconnected session keeps running with everything open. On a server with a session limit, abandoned sessions fill it up and nobody else can connect. Set idle and disconnected session limits by policy.

---

## Troubleshooting

| Symptom | Cause | Check |
| --- | --- | --- |
| Cannot connect at all | RDP disabled, or firewall | `Test-NetConnection -Port 3389` |
| "Remote Desktop can't connect" | Service stopped, or wrong name | `Get-Service TermService` |
| Credentials rejected but correct | Not in Remote Desktop Users | Check group membership |
| Connects then drops immediately | Session limit, or another session | `query user` |
| Black screen after login | Graphics driver, or a slow profile | Wait, then try `/admin` |
| Very slow | Bandwidth, or visual effects | Lower colour depth and resolution |
| Certificate warning every time | Self-signed cert | Deploy a proper certificate by GPO |
| "Another user is signed in" | Workstation allows one session | Coordinate, or use a server |

```powershell
Get-Service TermService | Select-Object Status, StartType
Get-NetFirewallRule -DisplayGroup 'Remote Desktop' | Select-Object DisplayName, Enabled
Get-WinEvent -LogName 'Microsoft-Windows-TerminalServices-LocalSessionManager/Operational' -MaxEvents 20
```

---

## Security

RDP is worth treating carefully. A short list that covers most of the risk.

**Never expose 3389 to the internet.** Not with a strong password, not on a non-standard port. Port scanning finds it either way. Use a VPN, or Azure Bastion, or an RD Gateway.

**Require MFA.** Duo Authentication for Windows Logon puts a second factor in front of RDP. See [Duo MFA](../MDM/Duo-MFA.md).

**Restrict who can connect** by group, not by leaving it to Administrators.

**Block local administrator accounts from connecting over the network.** This is how an attacker with one machine's local admin hash moves to the next. Deny `Local account and member of Administrators group` the **Deny log on through Remote Desktop Services** right.

**Set an account lockout policy.** Without one, RDP is an unlimited password guessing interface.

**Enable NLA.** Covered above.

**Log and watch it.** Event **4625** is a failed logon, **4624** with logon type **10** is a successful RDP session.

```powershell
# failed logons
Get-WinEvent -FilterHashtable @{LogName='Security'; ID=4625} -MaxEvents 50 |
    Select-Object TimeCreated, Message

# successful RDP sessions
Get-WinEvent -FilterHashtable @{LogName='Security'; ID=4624} -MaxEvents 50 |
    Where-Object { $_.Message -match 'Logon Type:\s+10' } |
    Select-Object TimeCreated, Message
```

A run of 4625 events from one external address is a brute force attempt in progress. That is a security ticket, not a user problem.

**Use LAPS** so every machine has a different local administrator password. Shared local passwords are what turn one compromised machine into all of them.

---

## Alternatives

| Tool | Suits |
| --- | --- |
| **RDP** | Internal admin access to Windows |
| **RD Gateway** | RDP over HTTPS without exposing 3389 |
| **Azure Bastion** | Browser access to Azure VMs, no public IP |
| **Quick Assist** | One-off user support, built into Windows |
| **TeamViewer / AnyDesk / Splashtop** | Cross-platform, attended support |
| **RMM remote tools** | Unattended support at scale |

For helping a user with something on screen, an attended tool is usually better than RDP. RDP disconnects the local session, so the user cannot see what you are doing.

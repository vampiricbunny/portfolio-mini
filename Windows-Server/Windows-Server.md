# Windows Server Fundamentals

Orientation for Windows Server 2022 - what it is, how it differs from desktop Windows, how roles and features work, and the initial configuration every server needs before it does anything useful.

The deeper walkthroughs live in their own documents:

- [Building the Lab](../Windows-Server-2025/Active-Directory-Setup.md) - full domain controller build on Server 2025
- [Active Directory](Active-Directory.md) - directory administration
- [File Sharing and NTFS](File-Sharing-NTFS.md) - shares and permissions
- [Group Policy Management](Group-Policy-Management.md) - policy authoring and troubleshooting

---

## What Windows Server Is

Windows Server shares a codebase with desktop Windows but is built to provide services rather than to be sat in front of. Server 2022 corresponds to Windows 10; Server 2025 to Windows 11.

The practical differences:

| | Desktop Windows | Windows Server |
| --- | --- | --- |
| Purpose | One user at a keyboard | Services consumed over a network |
| Concurrent sessions | One interactive user | Many, via RDS |
| Connection limits | 20 inbound SMB connections | Unlimited, licence permitting |
| Roles | None | AD DS, DNS, DHCP, file, web, Hyper-V, and more |
| Hardware ceiling | Consumer-scale | Very large CPU and memory configurations |
| Support lifecycle | ~2 years per release | 10 years for LTSC (5 mainstream + 5 extended) |

### Release History

Server 2003 → 2008 / 2008 R2 → 2012 / 2012 R2 → 2016 → 2019 → 2022 → 2025.

Worth knowing because environments are rarely uniform. Encountering a 2012 R2 box still running a line-of-business application is normal, and it is out of support - which makes it a finding, not just an inconvenience.

### Editions

| Edition | Suits | Virtualisation rights |
| --- | --- | --- |
| **Standard** | Physical or lightly virtualised | 2 virtual instances |
| **Datacenter** | Dense virtualisation | Unlimited virtual instances |

Feature sets are nearly identical; the difference is virtualisation rights and a handful of software-defined datacentre features. Evaluation ISOs from the Microsoft Evaluation Center run 180 days and are the right choice for a lab.

### Desktop Experience vs Server Core

| | Desktop Experience | Server Core |
| --- | --- | --- |
| GUI | Full desktop and consoles | Command line only |
| Disk footprint | Larger | Roughly 40% smaller |
| Patches | More, because more components | Fewer |
| Attack surface | Larger - browser, Explorer, media components | Smaller |
| Managed by | Local consoles | RSAT, Windows Admin Center, PowerShell remoting |

**Core is the better production choice** - a smaller install means fewer things to patch and fewer components to exploit. Desktop Experience is the sensible choice while learning the consoles, which is why this lab uses it.

You cannot convert between them after installation in current releases. Pick at install time.

---

## Roles vs Features

- A **role** is the primary job of a server - AD DS, DNS, DHCP, File Services, Web Server (IIS), Hyper-V.
- A **feature** is a supporting capability - .NET Framework, Failover Clustering, BitLocker, Windows Server Backup, RSAT.

Both are installed through the same wizard. Installing a role usually pulls in the features it depends on, including its management tools.

```powershell
Get-WindowsFeature | Where-Object Installed
Install-WindowsFeature DNS -IncludeManagementTools
Uninstall-WindowsFeature Windows-Defender-GUI
```

> **Install only what the server needs.** Every additional role is more attack surface, more patching, and more that can break. A domain controller should be a domain controller - not also a file server and a web server.

---

## Building the VM

**Download:** Windows Server 2022 evaluation ISO from the Microsoft Evaluation Center, and VMware Workstation Pro or VirtualBox.

**Baseline allocation:**

| Resource | Minimum | Comfortable |
| --- | --- | --- |
| vCPUs | 2 | 2-4 |
| Memory | 2 GB | 4-8 GB |
| Disk | 32 GB | 60-80 GB |
| Network | - | Host-only for an isolated lab |

In VMware Workstation:

1. **File** → **New Virtual Machine** → **Typical** → **Next**.
2. **I will install the operating system later** - installing from the ISO directly triggers Easy Install, which makes unattended choices you probably do not want.
3. Guest OS **Microsoft Windows**, version **Windows Server 2022** → **Next**.
4. Name and location → disk size → **Next**.
5. **Customize Hardware** → set memory and processors → **Network Adapter** → **Host-only** → **New CD/DVD** → **Use ISO image file** → browse to the ISO.
6. **Close** → **Finish**.

> **Host-only networking** keeps a lab that runs its own DHCP and DNS from interfering with the real network. See the [lab topology](../Windows-Server-2025/Active-Directory-Setup.md).

### Install

1. **Power on**, click inside the window, press a key when prompted to boot from the ISO. Missing the prompt means a reset and another attempt.
2. Language and keyboard → **Next** → **Install now**.
3. Choose **Windows Server 2022 Standard Evaluation (Desktop Experience)**.
4. Accept the licence terms → **Custom: Install Microsoft Server Operating System only**.
5. Select the unallocated disk → **Next**.
6. Wait for installation and reboot.
7. Set the built-in **Administrator** password. Use a lab-only password - never one you use elsewhere.

Install **VMware Tools** afterwards (**VM** → **Install VMware Tools** → run `setup64.exe`) for display scaling, clipboard sharing and clean shutdown.

---

## Initial Configuration Checklist

In this order, before installing any role:

1. **Rename the server** - trivial now, disruptive later. Renaming a domain controller means demoting and re-promoting it.

   ```powershell
   Rename-Computer -NewName 'FILE01' -Restart
   ```

2. **Set a static IP address** - servers must be reachable at a predictable address.

   ```powershell
   New-NetIPAddress -InterfaceAlias 'Ethernet0' -IPAddress 10.10.10.20 `
     -PrefixLength 24 -DefaultGateway 10.10.10.1
   Set-DnsClientServerAddress -InterfaceAlias 'Ethernet0' -ServerAddresses 10.10.10.10
   ```

   > **Leave IPv6 enabled.** Disabling it is a widespread habit and Microsoft advises against it - several components assume it is present, and disabling it on a domain controller causes problems that are hard to attribute later.

3. **Set the time zone and confirm time sync.** Kerberos rejects authentication when clocks differ by more than five minutes, and the resulting errors do not mention time.

   ```powershell
   Set-TimeZone -Name 'Eastern Standard Time'
   w32tm /query /status
   ```

4. **Apply updates** before joining a domain or installing roles.
5. **Configure the firewall** - leave it on and open what is needed.
6. **Enable remote management** if administering from elsewhere.
7. **Check the disk layout** - keep the OS volume separate from data.

```powershell
Get-ComputerInfo | Select-Object CsName, OsName, OsVersion, WindowsInstallationType
Get-NetIPConfiguration
Get-Volume
```

---

## Server Manager

The default console on Desktop Experience, opening at the dashboard.

| Area | Purpose |
| --- | --- |
| **Local Server** | Every initial-configuration setting in one list - the fastest place to work through the checklist above |
| **All Servers** | Manage multiple servers from one console |
| **Roles** | A tile per installed role, with health |
| **Manage** → Add Roles and Features | The install wizard |
| **Tools** | Launcher for every management console |

Adding remote servers under **All Servers** means administering them without an RDP session to each one - which is both faster and better practice, since signing in interactively to a server leaves credentials in its memory.

### Core Administration Tools

| Tool | Command | Purpose |
| --- | --- | --- |
| Active Directory Users and Computers | `dsa.msc` | Users, groups, computers |
| AD Administrative Center | `dsac.exe` | Recycle Bin, fine-grained password policies |
| Group Policy Management | `gpmc.msc` | GPO authoring and linking |
| DNS Manager | `dnsmgmt.msc` | Zones and records |
| DHCP | `dhcpmgmt.msc` | Scopes, leases, reservations |
| Computer Management | `compmgmt.msc` | Local users, disks, services, Event Viewer |
| Event Viewer | `eventvwr.msc` | Logs |
| Services | `services.msc` | Service state and startup |
| Task Scheduler | `taskschd.msc` | Scheduled jobs |
| Performance Monitor | `perfmon.msc` | Counters and data collector sets |
| Registry Editor | `regedit` | Registry |
| System Configuration | `msconfig` | Boot options |

---

## Remote Management

Administering servers remotely is the better default. It reduces RDP sessions, and an interactive logon to a server leaves credential material in memory that can be harvested if that server is compromised.

**PowerShell remoting:**

```powershell
Enable-PSRemoting -Force                       # on the server
Enter-PSSession -ComputerName FILE01           # interactive
Invoke-Command -ComputerName FILE01 -ScriptBlock { Get-Service }
```

**RSAT** on a Windows 11 admin workstation installs the same consoles locally:

```powershell
Get-WindowsCapability -Online -Name RSAT* | Where-Object State -eq 'NotPresent'
Add-WindowsCapability -Online -Name 'Rsat.ActiveDirectory.DS-LDS.Tools~~~~0.0.1.0'
Add-WindowsCapability -Online -Name 'Rsat.GroupPolicy.Management.Tools~~~~0.0.1.0'
```

**Windows Admin Center** gives a browser-based console covering most of the above, and is the practical way to manage Server Core.

**Remote Desktop** uses TCP 3389. Restrict it to an administrative network rather than exposing it - RDP on the open internet is among the most reliably attacked services there is.

---

## Identity and Session Commands

```powershell
whoami                  # DOMAIN\user
whoami /fqdn            # distinguished name in the directory
whoami /groups          # every group in the current access token
whoami /priv            # privileges held by this session
```

`whoami /groups` is the direct answer to "why can this account do that" - it shows the token as it actually is, including nested group memberships resolved at logon. If a group was added after sign-in, it will not be there until the user signs out and back in, which explains a good proportion of "I was given access but it doesn't work."

```powershell
Get-LocalUser
Get-LocalGroupMember -Group 'Administrators'
query user                    # sessions on this server
```

---

## Security Baseline

Before a server carries anything real:

- **Rename or disable the built-in Administrator** and use a named administrative account. Accountability requires knowing which person acted.
- **Separate admin accounts from daily-use accounts.**
- **Keep the firewall enabled**, including the domain profile.
- **Install only required roles.**
- **Apply updates on a schedule**, and know which servers cannot be patched and why.
- **Enable auditing** - logon events, account management, privilege use.
- **Do not browse the web or read mail from a server.**
- **Back up system state**, and test a restore. An untested backup is an assumption.

```powershell
Get-LocalUser | Select-Object Name, Enabled, LastLogon
Get-NetFirewallProfile | Select-Object Name, Enabled
Get-HotFix | Sort-Object InstalledOn -Descending | Select-Object -First 10
```

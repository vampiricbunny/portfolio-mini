# Print Server and Printer Troubleshooting

Setting up a print server on Windows Server, publishing printers to Active Directory, and working the tickets that follow.

Printing generates more tickets than almost anything else. Most of them come down to the spooler, the driver, or the queue.

---

## Scope It First

One question decides where you work.

**One user, or everyone?**

One user means the client. Restart the spooler on their machine, check their driver, remove and re-add the printer.

Everyone means the print server. Restart the spooler there. Doing it on the server when only one person is affected disrupts every print job in the building for no reason.

---

## Install the Print Server Role

1. **Server Manager**, **Manage**, **Add Roles and Features**.
2. **Role-based or feature-based installation**.
3. Select the server.
4. Under **Server Roles**, tick **Print and Document Services**, **Add Features**.
5. Under **Role Services**, tick **Print Server**. Leave the rest unless you need them.
6. **Install**.

```powershell
Install-WindowsFeature Print-Services -IncludeManagementTools
```

Manage it from **Server Manager**, **Tools**, **Print Management**, or run `printmanagement.msc`.

---

## The Console

**Print Servers**, then your server. Four nodes.

| Node | Holds |
| --- | --- |
| **Drivers** | Installed print drivers |
| **Forms** | Paper sizes |
| **Ports** | How printers connect, usually TCP/IP |
| **Printers** | Installed printers and their status |

---

## Give the Printer a Fixed Address

Do this before adding the printer. A printer on a changing DHCP address is a recurring ticket forever.

**Reservation in DHCP.**

1. **DHCP** console, expand the scope, right-click **Reservations**, **New Reservation**.
2. Name `HP-Accounting`, IP `10.10.10.60`, MAC from the printer's config page.
3. **Add**.

```powershell
Add-DhcpServerv4Reservation -ScopeId 10.10.10.0 -IPAddress 10.10.10.60 `
    -ClientId '00155D8A3C01' -Name 'HP-Accounting' -Description 'Accounting floor'
```

**Then a DNS record**, so you can reference it by name.

1. **DNS Manager**, expand **Forward Lookup Zones**, `vbunnylab.local`.
2. Right-click, **New Host (A or AAAA)**.
3. Name `hp-accounting`, address `10.10.10.60`. Tick **Create associated pointer (PTR) record**.

Now the printer port points at `hp-accounting.vbunnylab.local` instead of an address. Replace the hardware later and you update one DNS record rather than every client.

---

## Add the Printer

1. **Print Management**, **Printers**, right-click, **Add Printer**.
2. **Add a TCP/IP or Web Services Printer by IP address or hostname**.
3. Device type **TCP/IP Device**, hostname `hp-accounting.vbunnylab.local`.
4. Let it detect the driver, or **Install a new driver** and pick the model.
5. Name it something that says where it is. `HP-Accounting-Floor2` beats `HP LaserJet`.
6. Tick **Share this printer** and give it a share name.

If auto-detect fails, choose **Add the printer manually** and select **Standard TCP/IP Port**.

```powershell
Add-PrinterPort -Name 'hp-accounting' -PrinterHostAddress '10.10.10.60'
Add-PrinterDriver -Name 'HP Universal Printing PCL 6'
Add-Printer -Name 'HP-Accounting-Floor2' -DriverName 'HP Universal Printing PCL 6' `
    -PortName 'hp-accounting' -Shared -ShareName 'HP-Accounting'
```

**Use the universal driver where the vendor offers one.** One driver covering the whole fleet means far fewer driver tickets than a model-specific driver per printer.

---

## Permissions

Default permissions let Everyone print. Fine for a shared office printer. Not fine for one in HR or finance.

1. Right-click the printer, **Properties**, **Security**.
2. Remove **Everyone**.
3. **Add**, enter the security group, for example `GG-Accounting-Staff`.
4. Grant **Print**. Leave Manage this printer and Manage documents to admins.

Keep **CREATOR OWNER** so users can cancel their own jobs. Remove it and they have to call you to cancel a misprint.

| Permission | Allows |
| --- | --- |
| Print | Send jobs, manage own jobs |
| Manage this printer | Change settings, share, set permissions |
| Manage documents | Pause, resume, cancel anyone's jobs |

---

## Publish to Active Directory

**Properties**, **Sharing**, tick **List in the directory**.

Users can then search for printers by location instead of being told a UNC path. Handy in a building with a lot of them.

---

## Connect a Client

By UNC, which is the simplest:

```text
\\PRINTSERVER\HP-Accounting
```

Paste that into File Explorer. The driver installs from the server.

```powershell
Add-Printer -ConnectionName '\\PRINTSERVER\HP-Accounting'
Get-Printer | Select-Object Name, DriverName, PortName, PrinterStatus
```

**At scale, deploy with Group Policy Preferences.** **User Configuration**, **Preferences**, **Control Panel Settings**, **Printers**, **New**, **Shared Printer**. Use item-level targeting to scope it to the right group. Nobody should be installing printers by hand.

---

## Stuck Queue

The most common printer ticket there is.

**Try this first.**

1. Right-click the printer, **See what's printing**.
2. **Printer**, **Cancel All Documents**.

Jobs that will not cancel need the spooler stopped, because the files are locked while it runs.

```powershell
Stop-Service Spooler
Remove-Item "$env:SystemRoot\System32\spool\PRINTERS\*" -Force
Start-Service Spooler
```

That is the real fix. Clearing the spool folder is what actually removes a job that refuses to die.

**On the client** when it is one person. **On the print server** when it is everyone.

```powershell
Get-PrintJob -PrinterName 'HP-Accounting-Floor2'
Remove-PrintJob -PrinterName 'HP-Accounting-Floor2' -ID 3
```

---

## Symptom Reference

| Symptom | Likely cause | Fix |
| --- | --- | --- |
| Jobs queue and never print | Spooler stuck | Clear the spool folder |
| Printer shows offline but responds to ping | Port or SNMP status | Untick **SNMP Status Enabled** on the port |
| Garbled output | Wrong driver | Reinstall with the correct driver |
| Only one user affected | Client-side | Restart their spooler, re-add the printer |
| Everyone affected | Server-side | Restart the server spooler |
| Printer disappeared from clients | GPO or share change | Check the GPO and the share |
| Access denied on print | Permissions | Check group membership on the Security tab |
| Prints blank pages | Driver or toner | Test page from the printer's own panel |
| Slow printing | Spooling settings, network | Try **Print directly to the printer** |

**SNMP is worth knowing about.** Windows marks a printer offline when SNMP status queries fail, even though printing works perfectly. Untick **SNMP Status Enabled** in the port configuration and the phantom offline state goes away.

```powershell
Test-NetConnection 10.10.10.60 -Port 9100    # raw print port
Get-Printer | Where-Object PrinterStatus -ne 'Normal'
Get-Service Spooler | Select-Object Status, StartType
```

---

## Driver Updates

Drivers cause a large share of print problems. Update carefully.

1. **Print Management**, **Drivers**.
2. Right-click, **Add Driver**, follow the wizard.
3. Point the printer at the new driver in **Properties**, **Advanced**.
4. Test before rolling out.

Clients cache the old driver. After a server-side driver change they often need the printer removed and re-added. Expect a short burst of tickets and warn the service desk ahead of time.

**Isolate drivers.** Set **Print processor isolation** to Isolated in Print Management so a bad driver crashes its own process instead of the whole spooler.

---

## A Note on Print Spooler Security

The spooler has a long history of serious vulnerabilities. PrintNightmare in 2021 allowed remote code execution and local privilege escalation through it.

Practical steps:

- Keep the spooler patched
- Disable the Print Spooler service on servers that do not print. **Domain controllers do not need it.**
- Restrict which users can install printer drivers through the **Point and Print Restrictions** policy
- Do not let standard users install drivers

```powershell
# on a domain controller or any server with no print role
Get-Service Spooler
Stop-Service Spooler
Set-Service Spooler -StartupType Disabled
```

A domain controller running the print spooler is a standing finding. Turn it off.

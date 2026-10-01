# Windows Device Enrollment

Enrolling Windows machines into Intune with Autopilot, then pushing configuration, compliance and updates to them.

The goal is a laptop that ships sealed to the user. They open it, sign in, and it builds itself. IT never touches the hardware.

---

## Prerequisites

- Intune licence on the user. Business Premium, E3 or E5
- Automatic enrollment turned on in Entra ID
- Windows 10 or 11 **Pro, Enterprise or Education**. Home cannot join
- Groups to assign policy to, ideally dynamic

**Turn on automatic enrollment first.**

**Entra admin center**, **Devices**, **Mobility (MDM and MAM)**, **Microsoft Intune**. Set **MDM user scope** to All, or to a pilot group.

Skip this and devices join Entra ID but never enrol in Intune. Everything else looks configured and nothing applies.

---

## Autopilot

### Get the Hardware Hash

Vendors can register devices for you, which is the whole point at scale. For a lab or an existing machine, collect it yourself.

```powershell
Install-Script -Name Get-WindowsAutopilotInfo -Force
Set-ExecutionPolicy -Scope Process -ExecutionPolicy RemoteSigned
Get-WindowsAutopilotInfo -OutputFile .\AutopilotHWID.csv
```

That produces a CSV with the serial, Windows product ID and hardware hash.

### Import It

1. **Devices**, **Enrollment**, **Devices** under Windows Autopilot Deployment Program.
2. **Import**, upload the CSV.
3. Wait. Import takes up to 15 minutes.

### Build a Deployment Profile

1. **Devices**, **Enrollment**, **Deployment Profiles**, **Create profile**, **Windows PC**.
2. Name it.
3. **Convert all targeted devices to Autopilot**: Yes.
4. Out of box experience:

   | Setting | Value | Reason |
   | --- | --- | --- |
   | Deployment mode | User-driven | Standard laptop handover |
   | Join type | Microsoft Entra joined | Cloud-only. Pick Hybrid only if you need line-of-sight to a DC |
   | Microsoft Software Licence Terms | Hide | Nobody reads them |
   | Privacy settings | Hide | Set them by policy instead |
   | Account change options | Hide | Stops the user renaming the device |
   | User account type | **Standard** | Not Administrator |
   | Allow pre-provisioned deployment | Yes | Lets IT pre-stage the heavy work |
   | Apply device name template | Yes, `VB-%SERIAL%` | Consistent naming |

5. Assign to a group.

> **User account type Standard, not Administrator.** The default gives the first user local admin on their own laptop. That undoes a large part of the security value of managing it at all. Set it to Standard and grant admin by exception.

---

## Configuration Profiles

**Devices**, **Configuration**, **Create**, **New Policy**, Windows 10 and later.

Two ways in. **Templates** are guided and grouped by area. **Settings catalog** exposes every available setting and is the better option once you know what you are looking for.

Worth setting early:

| Profile | Covers |
| --- | --- |
| Device restrictions | Password rules, camera, storage, app store |
| Endpoint protection | Defender, firewall, BitLocker, Attack Surface Reduction |
| Device features | Start menu layout, branding |
| Wi-Fi | Corporate SSID and certificates |
| Certificates | SCEP or PKCS for 802.1X and VPN |
| OneDrive | Known Folder Move, Files On-Demand |

**Endpoint protection is the one to do first.** BitLocker with key escrow to Entra ID, Defender on with tamper protection, firewall on for all profiles, and Attack Surface Reduction rules in audit mode to start.

Assign each profile to a group, then check **Devices**, **Monitor**, **Assignment status** to confirm it actually landed.

---

## Compliance

Covered fully in [Compliance Policies](Compliance-Policies.md).

Short version. Build a Windows compliance policy requiring BitLocker, Secure Boot, a minimum OS build, firewall and antivirus. Then create a conditional access policy requiring a compliant device.

Without the conditional access half, compliance is a report and nothing more.

---

## Update Rings

**Devices**, **Windows updates**, **Update rings**, **Create profile**.

Rings let you stage updates instead of shipping them to everyone at once.

| Ring | Members | Quality update deferral | Feature update deferral |
| --- | --- | --- | --- |
| Pilot | IT, volunteers | 0 days | 0 days |
| Broad | Most of the fleet | 7 days | 30 days |
| Critical | Finance, exec, anything fragile | 14 days | 60 days |

Settings worth getting right:

- **Automatic update behaviour**: Auto install and restart at a scheduled time
- **Active hours**: 8am to 6pm, so nothing reboots mid-meeting
- **Deadline**: 7 days for quality, 14 for feature
- **Grace period**: 2 days
- **Restart notifications**: on. Silent reboots destroy trust

A pilot ring that gets updates first is how you find the one that breaks your line-of-business app before it reaches 500 machines.

---

## Enrolling a Machine

For a lab, a VM works fine.

1. Build a VM. 4 GB RAM, 2 vCPUs, 64 GB disk, Windows 11 Pro.
2. Install Windows and reach the out of box experience.
3. Connect to a network.
4. At **How would you like to set up**, choose **Set up for work or school**.
5. Sign in with the work account.
6. Complete MFA.
7. The device joins Entra ID and enrols in Intune automatically.
8. Policies and assigned apps start arriving.

Without Autopilot, enrol an existing machine through **Settings**, **Accounts**, **Access work or school**, **Connect**, then **Join this device to Microsoft Entra ID**.

---

## Verify

**On the device:**

```powershell
dsregcmd /status
```

Look for `AzureAdJoined : YES` and `DomainJoined : NO` for a cloud-only device.

Check the MDM enrollment under **Settings**, **Accounts**, **Access work or school**, click the account, **Info**. That page also has a **Sync** button, which is the fastest way to pull policy on demand.

**In the console:**

**Devices**, **All devices**, find the machine. Check ownership, compliance, last check-in, and which profiles applied.

---

## Common Problems

| Symptom | Cause | Fix |
| --- | --- | --- |
| Joins Entra ID, never enrols | Automatic enrollment scope not set | Set MDM user scope in Entra |
| "Your organisation does not support this" | No Intune licence | Assign one |
| Autopilot profile not applied | Hash not imported, or profile not assigned | Check the device list and assignment |
| Policy not arriving | Assigned to a group the user is not in | Check group membership |
| Device shows Not evaluated | No compliance policy targets it | Check assignments |
| Windows Home | Edition limitation | Pro or better |
| Apps not installing | Assignment or dependency | Check **Apps**, **Monitor**, install status |
| Enrolled twice | Manual join before Autopilot ran | Remove the duplicate record |

Force a policy sync from **Settings**, **Accounts**, **Access work or school**, **Info**, **Sync**. Intune checks in roughly every 8 hours on its own, so waiting for a natural cycle wastes time when testing.

---

## Practices

- Standard user, not administrator, in the Autopilot profile
- Dynamic groups so assignment keeps itself accurate
- Device naming template, so the fleet is readable
- Pilot ring before broad rollout, always
- BitLocker keys escrowed to Entra ID, and verify one before you need it
- Test the whole flow on a spare machine end to end before handing one to a user

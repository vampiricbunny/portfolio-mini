# Azure Virtual Machines

Building Windows VMs in Azure for lab work, and the settings that stop a lab VM turning into an incident or a bill.

An Azure VM with RDP open to the internet gets found within hours. That is not an exaggeration. Automated scanners sweep the public ranges constantly, and a default deployment leaves 3389 open to `0.0.0.0/0`.

---

## Before You Build

Three things to decide up front, because changing them later means rebuilding.

**Region.** Pick one close to you. It affects latency and price.

**Size.** `B2s` or `B2ms` is enough for a lab domain controller. B-series are burstable and cheap. `D2s_v3` if you want consistent performance.

**Disk.** Standard SSD for a lab. Premium SSD costs noticeably more and a lab will not notice the difference.

---

## Create the VM

1. Portal, **Virtual machines**, **Create**, **Azure virtual machine**.
2. **Basics**:

   | Field | Value |
   | --- | --- |
   | Resource group | `rg-vbunnylab` |
   | Name | `DC01` |
   | Region | Nearest |
   | Image | Windows Server 2022 Datacenter, Azure Edition |
   | Size | `Standard_B2ms` |
   | Username | Not `admin` or `administrator`. Azure rejects both |
   | Password | Long and random |
   | Inbound ports | **None** |

3. **Disks**: Standard SSD, delete with VM ticked.
4. **Networking**: new virtual network, **no public inbound ports**.
5. **Management**: enable auto-shutdown. This one matters.
6. **Review + create**.

> **Set inbound ports to None.** The wizard offers to open RDP for you and it is the wrong default. Access comes through Bastion or a VPN, covered below.

> **Turn on auto-shutdown.** A lab VM left running is the single most common way people get an Azure bill they did not expect. Set it to shut down every evening. You can always start it again.

### Resource Groups

A resource group holds resources that share a lifecycle. Everything for one lab goes in one group. Delete the group, everything goes with it, and nothing is left running quietly.

That is the cleanest way to tear down a lab. One delete.

---

## Getting In

### Azure Bastion, the right way

Bastion gives you RDP in the browser. No public IP on the VM, nothing exposed.

1. **Bastion** on the VM blade, **Deploy Bastion**.
2. It needs a subnet named exactly `AzureBastionSubnet`, `/26` or larger.
3. Connect from the portal with the VM credentials.

Bastion costs money per hour. For a lab, the Developer SKU is cheaper, or deploy it only when needed.

### Just-in-Time Access

If you do need a public IP, use JIT rather than leaving the port open.

**Microsoft Defender for Cloud**, **Workload protections**, **Just-in-time VM access**. Request access, get a time-limited rule for your IP only, and it closes itself afterwards.

### Point-to-Site VPN

Best option for a multi-VM lab. Connect to the virtual network and reach everything by private IP, the same as being on the LAN.

### What Not To Do

Do not open 3389 to Any. A VM with RDP exposed and a weak password gets brute forced, and the usual outcome is crypto mining on your subscription, at your cost.

---

## Network Security Groups

The firewall in front of the VM. Default rules deny inbound from the internet and allow everything outbound.

If you add a rule, scope the source.

| Field | Value |
| --- | --- |
| Source | **My IP address**, never Any |
| Destination port | 3389 |
| Action | Allow |
| Priority | 300 |

Home IP addresses change, so this needs updating. That friction is why Bastion is better.

```powershell
Get-AzNetworkSecurityGroup -ResourceGroupName rg-vbunnylab |
    Select-Object -ExpandProperty SecurityRules |
    Select-Object Name, Direction, Access, SourceAddressPrefix, DestinationPortRange
```

Check for any rule with source `*` or `Internet`. That is what to look for in a review.

---

## Static Private IP

A domain controller needs a fixed address. Azure gives dynamic by default.

**VM**, **Networking**, click the NIC, **IP configurations**, select `ipconfig1`, set **Assignment** to **Static**.

Set it inside the VM's subnet range. Azure reserves the first four addresses in every subnet, so start at `.4`.

**Do not set a static IP inside the guest OS.** Azure manages the address through DHCP. Setting it manually in Windows breaks networking. Set it static in the portal and leave the guest on DHCP. This catches out people coming from on-premises.

---

## Building a Domain Controller

Same as on-premises, with two Azure-specific points.

1. Set the private IP static in the portal.
2. Add a data disk for AD DS. **Host caching: None.** The database does not tolerate write caching.
3. Promote as normal. See [Building the Lab](../Windows-Server-2025/Active-Directory-Setup.md).
4. Update the virtual network's DNS servers to point at the DC's private IP.
5. Restart the other VMs so they pick up the new DNS.

Step 4 is the one people miss. Domain members must use the DC for DNS, not Azure's default resolver, or they cannot find the domain.

---

## Cost Control

Azure bills by the hour whether you are using it or not.

| Action | Effect |
| --- | --- |
| **Stop (deallocate)** from the portal | Compute charges stop. Storage still bills |
| Shut down from inside Windows | **Still billed.** The VM stays allocated |
| Auto-shutdown schedule | Set it on every lab VM |
| Delete the resource group | Everything goes |

**Shutting down from inside the guest does not stop the bill.** It has to be deallocated from the portal or by CLI. This surprises people the first time.

```powershell
Stop-AzVM -ResourceGroupName rg-vbunnylab -Name DC01 -Force
Start-AzVM -ResourceGroupName rg-vbunnylab -Name DC01
Remove-AzResourceGroup -Name rg-vbunnylab -Force
```

Set a budget alert on the subscription. **Cost Management**, **Budgets**. Even a small one will tell you when something is running that should not be.

Public IPs, disks and Bastion keep billing after a VM is deallocated. Deleting the resource group is what actually stops everything.

---

## Security Checklist

- No public inbound ports. Bastion, JIT or VPN
- Auto-shutdown on every lab VM
- Budget alert on the subscription
- NSG rules scoped to a source, never Any
- Unique admin username, not `admin`
- Disk encryption on, which is the default
- MFA on the Azure account itself
- Delete the resource group when the lab is finished

```powershell
# anything exposed to the internet
Get-AzNetworkSecurityGroup | ForEach-Object {
    $_.SecurityRules | Where-Object {
        $_.Direction -eq 'Inbound' -and $_.Access -eq 'Allow' -and
        $_.SourceAddressPrefix -in '*','Internet','0.0.0.0/0'
    } | Select-Object @{n='NSG';e={$_.Name}}, DestinationPortRange, SourceAddressPrefix
}
```

Run that before you leave a lab running. It is the same check worth running against a real subscription.

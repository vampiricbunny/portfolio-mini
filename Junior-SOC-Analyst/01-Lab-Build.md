# 01 - Lab Build

Building the environment on Proxmox VE. Segmentation, virtual machines, and the firewall policy that keeps the attacker segment one way.

---

## Design Goals

Four things had to be true before any detection work started.

**Segmented.** Flat networks hide lateral movement. If everything is one broadcast domain there is no east-west traffic to inspect, because nothing crosses a boundary.

**One way in.** The red segment reaches corporate. Corporate does not reach red. This is not for the attacker's benefit, it is so that anything corporate sends toward red is by definition suspicious and shows up in the firewall log.

**Isolated from the house.** Nothing routes to the physical LAN. A second DHCP server on a home network fights the router, and a lab domain controller answering DNS for real devices breaks them.

**Snapshottable.** Attack simulation destroys machines. Every VM gets a clean snapshot before a run so the whole lab rolls back in under a minute.

---

## Host

| | |
| --- | --- |
| Hypervisor | Proxmox VE 8.2 |
| CPU | 8 cores, 16 threads |
| RAM | 64 GB |
| Storage | 1 TB NVMe for VM disks, 2 TB HDD for backups |
| Physical NIC | `enp3s0`, single uplink |

64 GB is comfortable. It runs on 32 GB if the Wazuh indexer heap is reduced and one workstation is left shut down.

---

## Networking

### Bridges

Two bridges. `vmbr0` is the management uplink to the house network so I can reach the Proxmox web interface. `vmbr1` is VLAN aware with no physical port at all, which makes it an internal switch that only the VMs and the firewall touch.

`/etc/network/interfaces`:

```text
auto lo
iface lo inet loopback

auto enp3s0
iface enp3s0 inet manual

auto vmbr0
iface vmbr0 inet static
    address 192.168.1.50/24
    gateway 192.168.1.1
    bridge-ports enp3s0
    bridge-stp off
    bridge-fd 0

auto vmbr1
iface vmbr1 inet manual
    bridge-ports none
    bridge-stp off
    bridge-fd 0
    bridge-vlan-aware yes
    bridge-vids 2-4094
```

`bridge-ports none` is the important line. Without it the lab VLANs leak onto the physical network.

Apply it:

```bash
ifreload -a
ip -br link show type bridge
```

### VLANs

| VLAN | Name | Subnet | Contains |
| --- | --- | --- | --- |
| 10 | CORP | 10.20.10.0/24 | DC01, FS01, WS11-01, WS11-02 |
| 20 | SOC | 10.20.20.0/24 | SIEM01 |
| 30 | MGMT | 10.20.30.0/24 | OPNsense management interface |
| 99 | RED | 10.20.99.0/24 | KALI01 |

Splitting SOC from CORP matters more than it looks. If the SIEM sits in the same segment as the hosts it monitors, an attacker who lands on a workstation can reach the thing holding the evidence. Keeping it separate, and only allowing agent traffic inbound on 1514 and 1515, means compromising a workstation does not compromise the log store.

---

## Firewall

OPNsense runs as a VM with one interface per VLAN, all on `vmbr1` with the VLAN tag set on the virtual NIC.

### Interfaces

| Interface | VLAN tag | Address |
| --- | --- | --- |
| WAN | untagged on `vmbr0` | DHCP from the house router |
| CORP | 10 | 10.20.10.1/24 |
| SOC | 20 | 10.20.20.1/24 |
| MGMT | 30 | 10.20.30.1/24 |
| RED | 99 | 10.20.99.1/24 |

### Rules

Order matters. These are read top down, first match wins.

| # | Interface | Source | Destination | Port | Action | Reason |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | CORP | CORP net | SOC net | 1514, 1515 | Pass | Wazuh agent enrollment and events |
| 2 | CORP | CORP net | RED net | any | Block, log | Corporate should never talk to red. Logging this is the point |
| 3 | CORP | CORP net | MGMT net | any | Block | No path to the firewall from user space |
| 4 | CORP | CORP net | any | any | Pass | Internet and intra-VLAN |
| 5 | SOC | SOC net | CORP net | any | Block | The SIEM does not need to initiate to hosts |
| 6 | SOC | SOC net | any | 80, 443 | Pass | Updates and threat feeds |
| 7 | RED | RED net | CORP net | any | Pass | The attack path |
| 8 | RED | RED net | SOC net | any | Block | The attacker must not reach the evidence |
| 9 | RED | RED net | MGMT net | any | Block | No firewall access |
| 10 | any | any | any | any | Block, log | Default deny |

**Rule 2 is the useful one.** It never passes traffic. It exists so that the moment something on a workstation tries to reach 10.20.99.0/24, the firewall log records it and Suricata sees it. That is a free detection for outbound command and control toward a known bad segment.

**Rule 8 is the one people skip.** An attacker who can write to the SIEM can delete the evidence of how they got in. In a real environment this is the difference between an incident you can reconstruct and one you cannot.

### Suricata

Enabled on the CORP interface in IPS mode off, detection only. Rulesets: ET Open and the Abuse.ch feeds. Detection only is deliberate. Blocking is a different job, and at Tier 1 the value is seeing the alert, not dropping the packet.

---

## Virtual Machines

### Inventory

| VM ID | Name | OS | vCPU | RAM | Disk | VLAN |
| --- | --- | --- | --- | --- | --- | --- |
| 100 | FW01 | OPNsense 24.7 | 2 | 2 GB | 32 GB | all |
| 101 | DC01 | Windows Server 2022 | 2 | 4 GB | 80 GB | 10 |
| 102 | FS01 | Windows Server 2022 | 2 | 4 GB | 80 GB | 10 |
| 110 | WS11-01 | Windows 11 Pro | 2 | 4 GB | 60 GB | 10 |
| 111 | WS11-02 | Windows 11 Pro | 2 | 4 GB | 60 GB | 10 |
| 120 | SIEM01 | Ubuntu Server 22.04 | 4 | 12 GB | 200 GB | 20 |
| 199 | KALI01 | Kali Linux 2024.3 | 2 | 4 GB | 60 GB | 99 |

SIEM01 gets the most of everything. The Wazuh indexer is OpenSearch underneath, and OpenSearch is unhappy below 8 GB of heap. 12 GB of RAM gives it 6 GB of heap with room for the manager and dashboard alongside.

### Creating a VM from the command line

The web interface is fine, but scripting it means the lab rebuilds identically.

```bash
qm create 110 \
  --name WS11-01 \
  --memory 4096 \
  --cores 2 \
  --cpu host \
  --net0 virtio,bridge=vmbr1,tag=10 \
  --scsihw virtio-scsi-single \
  --scsi0 local-nvme:60,discard=on,ssd=1 \
  --ide2 local:iso/Win11_24H2.iso,media=cdrom \
  --ostype win11 \
  --bios ovmf \
  --efidisk0 local-nvme:1,efitype=4m,pre-enrolled-keys=1 \
  --tpmstate0 local-nvme:1,version=v2.0 \
  --machine q35 \
  --agent enabled=1
```

Windows 11 needs the last four lines. UEFI, secure boot keys, a virtual TPM 2.0, and the q35 machine type. Leave any of them out and setup refuses to install.

Windows also does not ship VirtIO drivers, so attach the VirtIO ISO as a second CD before first boot:

```bash
qm set 110 --ide3 local:iso/virtio-win.iso,media=cdrom
```

At the disk selection screen, choose Load driver and point it at `vioscsi\w11\amd64`.

### Windows 11 in a lab without a Microsoft account

Setup insists on network and an account. At the "Let's connect you to a network" screen press Shift + F10 for a command prompt and run:

```text
OOBE\BYPASSNRO
```

The machine reboots and the network step becomes skippable, which lets you create a local account and then domain join afterwards.

---

## Domain

`vbunnylab.local`, forest and domain functional level 2016.

```powershell
Install-WindowsFeature AD-Domain-Services -IncludeManagementTools

Install-ADDSForest `
    -DomainName 'vbunnylab.local' `
    -DomainNetbiosName 'VBUNNYLAB' `
    -ForestMode 'WinThreshold' `
    -DomainMode 'WinThreshold' `
    -InstallDns `
    -DatabasePath 'C:\Windows\NTDS' `
    -SysvolPath 'C:\Windows\SYSVOL' `
    -LogPath 'C:\Windows\NTDS' `
    -NoRebootOnCompletion:$false `
    -Force
```

### Accounts

Deliberately realistic, including the weak ones. A lab where every password is 24 random characters detects nothing, because nothing succeeds.

| Account | Type | Purpose |
| --- | --- | --- |
| `vampiricbunny` | Domain Admin | Administration |
| `vbunny` | Standard user | Patient zero |
| `m.calloway` | Standard user | Second workstation, lateral movement target |
| `svc_backup` | Service account | Weak password on purpose, the spray target |
| `svc_sql` | Service account | SPN set, Kerberoasting target |
| `breakglass` | Domain Admin | Emergency access, monitored |

`svc_backup` has the password `Summer2025!`. That is the point. It is exactly the shape of password that survives a complexity policy and dies to a spray, and if the lab does not contain one then the spray detection never gets a true positive to prove itself against.

### OU structure

```text
vbunnylab.local
├── Corp
│   ├── Users
│   ├── Workstations
│   ├── Servers
│   └── ServiceAccounts
└── Domain Controllers
```

Flat enough to be manageable, structured enough that GPOs can be scoped by machine type. The audit policy GPO links to Corp and applies to everything under it.

---

## Snapshots

Before every attack run:

```bash
for id in 101 102 110 111; do
  qm snapshot $id clean-$(date +%Y%m%d) --description "Pre-simulation clean state"
done
```

Rolling back:

```bash
qm rollback 110 clean-20260812
```

**Do not snapshot SIEM01 with the rest of them.** The whole point is that the log data survives the rollback. Rolling back the SIEM alongside the victims erases the evidence you just generated, which I learned by doing it once.

---

## Build Order

Order matters more than it looks. Each step depends on the one before.

1. **Proxmox host.** Install, configure bridges, apply with `ifreload -a`
2. **OPNsense.** Interfaces, then rules, then verify with a ping test in both directions
3. **DC01.** Static IP, promote, confirm SRV records exist in DNS
4. **DHCP.** Scope on DC01 for VLAN 10, DHCP relay on the OPNsense CORP interface
5. **FS01.** Domain join, create shares
6. **Workstations.** Domain join, confirm they resolve `vbunnylab.local` and authenticate
7. **SIEM01.** Wazuh all-in-one, then verify the dashboard loads before touching agents
8. **Agents.** Windows hosts, confirm each shows Active in the manager
9. **Audit policy and Sysmon.** GPO push, verify events arriving
10. **KALI01.** Last, after everything else is proven working

Standing up the attacker before the logging works is the classic mistake. You run the attack, see nothing, and then spend an hour not knowing whether the attack failed or the detection did.

---

## Verification

Before moving on, each of these should pass.

```powershell
# From WS11-01: the domain answers
nltest /dsgetdc:vbunnylab.local
Test-NetConnection 10.20.10.10 -Port 389

# From WS11-01: the SIEM is reachable on agent ports only
Test-NetConnection 10.20.20.10 -Port 1514   # expect success
Test-NetConnection 10.20.20.10 -Port 22     # expect failure

# From WS11-01: red is unreachable, and this attempt gets logged
Test-NetConnection 10.20.99.10 -Port 80     # expect failure
```

```bash
# From KALI01: corp is reachable
nmap -sn 10.20.10.0/24

# From KALI01: the SIEM is not
nc -zv 10.20.20.10 1514    # expect refused
```

If the third PowerShell test succeeds, rule 2 is in the wrong position. If the last test succeeds, rule 8 is missing and the attacker can reach your evidence.

---

Next: [02-Telemetry-and-Logging.md](02-Telemetry-and-Logging.md)

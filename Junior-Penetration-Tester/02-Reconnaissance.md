# 02 - Reconnaissance

Finding out what is on the network before touching any of it.

---

## The Goal

Turn "there is a network here" into "here are the six machines, here is what each one runs, and here is where I would start."

You do this before exploitation, thoroughly, because time spent here is repaid many times over later. **The engagement is usually won or lost in enumeration, not in exploitation.**

---

## Start Passive

Before sending a single packet at a host, listen.

```bash
# Watch the network for a few minutes. Who is talking, and about what
sudo responder -I eth0 -A
```

`-A` is analyse mode. It listens and reports without responding to anything. You learn machine names, the domain, and which hosts are chatty, all without touching a target.

**Passive first is a habit worth building.** On a real engagement it tells you the naming convention and the domain before you have announced your presence with a scan.

---

## Host Discovery

Find what is alive.

```bash
# Quick sweep of the subnet
sudo nmap -sn 10.50.10.0/24 -oA recon/01-ping-sweep
```

`-sn` is a ping sweep, no port scan. It answers one question: which addresses respond.

```text
Nmap scan report for 10.50.10.10   (DC01)
Nmap scan report for 10.50.10.20   (SRV-FILE01)
Nmap scan report for 10.50.10.30   (SRV-WEB01)
Nmap scan report for 10.50.10.101  (WS-01)
Nmap scan report for 10.50.10.102  (WS-02)
Nmap scan report for 10.50.10.200  (KALI, that is me)
```

Five targets.

**A ping sweep misses hosts that block ICMP.** If you expect more machines than you find, follow up with an ARP scan, which works at a lower level and is harder to hide from on a local network:

```bash
sudo nmap -sn -PR 10.50.10.0/24
```

---

## Port Scanning

For each live host, find the open ports.

### Fast first pass

```bash
# All TCP ports, fast, no service detection yet
sudo nmap -p- --min-rate 2000 -T4 10.50.10.10 -oA recon/02-dc01-allports
```

`-p-` is all 65535 ports. `--min-rate 2000` pushes the speed. This tells you which ports are open, quickly.

### Then go deep on what is open

```bash
# Service and version detection, plus default scripts, on the open ports only
sudo nmap -p 53,88,135,139,389,445,464,593,636,3268,3269,5985,9389 \
    -sC -sV 10.50.10.10 -oA recon/03-dc01-detailed
```

Two passes is faster than one deep scan of all ports. Find the open ports fast, then spend the time only on those.

### Always save the output

`-oA` writes three formats at once: normal, greppable, and XML. The XML is what you feed into other tools and into your report later.

---

## Reading the Results

The open ports tell you what each machine is. Learn to read them at a glance.

### DC01

```text
53/tcp    open  domain         Simple DNS Plus
88/tcp    open  kerberos-sec   Microsoft Windows Kerberos
135/tcp   open  msrpc          Microsoft Windows RPC
139/tcp   open  netbios-ssn
389/tcp   open  ldap           Microsoft Windows AD LDAP
445/tcp   open  microsoft-ds
464/tcp   open  kpasswd5
636/tcp   open  ldapssl
3268/tcp  open  ldap           Global Catalog
5985/tcp  open  wsman          WinRM
9389/tcp  open  adws           AD Web Services
```

**This is a domain controller, and it is obvious.** Kerberos on 88, LDAP on 389 and 636, the global catalog on 3268, DNS on 53. That combination is only ever a domain controller.

WinRM on 5985 is worth noting now. It is a remote management path, and it becomes the way in during lateral movement.

### The fingerprint table

Learn these combinations and you can identify most hosts from the port scan alone.

| Ports open | What it is |
| --- | --- |
| 88, 389, 636, 3268 | Domain controller |
| 445, 139, no Kerberos | File server or workstation |
| 80, 443 | Web server |
| 1433 | Microsoft SQL Server |
| 3306 | MySQL |
| 3389 | Remote Desktop |
| 5985, 5986 | WinRM, remote management |
| 22 | SSH, usually Linux |
| 25, 110, 143 | Mail server |

### SRV-FILE01

```text
135/tcp   open  msrpc
139/tcp   open  netbios-ssn
445/tcp   open  microsoft-ds
1433/tcp  open  ms-sql-s       Microsoft SQL Server 2019
5985/tcp  open  wsman
```

A file server that also runs SQL Server. **The SQL Server on 1433 is interesting**, because there was an SPN for `MSSQLSvc` on the `svc_sql` account, which makes it a Kerberoasting target. Recon and enumeration feed each other.

### SRV-WEB01

```text
22/tcp    open  ssh            OpenSSH 8.9
80/tcp    open  http           nginx 1.18.0
443/tcp   open  ssl/http       nginx 1.18.0
```

Linux, a web server. `nginx 1.18.0` is a version number, and version numbers are the start of a finding (PT-12).

### The workstations

```text
135/tcp   open  msrpc
139/tcp   open  netbios-ssn
445/tcp   open  microsoft-ds
3389/tcp  open  ms-wbt-server
5985/tcp  open  wsman
```

Both similar. RDP and WinRM both open, which are both lateral movement paths.

---

## Building the Picture

After recon, before enumeration, write down what you have.

```text
DC01         10.50.10.10   Domain controller, ptlab.local
SRV-FILE01   10.50.10.20   File server + SQL Server 2019
SRV-WEB01    10.50.10.30   Linux, nginx web server
WS-01        10.50.10.101  Windows 11 workstation
WS-02        10.50.10.102  Windows 11 workstation
```

### First questions

- **The domain is `ptlab.local`.** Everything Windows is joined to it, so Active Directory attacks are the likely path
- **SMB is open everywhere.** That is the enumeration starting point with no credentials
- **A SQL service account has an SPN.** Kerberoasting is on the table once I have any domain credential
- **WinRM is open on the servers and workstations.** That is how I move once I have credentials
- **The web server runs a specific nginx version.** Worth checking, low priority

**Recon does not find vulnerabilities. It finds the attack surface.** The vulnerabilities come from enumerating that surface, which is the next module.

---

## A Note on Noise

Everything in this module is loud. A ping sweep and a full port scan are exactly what an intrusion detection system is built to catch.

On a real engagement you decide how quiet to be based on the scope. A standard internal test does not need to be stealthy, because the goal is coverage, not evasion. A red team engagement is the opposite.

**This is worth understanding for the blue team side too.** In [SOC-01](../Junior-SOC-Analyst/) a port scan is a detection. Here it is step one. Same event, two perspectives, and understanding both is what makes you useful.

```bash
# If you did need to be quieter: slower, fewer ports, no scripts
sudo nmap -sS -T2 -p 445,3389,5985 10.50.10.0/24
```

`-T2` is slow. Slower scans are harder to spot against background noise, at the cost of taking much longer.

---

## Checklist

- [ ] Passive listening done before any active scan
- [ ] Host discovery complete, every live host identified
- [ ] Full TCP port scan on each host
- [ ] Service and version detection on open ports
- [ ] All output saved with `-oA`
- [ ] Each host identified by role from its ports
- [ ] A written summary of the attack surface
- [ ] First questions noted for enumeration

---

Next: [03-Enumeration.md](03-Enumeration.md)

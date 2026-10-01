# Network Troubleshooting

A method for isolating network faults, plus the command reference behind it.

Most network tickets are solved by working outward from the machine in a fixed order and stopping at the first layer that fails. Guessing (swapping DNS to `8.8.8.8`, reinstalling the adapter, rebooting the router) sometimes works, but it does not tell you what was wrong, which means it will happen again.

---

## Method: Work Outward, Stop at the First Failure

Each step assumes everything before it succeeded. The step that fails is the fault.

| # | Question | Command | Failure means |
| --- | --- | --- | --- |
| 1 | Is the interface up? | `Get-NetAdapter` | Cable, driver, disabled adapter, dead switch port |
| 2 | Does it have a valid address? | `Get-NetIPConfiguration` | DHCP failure, see APIPA below |
| 3 | Can it reach its own gateway? | `Test-NetConnection 10.10.10.1` | Local segment, VLAN, switch |
| 4 | Can it reach beyond the gateway? | `Test-NetConnection 8.8.8.8` | Routing, firewall, WAN link |
| 5 | Can it resolve names? | `Resolve-DnsName vbunnylab.local` | DNS, see [DNS](DNS.md) |
| 6 | Can it reach the service port? | `Test-NetConnection host -Port 443` | Firewall rule, service down |

**Scope it first.** One user or everyone? One machine or the whole floor? Wired or wireless? A fault affecting one machine is local; a fault affecting a subnet is infrastructure. That single question routes the ticket correctly and saves an hour of looking in the wrong place.

---

## Test-NetConnection Over ping

`ping` answers one question: does ICMP come back. That is genuinely useful, but plenty of hosts and firewalls drop ICMP while the service itself is fine, so a failed ping regularly gets a healthy server declared down.

```powershell
Test-NetConnection fileserver.vbunnylab.local -Port 445    # SMB
Test-NetConnection dc01.vbunnylab.local -Port 389          # LDAP
Test-NetConnection dc01.vbunnylab.local -Port 53           # DNS
Test-NetConnection mail.example.com -Port 993              # IMAPS

Test-NetConnection 8.8.8.8 -TraceRoute
Test-NetConnection -ComputerName fileserver -InformationLevel Detailed
```

It reports ping result, TCP handshake, name resolution and the route in one command, covering steps 3 through 6 of the method above in a single call.

---

## The Command Toolkit

### Interface and Address

```powershell
Get-NetAdapter | Select-Object Name, Status, LinkSpeed, MacAddress
Get-NetIPConfiguration
Get-NetIPAddress -AddressFamily IPv4
Get-NetRoute -AddressFamily IPv4
Get-DnsClientServerAddress
```

```cmd
ipconfig                :: quick view
ipconfig /all           :: MAC, DHCP server, lease times, DNS suffix
```

`ipconfig /all` is the highest-value single command in network support. It shows whether the address came from DHCP, which server issued it, when the lease expires, and which DNS servers are in use. Most of the method above can be short-circuited by reading it carefully.

### Reset Sequence

```cmd
ipconfig /release
ipconfig /renew
ipconfig /flushdns
netsh winsock reset      :: reboot required
netsh int ip reset       :: reboot required
```

Run these in order and only as far as needed. `netsh winsock reset` is a genuine repair for a corrupted network stack, not a routine step. It resets third-party layered service providers and requires a reboot.

### Path and Name

```powershell
Resolve-DnsName google.com
Resolve-DnsName fileserver.vbunnylab.local -Server 10.10.10.10
Test-NetConnection google.com -TraceRoute
```

```cmd
tracert google.com       :: hop-by-hop path
pathping google.com      :: slower, but shows per-hop packet loss
nslookup google.com
```

**`pathping` beats `tracert` for intermittent faults.** `tracert` shows the path; `pathping` samples each hop over roughly five minutes and reports loss percentages, which is how you distinguish "one hop is slow" from "one hop is dropping 8% of packets".

> Timeouts partway through a `tracert` are usually not a fault. Many routers deprioritise or drop ICMP TTL-expired replies while still forwarding traffic normally. Only a failure at the **final** hop, or loss that persists to the destination, is meaningful.

### Sessions and Ports

```powershell
Get-NetTCPConnection -State Established | Select-Object LocalPort, RemoteAddress, RemotePort, OwningProcess
Get-NetTCPConnection -State Listen | Select-Object LocalAddress, LocalPort, OwningProcess
Get-Process -Id (Get-NetTCPConnection -LocalPort 445).OwningProcess
```

```cmd
netstat -ano             :: all connections with owning PID
netstat -ab              :: with executable names (needs admin)
arp -a                   :: ARP cache, IP to MAC
```

Mapping a port to the process that owns it is the step people skip. "Port 445 is in use" is not actionable; "port 445 is held by PID 4, which is System" is.

---

## APIPA: the 169.254 Address

An address in `169.254.0.1` to `169.254.255.254` means the client asked for DHCP and never got an answer. Windows self-assigns so the machine can still talk on the local segment.

Causes, in the order worth checking:

1. **DHCP server down, or scope not activated.** See [DHCP](DHCP.md)
2. **Scope exhausted.** No free addresses left in the pool
3. **Server not authorised in AD.** A Windows DHCP server refuses to serve until it is
4. **Broadcast not reaching the server.** On a routed subnet this needs an IP helper address on the router
5. **Physical.** Dead port, bad cable, wrong VLAN

```powershell
ipconfig /release; ipconfig /renew
Get-DhcpServerv4Scope                                   # on the server
Get-DhcpServerv4ScopeStatistics -ScopeId 10.10.10.0     # is the pool full?
```

If renewal succeeds, it was transient. If it returns APIPA again, the fault is upstream of the client and no amount of adapter resetting will fix it.

---

## Symptom Reference

| Symptom | Likely cause | First check |
| --- | --- | --- |
| No IP at all, "Media disconnected" | Physical or driver | Cable, `Get-NetAdapter` status, switch port LED |
| `169.254.x.x` | No DHCP response | Scope activated? Authorised? Pool exhausted? |
| IP fine, gateway unreachable | Local segment or VLAN | `arp -a`, switch port config |
| Gateway reachable, internet not | Routing, firewall, WAN | `tracert 8.8.8.8` and read where it stops |
| Works by IP, fails by name | DNS | `Resolve-DnsName`, `ipconfig /flushdns`, check `hosts` |
| Resolves to the wrong address | Stale cache or `hosts` entry | `ipconfig /displaydns`, inspect `hosts` |
| Intermittent drops | Loss on one hop, duplex mismatch, Wi-Fi | `pathping`, check `LinkSpeed` |
| Slow only for large transfers | MTU, duplex mismatch, cable | `ping -f -l 1472`, check negotiated speed |
| One site fails, everything else fine | That site, proxy, or a filter | Test from another network |
| Domain logon fails, internet fine | DNS pointing at a public resolver | `Get-DnsClientServerAddress`, must be the DC |

> **The single most common domain-network fault:** a domain-joined machine configured with `8.8.8.8` as its DNS server. Internet works perfectly, so it looks healthy, but the client cannot resolve the `_msdcs` SRV records, so logon, Group Policy and drive mappings all fail. Domain members point at a domain controller. Always.

---

## Wi-Fi vs Ethernet

| | Wi-Fi | Ethernet |
| --- | --- | --- |
| Throughput | Shared with everyone on the AP | Dedicated per port |
| Latency | Variable | Stable |
| Reliability | Interference, roaming, range | Cable or no cable |
| Security | Depends on WPA2/WPA3 and 802.1X | Physical access plus 802.1X |

For diagnosing a "slow network" complaint, the first question is which one. Ethernet performance problems are usually duplex, cable or switch. Wi-Fi performance problems are usually signal, channel congestion or AP load: different tools, different team.

---

## Addressing and Ports

**Static vs dynamic:** static for anything other devices must find at a fixed address, such as servers, printers, switches and hypervisors. Dynamic for everything else. A printer with a DHCP address that changes is a recurring ticket; a **reservation** gives a fixed address while keeping central management.

### Private Ranges (RFC 1918)

| Range | CIDR |
| --- | --- |
| `10.0.0.0` to `10.255.255.255` | `/8` |
| `172.16.0.0` to `172.31.255.255` | `/12` |
| `192.168.0.0` to `192.168.255.255` | `/16` |

### Ports Worth Knowing

| Port | Service | Note |
| --- | --- | --- |
| 53 | DNS | TCP and UDP |
| 67 / 68 | DHCP | Server / client |
| 80 / 443 | HTTP / HTTPS | |
| 88 | Kerberos | Domain authentication |
| 135 | RPC endpoint mapper | |
| 389 / 636 | LDAP / LDAPS | Directory queries |
| 445 | SMB | File sharing, never expose externally |
| 3268 / 3269 | Global Catalog | Forest-wide lookups |
| 3389 | RDP | Never expose to the internet |
| 22 | SSH | |
| 25 / 587 | SMTP / submission | 587 with STARTTLS for clients |
| 110 / 995 | POP3 / POP3S | |
| 143 / 993 | IMAP / IMAPS | Prefer IMAP over POP3 |

Port 465 appears in older documentation as "SMTP over SSL". It was deprecated, then reinstated for implicit TLS submission, but **587 with STARTTLS is the current standard** for mail clients.

---

## What Network Troubleshooting Reveals

The same commands used for faults surface things worth escalating.

```powershell
arp -a                                    # duplicate MACs across IPs, possible ARP spoofing
Get-DhcpServerInDC                        # authorised DHCP servers; anything else answering is rogue
Get-NetTCPConnection -State Established   # unexpected outbound connections
Get-Content $env:SystemRoot\System32\drivers\etc\hosts
Get-NetFirewallProfile | Select-Object Name, Enabled
Get-NetRoute -AddressFamily IPv4          # routes nobody configured
```

Things that look like faults but are worth treating as findings:

- **Clients getting addresses from an unexpected server.** Whoever assigns the gateway and DNS controls where traffic goes. A rogue DHCP server is a straightforward path to intercepting traffic.
- **One MAC address appearing against several IPs in the ARP cache.** Normal for a router, suspicious for a workstation.
- **`hosts` entries redirecting known domains**, particularly security vendors or update servers pointed at `127.0.0.1`.
- **A changed DNS forwarder**, which silently redirects an entire network's resolution.
- **An added persistent route** sending a subnet somewhere unexpected.
- **Unexplained outbound connections on odd ports**, especially from processes that have no reason to talk to the internet.

None of these prove compromise on their own. All of them are worth a second look rather than being cleared away as part of a fix.

---

## Escalation and Documentation

Escalate when the fault is outside the endpoint: switch, router, firewall, ISP, or a server you do not administer. Include, so the next person does not repeat your work:

- Scope: who is affected, since when, and what changed
- `ipconfig /all` from an affected machine
- Results of each step of the method, including the ones that passed
- `tracert` or `pathping` output showing where it stops
- Relevant event log entries
- What you have already tried and ruled out

Write the ticket so the *next* occurrence is faster: what was reported, what you tested, what the results were, what the cause turned out to be, and what resolved it. "Rebooted, works now" is a closed ticket, not a resolved fault.

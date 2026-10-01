# Trust Relationship Failed

**"The trust relationship between this workstation and the primary domain failed."**

The machine still has a computer account in Active Directory. It can no longer prove it owns it.

---

## Why It Happens

Every domain-joined computer has its own account and its own password. Windows rotates that password every 30 days on its own. Nobody sees it happen.

The trust breaks when the two copies stop matching.

| Cause | What happened |
| --- | --- |
| Offline too long | Machine was off or off-network past the tombstone window |
| Restored from a snapshot or image | The image has an old password, AD has the current one |
| Cloned VM | Two machines, one computer account |
| Computer object deleted in AD | Nothing left to match against |
| Reset the account in ADUC | Resetting it breaks the current trust by design |

Snapshot restores are the usual one in a lab. Revert a VM to last month and its computer password is a month out of date.

---

## Fix It Without Rejoining

Try this first. It takes a minute and keeps the same computer account, so group memberships and GPO links survive.

Sign in with a local administrator account. `.\localadmin` at the sign-in screen, or `COMPUTERNAME\localadmin`.

Open PowerShell as admin:

```powershell
Test-ComputerSecureChannel -Verbose
Test-ComputerSecureChannel -Repair -Credential (Get-Credential)
```

Supply domain credentials that can join computers. Run the test again. It should return `True`.

No reboot needed most of the time. Sign out and back in with the domain account.

If `-Repair` fails, try resetting the password directly:

```powershell
Reset-ComputerMachinePassword -Server DC01 -Credential (Get-Credential)
```

---

## Rejoin If Repair Fails

The old way. It works, but you lose the original computer object, and anything tied to it.

1. Sign in as a local admin.
2. **File Explorer**, right-click **This PC**, **Properties**.
3. **Advanced system settings**, **Computer Name** tab, **Change**.
4. Select **Workgroup**, type `WORKGROUP`, **OK**.
5. Supply domain credentials when prompted.
6. Restart.
7. Sign in as local admin again.
8. Same path. Select **Domain**, enter `vbunnylab.local`.
9. Supply domain credentials.
10. Restart.

```powershell
Remove-Computer -UnjoinDomainCredential (Get-Credential) -PassThru -Restart
# after reboot
Add-Computer -DomainName 'vbunnylab.local' -Credential (Get-Credential) -Restart
```

> **Make sure you have a working local admin password before you start.** Leaving the domain means domain accounts cannot sign in. No local account means no way back in. This catches people out, and the recovery is offline password tooling or a rebuild.

Delete the stale computer object in ADUC before rejoining, or the join will fail on a name conflict.

---

## Check It Is Not Really DNS

The same error can appear when the trust is fine but the client cannot find a domain controller.

```powershell
Get-DnsClientServerAddress
Resolve-DnsName _ldap._tcp.dc._msdcs.vbunnylab.local
Test-NetConnection dc01.vbunnylab.local -Port 389
nltest /dsgetdc:vbunnylab.local
```

A domain member pointed at `8.8.8.8` cannot resolve the SRV records it needs. Internet works, logon does not. Fix DNS before touching the domain join.

---

## Preventing It

- Do not clone a joined VM. Sysprep it, or join after cloning.
- Do not revert a domain-joined snapshot past 30 days.
- Bring machines online periodically if they sit in storage.
- Clean up stale computer objects on a schedule so old records do not collide with new joins.

```powershell
Get-ADComputer -Filter {Enabled -eq $true} -Properties LastLogonDate |
    Where-Object { $_.LastLogonDate -lt (Get-Date).AddDays(-90) } |
    Select-Object Name, LastLogonDate | Sort-Object LastLogonDate
```

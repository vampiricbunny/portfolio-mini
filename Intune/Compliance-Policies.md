# Compliance Policies

A compliance policy is a set of rules a device has to meet. Intune checks the device against them and marks it Compliant or Non-compliant.

That flag does nothing on its own. It is a label.

**Conditional access is what turns the label into enforcement.** Compliance policy decides the verdict. Conditional access acts on it. Configure one without the other and you get an accurate report that changes nothing.

That gap is the most common finding when reviewing an Intune tenant. Policies exist, devices are correctly flagged, and non-compliant machines still get their email.

---

## Build a Policy

1. **Devices**, **Compliance policies**, **Create policy**.
2. Pick the platform. Policies are per-platform, so Windows and Android need separate ones.
3. Set the rules.
4. Configure **Actions for noncompliance**.
5. Assign to a group.

---

## Windows Rules Worth Setting

| Setting | Value | Why |
| --- | --- | --- |
| Require BitLocker | Require | A stolen laptop is a data breach without it |
| Require Secure Boot | Require | Blocks bootkits |
| Require code integrity | Require | Only signed drivers load |
| Minimum OS version | Current supported build | Keeps unpatched machines out |
| Password required | Yes, 8 or more | |
| Firewall | Require | |
| Antivirus and antispyware | Require | |
| Defender antimalware | Require | |
| Real-time protection | Require | |
| Machine risk score | Medium or below | Needs Defender for Endpoint |

**Minimum OS version is the one that quietly does the most work.** It stops a laptop that has not been patched in a year from reaching company data, without anyone having to chase it.

### Android

- Require device encryption
- Require a passcode, 6 digits or more
- Block rooted devices
- Minimum OS version
- Require Play Integrity to pass

### iOS

- Require a passcode
- Block jailbroken devices
- Minimum OS version
- Require encryption, which is on by default on iOS

---

## Actions for Non-Compliance

Do not go straight to blocking. Give people a path back.

A sensible ladder:

| Day | Action |
| --- | --- |
| 0 | Mark non-compliant, send an email to the user |
| 1 | Send a push notification |
| 3 | Email the user and their manager |
| 7 | Remotely lock, or block access |

Set this under **Actions for noncompliance** when building the policy.

Immediate blocking generates a flood of tickets and a lot of ill will, usually for something the user did not know about and could have fixed in two minutes.

---

## Connect It to Conditional Access

This is the step that matters.

1. **Entra admin center**, **Protection**, **Conditional Access**.
2. **New policy**, name it clearly. `CA004-Require-Compliant-Device-M365`.
3. **Users**: target the group. **Exclude your break-glass accounts.**
4. **Target resources**: Office 365, or All cloud apps.
5. **Grant**: **Require device to be marked as compliant**.
6. Set to **Report-only** first.
7. Read the sign-in logs for a few days, then enable.

> **Exclude the break-glass accounts.** A conditional access policy requiring a compliant device, applied to everyone, with no exclusions, locks every administrator out of the tenant. Those accounts exist for exactly this.

> **Run it in report-only first.** The sign-in logs show precisely who would have been blocked. That is a far better way to find out than the service desk telling you.

---

## The Default Setting

**Devices**, **Compliance policies**, **Compliance policy settings**.

**Mark devices with no compliance policy assigned as:** defaults to **Compliant**.

Set it to **Not compliant**.

The default means any device not covered by a policy is treated as fine. A device that slipped through assignment gets full access. Flipping it to Not compliant means anything unmanaged fails closed instead.

Change this only after you have confirmed your policies actually cover everyone, or you will lock out real users.

Also set **Compliance status validity period** to 30 days. A device that stops checking in becomes non-compliant instead of sitting on its last good result forever.

---

## Monitoring

**Devices**, **Monitor**, **Device compliance**.

Worth watching:

- Non-compliant devices, and which rule they fail
- Devices with no policy assigned
- Devices that have not checked in for 30 days
- The trend, not just today's number

Per device: **Devices**, **All devices**, select one, **Device compliance**. That shows each setting and its result, which answers "why is this thing non-compliant" directly.

---

## Common Problems

| Symptom | Cause | Fix |
| --- | --- | --- |
| Device shows Not evaluated | No policy assigned to that user or platform | Check assignments |
| Non-compliant with no clear reason | Open the device and read the per-setting results | |
| BitLocker rule fails on a compliant machine | Encryption still in progress, or no TPM | Check `Get-BitLockerVolume` |
| Compliant device still blocked | The CA policy targets something else | Read the sign-in log |
| Everything went non-compliant overnight | Minimum OS version raised, or grace period expired | Check recent policy edits |
| Policy applies to nobody | Assigned to a group with no members | Check the group |

```powershell
Get-BitLockerVolume -MountPoint C: | Select-Object VolumeStatus, ProtectionStatus
Get-MpComputerStatus | Select-Object RealTimeProtectionEnabled, AntivirusSignatureAge
Get-Tpm | Select-Object TpmPresent, TpmReady
```

Compliance evaluates on a schedule, roughly every eight hours on Windows. After a fix, force a sync from **Company Portal**, **Settings**, **Sync** rather than waiting.

---

## Practices

- One policy per platform, assigned to everyone, not a stack of overlapping ones
- Set the default to Not compliant, once coverage is confirmed
- Always pair compliance with a conditional access policy, or it does nothing
- Report-only before enforcement, every time
- Give a grace period before blocking
- Exclude break-glass accounts from every CA policy
- Review non-compliant devices weekly. A list nobody reads is not monitoring

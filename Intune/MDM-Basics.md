# Mobile Device Management Basics

What MDM does, where Intune sits, and how devices get enrolled on each platform.

MDM exists to answer one question. Company data is sitting on a device you do not physically control, so how do you set rules for it and take it back when you need to?

---

## MDM and MAM

Two different approaches. People mix them up constantly.

**MDM manages the device.** Full control. You enforce encryption, push apps, set passcode rules, and wipe the whole thing. Right for company-owned hardware.

**MAM manages the app.** You control the corporate data inside Outlook or Teams and nothing else. No enrollment. Block copy and paste out of work apps, require a PIN to open them, wipe just the work data.

| | MDM | MAM |
| --- | --- | --- |
| Enrollment needed | Yes | No |
| Scope | Whole device | Work apps only |
| Wipe | Everything | Work data only |
| Suits | Company-owned | BYOD |
| User pushback | High on personal phones | Low |

**MAM is usually the right answer for BYOD.** People do not want their employer able to wipe their personal phone, and they are not wrong. MAM gives you control over company data without touching their photos.

You can run both. MDM on company laptops, MAM on personal phones.

---

## Where Intune Sits

Intune is the MDM and MAM service in Microsoft Intune (formerly Endpoint Manager). It connects to the rest of the stack.

| Piece | Job |
| --- | --- |
| **Entra ID** | Identity. Who the user is, which device they are on |
| **Intune** | Policy, apps, compliance evaluation |
| **Conditional access** | Enforcement. Blocks access when the device fails |
| **Defender for Endpoint** | Risk signal that feeds compliance |

The link that matters: **Intune decides whether a device is compliant, and conditional access does something about it.** Compliance policy on its own changes nothing. It marks a device non-compliant and stops there. Without a conditional access policy requiring compliance, that device still gets its email.

That gap is common in real tenants. Policies are configured, nothing is enforced, and everyone assumes they are covered.

---

## Enrollment by Platform

| Platform | Method | Use |
| --- | --- | --- |
| **Windows** | Autopilot | Company-owned, ships to the user, configures itself |
| **Windows** | Entra join during OOBE | Company-owned, set up by IT |
| **Windows** | Group Policy auto-enrol | Existing hybrid-joined fleet |
| **Windows** | Company Portal | BYOD |
| **Android** | Work Profile | BYOD, splits work and personal |
| **Android** | Fully Managed | Company-owned, whole device |
| **Android** | Dedicated | Kiosks, shared shop-floor devices |
| **iOS** | Apple Business Manager + ADE | Company-owned, supervised |
| **iOS** | Company Portal | BYOD |
| **macOS** | Apple Business Manager | Company-owned |

**Autopilot for Windows and Apple Business Manager for iOS are what you want at scale.** The device enrols itself from the factory. Nobody touches it before the user does.

---

## Prerequisites

- Microsoft 365 tenant
- Intune licence assigned to each user. Usually Microsoft 365 Business Premium, E3 or E5
- MDM authority set to Intune, which is now the default
- Enrollment restrictions configured
- Access to [intune.microsoft.com](https://intune.microsoft.com)

**Check licensing first.** Enrollment failing with a vague error is nearly always a missing licence.

---

## Android Enrollment

Android has three modes and they behave very differently.

### Turn On Android Enterprise

1. **Devices**, **Android**, **Android enrollment**.
2. **Managed Google Play**, connect it to a Google account. Use a shared account, not a person's.
3. Pick the enrollment types you want.

### Work Profile, for BYOD

Android creates a separate work container. Work apps carry a briefcase badge. Personal apps are untouched, and you cannot see or wipe them.

1. User installs **Company Portal** from Google Play.
2. Signs in with their work account.
3. Taps through the work profile setup.
4. Work apps appear in the separate profile.

Wiping removes the work profile only. Personal data stays. That is what makes it acceptable to users.

### Fully Managed, for Company-Owned

Whole device under management.

1. **Devices**, **Android**, **Enrollment profiles**, create one. Save the QR code.
2. Factory reset the device.
3. On the very first setup screen, tap the same spot **six times**.
4. Scan the QR code.
5. Device enrols and provisions itself.

The six-tap has to happen on a factory-fresh device. Miss it and you reset and start again.

### Dedicated, for Kiosks

Same QR process, locked to a single app or a small set. Used for shop floors, warehouse scanners and till systems.

---

## Windows Enrollment

**Autopilot** is the one to know.

1. Get the hardware hash from the vendor, or collect it with `Get-WindowsAutopilotInfo`.
2. Import to **Devices**, **Windows**, **Windows enrollment**, **Devices**.
3. Build an Autopilot deployment profile.
4. Assign it to a group.
5. Ship the laptop sealed to the user.

The user unboxes it, connects to Wi-Fi, signs in with their work account, and the device configures itself. IT never opens the box.

**Automatic enrollment for existing machines:**

**Devices**, **Enrollment**, **Automatic Enrollment**. Set MDM user scope to All or a group. Entra-joined devices then enrol on their own.

---

## Verify Enrollment

**On the device**, open Company Portal, check **Devices**, look for Managed and Compliant.

**In the console**, **Devices**, **All devices**. Check:

| Column | Watch for |
| --- | --- |
| Managed by | Should say Intune |
| Compliance | Compliant, Non-compliant, or Not evaluated |
| Last check-in | Stale means the device is not talking to the service |
| Ownership | Corporate or Personal |

**Not evaluated** usually means no compliance policy is assigned to that user or platform. It does not mean the device passed.

---

## Enrollment Restrictions

**Devices**, **Enrollment**, **Enrollment device limit restrictions** and **Enrollment device platform restrictions**.

Set these before opening enrollment up.

- Block platforms you do not support
- Set a minimum OS version, which keeps unpatched devices out
- Block personally owned devices where you only want corporate hardware
- Cap devices per user, five is a reasonable default

Without restrictions, anyone with a licence can enrol anything, including an unpatched phone running a five-year-old Android build.

---

## Common Enrollment Failures

| Symptom | Cause |
| --- | --- |
| "Your organisation does not support this" | No Intune licence on the user |
| Enrollment blocked | Platform restriction, or OS version too low |
| "Device cap reached" | Per-user device limit hit |
| Android Work Profile will not start | Managed Google Play not connected |
| Windows enrols but no policy arrives | No policy assigned to that user's group |
| Device shows Not evaluated | No compliance policy targeting it |
| iOS enrollment fails | APNs certificate expired |

**The APNs certificate expires every year.** When it does, every iOS device stops checking in at once and enrollment breaks. Put the renewal date in a calendar. It is a predictable outage that catches people every year.

---

## Next

- [Device Enrollment](Device-Enrollment.md) for the Windows walkthrough
- [Compliance Policies](Compliance-Policies.md) for setting and enforcing the rules
- [App Deployment](App-Deployment.md) for pushing software

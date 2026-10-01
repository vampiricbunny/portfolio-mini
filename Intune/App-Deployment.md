# Application Deployment

Packaging and deploying software to Intune-managed Windows devices.

Most of this document is about Win32 apps, because that is where the work is and where deployments fail.

---

## App Types

| Type | Use | Effort |
| --- | --- | --- |
| **Microsoft Store app (new)** | Anything in the Store, including winget packages | Very low |
| **Microsoft 365 Apps** | Office, with a built-in configuration designer | Low |
| **Web link** | Shortcut to a web app | None |
| **Line-of-business** | A single MSI | Low |
| **Windows app (Win32)** | Anything else. EXE installers, MSI with switches, scripts | Medium |

**Try the Store app type first.** It now covers a large amount of common software through winget, and it handles updates on its own. Packaging Chrome as a Win32 app when the Store version works is wasted effort.

Reach for Win32 when you need install switches, a custom detection rule, dependencies, or an EXE installer.

---

## Assignment Types

This trips people up more than packaging does.

| Assignment | Behaviour |
| --- | --- |
| **Required** | Installs on its own, no user action |
| **Available for enrolled devices** | Appears in Company Portal, user chooses to install |
| **Uninstall** | Removes it |

**Required and Available can be assigned to the same app, targeting different groups.** Required for the team that must have it, Available for everyone else.

Assigning **Uninstall** to a group that overlaps a Required group produces a loop. The app installs, gets removed, installs again. Check for overlap before assigning.

Assign to **groups**, not All Users, unless you genuinely mean everyone.

---

## Packaging a Win32 App

### Get the Prep Tool

Download the [Win32 Content Prep Tool](https://github.com/microsoft/Microsoft-Win32-Content-Prep-Tool) from Microsoft's GitHub.

It wraps the installer and its files into a single encrypted `.intunewin` package. Intune will not accept a raw installer.

### Lay Out the Files

```text
C:\Packaging\Chrome\
    GoogleChromeStandaloneEnterprise64.msi
    IntuneWinAppUtil.exe
```

Everything the installer needs goes in the source folder. The tool packages the whole folder, not just the one file.

### Build the Package

```cmd
cd C:\Packaging\Chrome
IntuneWinAppUtil.exe -c C:\Packaging\Chrome -s GoogleChromeStandaloneEnterprise64.msi -o C:\Packaging\Output
```

| Switch | Means |
| --- | --- |
| `-c` | Source folder |
| `-s` | Setup file inside that folder |
| `-o` | Where to write the `.intunewin` |
| `-q` | Quiet, for scripting |

Output is `GoogleChromeStandaloneEnterprise64.intunewin`.

---

## Upload and Configure

**Apps**, **Windows**, **Add**, app type **Windows app (Win32)**, then select the `.intunewin`.

### App Information

Name, publisher, category, description. Add a logo. Users see all of this in Company Portal, and an app with no icon and no description looks like something they should not click.

### Install Commands

```text
Install:    msiexec /i "GoogleChromeStandaloneEnterprise64.msi" /qn /norestart
Uninstall:  msiexec /x "{GUID}" /qn /norestart
```

For an EXE, check the vendor's silent switches. They vary.

```text
Install:    setup.exe /S /v/qn
Install:    installer.exe --silent --system-level
```

**Install behaviour: System**, unless the app genuinely has to install per user. System installs once for the machine.

**Device restart behaviour**: No specific action, in most cases. Let the app decide.

### Requirements

- Architecture: 64-bit, unless you need both
- Minimum OS: set it deliberately

You can add a custom requirement script. Handy for things like installing only on laptops, or only where a dependency is already present.

### Detection Rules

**This is where Win32 deployments fail.**

The detection rule is how Intune decides whether the app is already installed. Get it wrong and the app either reinstalls on every check-in, or reports failure after a successful install.

| Rule type | Use |
| --- | --- |
| **MSI product code** | MSI installers. Simplest and most reliable |
| **File** | EXE installers. Check the file exists, or a version |
| **Registry** | Check an uninstall key or a version value |
| **Custom script** | Anything complicated |

For an MSI, pick MSI and let it read the product code from the package.

For a file rule, check the version rather than just existence:

```text
Path:        C:\Program Files\Google\Chrome\Application
File:        chrome.exe
Detection:   String comparison, Version, Greater than or equal to
Value:       120.0.0.0
```

A script rule has to write to stdout **and** exit 0 to signal detected:

```powershell
$path = 'C:\Program Files\Google\Chrome\Application\chrome.exe'
if (Test-Path $path) {
    $v = (Get-Item $path).VersionInfo.ProductVersion
    if ([version]$v -ge [version]'120.0.0.0') {
        Write-Output "Installed $v"
        exit 0
    }
}
exit 1
```

Output alone is not enough. Exit code alone is not enough. It needs both.

### Dependencies and Supersedence

**Dependencies** install first. Use for runtimes like .NET or Visual C++ redistributables.

**Supersedence** replaces an older app. Point the new version at the old one and choose whether to uninstall the previous version first. This is how you handle upgrades without leaving two versions behind.

---

## Monitor It

**Apps**, select the app, **Device install status** and **User install status**.

| Status | Means |
| --- | --- |
| Installed | Detection rule matched |
| Failed | Check the error code |
| Pending | Not checked in yet |
| Not applicable | Failed a requirement rule |

**Not applicable** is worth reading carefully. It means the device did not meet a requirement, usually architecture or minimum OS. The deployment is not broken, it just excluded that machine.

---

## Troubleshooting

The log is the answer to nearly everything.

```text
C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\IntuneManagementExtension.log
```

Read it with CMTrace, or:

```powershell
Get-Content 'C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\IntuneManagementExtension.log' -Tail 100 -Wait
```

| Symptom | Cause |
| --- | --- |
| Installs repeatedly | Detection rule never matches |
| Reports failed, but the app is there | Detection rule wrong |
| Never attempts install | Requirement rule excluded it, or no assignment |
| Fails with 1603 | Generic MSI failure. Look at the MSI log |
| Fails with 1618 | Another install already running |
| Fails with 1619 | Package could not be opened |
| Nothing happens at all | Intune Management Extension not installed |

The Intune Management Extension is what runs Win32 deployments and it arrives after the first Win32 app or PowerShell script is assigned. A brand new device with no Win32 app assigned will not have it yet.

```powershell
Get-Service IntuneManagementExtension
Restart-Service IntuneManagementExtension
```

**Test the install command manually before packaging.** Run it as SYSTEM with PsExec, or at least as admin. Most "Intune failed" tickets are the install command being wrong, not Intune.

---

## Practices

- Store app type first. Package only when you have to
- Test the silent install manually before packaging
- Version-based detection rules, not file existence
- One app per package. Bundling makes failures impossible to diagnose
- Assign to a pilot group first
- Name packages with the version, `Chrome-120.0.6099.110`
- Keep source files and the packaging command, so the next version takes two minutes
- Use supersedence for upgrades rather than stacking new packages

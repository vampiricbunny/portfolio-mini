# CIPP Troubleshooting Runbook

Real faults from supporting CIPP, with the diagnosis and the fix. Written as case studies because the reasoning is the useful part, not just the resolution.

A theme runs through most of them. The symptom rarely describes the cause. "It is slow" turns out to be Azure cold start. "It says out of date" turns out to be a browser cache. Reading the actual error code saves more time than anything else.

---

## Case 1: Dashboard Slow on First Load

**Symptom.** User reports CIPP is slow to load. Once it is up, it is fine.

**Investigation.** Asked whether it was slow every time or only the first time. Only the first load after not using it for a while.

**Cause.** Azure Functions cold start.

Self-hosted CIPP runs on Azure Functions on a consumption plan. The backend scales to zero when idle so you are not billed for nothing. The first request after idle has to wake it, which takes several seconds.

This is the hosting model working as designed, not a fault.

**Resolution.** Explained the behaviour. Asked the user to click through several menus quickly, which confirmed normal speed after the first load.

No technical change made. The alternative is moving to a Premium plan with always-ready instances, which costs more and is rarely worth it for an internal tool.

**Worth noting.** Resolving a ticket with an explanation rather than a change is a valid outcome. Making a change to satisfy a misunderstanding just adds cost.

---

## Case 2: Sponsor Access Returning 403

**Symptom.** An MSP sponsored the project through their corporate GitHub organisation account and could not access sponsor-only features. 403 Forbidden.

**Investigation.** The management portal authenticates with GitHub OAuth.

The constraint is that **you cannot sign in as a GitHub organisation.** An organisation is not a login identity. Only individual user accounts authenticate.

**Cause.** The sponsorship was attached to the organisation. The individual signing in had no entitlement linked to their personal account, so the system correctly refused them.

**Resolution.** Linked the individual's GitHub username to the organisation's sponsor ID in the entitlement backend. Asked them to sign out and back in. The portal then recognised their personal account as a seat under the corporate sponsorship.

**The lesson generalises.** Sponsorship, licensing and entitlement frequently attach to an organisation while authentication happens as an individual. When a paid feature returns 403 for someone who has definitely paid, check what the entitlement is attached to versus what is signing in.

---

## Case 3: "Version Out of Date" After Updating

**Symptom.** User updated CIPP successfully. The dashboard still showed a red "Version Out of Date" banner.

**Investigation.** Confirmed the backend had actually updated by checking the deployed version directly, rather than trusting the banner. It had.

**Cause.** Browser caching.

CIPP v7 and later is heavily client-side JavaScript. After a backend update, the browser often keeps the old `.js` and `.css` files. The client is still running the previous version and reports itself as out of date. The server is fine.

**Resolution.** A normal refresh is not enough. It re-requests the page and keeps the cached assets.

**Chrome and Edge:**

1. `F12` to open Developer Tools
2. Right-click the refresh button
3. **Empty Cache and Hard Reload**

**Firefox:** `Ctrl + Shift + R`, or clear site data from the padlock icon.

**Expectation set.** Where an Azure CDN is in front of the app, propagation can take longer, occasionally up to 48 hours. The hard reload fixes it immediately in almost every case.

**Result.** Banner cleared.

**Generalises to any SPA.** A single-page application reporting a stale version after a confirmed update is a cache problem far more often than a deployment problem. Verify the backend version before touching the deployment.

---

## Case 4: Tenant Access Denied, AADSTS50076

**Symptom.** User could manage most client tenants but was locked out of one. Screenshot showed `AADSTS50076`.

**Reading the error.** `AADSTS50076` means MFA is required but was not satisfied for that resource. It is not a permissions error, even though "access denied" suggests one.

That distinction matters. Chasing GDAP roles and application permissions on an MFA error wastes time.

**Investigation steps.**

1. Triggered a manual tenant refresh from CIPP.
2. Checked CIPP application permissions for that tenant.
3. Checked the GDAP relationship was still active and had not expired.
4. Checked the client tenant's conditional access policies.

**Cause.** The client tenant had a conditional access policy requiring MFA for all users including guests and external identities, with no exclusion for the partner's service principal.

The delegated access was valid. The policy was blocking it.

**Resolution.** Worked with the client to exclude the partner service principal from that policy, scoped narrowly rather than broadly.

**The wider point.** Delegated access depends on the *client's* conditional access, not just your permissions. A client tightening their CA policy can break partner access without either side realising the connection. When one tenant fails and the rest work, look at what is different about that tenant's policies before anything else.

---

## Diagnostic Order

Working any CIPP fault, in this order:

1. **Read the exact error code.** `AADSTS` codes are specific and documented. The code usually names the cause
2. **One tenant or all of them?** One tenant points at that relationship or that tenant's config. All of them points at CIPP itself
3. **One user or all users?** One user points at their group membership or role
4. **Check the GDAP relationship.** Active? Expired? Correct roles?
5. **Run the Permissions Check.** Does the service principal still have what it needs
6. **Check the client's conditional access.** It can block delegated access
7. **Hard reload the browser** before believing anything the UI reports about versions
8. **Check the CIPP logs.** Self-hosted means Azure Function logs in Application Insights

---

## Common Error Codes

| Code | Means | Usually |
| --- | --- | --- |
| `AADSTS50076` | MFA required, not satisfied | Client CA policy blocking the partner |
| `AADSTS65001` | Consent not granted | Permissions check needed |
| `AADSTS700016` | Application not found in tenant | Service principal missing |
| `AADSTS50020` | User from another tenant | Wrong account signed in |
| `403 Forbidden` | Authenticated but not authorised | Entitlement or role mapping |
| `Invalid Grant` | Token or consent problem | Refresh the tenant, re-check GDAP |

---

## Practices

- Read the error code before forming a theory
- Establish scope first. One tenant, or all
- Verify the backend version before trusting the UI
- Check the client's conditional access when delegated access fails
- Enable automatic GDAP extension so relationships do not lapse quietly
- Run the Permissions Check after any tenant change
- Write the case up. These recur, and the second time should be faster

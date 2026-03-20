# Salesforce Org Chart (User.ManagerId + D3)

Disclaimer: Cursor AI was used to create this functionality after examining a salesforce.com org chart visualforce implementation. AI can make mistakes. Structure: Metadata lives under `force-app/main/default`. There is **no employee data** in the repo: hierarchy, search, and profile payloads are built at runtime from **active `User`** rows and **`User.ManagerId`**. 

## How the root and top of the chart are determined

There is **no** special CEO detection—no lookup by title, custom field, or named user. The tree is built entirely from **`User.ManagerId`** and who appears in the **same SOQL result** (`OrgChartService.getHierarchy`).

### Synthetic root node

The D3 layout expects a single root. Apex creates a non-user node:

- **Name:** `Organization`
- **Federation id:** `organization@internal` (`OrgChartService.SYNTHETIC_ROOT_FEDERATION_ID`)

The UI treats this like the old hidden Salesforce root (collapsed children one level down). It is not stored on `User`.

### Who appears directly under “Organization”

A user is **linked under their manager** only when **all** of the following are true:

1. `User.ManagerId` is not null.
2. That manager’s `User` row is **also** in the queried list (same filters: active, optional `UserType = 'Standard'`).
3. `isValidManagerChain` allows the link (no cycle back to the same user).

Otherwise the user is **not** attached under anyone in this graph and is treated as **top-level**.

So the **first visible row of real people** (under the synthetic org node) can include:

- Users with **`ManagerId = null`** (often includes a CEO if your org leaves the CEO’s manager blank).
- Users whose **manager is missing from the query** (inactive manager, manager outside the filtered population, or the running user cannot read that manager).
- Users **deliberately detached** when the code rejects a **cyclic** manager chain.

If multiple people satisfy “top-level,” you will see **multiple** nodes beside each other under `Organization`—not necessarily a single CEO.

### Customizing “who is at the top”

To enforce a single executive root (or a specific root user), extend `OrgChartService.getHierarchy` (or add a filter layer), for example:

- Require a **custom field** (e.g. “Org chart root”) or **Hierarchy_Custom_Setting__c** with a designated `User` Id.
- Or treat only users with `ManagerId = null` as top-level and hide others (org-specific rule).

Until you add such rules, the chart is a **literal reflection of `ManagerId` + visibility**, not an HR title graph.

## What was recreated

| Original (standalone) | Salesforce replacement |
|----------------------|-------------------------|
| `/api/employees/hierarchy` | `GET .../OrgChart/v1?action=hierarchy` → `OrgChartService.getHierarchy` |
| `/api/employees?search=` | `GET ...?action=search&q=` |
| `/api/employees/{key}` | `GET ...?action=detail&federationId=` |
| `/api/employees/me` | `GET ...?action=me` |
| Synthetic root `salesforce@salesforce.com` | `organization@internal` (`OrgChartService.SYNTHETIC_ROOT_FEDERATION_ID`) |

**Visualforce (`OrgChart.page`)** does **not** use JavaScript remoting (`/soap/ajax/.../apex.js`). It calls **Apex REST** at **`/services/apexrest/OrgChart/v1`**. On **`*.vf.force.com`**, **`fetch` with cookies alone often gets 401** because the **session cookie may not authorize `/services/apexrest`** the way a full API session does. The page therefore sets **`window.ORGCHART_SESSION_ID`** from the Visualforce merge field **`{!$Api.Session_ID}`** (output with **`JSENCODE`**), and **`orgchart_magic.js`** sends **`Authorization: Bearer &lt;sessionId&gt;`** (REST treats the VF **`$Api.Session_ID`** as an access token for API calls). That is the usual VF pattern for same-page REST; it is still sensitive to **XSS**—keep **`/apex/OrgChart`** restricted and hardened like any page that touches session material. This is separate from calling **`UserInfo.getSessionId()`** from Apex only to push a string to the client.

`orgchart_magic.js` uses **REST when `ORGCHART_REST_BASE` is set** (the Visualforce case). If `ORGCHART_REST_BASE` is unset, it can fall back to **remoting** when **`ORGCHART_REMOTE_ACTIONS`** is set (custom hosting only — not used by **`OrgChart.page`**).

**`OrgChartPageController` has no `@RemoteAction`** (see InternalDialogs section). **`OrgChartController`** (`@AuraEnabled`) is for Lightning imperative Apex.

## Fonts on Visualforce

SLDS ships `@font-face` rules with paths like `../fonts/webfonts/*.woff2`. On `*.vf.force.com`, the browser resolves those URLs against `/resource/<cachebuster>/`, **not** against `.../OrgChartAssets/...`, so you get **404** on font files even when they exist in the zip.

This project fixes that by:

1. Bundling **Salesforce Sans** under `fonts/webfonts/` in **OrgChartAssets** (from `@salesforce-ux/design-system` matching your SLDS version).
2. **Removing** the `@font-face` preamble from the zipped `salesforce-lightning-design-system.min.css` during `rebuild-static-resource.sh`.
3. Re-declaring `@font-face` in **`OrgChart.page`** using `{!URLFOR($Resource.OrgChartAssets, 'fonts/webfonts/...')}` so every `src` is a full, correct static-resource URL.

## `401` on `/services/apexrest/OrgChart/v1`

- Ensure the user’s profile/permission set includes **`OrgChartRest`** (see **Org Chart User** permission set).
- Enable **API** access for the user if your org requires it for REST (**Setup → Profile / Permission Set → System Permissions → API Enabled** where applicable).
- Use the **relative** REST URL on the **same host** as the VF page (`/services/apexrest/OrgChart/v1`).
- **`OrgChart.page`** sets **`ORGCHART_SESSION_ID`** from **`$Api.Session_ID`** so **`Authorization: OAuth …`** is sent; without it, **vf.force.com** often returns **401** even though the page is “logged in.”

**Alternative (no session in markup):** Host the chart in **Lightning** and load data with **`@AuraEnabled`** Apex (`OrgChartController`) instead of REST from a VF page.

## `InternalDialogs` / VFRemote remoting errors

Visualforce **automatically injects** the JavaScript remoting stack (**VFRemote / `apex.js`**) when the **page controller** (or an extension) declares **`@RemoteAction`** — even if you never add `<apex:includeScript value="/soap/ajax/.../apex.js"/>`. That bootstrap expects **`InternalDialogs`** and breaks on many **`showHeader="false"`** pages.

**`OrgChartPageController` intentionally has no `@RemoteAction` methods** so **`OrgChart`** does not load VFRemote at all; chart data uses **Apex REST** only.

If you still see VFRemote after deploy, you are on a **cached** page, a **different** VF page, or a controller that still exposes `@RemoteAction`.

## Deploy

Prerequisites: Salesforce CLI (`sf`), target org with API access.

```bash
sf project deploy start --source-dir force-app --target-org YOUR_ALIAS
sf apex run test --tests OrgChartServiceTest,OrgChartControllerTest,OrgChartPageControllerTest --target-org YOUR_ALIAS --result-format human
```

Assign **Org Chart User** (`permissionsets/Org_Chart_User.permissionset-meta.xml`) to users who should open the chart.

## Entry points

1. **Visualforce (recommended for full UI)**  
   Open `/apex/OrgChart`. The page loads jQuery, D3 v3, and `orgchart_magic.js` from **OrgChartAssets** and loads chart data via **same-origin `fetch`** to **`OrgChartRest`** (`/services/apexrest/OrgChart/v1`), not JavaScript remoting.

2. **Lightning**  
   Add the **`orgChartShell`** Lightning web component to an app/home page. It iframes `/apex/OrgChart` so you keep one implementation of the D3 UI.

3. **SPA / custom host**  
   Call the REST resource with an authenticated session (e.g. same-origin cookie after login, or OAuth for external hosts):

   - `GET /services/apexrest/OrgChart/v1?action=hierarchy&fteOnly=false`
   - `GET /services/apexrest/OrgChart/v1?action=search&q=pat&limit=25&fteOnly=false`
   - `GET /services/apexrest/OrgChart/v1?action=detail&federationId=user@company.com`
   - `GET /services/apexrest/OrgChart/v1?action=me`

   External SPAs must handle **CORS and OAuth** yourself; the packaged REST class does not enable CORS.

## FAQ / Contact / Settings dialogs

`orgchart_magic.js` loads **`features/faq.html`**, **`contact.html`**, and **`settings.html`** from the static resource when the URL hash is `#faq`, `#contact`, or `#settings`. **`OrgChart.page`** sets **`ORGCHART_FEATURES = ['faq','contact','settings']`** and includes header links for each.

Edit the HTML under **`salesforce/orgchart-ui/features/`**, then run **`rebuild-static-resource.sh`**. Placeholder copy uses **`#any-slack-channel`** and a generic **help article** (replace with your org’s Slack and KB links).

**Troubleshooting (dialogs empty or chart never loads):** Do not use **`id="settings"`** on the Settings link (it clobbers **`window.settings`**). Use **`id="orgchart-settings-link"`**. Header links use **`data-orgchart-feature="faq|contact|settings"`** so dialogs open via a delegated click handler (works when **`hashchange`** is unreliable, e.g. some iframe/VF contexts) and **`ORGCHART_ASSET_BASE`** is resolved with **`new URL(base, location.href)`** so static-resource paths stay same-origin. Dialog close uses **`data-orgchart-close`** (no inline **`onclick`**) for stricter CSP. The script still syncs **`location.hash`** and runs an initial hash pass on load.

## Rebuilding the static resource zip

After editing `assets/orgchart_magic_salesforce.js` or `salesforce/orgchart-ui/features/*`:

```bash
./salesforce/scripts/rebuild-static-resource.sh
```

## Org behavior & customization

- **Tree shape** comes from `User.ManagerId`; see **[How the root and top of the chart are determined](#how-the-root-and-top-of-the-chart-are-determined)** for exactly who becomes top-level.
- **`fteOnly`** uses `User.UserType = 'Standard'` when enabled (approximates “internal” users; adjust `OrgChartService.userTypeClause` if your org models contractors differently).
- **Pronoun line** in the detail panel uses a short preview of **`User.AboutMe`** (optional). Replace with a custom field in `getUserDetail` if you store pronouns elsewhere.
- **Profile link** uses `userRecordUrl` (Lightning record URL for `User`) returned from Apex.
- **Sharing**: class is `with sharing`; users only see Users allowed by your sharing and FLS.

## Files of note

- `classes/OrgChartService.cls` — SOQL, DTOs, tree build  
- `classes/OrgChartController.cls` — `@AuraEnabled` for future pure-LWC data loading  
- `classes/OrgChartRest.cls` — SPA / static resource `fetch` API  
- `classes/OrgChartPageController.cls` — VF bootstrap URLs  
- `pages/OrgChart.page` — Host page  
- `staticresources/OrgChartAssets.zip` — D3, jQuery, SLDS CSS, `orgchart_magic.js`, `features/settings.html`


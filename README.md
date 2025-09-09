# npm Supply-Chain Checker

Detects known-bad package **versions** in local/global Node projects and in **vendored Electron** app bundles on Windows.

> This repo contains two PowerShell scripts:
>
> * `npm-supply-chain-checker.ps1` — scans your **project** and **global** npm trees.
> * `npm-supply-chain-checker_ELECTRON.ps1` — scans installed **Electron** apps (packed `app.asar` / unpacked `resources\app`).

---

## Why this exists

Name-matching is useless in a supply-chain incident. Attacks are **version-specific** and time-bounded. These scripts only flag packages when their **name *and* version** match a list you maintain.

You must populate the list of malicious versions from the official advisory you trust.

---

## What the scripts check

### 1) `npm-supply-chain-checker.ps1`

* Enumerates dependencies with `npm ls --all --json` for:

  * the current project (run in the project root),
  * the global install tree (`-g`).
* Walks the tree and reports **hits** where `name` and `version` match your bad-list.
* Safe to run in Yarn v1 (Classic) projects that have a `node_modules` tree; `npm ls` can still read the graph.

  * Not designed for Yarn Berry (PnP) or pnpm lockfiles.

### 2) `npm-supply-chain-checker_ELECTRON.ps1`

* Recursively searches common Windows install roots:

  * `%LOCALAPPDATA%\Programs`, `%ProgramFiles%`, `%ProgramFiles(x86)%`, `%APPDATA%`.
* For each Electron app:

  * If `resources\app.asar.unpacked` exists, scans its `node_modules`.
  * Otherwise extracts `resources\app.asar` to a temp dir (via `npx asar`) and scans the extracted `node_modules`.
  * Also scans unpacked `resources\app\` folders when present.
* Reports **hits** by package name, version, and file path.

---

## Prerequisites

* Windows 10/11.
* PowerShell 5.1 or 7+.
* Node.js + npm in `PATH`.
* For Electron scan: `npx` must be available; the script shells out to `npx asar`.

  * First run will auto-download the `asar` CLI into your npm cache.

---

## Configure the malicious versions

Both scripts contain a hashtable named `$bad`:

```powershell
# Example (you must fill this with the advisory’s exact versions)
$bad = @{
  'chalk'            = @('5.6.1')
  'ansi-styles'      = @()
  'supports-color'   = @()
  # …
}
```

Populate it with **only** the compromised versions from the official advisory or CSA you follow. Keep it tight to avoid false positives.

---

## Usage

### Scan a project and global npm

```powershell
# From your project root
pwsh -File .\npm-supply-chain-checker.ps1
```

**Output**

* On hits: a table of `{ name, version }` (and possibly path).
* On no hits: `No known-bad versions found.`

> Tip: run this in each important repo and CI workspace. Also run once with `--global` if you add that option, or keep the default script that already checks `-g`.

### Scan installed Electron apps

```powershell
pwsh -File .\npm-supply-chain-checker_ELECTRON.ps1
```

**Output**

* On hits: a table of `{ appRoot, name, version, file }`.
* On no hits: `No known-bad versions found in Electron app bundles.`

---

## What this repo does **not** do

* It does not fetch advisories for you.
* It does not repair or pin dependencies.
* It does not scan Yarn Berry (PnP) or pnpm lockfiles. See **Extensions** below.

---

## Extensions (optional)

If you also use these ecosystems, add companion checks:

* **Yarn Berry (PnP)**: parse `yarn.lock` and extract `name -> version` pairs for your target packages, then compare to `$bad`.
* **pnpm**: traverse `pnpm list --depth Infinity --json`, walk `.dependencies`, and match `name + version`.
* **CI caches / artifact stores**: scan extracted `node_modules` archives or lockfiles in cache buckets.

(Working snippets for Yarn Berry and pnpm are easy to add; keep the same `$bad` structure.)

---

## Interpreting results and next steps

If you get hits:

1. **Quarantine** the affected machine or project if the advisory indicates credential/token theft.
2. **Remove** `node_modules`, clear caches:

   * `npm cache clean --force`
3. **Pin or upgrade** to known-good versions and **reinstall**.
4. **Rotate secrets** exposed to build scripts or postinstall hooks (tokens, NPM auth, CI creds).
5. **Audit logs** for suspicious install events or network egress at the compromise window.
6. Re-run the checker to confirm clean state.

---

## Limitations

* Results are only as good as your `$bad` list.
* Electron scanning relies on discovering `resources\app(.asar)` layouts; vendor packaging can vary.
* Some products self-update in custom locations; you may need to add extra root paths.
* No guaranteed exit codes. The scripts print findings; wire your own `$LASTEXITCODE` or throw on hits if you need CI gating.

---

## Safety and performance

* Read-only file operations except temporary extraction of `app.asar`.
* Electron extraction happens in `%TEMP%\asar-scan\…` and is removed after scanning.
* On very large install trees, first run may take minutes due to `asar` fetch and deep directory traversal.

---

## FAQ

**Q: Why not just search for package names?**
A: Because most versions are safe. Attacks are version-specific.

**Q: Will this find compromised transitive deps?**
A: Yes. The npm tree walk includes transitive packages.

**Q: Can I feed a JSON list of bad versions?**
A: Not out of the box. Easiest path is to generate the PowerShell hashtable and paste it. Add a `-BadListJson` param if you prefer external files.

---

## Contributing

* Keep changes small and test on:

  * a plain npm project,
  * a global npm environment with a few utilities,
  * at least one Electron app.
* PRs that add Yarn Berry/pnpm support while preserving clarity are welcome.

---

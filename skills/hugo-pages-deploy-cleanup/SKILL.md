---
name: hugo-pages-deploy-cleanup
description: Safely build, deploy, verify, and clean Hugo sites published with GitHub Pages Actions. Use when migrating or releasing a Hugo blog, configuring Pages to use GitHub Actions, checking legacy URLs, search, and assets, or starting and stopping local previews; always track owned processes and generated artifacts and remove them at the end.
---

# Hugo Pages Deploy Cleanup

## Operating contract

Treat deployment as a lifecycle with an explicit owner for every process and path.

- Inspect `git status`, the current branch, the remote, existing listeners, and the Pages source before changing anything.
- Keep temporary builds, screenshots, browser profiles, and downloaded tools under a uniquely named directory in `$env:TEMP`. Do not put them in the repository unless an existing audit explicitly requires a temporary `public/` directory.
- Record every server PID, port, temporary directory, and browser profile as soon as it is created. Do not kill all `node`, `python`, or `hugo` processes and do not delete all of `%TEMP%`.
- Prefer pinned Hugo Extended and Dart Sass versions. Include the theme submodule when checking out the repository.
- Always run cleanup in a `finally`-style step, even when a build or browser check fails.

## Release workflow

### 1. Preflight

Confirm the repository root and branch, then check for uncommitted work. Inspect listeners on the planned preview port and identify their command lines before reusing or stopping them. Refuse to overwrite unrelated work.

Check `.gitignore` and the workflow before building. The workflow should use `actions/configure-pages`, `actions/upload-pages-artifact`, and `actions/deploy-pages`, with `pages: write` and `id-token: write` permissions. Pin the Hugo version used locally to the workflow version.

### 2. Build in a disposable location

Create a unique temporary directory and keep its path in a variable:

```powershell
$releaseRoot = Join-Path $env:TEMP ("hugo-release-" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $releaseRoot -Force | Out-Null
$output = Join-Path $releaseRoot "public"
hugo --gc --minify --cleanDestinationDir --destination $output
```

If an existing audit script requires `public/` inside the repository, create it only for the audit and remove it immediately afterward. Never stage `public/`, `resources/`, `.hugo_build.lock`, or generated `assets/jsconfig.json`.

### 3. Validate before publishing

Run the narrowest checks that cover the change, then broaden them for a migration:

```powershell
git diff --check
pwsh -NoProfile -File tests/site-audit.ps1
actionlint
```

Check the generated HTML for the expected Hugo generator, the homepage article list, search JSON, RSS, taxonomies, and every preserved legacy URL. Use a real browser for search interaction, one article with images and code, desktop/mobile overflow, and console errors.

### 4. Publish with Pages Actions

Set the repository Pages **Source** to **GitHub Actions**. A successful `deploy-pages` job is not enough while Pages still says “Deploy from a branch”; in that state the public URL can continue serving an old Jekyll build. If the source is changed after the commit, trigger the workflow through `workflow_dispatch` and wait for both `build` and `deploy` jobs to finish.

### 5. Verify the live deployment

Verify the exact commit in the Actions run, then request the live root and representative endpoints. Require HTTP success, the Hugo generator, and expected Stack markers. Check `/search/index.json`, `/feed.xml`, `/archives/`, `/categories/`, `/tags/`, one article, one image, and old case-sensitive URLs. Do not call the release complete while the public response is still Jekyll or README content.

## Cleanup

Run the bundled script after every preview or release:

```powershell
pwsh -NoProfile -File skills/hugo-pages-deploy-cleanup/scripts/cleanup-hugo.ps1 `
  -RepoRoot (Get-Location) `
  -Ports 4173 `
  -TempPath $releaseRoot
```

The script removes only known, untracked Hugo outputs inside the repository and explicitly supplied temporary paths under `%TEMP%`. It stops a listener only when its command line identifies a known development server and points at the current repository. Use `-WhatIf` first when the ownership is uncertain.

After cleanup, verify all of the following:

- no intended port is in `Listen` state;
- no task-owned server or browser-test process remains;
- every registered temporary path is gone;
- `git status --short --ignored` shows no unexpected build output;
- the repository still points at the intended commit and remote.

## Failure handling

- Build failure: keep only the temporary log needed for diagnosis, then remove the release directory.
- Public site still shows Jekyll: inspect Pages Source before changing templates or content.
- A legacy URL fails: compare the exact case and percent-encoding against the generated output; add an explicit `url` or alias rather than a broad redirect.
- Browser automation fails: close the owned tab/profile and stop its daemon before retrying. Never leave a headed browser or local server running as a side effect.

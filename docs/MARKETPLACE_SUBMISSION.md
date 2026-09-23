# Omafold marketplace submission draft

Status: **ready for owner confirmation; not submitted**. The code is public
at https://github.com/baranskyi/omafold. Before submission, the owner must directly
approve the title and exact body and confirm that every checklist statement,
including preview-asset ownership, is true.

## Pre-submission checks

Run these on the exact commit that will be pushed:

```bash
npm test
omarchy plugin validate .
```

The marketplace's own static security baseline
(`scripts/security-baseline-analysis.mjs` in `omacom/omarchy-plugin-marketplace`),
run locally over `BarWidget.qml`, `OptionsMenu.qml`, `DrawerModel.js` and
`README.md` on 2026-09-23, reported `outcome: passed`, `disposition: clear`, with no findings
and no review capabilities. Keep `git clone` or other remote-build commands out
of the README: the baseline reports them as a `remote-build` capability, which
turns the result into `review-required`.

`preview.png` is a 1672x941 cover generated with Codex's built-in image tool
from the owner's own screenshots: the real options menu and two bar strips.
The omacash amount that sat next to the controller was cut out of the strips
before they were used, and no wallpaper or other screen content was supplied.
Every label on the cover was checked against the real menu.

## Proposed listing

- Title: `[Plugin]: Omafold`
- Repository: `https://github.com/baranskyi/omafold`
- Category: `Widgets`
- Tags: `bar, quickshell`
- Permanent plugin ID: `io.github.baranskyi.omafold` (not present in
  `registry.json` or `retiredPluginIds` on 2026-09-23)

## Exact issue body

Copy only the contents of this code block into the marketplace submission
issue. Keep every heading and checklist item in this order.

```markdown
### Repository URL

https://github.com/baranskyi/omafold

### Category

Widgets

### Tags

bar, quickshell

### Suggest a missing tag

_No response_

### Maintainer notes

Omafold is a single bar widget, not a replacement bar: its arrow is the border between always-visible, hidden and always-hidden widgets in the same bar section. Hidden widgets are never reloaded or re-parented; the controller only animates their slot size and opacity, so their state, tooltips and panels keep working. It reveals on hover, pins on click, reveals the always-hidden tier on middle-click, and exposes show/hide/toggle/showAll/options over IPC for key bindings. A right-click menu lists the managed widgets by name and sets each one visible, hidden or always hidden, alongside the behaviour settings. It makes no network requests, runs no processes and writes no files; menu choices are saved to its own shell.json entry through Omarchy's bar.shell.updateEntryInline, only when the user picks them. It needs nothing beyond Omarchy Shell.

### Submission checklist

- [x] The repository is public and contains installation and removal instructions.
- [x] I have documented the plugin license and any external dependencies.
- [x] I confirm that I own or have permission to submit this plugin and its preview assets.
- [x] The plugin does not overwrite user configuration without explicit consent.
- [x] I understand that approval is for listing and is not a security review.
```

## Submission command — do not run before owner approval

After the repository is public, the checks pass on the exact remote commit,
and the owner directly approves submission, create the issue with:

```bash
gh issue create \
  --repo omacom/omarchy-plugin-marketplace \
  --title "[Plugin]: Omafold" \
  --body-file /tmp/omarchy-plugin-submission.md
```

The `/tmp/omarchy-plugin-submission.md` file must contain only the exact issue
body above. Opening the issue triggers marketplace validation; it does not
publish the plugin immediately.

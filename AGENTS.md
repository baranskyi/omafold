# Omafold development

This directory is the standalone Omarchy plugin repository for
`io.github.baranskyi.omafold`.

- Keep the permanent plugin ID stable across releases.
- Never edit packaged Omarchy files under `/usr/share/omarchy`.
- The plugin must remain local-only: no network, process execution, file writes,
  elevated privileges, or external runtime dependencies. Its own settings are
  persisted only through `bar.shell.updateEntryInline`, and only when the user
  picks an option in the right-click menu; Omarchy Shell writes the file.
- Preserve all three item groups: always visible, hidden, and always hidden.
- Run `npm test` and `omarchy plugin validate .` after behavior or manifest
  changes. Keep the settings table in `README.md` in step with the manifest
  schema.
- Keep remote-build commands such as `git clone` out of `README.md`; the
  marketplace security baseline flags them as `review-required`. The listing
  draft and its checks live in `docs/MARKETPLACE_SUBMISSION.md`.
- `preview.png` is a public asset: never let private widget values (balances,
  calendar entries, notifications) into it.
- Test live QML changes through a symlink in
  `~/.config/omarchy/plugins/io.github.baranskyi.omafold` and restart
  the shell when a hot reload is insufficient.
- Do not submit to the marketplace, create a GitHub repository, or publish a
  release without the owner's explicit approval.

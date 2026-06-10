# Exiled Exchange 2 — local Wayland fork

**Upgrading to a new upstream patch? Read `WAYLAND-PATCH-RUNBOOK.md` first.**
It is the complete, current procedure (re-integrate the single
`wayland-overlay-patch` commit on top of upstream, rebuild the AppImage,
verify the overlay). Do not reconstruct the procedure from graphiti or from
old sessions — the runbook in this repo is the source of truth.

Key facts (details in the runbook):
- Custom fork: carries an `electron-overlay-window` patch (OW_OVERLAY_SCALE
  coordinate fix for KWin's 1.7x Xwayland scale + GCC 15 build fix), applied
  via patch-package on postinstall.
- NEVER let the in-app auto-updater run — it overwrites the patched AppImage
  with vanilla upstream and silently kills the overlay.
- Launcher: the `poetrade` zsh function picks the newest `main/dist/*.AppImage`
  automatically; a fresh build is picked up with no extra wiring.
- Build: `node build/script.mjs` paths are covered in the runbook; the
  `poetrade-rebuild` helper regenerates gitignored data offset indexes first.

# Wayland Overlay Patch — Build & Upgrade Runbook

This is a **custom local fork** of Exiled Exchange 2. It carries a patch that the
upstream project does not have, so it **cannot be updated through the app's
built-in updater** — see the warning below. Every time upstream cuts a new
release, the patch has to be re-integrated and the AppImage rebuilt by hand.
This file is the quick reference for doing that.

## What's custom (and why)

On this rig (KDE Plasma 6 on Wayland, mixed-DPI multi-monitor) KWin runs the
entire Xwayland coordinate space at a **global 1.7x scale**. The
`electron-overlay-window` native module reads raw X11 pixel bounds and hands them
to Electron's `setBounds()`, which expects *logical* (DIP) coordinates — so the
price-check overlay landed 1.7x too far and too large, spilling off-screen.

The fix lives in two places, both committed on the `wayland-overlay-patch`
branch as a **single commit on top of upstream**:

1. **`main/patches/electron-overlay-window+4.0.2.patch`** — a
   [patch-package](https://www.npmjs.com/package/patch-package) patch that:
   - divides reported window bounds by an `OW_OVERLAY_SCALE` env var in
     `src/lib/x11.c` `get_content_bounds()` (default `1.0` = no-op on a real X server),
   - adds an `OW_MANAGED_OVERLAY` escape hatch in the override-redirect path,
   - includes a GCC 15 build fix in `src/lib/addon.c` (`(void**)` cast), and
   - ships the **already-compiled patched `.node`** binary (the binary blob in
     the patch). patch-package drops this over the prebuilt on install.
2. **`main/src/main.ts`** — defaults `OW_OVERLAY_SCALE=1.7` on Linux when unset,
   so this specific rig works with no extra env wiring.

The patch is wired in via `main/package.json`:
- `"postinstall": "patch-package"` re-applies it on every `npm install`,
- `"electron-overlay-window": "4.0.2"` pinned exact so the patch keeps matching.

## ⚠️ DO NOT use the in-app auto-updater

EE2 is an electron-builder app and ships an Electron `autoUpdater` feed
(`dist/latest-linux.yml`). If it ever runs, it will download the **vanilla
upstream AppImage** and overwrite our patched one — silently killing the overlay
on Wayland. Always upgrade by rebuilding from this branch (below), never by
letting the app update itself.

## Launcher

The overlay is launched via the `poetrade` zsh function (in `~/.zshrc`). It
auto-picks the **newest `*.AppImage`** in `main/dist/` and runs it with
`--no-sandbox --ozone-platform=x11` (forces Xwayland). Because it globs for the
newest file, a fresh build is picked up automatically — no version hardcoded.

## Upgrade procedure (re-integrate upstream + rebuild)

Run from the repo root (`~/src/Exiled-Exchange-2`).

```bash
# 0. Safety anchor + stash any working-tree churn
git tag -f pre-upgrade wayland-overlay-patch
git stash push -m "pre-upgrade churn" 2>/dev/null

# 1. Pull upstream and replay our single patch commit on top of it
git fetch origin
git rebase origin/master            # our patch commit lands on the new release
#   If main/package.json conflicts on the version field, keep UPSTREAM's
#   (the higher) version, re-add nothing else, then: git rebase --continue

# 2. Sanity check the patch survived the rebase
grep '"version"' main/package.json                 # -> new upstream version
ls main/patches/                                    # -> electron-overlay-window+4.0.2.patch
grep -n OW_OVERLAY_SCALE main/src/main.ts           # -> default 1.7 present
grep -n patch-package main/package.json             # -> postinstall wired

# 3. Rebuild + repackage (this is exactly what testUpdate.sh does)
#    `npm install` in main/ runs the postinstall that re-applies the patch.
sh testUpdate.sh

# 4. Verify the patched native module is in place after install
#    (mtime/size should match the patched .node, not the stock prebuilt)
ls -la main/node_modules/electron-overlay-window/prebuilds/linux-x64/*.node

# 5. New AppImage is at main/dist/Exiled-Exchange-2-<version>.AppImage
#    Launch it:
poetrade
```

## When a native recompile IS required

The shipped `.node` in the patch is ABI-tied to the N-API/Electron it was built
against. N-API is ABI-stable across Electron versions, so routine upstream data
bumps need **no** recompile. You only need to rebuild the native module from
`wayland-overlay-patch/{x11.c,addon.c}` (the kept source copies) if upstream
bumps either:

- **`electron-overlay-window`** to a new major (patch filename would change), or
- **Electron** to a new major where the prebuilt fails to load.

To recompile: build `electron-overlay-window` from source against the new
Electron (needs `libxcb1-dev`), apply the two `.c` files from
`wayland-overlay-patch/`, then regenerate the patch with
`npx patch-package electron-overlay-window` so the new `.node` is captured.

## Rollback

```bash
git reset --hard pre-upgrade        # branch back to pre-upgrade state
# the previous AppImage in main/dist/ is untouched unless you re-ran testUpdate.sh
```

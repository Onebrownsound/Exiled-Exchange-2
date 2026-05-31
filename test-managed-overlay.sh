#!/usr/bin/env bash
# Launch the Wayland-patched Exiled Exchange 2 (managed-overlay build).
#
# The patched electron-overlay-window no longer forces the price-check window
# to be X11 override-redirect when OW_MANAGED_OVERLAY=1, so KWin treats it as a
# normal keep-above window and floats it over the game on Wayland.
#
# Usage:
#   ./test-managed-overlay.sh           # patched managed overlay (the fix)
#   ./test-managed-overlay.sh original  # original override-redirect behaviour (A/B)
set -euo pipefail

APP="$HOME/src/Exiled-Exchange-2/main/dist/linux-unpacked/exiled-exchange-2"
[ -x "$APP" ] || { echo "error: $APP not found/executable"; exit 1; }

MODE="${1:-managed}"

echo ">> Closing any running Exiled Exchange 2 instance..."
pkill -f 'exiled-exchange-2' 2>/dev/null || true
# give it a moment to release its global hotkeys
for _ in 1 2 3 4 5; do pgrep -f 'exiled-exchange-2' >/dev/null || break; sleep 0.5; done

if [ "$MODE" = "original" ]; then
  echo ">> Launching ORIGINAL (override-redirect) overlay for comparison..."
  unset OW_MANAGED_OVERLAY
else
  echo ">> Launching PATCHED (managed keep-above) overlay [OW_MANAGED_OVERLAY=1, OW_OVERLAY_SCALE=1.7]..."
  export OW_MANAGED_OVERLAY=1
  # Global Xwayland scale on this machine is 1.7 (mixed-DPI multi-monitor);
  # divide X11 pixel coords by it so the overlay lands logically over the game.
  export OW_OVERLAY_SCALE="${OW_OVERLAY_SCALE:-1.7}"
fi

# --ozone-platform=x11 keeps EE2 on Xwayland (its input + window tracking need X11);
# --no-sandbox matches how the AppImage runs.
exec "$APP" --no-sandbox --ozone-platform=x11

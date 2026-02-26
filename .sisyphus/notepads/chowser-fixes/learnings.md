## Quick Actions Menu Addition (2026-02-27)

- Added a Quick Actions menu button (three dots / ellipsis icon) to the picker header
- Menu includes:
  1. "Open in Private" - Opens URL in first available browser with private/incognito mode
  2. "Copy URL" - Copies current URL to clipboard (with visual feedback)
  3. "Configure Rule" - Shows the configure rule sheet
  4. "Settings..." - Opens settings window
- Menu positioned between existing gear button and X close button
- Private mode implementation:
  - Chromium browsers: Uses `--incognito` flag
  - Firefox browsers: Uses `-private-window` flag
  - Safari: Falls back to normal mode (no CLI private mode support)
  - Uses `/usr/bin/open -n -a` approach consistent with existing profile launch logic
- Menu uses `.menuStyle(.borderlessButton)` for consistent styling with other header buttons
- All accessibility identifiers and labels added for testability

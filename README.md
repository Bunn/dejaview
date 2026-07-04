# Deja View (dejaview)

Starter iOS client for macOS Screen Sharing (VNC/RFB), built on [RoyalVNC](https://github.com/royalapplications/royalvnc).

## Setup

1. Open `dejaview.xcodeproj` in Xcode (16 or later).
2. Wait for Xcode to resolve the RoyalVNC Swift package.
3. Select the dejaview target → Signing & Capabilities → choose your development team.
4. Build and run on a device or simulator on the same network as the target Mac.

On the target Mac: System Settings → General → Sharing → enable **Screen Sharing**.

## What's included

- **Bonjour discovery** of `_rfb._tcp` services. Each discovered Mac is eagerly resolved to an IPv4 address (shown in the row); tapping fills host + port.
- **Apple Remote Desktop auth**: enter your macOS username + password. If username is left blank and the server uses legacy VNC auth, only the password is sent.
- **Rendering**: full-screen framebuffer drawn into a `CALayer` (aspect-fit), status bar and home indicator hidden.
- **Input**: tap = left click, drag = click-drag; a floating glass pill toggles a keystroke bar and disconnects.
- **Liquid Glass** styling on iOS 26+ (`glassEffect`, `.glass`/`.glassProminent` buttons) with material fallbacks for iOS 17+ (see `UIHelpers.swift`).
- **Options menu**: bottom-right glass button that morphs open (`GlassEffectContainer` + `glassEffectID`) with quality presets (24/16-bit color — no 8-bit, macOS's server resets those sessions) and clipboard sync. Settings are immutable per connection, so changes briefly reconnect (with a 2s grace period).
- **Saved machines**: one-tap connect entries with editable name/host/port/login (`MachineStore`). Metadata in UserDefaults, passwords in the Keychain.

## Notes & next steps

- First connection triggers iOS's Local Network permission prompt (keys are in `Support/Info.plist`, merged with the generated Info.plist).
- The API usage follows RoyalVNC's `USAGE.md` on `main`. If the branch API drifts, pin the package to a release tag in the project's Package Dependencies.
- Performance: the whole framebuffer image is republished on every update. For production, render only the dirty rect passed to `didUpdateFramebuffer`.
- Not implemented yet: right-click (try a long-press gesture → `.right` button), scroll wheel, pinch-to-zoom, modifier keys, clipboard UI, remote cursor rendering, connection bookmarks / Keychain storage.
- macOS Sonoma+ "high-performance" screen sharing is a separate proprietary protocol; third-party clients use the classic VNC path (this is fine — macOS still serves it).

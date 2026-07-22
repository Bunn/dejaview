# Feature Ideas

Grounded in the current codebase (Bonjour discovery, SwiftData-backed saved machines and history, App Intents, zoom/trackpad session controls, hardware keyboard forwarding). Complements `wwdc-2026-feature-ideas.md`, where the Shortcuts (#1) and SwiftData (#8) items are already implemented.

## Session quality of life

### Special keys toolbar
The input bar sends text and Return, but touch-only users have no Esc, Tab, arrows, Cmd+Tab, Cmd+Q, or function keys. Add a small strip above the input bar (or a section in the session options menu) covering the most common "I'm stuck" moments.

### Multi-session support
The architecture is one `VNCSession` per fullScreenCover. Let users keep two sessions alive and switch between them (picture-in-picture tile or a session switcher). Most iOS VNC clients do this badly — a genuine differentiator.

### Connection thumbnails
The framebuffer is already available as a `CGImage`; snapshot it on disconnect and show it on `SavedMachineTile`. Cheap to build and makes the connect screen feel alive.

### Auto-reconnect on network blips
`retryConnect` and `reconnectPending` already exist; extend them into transparent reconnection with a "reconnecting…" overlay when Wi-Fi hiccups, instead of dropping to the disconnected screen.

## Reach and awareness

### Live Activity for active sessions
Host name, elapsed time, and a disconnect button on the Lock Screen / Dynamic Island. Pairs well with auto-reconnect since connection state changes become glanceable. (Also idea #4 in the WWDC doc.)

### Wake-on-LAN
Send a magic packet before connecting so users can reach a sleeping Mac. A very common request for this app category; per-machine MAC address storage fits naturally in `SavedMachineRecord`.

### External display support
On iPad with Stage Manager or a connected monitor, render the stream full-screen on the external display and keep controls on the iPad. The CALayer frame pipeline (frames bypass SwiftUI via `imagePublisher`) makes this straightforward.

## Input depth

### Per-machine defaults
Remember quality, touch mode, and zoom per saved machine instead of resetting each session. `SavedMachineRecord` is the natural home.

### Trackpad polish
Two-finger tap-and-a-half drag, a pointer acceleration curve, and a visible client-side virtual cursor in trackpad mode (`cursorLocation` already exists; drawing it locally helps on laggy links).

## Suggested first picks

1. Special keys toolbar — biggest daily pain, smallest lift.
2. Per-machine defaults — small model change, immediate comfort win.
3. Wake-on-LAN — high perceived value, self-contained networking code.

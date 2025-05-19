# _forDeadJerry

This repository contains the experimental **Shakedown Shuffle** SwiftUI app. The app lets you browse and stream Grateful Dead and Jerry Garcia shows from locally bundled JSON data.

## YouTube Support

A new YouTube section lists shows that have associated YouTube videos. Selecting a show opens an in‑app player powered by `WKWebView`.

The `LandingView` now links to this section and the `PlayerCoordinator` can track YouTube playback alongside the existing Dead and Jerry players.

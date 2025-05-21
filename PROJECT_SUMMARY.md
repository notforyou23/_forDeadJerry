**Project:** Shakedown Shuffle

**Purpose:**
The Shakedown Shuffle app is an experimental iOS application built with SwiftUI. Its primary purpose is to allow users to browse and stream Grateful Dead and Jerry Garcia music shows. The audio content is sourced from locally bundled JSON data. Additionally, the app integrates YouTube functionality to play shows that have associated videos.

**Main Features:**
*   **Browse and Stream Shows:** Users can browse through a collection of Grateful Dead and Jerry Garcia shows.
*   **Local Data:** Show information and potentially audio metadata are stored in local JSON files.
*   **YouTube Integration:** A dedicated section lists shows with YouTube videos, which can be played using an in-app `WKWebView`.
*   **Playback Coordination:** The app seems to have a system (`PlayerCoordinator`) to manage playback from different sources (local audio and YouTube).
*   **SwiftUI Interface:** The application's user interface is built using SwiftUI.
*   **Data Management:** The app uses Core Data for persistence, as indicated by the `.xcdatamodeld` file.
*   **Show History:** Features like `ShowHistoryManager` and `ShowHistoryView` suggest the app keeps track of listened shows.
*   **Categorization/Filtering:** Files like `show_categories.json` and views like `EraShowsView` imply that shows can be categorized or filtered (e.g., by era).

**Technologies Used:**
*   **Swift:** The primary programming language for iOS development.
*   **SwiftUI:** The modern declarative UI framework for building iOS apps.
*   **Core Data:** Apple's framework for data persistence.
*   **WKWebView:** Used for embedding web content, specifically for playing YouTube videos.
*   **JSON:** Used for storing show data locally.
*   **GitHub Actions:** Used for CI/CD, as indicated by the `.github/workflows/swift.yml` file.

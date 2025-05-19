import Foundation
import Combine

@MainActor
class YouTubeShowViewModel: ObservableObject {
    static let shared = YouTubeShowViewModel()

    private let favoriteShowsKey = "youtubeFavoriteShows"

struct YouTubeShow: Identifiable, Codable {
        let id: String
        let date: String
        let venue: String
        let location: String
        let name: String
        let urlString: String
        let url: String?
        let setlists: [[String]]
        let notes: String?

        /// Convert the stored YouTube link into an embeddable URL that auto plays
        /// and starts unmuted. Falls back to the original URL if parsing fails.
        var youtubeURL: URL? {
            if let id = Self.extractVideoID(from: urlString) {
                var components = URLComponents()
                components.scheme = "https"
                components.host = "www.youtube.com"
                components.path = "/embed/\(id)"
                components.queryItems = [
                    URLQueryItem(name: "playsinline", value: "1"),
                    URLQueryItem(name: "autoplay", value: "1"),
                    URLQueryItem(name: "mute", value: "0")
                ]
                return components.url
            }
            return URL(string: urlString)
        }

        /// Standard watch URL used as a fallback when embedding fails.
        var watchURL: URL? {
            if let id = Self.extractVideoID(from: urlString) {
                var components = URLComponents()
                components.scheme = "https"
                components.host = "www.youtube.com"
                components.path = "/watch"
                components.queryItems = [URLQueryItem(name: "v", value: id)]
                return components.url
            }
            return URL(string: urlString)
        }

        /// Attempt to extract a YouTube video ID from a variety of URL formats.
        private static func extractVideoID(from link: String) -> String? {
            // Trim whitespace/newlines and create URL
            let trimmed = link.trimmingCharacters(in: .whitespacesAndNewlines)
            guard let url = URL(string: trimmed) else { return nil }

            let host = url.host ?? ""

            // https://youtu.be/<id>
            if host.contains("youtu.be") {
                return url.pathComponents.dropFirst().first
            }

            // Variations like youtube.com, m.youtube.com, youtube-nocookie.com
            if host.contains("youtube") {
                let components = URLComponents(url: url, resolvingAgainstBaseURL: false)

                // Standard watch URL: https://youtube.com/watch?v=<id>
                if let id = components?.queryItems?.first(where: { $0.name == "v" })?.value {
                    return id
                }

                let parts = url.pathComponents

                // /embed/<id>
                if let idx = parts.firstIndex(of: "embed"), parts.count > idx + 1 {
                    return parts[idx + 1]
                }

                // /shorts/<id>, /live/<id>
                if let idx = parts.firstIndex(where: { $0 == "shorts" || $0 == "live" }), parts.count > idx + 1 {
                    return parts[idx + 1]
                }

                // /v/<id>
                if parts.count > 2 && parts[1] == "v" {
                    return parts[2]
                }
            }

            return nil
        }
    }


    struct ShowData: Codable {
        let id: String
        let date: String
        let venue: String
        let location: String
        let name: String
        let url: String?
        let setlists: [[String]]
        let notes: String?
        let download_info: [DownloadInfo]?
    }

    struct DownloadInfo: Codable {
        let video_id: String?
        let source: String?
        let url: String?
    }

    @Published private(set) var shows: [YouTubeShow] = []
    @Published private(set) var isLoading = false
    @Published private(set) var error: Error?
    @Published var currentShow: YouTubeShow?
    @Published var isPlaying = false
    @Published var coordinator: WebViewCoordinator?
    @Published private(set) var favoriteShows: [YouTubeShow] = []
    @Published var isPlayerPresented = false

    private init() {
        loadFavorites()
    }

    func loadShows() async {
        isLoading = true
        error = nil
        do {
            guard let url = Bundle.main.url(forResource: "master_jerry_db", withExtension: "json") else {
                throw NSError(domain: "YouTubeShowViewModel", code: 0, userInfo: [NSLocalizedDescriptionKey: "Data file missing"])
            }
            let data = try Data(contentsOf: url)
            let raw = try JSONDecoder().decode([ShowData].self, from: data)
            shows = raw.compactMap { item in
                guard let info = item.download_info?.first(where: { $0.source == "youtube" }),
                      let link = info.url else { return nil }
                return YouTubeShow(id: item.id,
                                   date: item.date,
                                   venue: item.venue,
                                   location: item.location,
                                   name: item.name.isEmpty ? "Jerry Garcia" : item.name,
                                   urlString: link,
                                   url: item.url,
                                   setlists: item.setlists,
                                   notes: item.notes)
            }
        } catch {
            self.error = error
        }
        isLoading = false
    }

    func play(show: YouTubeShow) {
        currentShow = show
        guard let url = show.youtubeURL else {
            coordinator = nil
            return
        }

        if let existing = coordinator {
            if existing.url != url {
                existing.setURL(url, fallback: show.watchURL)
            }
        } else {
            coordinator = WebViewCoordinator(url: url, fallbackURL: show.watchURL)
        }

        isPlaying = true
        PlayerCoordinator.shared.setActivePlayer(.youtube)
    }

    func stopPlayback() {
        isPlaying = false
        currentShow = nil
        coordinator = nil
    }

    func presentPlayer() {
        isPlayerPresented = true
    }

    func dismissPlayer() {
        isPlayerPresented = false
    }

    private func loadFavorites() {
        if let data = UserDefaults.standard.data(forKey: favoriteShowsKey),
           let favorites = try? JSONDecoder().decode([YouTubeShow].self, from: data) {
            self.favoriteShows = favorites
        }
    }

    private func saveFavorites() {
        if let data = try? JSONEncoder().encode(favoriteShows) {
            UserDefaults.standard.set(data, forKey: favoriteShowsKey)
        }
    }

    func toggleFavorite(_ show: YouTubeShow) {
        if let index = favoriteShows.firstIndex(where: { $0.id == show.id }) {
            favoriteShows.remove(at: index)
        } else {
            favoriteShows.append(show)
        }
        saveFavorites()
    }
}

// Conformance to DetailableShow for use with UnifiedShowDetailView
extension YouTubeShowViewModel.YouTubeShow: DetailableShow {
    var detailTitle: String { name }
    var locationString: String { location }
    var sectionType: AppSection { .youtube }
    var sourceInfo: String? { nil }
    var rating: Double? { nil }
    var showNotes: String? { notes }
    var showSetlists: [[String]]? { setlists }
}

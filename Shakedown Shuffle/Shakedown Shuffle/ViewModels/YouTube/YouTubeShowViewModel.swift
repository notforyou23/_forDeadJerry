import Foundation
import Combine

@MainActor
class YouTubeShowViewModel: ObservableObject {
    static let shared = YouTubeShowViewModel()

    struct YouTubeShow: Identifiable, Codable {
        let id: String
        let date: String
        let venue: String
        let location: String
        let name: String
        let urlString: String

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

        /// Attempt to extract a YouTube video ID from a variety of URL formats.
        private static func extractVideoID(from link: String) -> String? {
            guard let url = URL(string: link) else { return nil }
            let host = url.host ?? ""
            if host.contains("youtu.be") {
                return url.pathComponents.dropFirst().first.map(String.init)
            }
            if host.contains("youtube.com") {
                let comps = URLComponents(url: url, resolvingAgainstBaseURL: false)
                if let id = comps?.queryItems?.first(where: { $0.name == "v" })?.value {
                    return id
                }
                let parts = url.pathComponents
                if let idx = parts.firstIndex(of: "embed"), parts.count > idx + 1 {
                    return parts[idx + 1]
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

    private init() {}

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
                                   urlString: link)
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
                existing.setURL(url)
            }
        } else {
            coordinator = WebViewCoordinator(url: url)
        }

        isPlaying = true
        PlayerCoordinator.shared.setActivePlayer(.youtube)
    }

    func stopPlayback() {
        isPlaying = false
    }
}

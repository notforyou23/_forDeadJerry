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

        var youtubeURL: URL? {
            URL(string: urlString)
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
        if let url = show.youtubeURL {
            if coordinator?.url != url {
                coordinator = WebViewCoordinator(url: url)
            }
        } else {
            coordinator = nil
        }
        isPlaying = true
        PlayerCoordinator.shared.setActivePlayer(.youtube)
    }

    func stopPlayback() {
        isPlaying = false
    }
}

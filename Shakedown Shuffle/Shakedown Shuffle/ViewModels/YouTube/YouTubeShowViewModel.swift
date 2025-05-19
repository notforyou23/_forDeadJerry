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
        let videoID: String

        var youtubeURL: URL? {
            URL(string: "https://www.youtube.com/embed/\(videoID)?playsinline=1")
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
    }

    @Published private(set) var shows: [YouTubeShow] = []
    @Published private(set) var isLoading = false
    @Published private(set) var error: Error?
    @Published var currentShow: YouTubeShow?
    @Published var isPlaying = false

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
                guard let vid = item.download_info?.first(where: { $0.source == "youtube" })?.video_id else { return nil }
                return YouTubeShow(id: item.id, date: item.date, venue: item.venue, location: item.location, name: item.name.isEmpty ? "Jerry Garcia" : item.name, videoID: vid)
            }
        } catch {
            self.error = error
        }
        isLoading = false
    }

    func play(show: YouTubeShow) {
        currentShow = show
        isPlaying = true
        PlayerCoordinator.shared.setActivePlayer(.youtube)
    }

    func stopPlayback() {
        isPlaying = false
    }
}

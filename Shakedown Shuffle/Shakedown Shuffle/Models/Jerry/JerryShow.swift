import Foundation

// Model for loading from full_master_jerry.json
struct JerryShowData: Codable {
    let id: String
    let date: String
    let venue: String
    let location: String
    let name: String
    let url: String?
    let setlists: [[String]]
    let notes: String?
}

// Combined model for display and playback
struct JerryShow: Identifiable, Codable {
    let id: String
    let date: String
    let venue: String
    let location: String
    let name: String
    let url: String?
    let setlists: [[String]]
    let notes: String?
    let folder: String
    var audioFiles: [JerryAudioFile]?
    
    // For history tracking
    var lastPlayedDate: Date?
    var playCount: Int
    var isPartiallyPlayed: Bool
    var isCompleted: Bool
    var isFavorite: Bool
    
    // Alias for compatibility with existing views
    var downloads: [JerryAudioFile]? {
        get { audioFiles }
        set { audioFiles = newValue }
    }
    
    // Computed property for audio URL construction
    var audioBasePath: String {
        "recordings/Jerry/Jerry Garcia Shows/\(folder)"
    }
    
    // Sort audio files by track number if available
    var sortedAudioFiles: [JerryAudioFile]? {
        audioFiles?.sorted { file1, file2 in
            // First try extracted track numbers
            if let num1 = file1.extractedTrackNumber,
               let num2 = file2.extractedTrackNumber {
                return num1 < num2
            }
            // Fall back to filename comparison
            return file1.name < file2.name
        }
    }
    
    // Initialize from master data and show file
    init(masterData: JerryShowData, folder: String, audioFiles: [JerryAudioFile]?) {
        self.id = masterData.id
        self.date = masterData.date
        self.venue = masterData.venue
        self.location = masterData.location
        self.name = masterData.name
        self.url = masterData.url
        self.setlists = masterData.setlists
        self.notes = masterData.notes
        self.folder = folder
        self.audioFiles = audioFiles
        
        // Initialize history tracking fields
        self.lastPlayedDate = nil
        self.playCount = 0
        self.isPartiallyPlayed = false
        self.isCompleted = false
        self.isFavorite = false
    }
    
    // For decoding from UserDefaults
    enum CodingKeys: String, CodingKey {
        case id, date, venue, location, name, url, setlists, notes, folder, audioFiles
        case lastPlayedDate, playCount, isPartiallyPlayed, isCompleted, isFavorite
    }
}

struct JerryAudioFile: Codable, Identifiable {
    let name: String
    let path: String
    let songTitle: String?
    let set: String?
    let position: Int?
    let trackNumber: Int?  // Added to handle numbered files
    
    var fullPath: String {
        "recordings/\(path)"
    }
    
    var id: String { name }
    
    // Extract track number from filename if present (e.g., "01_song.mp3" -> 1)
    var extractedTrackNumber: Int? {
        if let firstPart = name.split(separator: "_").first,
           let number = Int(firstPart) {
            return number
        }
        return nil
    }
    
    enum CodingKeys: String, CodingKey {
        case name, path
        case songTitle = "song_title"
        case set, position
        case trackNumber = "track_number"
    }
}

// We'll keep these for future use but they're not required for initial implementation
struct JerryShowMetadata: Codable {
    let recordingInfo: JerryRecordingInfo?
    let bandMembers: [String: String?]?
    let notes: String?
    
    enum CodingKeys: String, CodingKey {
        case recordingInfo = "recording_info"
        case bandMembers = "band_members"
        case notes
    }
}

struct JerryRecordingInfo: Codable {
    let sourceType: String?
    let notes: String?
    let lineage: String?
    let taper: String?
    let transfer: String?
    
    enum CodingKeys: String, CodingKey {
        case sourceType = "source_type"
        case notes, lineage, taper, transfer
    }
} 
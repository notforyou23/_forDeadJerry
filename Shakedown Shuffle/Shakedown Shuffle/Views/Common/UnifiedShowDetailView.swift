import SwiftUI

// Protocol for show detail requirements
protocol DetailableShow {
    var detailTitle: String { get }
    var date: String { get }
    var venue: String { get }
    var locationString: String { get }
    var sectionType: AppSection { get }
    var sourceInfo: String? { get }
    var rating: Double? { get }
    var showNotes: String? { get }
    var showSetlists: [[String]]? { get }
}

// Extension for EnrichedShow to conform to DetailableShow
extension EnrichedShow: DetailableShow {
    var detailTitle: String {
        // Remove "Grateful Dead Live at" prefix if present
        if metadata.title.hasPrefix("Grateful Dead Live at ") {
            return String(metadata.title.dropFirst("Grateful Dead Live at ".count))
        }
        return metadata.title
    }
    
    var date: String {
        return identifier.prefix(10).description
    }
    
    var venue: String {
        return location.venue
    }
    
    var locationString: String {
        return "\(location.city), \(location.state)"
    }
    
    var sectionType: AppSection {
        return .dead
    }
    
    var sourceInfo: String? {
        return recordingInfo.sourceType
    }
    
    var rating: Double? {
        return recordingInfo.avgRating
    }
    
    var showNotes: String? {
        // Combine various note fields
        let noteFields = [
            metadata.notes
            // We can't access these fields as they don't exist in the recordingInfo struct
            // Commenting them out for now
            // recordingInfo.taper.isEmpty ? nil : "Taper: \(recordingInfo.taper)",
            // recordingInfo.transferer.isEmpty ? nil : "Transfer: \(recordingInfo.transferer)",
            // recordingInfo.lineage.isEmpty ? nil : "Lineage: \(recordingInfo.lineage)"
        ].compactMap { $0 }
        
        return noteFields.isEmpty ? nil : noteFields.joined(separator: "\n\n")
    }
    
    var showSetlists: [[String]]? {
        // Try to reconstruct setlist from tracks
        var sets: [[String]] = []
        var currentSet: [String] = []
        
        for track in tracks {
            // Check if this track is in a new set
            // Since 'set' is not a property of Track, we'll just group all tracks together
            currentSet.append(track.title)
        }
        
        // Add the last set if not empty
        if !currentSet.isEmpty {
            sets.append(currentSet)
        }
        
        return sets.isEmpty ? nil : sets
    }
}

// Extension for JerryShow to conform to DetailableShow
extension JerryShow: DetailableShow {
    var detailTitle: String {
        return name
    }
    
    var locationString: String {
        return location
    }
    
    var sectionType: AppSection {
        return .jerry
    }
    
    var sourceInfo: String? {
        return nil // JerryShow might not have this info directly
    }
    
    var rating: Double? {
        return nil // JerryShow might not have ratings
    }
    
    var showNotes: String? {
        return notes
    }
    
    var showSetlists: [[String]]? {
        return setlists
    }
}

// Unified show detail view
struct UnifiedShowDetailView: View {
    let show: DetailableShow
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Show header
                VStack(alignment: .leading, spacing: 4) {
                    Text(show.detailTitle)
                        .font(.title2)
                        .bold()
                        .foregroundColor(AppTheme.textPrimary)
                    
                    Text(show.date)
                        .font(.headline)
                        .foregroundColor(AppTheme.accentColor(for: show.sectionType))
                    
                    Text("\(show.venue)")
                        .font(.subheadline)
                        .foregroundColor(AppTheme.textPrimary)
                    
                    Text(show.locationString)
                        .font(.subheadline)
                        .foregroundColor(AppTheme.textSecondary)
                }
                .padding(.bottom)
                
                // Recording information
                if let sourceInfo = show.sourceInfo {
                    detailSection(title: "Recording Info", content: {
                        HStack {
                            Label(sourceInfo, systemImage: "waveform")
                                .foregroundColor(AppTheme.textPrimary)
                            
                            Spacer()
                            
                            if let rating = show.rating {
                                Label(String(format: "%.1f", rating), systemImage: "star.fill")
                                    .foregroundColor(.yellow)
                            }
                        }
                    })
                }
                
                // Setlist
                if let setlists = show.showSetlists, !setlists.isEmpty {
                    detailSection(title: "Setlist", content: {
                        ForEach(0..<setlists.count, id: \.self) { setIndex in
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Set \(setIndex + 1)")
                                    .font(.headline)
                                    .foregroundColor(AppTheme.accentColor(for: show.sectionType))
                                
                                ForEach(setlists[setIndex], id: \.self) { song in
                                    Text("• \(song)")
                                        .foregroundColor(AppTheme.textPrimary)
                                }
                            }
                            .padding(.bottom, 8)
                        }
                    })
                }
                
                // Notes
                if let notes = show.showNotes, !notes.isEmpty {
                    detailSection(title: "Notes", content: {
                        Text(notes)
                            .foregroundColor(AppTheme.textSecondary)
                    })
                }
                
                Spacer()
            }
            .padding()
        }
        .navigationTitle("Show Details")
        .background(
            RadialGradient(
                gradient: AppTheme.mainGradient(for: show.sectionType),
                center: .top,
                startRadius: 0,
                endRadius: 500
            )
            .ignoresSafeArea()
        )
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Done") {
                    dismiss()
                }
            }
        }
    }
    
    // Helper function to create consistent section styling
    @ViewBuilder
    private func detailSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.title3)
                .bold()
                .foregroundColor(AppTheme.textPrimary)
                .padding(.bottom, 2)
            
            content()
        }
        .padding(.vertical, 8)
    }
}

// Preview for the unified show detail view
#Preview {
    NavigationView {
        // Create a sample EnrichedShow for preview
        let previewShow = createPreviewShow()
        
        return UnifiedShowDetailView(show: previewShow)
    }
    .preferredColorScheme(.dark)
}

// Helper function to create a sample show for preview
private func createPreviewShow() -> EnrichedShow {
    let metadata = ShowMetadata(
        title: "Grateful Dead Live at Barton Hall, Cornell University",
        collection: ["GratefulDead"],
        source: "Audience",
        lineage: "Master > Cassette > DAT > CD",
        notes: "This is widely regarded as one of the best Dead shows of all time.",
        setlist: "Set 1: New Minglewood Blues, Loser, El Paso"
    )
    
    let location = Location(
        venue: "Barton Hall, Cornell University",
        city: "Ithaca",
        state: "NY"
    )
    
    let recordingInfo = RecordingInfo(
        sourceType: "SBD",
        avgRating: 4.9,
        downloads: 500000,
        downloadRate: 100.0,
        numReviews: 1000,
        addedDate: "2004-06-30"
    )
    
    let tracks = [
        Track(title: "New Minglewood Blues", filename: "gd77-05-08d1t01.mp3", length: "5:34", trackNumber: 1),
        Track(title: "Loser", filename: "gd77-05-08d1t02.mp3", length: "7:47", trackNumber: 2),
        Track(title: "El Paso", filename: "gd77-05-08d1t03.mp3", length: "4:50", trackNumber: 3)
    ]
    
    return EnrichedShow(
        identifier: "gd1977-05-08",
        score: 4.9,
        location: location,
        recordingInfo: recordingInfo,
        metadata: metadata,
        tracks: tracks
    )
} 
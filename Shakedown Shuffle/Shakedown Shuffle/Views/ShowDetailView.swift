import SwiftUI

struct ShowDetailView: View {
    let show: EnrichedShow?
    
    private func formatTitle(_ title: String) -> String {
        // Remove "Grateful Dead Live at" prefix if present
        if title.hasPrefix("Grateful Dead Live at ") {
            return String(title.dropFirst("Grateful Dead Live at ".count))
        }
        return title
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Show Info
                VStack(alignment: .leading, spacing: 8) {
                    Text(formatTitle(show?.metadata.title ?? "Unknown Show"))
                        .font(.title2)
                        .bold()
                    
                    Text("\(show?.location.venue ?? "") • \(show?.location.city ?? ""), \(show?.location.state ?? "")")
                        .font(.headline)
                }
                .padding()
                
                // Recording Info
                if let recordingInfo = show?.recordingInfo {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Recording Details")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            InfoRow(label: "Source", value: recordingInfo.sourceType)
                            InfoRow(label: "Rating", value: String(format: "%.2f", recordingInfo.avgRating))
                            InfoRow(label: "Downloads", value: "\(recordingInfo.downloads)")
                            InfoRow(label: "Reviews", value: "\(recordingInfo.numReviews)")
                            InfoRow(label: "Added", value: recordingInfo.addedDate)
                        }
                        .padding(.horizontal)
                    }
                }
                
                // Source Info
                if let metadata = show?.metadata {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Source Information")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        if let source = metadata.source {
                            InfoRow(label: "Source", value: source)
                        }
                        if let lineage = metadata.lineage {
                            InfoRow(label: "Lineage", value: lineage)
                        }
                        if let notes = metadata.notes {
                            InfoRow(label: "Notes", value: notes)
                        }
                    }
                    .padding(.horizontal)
                }
                
                // Track List
                VStack(alignment: .leading, spacing: 8) {
                    Text("Track List")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    ForEach(show?.tracks ?? [], id: \.filename) { track in
                        HStack {
                            Text("\(track.trackNumber).")
                                .foregroundColor(.secondary)
                            Text(track.title)
                            Spacer()
                            Text(track.length)
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal)
                    }
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct InfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.body)
        }
        .padding(.vertical, 2)
    }
}

// Preview
struct ShowDetailView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            ShowDetailView(show: nil)
        }
    }
} 
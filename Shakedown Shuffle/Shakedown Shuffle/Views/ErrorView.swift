import SwiftUI

struct ErrorView: View {
    let error: Error
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 50))
                .foregroundColor(.red)
            
            Text("Error Loading Data")
                .font(.title)
            
            Text(error.localizedDescription)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
                .foregroundColor(.secondary)
            
            Button("Try Again") {
                // Reload the app
                // This is a simple way to reload - you might want to implement
                // a more sophisticated retry mechanism
                Task {
                    do {
                        try await DatabaseManager.shared.loadData()
                    } catch {
                        // Handle retry error
                    }
                }
            }
            .buttonStyle(.bordered)
        }
        .padding()
    }
}

#Preview {
    ErrorView(error: DatabaseError.fileNotFound("test.json"))
} 
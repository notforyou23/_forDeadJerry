import SwiftUI

struct EraShowsView: View {
    let era: String
    let databaseManager = DatabaseManager.shared
    
    var shows: [String] {
        switch era {
        case "pigpen":
            return databaseManager.getShowsByEra()?.pigpen ?? []
        case "keith":
            return databaseManager.getShowsByEra()?.keith ?? []
        case "brent":
            return databaseManager.getShowsByEra()?.brent ?? []
        case "vince":
            return databaseManager.getShowsByEra()?.vince ?? []
        default:
            return []
        }
    }
    
    var body: some View {
        List {
            ForEach(shows, id: \.self) { show in
                NavigationLink(destination: ShowDetailView(show: databaseManager.getShow(forDate: show))) {
                    Text(show)
                }
            }
        }
        .navigationTitle("\(era.capitalized) Era Shows")
    }
} 

// Preview
struct EraShowsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            EraShowsView(era: "brent")
        }
    }
}

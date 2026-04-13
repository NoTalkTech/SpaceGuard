import SwiftUI

// MARK: - Disk Info Settings View
struct DiskInfoSettingsView: View {
    @Binding var rules: CleanupRules

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                EditableListSection(
                    title: "Included Locations",
                    items: $rules.includeLocations,
                    placeholder: "Add location path..."
                )

                Divider()

                EditableListSection(
                    title: "Excluded Locations",
                    items: $rules.excludeLocations,
                    placeholder: "Add excluded path..."
                )

                Divider()

                EditableListSection(
                    title: "App Caches to Clean",
                    items: $rules.appCachesToClean,
                    placeholder: "Add app bundle ID..."
                )
            }
            .padding()
        }
    }
}

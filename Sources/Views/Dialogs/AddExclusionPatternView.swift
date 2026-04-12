import SwiftUI

struct AddExclusionPatternView: View {
    @Binding var isPresented: Bool
    @Binding var exclusionPatterns: [String]

    @State private var pattern: String = ""
    @State private var description: String = ""

    private let samplePatterns = [
        ".*\\.app$": "Matches all .app files",
        ".*/Library/Preferences/.*": "Matches preference files",
        ".*\\.(dmg|pkg|kext)$": "Matches installer files",
        ".*/Documents/.*\\.pdf$": "Matches PDF files in Documents",
        ".*/Desktop/.*": "Matches all files on Desktop"
    ]

    var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
                    .foregroundColor(.accentColor)

                Text("Add Exclusion Pattern")
                    .font(.headline)

                Spacer()

                Button(action: { isPresented = false }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal)
            .padding(.top)

            Divider()

            Form {
                Section("Pattern") {
                    VStack(alignment: .leading, spacing: 8) {
                        TextField("Enter regular expression pattern", text: $pattern)
                            .textFieldStyle(.roundedBorder)

                        Text("Examples:")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        ForEach(Array(samplePatterns.keys.sorted()), id: \.self) { key in
                            HStack {
                                Text(key)
                                    .font(.caption)
                                    .foregroundColor(.blue)
                                    .textSelection(.enabled)

                                Spacer()

                                Text(samplePatterns[key]!)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.vertical, 2)
                            .onTapGesture {
                                pattern = key
                            }
                        }
                    }
                }

                Section("Description") {
                    TextField("Optional description", text: $description)
                        .textFieldStyle(.roundedBorder)
                }

                Section("How Patterns Work") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Patterns are regular expressions that match file paths.")
                            .font(.caption)

                        Text("Files matching any pattern will be excluded from cleanup.")
                            .font(.caption)

                        Text("Use regex syntax: .* for any characters, \\. for literal dot, $ for end of string.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.horizontal)

            Divider()

            // Action Buttons
            HStack {
                Button("Cancel") {
                    isPresented = false
                }
                .keyboardShortcut(.escape)

                Spacer()

                Button("Add Pattern") {
                    addPattern()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(pattern.isEmpty)
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
        .frame(width: 500, height: 500)
    }

    private func addPattern() {
        guard !pattern.isEmpty else { return }

        // Validate pattern
        if let _ = try? NSRegularExpression(pattern: pattern) {
            if !exclusionPatterns.contains(pattern) {
                exclusionPatterns.append(pattern)
            }
            isPresented = false
        } else {
            // Show error - pattern is invalid
            // In a real app, you'd show an alert here
            print("Invalid regex pattern: \(pattern)")
        }
    }
}

struct AddExclusionPatternView_Previews: PreviewProvider {
    static var previews: some View {
        @State var patterns: [String] = []

        AddExclusionPatternView(
            isPresented: .constant(true),
            exclusionPatterns: $patterns
        )
    }
}
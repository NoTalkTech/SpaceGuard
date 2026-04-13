import SwiftUI

struct AddCustomRiskOverrideView: View {
    @Binding var isPresented: Bool
    @Binding var customRiskOverrides: [CustomRiskOverride]

    @State private var path: String = ""
    @State private var selectedRiskLevel: RiskLevel = .medium
    @State private var showFilePicker = false

    var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
                    .foregroundColor(.accentColor)

                Text("Add Custom Risk Override")
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
                Section("Path") {
                    HStack {
                        TextField("Enter file or directory path", text: $path)
                            .textFieldStyle(.roundedBorder)

                        Button("Browse...") {
                            showFilePicker = true
                        }
                    }

                    Text("Examples: ~/Downloads/old_files, /Users/Shared/Temp")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Section("Risk Level") {
                    Picker("Risk Level", selection: $selectedRiskLevel) {
                        ForEach(RiskLevel.allCases, id: \.self) { level in
                            HStack {
                                Circle()
                                    .fill(riskColor(level))
                                    .frame(width: 8, height: 8)
                                Text(level.rawValue)
                                Spacer()
                                Text(level.description)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .tag(level)
                        }
                    }
                    .pickerStyle(.radioGroup)
                }

                Section("Description") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("This will override the automatic risk classification for files matching the specified path prefix.")
                            .font(.caption)

                        Text("For example, setting '~/Downloads' to High risk will prevent any file in your Downloads folder from being deleted.")
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

                Button("Add Override") {
                    addOverride()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(path.isEmpty)
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
        .frame(width: 500, height: 420)
        .sheet(isPresented: $showFilePicker) {
            FilePickerView(selectedPath: $path)
        }
    }

    private func addOverride() {
        guard !path.isEmpty else { return }

        // Expand tilde in path
        let expandedPath = (path as NSString).expandingTildeInPath

        // Check if override already exists for this path
        if !customRiskOverrides.contains(where: { $0.path == expandedPath }) {
            let newOverride = CustomRiskOverride(path: expandedPath, riskLevel: selectedRiskLevel)
            customRiskOverrides.append(newOverride)
        }

        isPresented = false
    }

    private func riskColor(_ level: RiskLevel) -> Color {
        switch level {
        case .low: return .green
        case .medium: return .orange
        case .high: return .red
        }
    }
}

struct FilePickerView: View {
    @Binding var selectedPath: String
    @Environment(\.dismiss) var dismiss

    @State private var isSelectingDirectory = false
    @State private var isSelectingFile = false

    var body: some View {
        VStack(spacing: 20) {
            HStack {
                Image(systemName: "folder.fill")
                    .font(.title2)
                    .foregroundColor(.accentColor)

                Text("Select Path")
                    .font(.headline)

                Spacer()

                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()

            VStack(spacing: 16) {
                Button("Select Directory") {
                    isSelectingDirectory = true
                }
                .buttonStyle(.bordered)
                .frame(maxWidth: .infinity)

                Button("Select File") {
                    isSelectingFile = true
                }
                .buttonStyle(.bordered)
                .frame(maxWidth: .infinity)

                Divider()

                Text("Current selection: \(selectedPath)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal)

            Spacer()

            HStack {
                Spacer()
                Button("Done") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
        }
        .frame(width: 400, height: 300)
        .fileImporter(
            isPresented: $isSelectingDirectory,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            handleSelection(result: result)
        }
        .fileImporter(
            isPresented: $isSelectingFile,
            allowedContentTypes: [.item],
            allowsMultipleSelection: false
        ) { result in
            handleSelection(result: result)
        }
    }

    private func handleSelection(result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            if let url = urls.first {
                selectedPath = url.path
            }
        case .failure(let error):
            print("Error selecting file: \(error)")
        }
    }
}

struct AddCustomRiskOverrideView_Previews: PreviewProvider {
    static var previews: some View {
        @State var overrides: [CustomRiskOverride] = []

        AddCustomRiskOverrideView(
            isPresented: .constant(true),
            customRiskOverrides: $overrides
        )
    }
}
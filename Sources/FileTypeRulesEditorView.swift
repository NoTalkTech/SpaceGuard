import SwiftUI

struct FileTypeRulesEditorView: View {
    @Binding var isPresented: Bool
    @Binding var fileTypeRules: FileTypeRules

    @State private var enabled: Bool = false
    @State private var whitelistText: String = ""
    @State private var blacklistText: String = ""
    @State private var validationError: String?
    @State private var showExamples = false

    private let commonExtensions = [
        "log", "cache", "tmp", "temp", "db", "db-wal", "db-shm",
        "app", "dmg", "pkg", "kext", "component", "framework",
        "jpg", "jpeg", "png", "gif", "pdf", "doc", "docx", "xls", "xlsx"
    ]

    var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                Image(systemName: "doc.text.fill")
                    .font(.title2)
                    .foregroundColor(.accentColor)

                Text("Edit File Type Rules")
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
                Section("Filtering Mode") {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Toggle("Enable file type filtering", isOn: $enabled)
                                .help("When enabled, only specified file extensions will be cleaned")
                                .frame(maxWidth: .infinity, alignment: .leading)

                            Button("Show Examples") {
                                showExamples.toggle()
                            }
                            .buttonStyle(.bordered)
                            .font(.caption)
                        }

                        if showExamples {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Common patterns:")
                                    .font(.caption)
                                    .foregroundColor(.secondary)

                                Text("• Whitelist only: 'log,cache,tmp' - clean only these file types")
                                    .font(.caption)

                                Text("• Blacklist only: 'app,dmg,pkg' - never clean these file types")
                                    .font(.caption)

                                Text("• Mixed: 'log,tmp' whitelist with 'app,dmg' blacklist")
                                    .font(.caption)
                            }
                            .padding(8)
                            .background(Color.secondary.opacity(0.1))
                            .cornerRadius(8)
                        }
                    }
                }

                Section("Whitelisted Extensions") {
                    VStack(alignment: .leading, spacing: 8) {
                        TextField("Extensions to allow (comma-separated)", text: $whitelistText)
                            .textFieldStyle(.roundedBorder)
                            .help("Extensions that CAN be cleaned (e.g., 'log,cache,tmp'). Leave empty to allow all.")
                            .onChange(of: whitelistText) { _ in
                                validateInput()
                            }

                        Text("Note: Empty whitelist means ALL file types are allowed, except blacklisted.")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        if !enabled && !whitelistText.isEmpty {
                            Text("Warning: Filtering is disabled but whitelist is not empty")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                    }
                }

                Section("Blacklisted Extensions") {
                    VStack(alignment: .leading, spacing: 8) {
                        TextField("Extensions to never clean (comma-separated)", text: $blacklistText)
                            .textFieldStyle(.roundedBorder)
                            .help("Extensions that will NEVER be cleaned (e.g., 'app,dmg,pkg')")
                            .onChange(of: blacklistText) { _ in
                                validateInput()
                            }

                        HStack {
                            Text("Current blacklist defaults:")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            Spacer()

                            Text(".app, .dmg, .pkg, .kext, .component")
                                .font(.caption)
                                .foregroundColor(.blue)
                        }
                    }
                }

                if let error = validationError {
                    Section("Validation") {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                            .padding(4)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                Section("How File Type Filtering Works") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("1. Whitelist empty = ALL file types allowed")
                            .font(.caption)

                        Text("2. Whitelist not empty = ONLY specified extensions allowed")
                            .font(.caption)

                        Text("3. Blacklist always applies - these extensions are NEVER cleaned")
                            .font(.caption)

                        Text("4. Extensions should be without dots (use 'log' not '.log')")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Text("5. Case-insensitive matching")
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

                Button("Save Changes") {
                    saveChanges()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(validationError != nil)
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
        .frame(width: 500, height: 600)
        .onAppear {
            loadCurrentRules()
        }
    }

    private func loadCurrentRules() {
        // Load current values
        enabled = !fileTypeRules.whitelistedExtensions.isEmpty
        whitelistText = fileTypeRules.whitelistedExtensions.joined(separator: ", ")
        blacklistText = fileTypeRules.blacklistedExtensions.joined(separator: ", ")
        validateInput()
    }

    private func validateInput() {
        validationError = nil

        // Parse extensions
        let whitelist = parseExtensions(whitelistText)
        let blacklist = parseExtensions(blacklistText)

        // Check for duplicates between whitelist and blacklist
        let intersection = Set(whitelist).intersection(Set(blacklist))
        if !intersection.isEmpty {
            validationError = "Extensions appear in both lists: \(intersection.joined(separator: ", "))"
            return
        }

        // Validate individual extensions
        for ext in whitelist + blacklist {
            if ext.contains(".") {
                validationError = "Extension '\(ext)' should not include dots (use 'log' not '.log')"
                return
            }
            if ext.isEmpty || ext.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                validationError = "Empty extension found - check for extra commas"
                return
            }
            if !ext.allSatisfy({ $0.isLetter || $0.isNumber }) {
                validationError = "Extension '\(ext)' contains invalid characters (letters and numbers only)"
                return
            }
        }

        // If filtering is enabled but whitelist is empty, warn but don't block
        if enabled && whitelist.isEmpty {
            validationError = "Warning: Filtering enabled but whitelist is empty (all file types allowed)"
        }
    }

    private func parseExtensions(_ text: String) -> [String] {
        guard !text.isEmpty else { return [] }
        return text.split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .filter { !$0.isEmpty }
    }

    private func saveChanges() {
        guard validationError == nil else { return }

        // Update rules
        if enabled {
            fileTypeRules.whitelistedExtensions = parseExtensions(whitelistText)
        } else {
            // If filtering is disabled, clear whitelist
            fileTypeRules.whitelistedExtensions = []
        }
        fileTypeRules.blacklistedExtensions = parseExtensions(blacklistText)

        isPresented = false
    }
}

struct FileTypeRulesEditorView_Previews: PreviewProvider {
    static var previews: some View {
        @State var rules = FileTypeRules()
        @State var isPresented = true

        FileTypeRulesEditorView(
            isPresented: $isPresented,
            fileTypeRules: $rules
        )
    }
}
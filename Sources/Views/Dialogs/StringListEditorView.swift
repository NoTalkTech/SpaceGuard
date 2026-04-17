import AppKit
import SwiftUI

struct StringListEditorView: View {
    @Binding var isPresented: Bool
    @Binding var items: [String]

    let title: String
    let subtitle: String
    let placeholder: String
    let emptyStateText: String

    @State private var searchText = ""
    @State private var newItem = ""

    var body: some View {
        VStack(spacing: 20) {
            header

            Divider()

            VStack(alignment: .leading, spacing: 16) {
                searchField
                addControls
                itemList
                footer
            }
            .padding(.horizontal)

            Divider()

            HStack {
                Button("Done") {
                    isPresented = false
                }
                .keyboardShortcut(.defaultAction)

                Spacer()
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
        .frame(width: 640, height: 560)
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.headline)

                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button {
                isPresented = false
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal)
        .padding(.top)
    }

    private var searchField: some View {
        TextField("Search", text: $searchText)
            .textFieldStyle(.roundedBorder)
    }

    private var addControls: some View {
        HStack(spacing: 12) {
            TextField(placeholder, text: $newItem)
                .textFieldStyle(.roundedBorder)
                .onSubmit {
                    addItem()
                }

            Button("Paste") {
                addItemsFromPasteboard()
            }
            .buttonStyle(.bordered)

            Button("Add") {
                addItem()
            }
            .buttonStyle(.borderedProminent)
            .disabled(trimmedNewItem.isEmpty)
        }
    }

    private var itemList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 8) {
                if filteredItems.isEmpty {
                    Text(emptyListText)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 8)
                } else {
                    ForEach(filteredItems, id: \.self) { item in
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item)
                                    .font(.system(size: 13))
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                    .help(item)

                                Text(itemKindText(for: item))
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            Button {
                                removeItem(item)
                            } label: {
                                Image(systemName: "trash")
                                    .foregroundColor(.red)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(Color.secondary.opacity(0.08))
                        .cornerRadius(8)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var footer: some View {
        HStack {
            Text("\(items.count) item\(items.count == 1 ? "" : "s")")
                .font(.caption)
                .foregroundColor(.secondary)

            Spacer()

            if !items.isEmpty {
                Button("Remove All") {
                    items.removeAll()
                }
                .buttonStyle(.bordered)
            }
        }
    }

    private var filteredItems: [String] {
        if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return items
        }

        return items.filter { item in
            item.localizedCaseInsensitiveContains(searchText)
        }
    }

    private var trimmedNewItem: String {
        newItem.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var emptyListText: String {
        if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return emptyStateText
        }

        return "No matching items."
    }

    private func addItem() {
        guard !trimmedNewItem.isEmpty else { return }
        guard !items.contains(trimmedNewItem) else {
            newItem = ""
            return
        }

        items.append(trimmedNewItem)
        newItem = ""
    }

    private func addItemsFromPasteboard() {
        guard let pastedText = NSPasteboard.general.string(forType: .string) else { return }

        let pastedItems = pastedText
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        for pastedItem in pastedItems where !items.contains(pastedItem) {
            items.append(pastedItem)
        }
    }

    private func removeItem(_ item: String) {
        items.removeAll { $0 == item }
    }

    private func itemKindText(for item: String) -> String {
        if item.hasPrefix("/") || item.hasPrefix("~") {
            return "Path"
        }

        return "App identifier"
    }
}

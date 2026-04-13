import SwiftUI

struct EditableListSection: View {
    let title: String
    @Binding var items: [String]
    let placeholder: String

    @State private var newItem = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .leading, spacing: 12) {
                // Add new item
                HStack {
                    TextField(placeholder, text: $newItem)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit {
                            addItem()
                        }

                    Button(action: addItem) {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(.accentColor)
                    }
                    .buttonStyle(.plain)
                    .disabled(newItem.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .help("Add item")
                }

                // List of items
                if items.isEmpty {
                    Text("No items")
                        .font(.caption)
                        .foregroundColor(Color(hex: "#86868b"))
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(items, id: \.self) { item in
                            HStack {
                                Text(item)
                                    .font(.system(size: 13, weight: .regular))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                Spacer()
                                Button(action: {
                                    if let index = items.firstIndex(of: item) {
                                        items.remove(at: index)
                                    }
                                }) {
                                    Image(systemName: "trash")
                                        .foregroundColor(.red)
                                        .font(.system(size: 11))
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.vertical, 6)
                            .padding(.horizontal, 8)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(4)
                        }
                    }
                    .frame(maxHeight: 120)
                }

                // Info text
                Text("Click trash icon to delete items")
                    .font(.caption)
                    .foregroundColor(Color(hex: "#86868b"))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func addItem() {
        let trimmed = newItem.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if !items.contains(trimmed) {
            items.append(trimmed)
        }
        newItem = ""
    }
}

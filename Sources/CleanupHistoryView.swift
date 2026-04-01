import SwiftUI

struct CleanupHistoryView: View {
    @ObservedObject private var historyManager = CleanupHistoryManager.shared
    @State private var selectedRecord: CleanupHistoryRecord?
    @State private var showingDeleteConfirmation = false
    @State private var recordToDelete: CleanupHistoryRecord?

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerSection

            Divider()

            // Content
            if historyManager.records.isEmpty {
                emptyState
            } else {
                historyList
            }
        }
        .onAppear {
            historyManager.load()
        }
        .sheet(item: $selectedRecord) { record in
            CleanupHistoryDetailView(record: record)
        }
        .alert("Delete Record", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                if let record = recordToDelete {
                    historyManager.deleteRecord(record)
                }
            }
        } message: {
            Text("Are you sure you want to delete this cleanup record?")
        }
    }

    private var headerSection: some View {
        HStack {
            Text("Cleanup History")
                .font(.headline)

            Spacer()

            Button(action: {
                historyManager.clearHistory()
            }) {
                Label("Clear All", systemImage: "trash")
            }
            .disabled(historyManager.records.isEmpty)
            .buttonStyle(.bordered)
        }
        .padding()
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text("No Cleanup History")
                .font(.title2)
                .foregroundColor(.secondary)
            Text("Your cleanup operations will appear here")
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
        }
    }

    private var historyList: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(historyManager.records) { record in
                    CleanupHistoryRowView(record: record)
                        .onTapGesture {
                            selectedRecord = record
                        }
                        .contextMenu {
                            Button(role: .destructive) {
                                recordToDelete = record
                                showingDeleteConfirmation = true
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                }
            }
            .padding()
        }
    }
}

// MARK: - History Row View
struct CleanupHistoryRowView: View {
    let record: CleanupHistoryRecord

    var body: some View {
        HStack(spacing: 12) {
            // Icon
            Image(systemName: record.iconName)
                .font(.title2)
                .foregroundColor(Color(hex: record.iconColorHex))
                .frame(width: 40, height: 40)
                .background(Color(hex: record.iconColorHex).opacity(0.1))
                .cornerRadius(8)

            // Main info
            VStack(alignment: .leading, spacing: 4) {
                Text(record.cleanupType.rawValue)
                    .font(.system(size: 14, weight: .semibold))

                HStack(spacing: 8) {
                    Label("\(record.filesDeleted) files", systemImage: "doc")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Label(record.formattedSpaceFreed, systemImage: "internaldrive")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            // Date and status
            VStack(alignment: .trailing, spacing: 4) {
                Text(record.formattedDate)
                    .font(.caption)
                    .foregroundColor(.secondary)

                if record.wasCancelled {
                    Label("Cancelled", systemImage: "xmark.circle.fill")
                        .font(.caption)
                        .foregroundColor(.orange)
                } else if record.errors > 0 {
                    Label("\(record.errors) errors", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundColor(.orange)
                } else {
                    Label("Success", systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundColor(.green)
                }
            }
        }
        .padding(12)
        .background(Color.secondary.opacity(0.05))
        .cornerRadius(10)
    }
}

// MARK: - History Detail View
struct CleanupHistoryDetailView: View {
    let record: CleanupHistoryRecord
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Cleanup Details")
                    .font(.headline)
                Spacer()
                Button("Done") { dismiss() }
                    .buttonStyle(.borderedProminent)
            }
            .padding()

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Summary
                    summarySection

                    Divider()

                    // Details
                    detailsSection
                }
                .padding()
            }
        }
        .frame(width: 500, height: 500)
    }

    private var summarySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Summary")
                .font(.headline)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                HistorySummaryCard(
                    title: "Files Deleted",
                    value: "\(record.filesDeleted)",
                    icon: "doc.fill",
                    color: .blue
                )
                HistorySummaryCard(
                    title: "Space Freed",
                    value: record.formattedSpaceFreed,
                    icon: "internaldrive.fill",
                    color: .green
                )
                HistorySummaryCard(
                    title: "Duration",
                    value: record.formattedDuration,
                    icon: "clock.fill",
                    color: .orange
                )
                HistorySummaryCard(
                    title: "Status",
                    value: record.wasCancelled ? "Cancelled" : "Completed",
                    icon: record.wasCancelled ? "xmark.circle.fill" : "checkmark.circle.fill",
                    color: record.wasCancelled ? .orange : .green
                )
            }
        }
    }

    private var detailsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Details")
                .font(.headline)

            VStack(alignment: .leading, spacing: 8) {
                DetailRow(label: "Operation Type", value: record.cleanupType.rawValue)
                DetailRow(label: "Date & Time", value: record.formattedDate)
                DetailRow(label: "Errors", value: record.errors > 0 ? "\(record.errors)" : "None")
            }
        }
    }
}

struct HistorySummaryCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Text(value)
                .font(.system(size: 16, weight: .semibold))
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color.opacity(0.1))
        .cornerRadius(8)
    }
}

struct DetailRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 120, alignment: .leading)
            Text(value)
                .font(.caption)
                .foregroundColor(.primary)
            Spacer()
        }
    }
}

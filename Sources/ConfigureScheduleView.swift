import SwiftUI

struct ConfigureScheduleView: View {
    @Binding var isPresented: Bool
    @Binding var scheduledCleanup: ScheduledCleanup?

    @State private var enabled: Bool = false
    @State private var frequency: ScheduledCleanup.CleanupFrequency = .weekly
    @State private var timeOfDay: Date = Calendar.current.date(bySettingHour: 2, minute: 0, second: 0, of: Date()) ?? Date()
    @State private var showTimePicker = false

    var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                Image(systemName: "calendar.badge.clock")
                    .font(.title2)
                    .foregroundColor(.accentColor)

                Text("Configure Scheduled Cleanup")
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
                Section("Schedule") {
                    Toggle("Enable scheduled cleanup", isOn: $enabled)

                    if enabled {
                        Picker("Frequency", selection: $frequency) {
                            ForEach(ScheduledCleanup.CleanupFrequency.allCases, id: \.self) { freq in
                                Text(freq.rawValue).tag(freq)
                            }
                        }
                        .pickerStyle(.segmented)

                        HStack {
                            Text("Time of day")

                            Spacer()

                            Button(action: { showTimePicker.toggle() }) {
                                Text(timeOfDay, style: .time)
                                    .foregroundColor(.accentColor)
                            }
                            .buttonStyle(.plain)
                        }

                        if showTimePicker {
                            DatePicker("Select time", selection: $timeOfDay, displayedComponents: .hourAndMinute)
                                .datePickerStyle(.graphical)
                                .labelsHidden()
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Cleanup will run:")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            if let nextRun = calculateNextRun() {
                                Text("Next run: \(nextRun, style: .date) at \(nextRun, style: .time)")
                                    .font(.caption)
                            }

                            Text("The app must be running for scheduled cleanup to work.")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                        .padding(.vertical, 4)
                    }
                }

                Section("Recommendations") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("• Schedule during off-hours (e.g., 2 AM)")
                            .font(.caption)

                        Text("• Weekly is usually sufficient for most users")
                            .font(.caption)

                        Text("• Ensure the app is running at the scheduled time")
                            .font(.caption)

                        Text("• Scheduled runs will use your current risk settings")
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

                Button("Save Schedule") {
                    saveSchedule()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
        .frame(width: 500, height: 450)
        .onAppear {
            if let schedule = scheduledCleanup {
                enabled = schedule.enabled
                frequency = schedule.frequency
                timeOfDay = schedule.timeOfDay
            }
        }
    }

    private func saveSchedule() {
        let newSchedule = ScheduledCleanup(
            enabled: enabled,
            frequency: frequency,
            timeOfDay: timeOfDay,
            lastRun: scheduledCleanup?.lastRun
        )

        scheduledCleanup = newSchedule
        isPresented = false
    }

    private func calculateNextRun() -> Date? {
        guard enabled else { return nil }

        let now = Date()
        let calendar = Calendar.current

        // Get today's date at the scheduled time
        var components = calendar.dateComponents([.year, .month, .day], from: now)
        let timeComponents = calendar.dateComponents([.hour, .minute], from: timeOfDay)
        components.hour = timeComponents.hour
        components.minute = timeComponents.minute

        guard let todayAtScheduledTime = calendar.date(from: components) else {
            return nil
        }

        // If today's scheduled time hasn't passed yet, use it
        if todayAtScheduledTime > now {
            return todayAtScheduledTime
        }

        // Otherwise, add the frequency interval
        return calendar.date(byAdding: .second, value: Int(frequency.timeInterval), to: todayAtScheduledTime)
    }
}

struct ConfigureScheduleView_Previews: PreviewProvider {
    static var previews: some View {
        @State var schedule: ScheduledCleanup? = ScheduledCleanup()

        ConfigureScheduleView(
            isPresented: .constant(true),
            scheduledCleanup: $schedule
        )
    }
}
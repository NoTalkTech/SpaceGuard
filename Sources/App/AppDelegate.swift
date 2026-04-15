import AppKit
import Combine
import SwiftUI
import UserNotifications

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var menu: NSMenu!
    var settingsWindow: NSWindow?
    private var diskStats: DiskStats?
    @MainActor private lazy var dependencies = AppDependencies()
    @MainActor private let settingsNavigationState = SettingsNavigationState()
    private let filePreviewer = FilePreviewer()
    private var cancellables = Set<AnyCancellable>()
    private var menuStatusResetTask: Task<Void, Never>?
    private var diskInfoItem: NSMenuItem?
    private var activityItem: NSMenuItem?
    private var analyzeItem: NSMenuItem?
    private var cleanupItem: NSMenuItem?

    @MainActor private var progressTracker: ProgressTracker {
        dependencies.progressTracker
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusBar()
        setupMenu()
        updateDiskInfo()

        // Update disk info periodically (every 5 minutes)
        Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.updateDiskInfo()
            }
        }

        // Setup confirmation callback for medium/high risk files
        progressTracker.confirmDeletion = { [weak self] file in
            guard let self = self else { return false }
            return await self.showFilePreview(for: file)
        }

        bindProgressTracker()
        refreshStatusUI()

        // Request notification permission after a short delay (avoids bundle proxy issue)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.requestNotificationPermission()
        }
    }

    func requestNotificationPermission() {
        // Only request notification permission if we're running in a proper app bundle
        // This avoids crashes when running from command line or development environment
        if Bundle.main.bundleIdentifier != nil {
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
                if granted {
                    print("Notification permission granted")
                } else if let error = error {
                    print("Notification permission error: \(error)")
                }
            }
        } else {
            print("Skipping notification permission request: No bundle identifier")
        }
    }

    func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "internaldrive", accessibilityDescription: "SpaceGuard")
            button.image?.size = NSSize(width: 18, height: 18)
        }
    }

    func setupMenu() {
        menu = NSMenu()

        // Disk usage summary
        let diskItem = NSMenuItem(title: "Scanning disk...", action: nil, keyEquivalent: "")
        diskItem.isEnabled = false
        menu.addItem(diskItem)
        diskInfoItem = diskItem

        let activityItem = NSMenuItem(title: "Ready", action: nil, keyEquivalent: "")
        activityItem.isEnabled = false
        activityItem.isHidden = true
        menu.addItem(activityItem)
        self.activityItem = activityItem

        menu.addItem(NSMenuItem.separator())

        // Quick actions
        let analyzeItem = NSMenuItem(title: "Analyze Disk", action: #selector(analyzeDisk), keyEquivalent: "a")
        analyzeItem.target = self
        menu.addItem(analyzeItem)
        self.analyzeItem = analyzeItem

        let cleanupItem = NSMenuItem(title: "Quick Cleanup", action: #selector(quickCleanup), keyEquivalent: "q")
        cleanupItem.target = self
        menu.addItem(cleanupItem)
        self.cleanupItem = cleanupItem

        menu.addItem(NSMenuItem.separator())

        // Settings
        let settingsItem = NSMenuItem(title: "Settings...", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(NSMenuItem.separator())

        // Quit
        let quitItem = NSMenuItem(title: "Quit SpaceGuard", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    @objc func analyzeDisk() {
        activityItem?.isHidden = false
        activityItem?.title = "Scanning: Starting disk analysis..."
        updateStatusButton(symbolName: "magnifyingglass.circle.fill", title: " Scanning", toolTip: "Starting disk analysis...")

        Task {
            showNotification(title: "Disk Analysis", message: "Starting disk analysis...")

            if let result = await progressTracker.startScan() {
                let formattedSize = ByteCountFormatter.string(fromByteCount: result.totalSize, countStyle: .file)
                showNotification(
                    title: "Disk Analysis Complete",
                    message: "Scanned \(result.fileCount) files, total size: \(formattedSize)"
                )
            } else {
                showNotification(title: "Disk Analysis Failed", message: "Unable to complete disk analysis")
            }
        }
    }

    @objc func quickCleanup() {
        activityItem?.isHidden = false
        activityItem?.title = "Cleanup: Starting quick cleanup..."
        updateStatusButton(symbolName: "trash.circle.fill", title: " Cleaning", toolTip: "Starting quick cleanup...")

        Task {
            showNotification(title: "Quick Cleanup", message: "Scanning for files to clean...")

            let rules = RulesPersistenceService().loadRules()
            guard let result = await progressTracker.quickCleanup(rules: rules) else {
                showNotification(title: "Quick Cleanup", message: "Cleanup is already in progress")
                return
            }

            if !result.errors.isEmpty {
                let quickPaths = dependencies.cleanupEngine.getQuickCleanupPaths()
                let scanErrorCount = result.errors.filter { quickPaths.contains($0.filePath) }.count
                if scanErrorCount > 0 {
                    showNotification(
                        title: "Quick Cleanup Warning",
                        message: "Encountered \(scanErrorCount) error(s) while scanning, some files may not be included"
                    )
                }
            }

            if result.filesDeleted == 0 {
                showNotification(title: "Quick Cleanup", message: "No low-risk files found to clean")
                return
            }

            let formattedFreed = ByteCountFormatter.string(fromByteCount: result.spaceFreed, countStyle: .file)
            showNotification(
                title: "Quick Cleanup Complete",
                message: "Freed \(formattedFreed) by deleting \(result.filesDeleted) files"
            )
        }
    }

    func updateDiskInfo() {
        diskStats = dependencies.scanner.getDiskUsage()

        // Update menu item
        if let diskItem = diskInfoItem {
            if let stats = diskStats {
                let usedPercent = String(format: "%.1f", stats.usedPercentage)
                diskItem.title = "Disk: \(stats.formattedUsed) used (\(usedPercent)%)"
            } else {
                diskItem.title = "Disk: Unable to read usage"
            }
        }
    }

    @objc func openSettings() {
        presentSettings(selecting: .settings)
    }

    @MainActor
    private func presentSettings(selecting tab: SettingsView.SidebarTab) {
        settingsNavigationState.selectedTab = tab

        if settingsWindow == nil {
            let settingsView = SettingsView(
                progressTracker: dependencies.progressTracker,
                navigationState: settingsNavigationState
            )
            .environmentObject(dependencies.historyManager)
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 700, height: 500),
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered,
                defer: false
            )
            window.center()
            window.title = "SpaceGuard Settings"
            window.contentView = NSHostingView(rootView: settingsView)
            window.isReleasedWhenClosed = false
            window.delegate = self

            settingsWindow = window
        }

        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc func quitApp() {
        NSApplication.shared.terminate(nil)
    }

    @MainActor
    func showFilePreview(for file: FileItem) async -> Bool {
        return await withCheckedContinuation { continuation in
            let previewInfo = filePreviewer.getPreviewInfo(for: file)

            // Create a window to host the SwiftUI view
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 620, height: 740),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            window.center()
            window.title = "Confirm Deletion: \(file.name)"
            window.isReleasedWhenClosed = false
            window.level = .modalPanel

            // Create the SwiftUI view with callbacks that close the window
            let previewView = FilePreviewView(
                fileItem: file,
                previewInfo: previewInfo,
                isPresented: .constant(true),
                onConfirm: {
                    window.close()
                    continuation.resume(returning: true)
                },
                onCancel: {
                    window.close()
                    continuation.resume(returning: false)
                }
            )

            window.contentView = NSHostingView(rootView: previewView)
            window.makeKeyAndOrderFront(nil)
        }
    }

    func showNotification(title: String, message: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = message
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil // Deliver immediately
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error showing notification: \(error)")
            }
        }
    }

    private func bindProgressTracker() {
        progressTracker.$currentStatus
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.refreshStatusUI()
            }
            .store(in: &cancellables)

        progressTracker.$isScanning
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.refreshStatusUI()
            }
            .store(in: &cancellables)

        progressTracker.$isCleaning
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.refreshStatusUI()
            }
            .store(in: &cancellables)
    }

    private func refreshStatusUI() {
        let status = progressTracker.currentStatus
        let isWorking = progressTracker.isScanning || progressTracker.isCleaning

        analyzeItem?.isEnabled = !isWorking
        cleanupItem?.isEnabled = !isWorking

        if isWorking {
            menuStatusResetTask?.cancel()

            activityItem?.isHidden = false
            activityItem?.title = progressSummary(for: status)

            if let button = statusItem.button {
                button.image = NSImage(systemSymbolName: progressTracker.isScanning ? "magnifyingglass.circle.fill" : "trash.circle.fill", accessibilityDescription: "SpaceGuard busy")
                button.title = progressTracker.isScanning ? " Scanning" : " Cleaning"
                button.toolTip = status
            }
            return
        }

        if isTerminalStatus(status) {
            activityItem?.isHidden = false
            activityItem?.title = status
            scheduleStatusReset()

            if let button = statusItem.button {
                button.image = NSImage(systemSymbolName: symbolName(for: status), accessibilityDescription: "SpaceGuard status")
                button.title = buttonTitle(for: status)
                button.toolTip = status
            }
            return
        }

        activityItem?.isHidden = true
        resetStatusButtonAppearance()
    }

    private func scheduleStatusReset() {
        menuStatusResetTask?.cancel()
        menuStatusResetTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 4_000_000_000)
            guard let self = self else { return }
            guard !self.progressTracker.isScanning, !self.progressTracker.isCleaning else { return }
            self.activityItem?.isHidden = true
            self.resetStatusButtonAppearance()
        }
    }

    private func resetStatusButtonAppearance() {
        updateStatusButton(symbolName: "internaldrive", title: "", toolTip: "SpaceGuard")
    }

    private func isTerminalStatus(_ status: String) -> Bool {
        status.hasPrefix("Scan complete")
            || status.hasPrefix("Cleanup complete")
            || status.hasPrefix("Quick cleanup complete")
            || status.hasPrefix("Scan failed")
            || status.hasSuffix("cancelled")
    }

    private func progressSummary(for status: String) -> String {
        if progressTracker.isScanning {
            return "Scanning: \(status)"
        }

        if progressTracker.isCleaning {
            return "Cleanup: \(status)"
        }

        return status
    }

    private func symbolName(for status: String) -> String {
        if status.hasPrefix("Scan failed") {
            return "xmark.octagon.fill"
        }

        if status.hasSuffix("cancelled") {
            return "exclamationmark.triangle.fill"
        }

        return "checkmark.circle.fill"
    }

    private func buttonTitle(for status: String) -> String {
        if status.hasPrefix("Scan failed") {
            return " Failed"
        }

        if status.hasSuffix("cancelled") {
            return " Cancelled"
        }

        return " Done"
    }

    private func updateStatusButton(symbolName: String, title: String, toolTip: String) {
        guard let button = statusItem.button else { return }
        button.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: "SpaceGuard")
        button.image?.size = NSSize(width: 18, height: 18)
        button.title = title
        button.toolTip = toolTip
    }
}

extension AppDelegate: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        if let window = notification.object as? NSWindow, window == settingsWindow {
            settingsWindow = nil
        }
    }
}

import AppKit
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

        menu.addItem(NSMenuItem.separator())

        // Quick actions
        let analyzeItem = NSMenuItem(title: "Analyze Disk", action: #selector(analyzeDisk), keyEquivalent: "a")
        analyzeItem.target = self
        menu.addItem(analyzeItem)

        let cleanupItem = NSMenuItem(title: "Quick Cleanup", action: #selector(quickCleanup), keyEquivalent: "q")
        cleanupItem.target = self
        menu.addItem(cleanupItem)

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
        presentSettings(selecting: .cleanup)

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
        presentSettings(selecting: .cleanup)

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
        if let diskItem = menu.item(at: 0) {
            if let stats = diskStats {
                let usedPercent = String(format: "%.1f", stats.usedPercentage)
                diskItem.title = "Disk: \(stats.formattedUsed) used (\(usedPercent)%)"
            } else {
                diskItem.title = "Disk: Unable to read usage"
            }
        }
    }

    @objc func openSettings() {
        presentSettings(selecting: .general)
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
}

extension AppDelegate: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        if let window = notification.object as? NSWindow, window == settingsWindow {
            settingsWindow = nil
        }
    }
}

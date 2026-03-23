import AppKit
import SwiftUI
import UserNotifications

@main
struct SpaceGuardApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var menu: NSMenu!
    var settingsWindow: NSWindow?
    private var diskStats: DiskStats?
    @MainActor private var progressTracker = ProgressTracker()
    private let filePreviewer = FilePreviewer()

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusBar()
        setupMenu()
        updateDiskInfo()

        // Update disk info periodically (every 5 minutes)
        Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            self?.updateDiskInfo()
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
        menu.addItem(NSMenuItem(title: "Analyze Disk", action: #selector(analyzeDisk), keyEquivalent: "a"))
        menu.addItem(NSMenuItem(title: "Quick Cleanup", action: #selector(quickCleanup), keyEquivalent: "q"))

        menu.addItem(NSMenuItem.separator())

        // Settings
        menu.addItem(NSMenuItem(title: "Settings...", action: #selector(openSettings), keyEquivalent: ","))

        menu.addItem(NSMenuItem.separator())

        // Quit
        menu.addItem(NSMenuItem(title: "Quit SpaceGuard", action: #selector(quitApp), keyEquivalent: "q"))

        statusItem.menu = menu
    }

    @objc func analyzeDisk() {
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
        Task {
            showNotification(title: "Quick Cleanup", message: "Starting quick cleanup...")

            let rules = CleanupRules.load()
            if let result = await progressTracker.quickCleanup(rules: rules) {
                let formattedFreed = ByteCountFormatter.string(fromByteCount: result.spaceFreed, countStyle: .file)
                showNotification(
                    title: "Quick Cleanup Complete",
                    message: "Freed \(formattedFreed) by deleting \(result.filesDeleted) files"
                )
            } else {
                showNotification(title: "Quick Cleanup Failed", message: "Unable to complete cleanup")
            }
        }
    }

    func updateDiskInfo() {
        let scanner = DiskScanner()
        diskStats = scanner.getDiskUsage()

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
        if settingsWindow == nil {
            let settingsView = SettingsView()
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

import Cocoa
import AppKit
import SwiftUI
import Combine
import OrcaNotesCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var cancellables = Set<AnyCancellable>()
    private var dictationCancellable: AnyCancellable?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Create Status Item in macOS Menu Bar
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem.button {
            button.image = AppDelegate.idleIcon()
            button.action = #selector(togglePopover(_:))
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        
        // Setup SwiftUI Lite Interface Popover
        setupPopover()
        
        // Subscribe to AppState changes to update the menu bar icon & timer live
        observeAppState()

        // Push-to-talk dictation
        DictationController.shared.registerHotKey()
        dictationCancellable = DictationController.shared.$phase.sink { [weak self] phase in
            guard let button = self?.statusItem.button, !AppState.shared.isRecording else { return }
            switch phase {
            case .listening: button.title = " 🎙 Listening…"
            case .transcribing: button.title = " … Transcribing"
            default: if !AppState.shared.isProcessing { button.title = "" }
            }
        }
        if Preferences.useLocalSTT { LocalTranscriber.shared.prepare() }
    }
    
    private func setupPopover() {
        popover = NSPopover()
        popover.contentSize = NSSize(width: 330, height: 440)
        popover.behavior = .transient
        popover.animates = true
        popover.contentViewController = NSHostingController(rootView: MainPopoverView())
    }
    
    private func observeAppState() {
        let state = AppState.shared
        
        // Observe Recording & Timer
        Publishers.CombineLatest3(state.$isRecording, state.$elapsedSeconds, state.$isProcessing)
            .receive(on: RunLoop.main)
            .sink { [weak self] isRecording, elapsed, isProcessing in
                guard let self = self, let button = self.statusItem.button else { return }
                
                if isRecording {
                    let mins = String(format: "%02d", elapsed / 60)
                    let secs = String(format: "%02d", elapsed % 60)
                    button.title = " 🔴 \(mins):\(secs)"
                    button.image = nil
                } else if isProcessing {
                    button.title = " ⚡ Processing..."
                    button.image = NSImage(systemSymbolName: "bolt.fill", accessibilityDescription: "Processing")
                } else {
                    button.title = ""
                    button.image = AppDelegate.idleIcon()
                }
            }
            .store(in: &cancellables)
    }
    
    @objc private func togglePopover(_ sender: AnyObject?) {
        guard let button = statusItem.button else { return }
        
        let event = NSApp.currentEvent
        if event?.type == .rightMouseUp {
            // Right-click shows quick context menu
            showContextMenu(button: button)
            return
        }
        
        if popover.isShown {
            popover.performClose(sender)
        } else {
            AppState.shared.checkPermissions()
            AppState.shared.refreshRecentNotes()
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }
    
    private func showContextMenu(button: NSStatusBarButton) {
        let menu = NSMenu()
        let state = AppState.shared
        
        let toggleTitle = state.isRecording ? "Stop Recording & Generate Notes" : "Start Recording Meeting"
        let item = NSMenuItem(title: toggleTitle, action: #selector(menuToggleRecording), keyEquivalent: "r")
        item.target = self
        menu.addItem(item)
        
        menu.addItem(NSMenuItem.separator())
        
        let folderItem = NSMenuItem(title: "Open Meeting Notes Folder", action: #selector(openNotesFolder), keyEquivalent: "o")
        folderItem.target = self
        menu.addItem(folderItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let quitItem = NSMenuItem(title: "Quit OrcaNotes", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
        
        statusItem.menu = menu
        button.performClick(nil)
        statusItem.menu = nil // Reset so left-click continues to open popover
    }
    
    @objc private func menuToggleRecording() {
        AppState.shared.toggleRecording()
    }
    
    @objc private func openNotesFolder() {
        AppState.shared.openNotesFolder()
    }
    
    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }

    /// Orca whale app icon, sized for the menu bar (falls back to the waveform symbol).
    static func idleIcon() -> NSImage? {
        if let icon = NSApp.applicationIconImage, Bundle.main.path(forResource: "AppIcon", ofType: "icns") != nil {
            let img = icon.copy() as? NSImage ?? icon
            img.size = NSSize(width: 18, height: 18)
            img.isTemplate = false
            return img
        }
        return NSImage(systemSymbolName: "waveform", accessibilityDescription: "OrcaNotes")
    }
}

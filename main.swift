// KeyCrib – a floating cheat sheet of the special characters on your keyboard layout.
//
// The key combinations are not hard-coded: KeyCrib reads the active macOS keyboard
// layout (UCKeyTranslate) and works out which keys type which character, so it is
// correct for Hungarian, German, French, Czech, Polish, ... layouts alike, and it
// follows you when you switch input sources.
//
// No permissions needed (the global hotkey is a Carbon hotkey, not an event tap),
// and no network access: the cheat sheet page ships inside the app bundle.

import Cocoa
import Carbon.HIToolbox
import ServiceManagement
import WebKit

// The hotkey is Option + the key to the right of P (Ő on Hungarian, Ü on German, [ on US).
let hotKeyCode = UInt16(kVK_ANSI_LeftBracket)

// MARK: - Reading the keyboard layout

struct KeyCombo: Encodable {
    let key: String      // the label printed on the key, e.g. "Ő"
    let mods: [String]   // e.g. ["Shift", "Option"]
    let dead: Bool       // dead key: press it, then Space
}

struct LayoutInfo: Encodable {
    let layout: String               // e.g. "Hungarian"
    let hotkey: [String]             // e.g. ["Option", "Ő"]
    let map: [String: KeyCombo]      // character -> simplest way to type it
}

enum KeyboardLayout {
    // Keys of the main block (ANSI/ISO virtual key codes), without Return, Tab and Space.
    static let keyCodes: [UInt16] = Array(0...50).filter { ![36, 48, 49].contains($0) }

    static let modifierSets: [(names: [String], value: UInt32)] = [
        ([], 0), (["Shift"], 2), (["Option"], 8), (["Shift", "Option"], 10),
    ]

    static func current() -> LayoutInfo {
        read(TISCopyCurrentKeyboardLayoutInputSource()?.takeRetainedValue())
    }

    static func read(_ source: TISInputSource?) -> LayoutInfo {
        guard let source, let rawData = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData)
        else { return LayoutInfo(layout: "Unknown", hotkey: ["Option", "["], map: [:]) }

        let name: String = {
            guard let raw = TISGetInputSourceProperty(source, kTISPropertyLocalizedName) else { return "" }
            return Unmanaged<CFString>.fromOpaque(raw).takeUnretainedValue() as String
        }()
        let data = Unmanaged<CFData>.fromOpaque(rawData).takeUnretainedValue()
        let layout = unsafeBitCast(CFDataGetBytePtr(data), to: UnsafePointer<UCKeyboardLayout>.self)
        let keyboardType = UInt32(LMGetKbdType())

        func translate(_ code: UInt16, _ mods: UInt32, _ options: OptionBits, _ state: inout UInt32) -> String {
            var length = 0
            var chars = [UniChar](repeating: 0, count: 8)
            UCKeyTranslate(layout, code, UInt16(kUCKeyActionDown), mods, keyboardType,
                           options, &state, chars.count, &length, &chars)
            return String(utf16CodeUnits: chars, count: length)
        }

        // What is printed on a key: its unmodified character, upper-cased.
        func label(_ code: UInt16) -> String {
            var state: UInt32 = 0
            return translate(code, 0, OptionBits(1 << kUCKeyTranslateNoDeadKeysBit), &state).uppercased()
        }

        var map: [String: KeyCombo] = [:]
        // Fewer modifiers first, so every character gets its simplest combination.
        for (names, value) in modifierSets {
            for code in keyCodes {
                let keyLabel = label(code)
                guard !keyLabel.isEmpty, !keyLabel.unicodeScalars.contains(where: { $0.value < 0x20 }) else { continue }

                var state: UInt32 = 0
                var char = translate(code, value, 0, &state)
                var dead = false
                if state != 0 {
                    // Dead key: the character appears after pressing Space.
                    char = translate(UInt16(kVK_Space), 0, 0, &state)
                    dead = true
                }
                guard !char.isEmpty, !char.unicodeScalars.contains(where: { $0.value < 0x20 }) else { continue }

                if let existing = map[char], !(existing.dead && !dead) { continue }
                map[char] = KeyCombo(key: keyLabel, mods: names, dead: dead)
            }
        }
        return LayoutInfo(layout: name, hotkey: ["Option", label(hotKeyCode)], map: map)
    }
}

// MARK: - Window

final class CheatPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override func cancelOperation(_ sender: Any?) { orderOut(nil) }  // Esc closes it
}

final class AppDelegate: NSObject, NSApplicationDelegate, WKScriptMessageHandler {
    var panel: CheatPanel!
    var web: WKWebView!
    var statusItem: NSStatusItem!
    var showItem: NSMenuItem!
    var loginItem: NSMenuItem!
    var hotKeyRef: EventHotKeyRef?

    func applicationDidFinishLaunching(_ note: Notification) {
        buildPanel()
        buildMenu()
        registerHotKey()
        refreshLayout()

        // Follow input source changes (e.g. switching between Hungarian and US).
        DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name(kTISNotifySelectedKeyboardInputSourceChanged as String),
            object: nil, queue: .main) { [weak self] _ in self?.refreshLayout() }
    }

    // Launching the app again (Spotlight, Finder) shows the cheat sheet.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        toggle()
        return false
    }

    func buildPanel() {
        panel = CheatPanel(
            contentRect: NSRect(x: 0, y: 0, width: 1061, height: 680),
            styleMask: [.titled, .closable, .resizable, .utilityWindow, .nonactivatingPanel],
            backing: .buffered, defer: false)
        panel.title = "KeyCrib"
        panel.level = .floating
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isReleasedWhenClosed = false
        // Default size: four tiles side by side.
        panel.setFrame(NSRect(x: 0, y: 0, width: 1061, height: 704), display: false)
        panel.center()
        panel.setFrameAutosaveName("KeyCribPanel")

        let config = WKWebViewConfiguration()
        config.userContentController.add(self, name: "copy")
        web = WKWebView(frame: panel.contentView!.bounds, configuration: config)
        web.autoresizingMask = [.width, .height]
        panel.contentView!.addSubview(web)
    }

    // Hands the current layout to the page and (re)loads it.
    func refreshLayout() {
        let info = KeyboardLayout.current()
        panel.title = info.layout.isEmpty ? "KeyCrib" : "KeyCrib — \(info.layout)"
        showItem?.title = "Show / Hide KeyCrib (\(info.hotkey.joined(separator: " + ")))"

        let json = (try? JSONEncoder().encode(info)).flatMap { String(data: $0, encoding: .utf8) } ?? "null"
        let script = """
        window.KEYCRIB = \(json);
        Object.defineProperty(navigator, 'clipboard', { configurable: true, value: {
          writeText: t => { window.webkit.messageHandlers.copy.postMessage(String(t)); return Promise.resolve(); }
        }});
        """
        let controller = web.configuration.userContentController
        controller.removeAllUserScripts()
        controller.addUserScript(WKUserScript(source: script, injectionTime: .atDocumentStart, forMainFrameOnly: true))

        if let url = Bundle.main.url(forResource: "index", withExtension: "html") {
            web.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
        }
    }

    // Click-to-copy from the page goes to the system clipboard.
    func userContentController(_ c: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let text = message.body as? String else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    @objc func toggle() {
        if panel.isVisible {
            panel.orderOut(nil)
        } else {
            panel.orderFrontRegardless()
            panel.makeKey()
        }
    }

    // MARK: Menu bar

    func buildMenu() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.image = NSImage(systemSymbolName: "keyboard", accessibilityDescription: "KeyCrib")

        let menu = NSMenu()
        showItem = NSMenuItem(title: "Show / Hide KeyCrib", action: #selector(toggle), keyEquivalent: "")
        showItem.target = self
        menu.addItem(showItem)
        menu.addItem(.separator())
        loginItem = NSMenuItem(title: "Open at Login", action: #selector(toggleLogin), keyEquivalent: "")
        loginItem.target = self
        loginItem.state = SMAppService.mainApp.status == .enabled ? .on : .off
        menu.addItem(loginItem)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit KeyCrib", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem.menu = menu
    }

    @objc func toggleLogin() {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            let alert = NSAlert()
            alert.messageText = "Couldn't change the login setting"
            alert.informativeText = "Add KeyCrib by hand in System Settings → General → Login Items.\n\n\(error.localizedDescription)"
            alert.runModal()
        }
        loginItem.state = SMAppService.mainApp.status == .enabled ? .on : .off
    }

    // MARK: Hotkey

    func registerHotKey() {
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, _, userData in
            let me = Unmanaged<AppDelegate>.fromOpaque(userData!).takeUnretainedValue()
            DispatchQueue.main.async { me.toggle() }
            return noErr
        }, 1, &spec, Unmanaged.passUnretained(self).toOpaque(), nil)

        let id = EventHotKeyID(signature: OSType(0x4B435242), id: 1)  // 'KCRB'
        let status = RegisterEventHotKey(UInt32(hotKeyCode), UInt32(optionKey), id,
                                         GetApplicationEventTarget(), 0, &hotKeyRef)
        if status != noErr {
            let alert = NSAlert()
            alert.messageText = "The KeyCrib shortcut is already taken"
            alert.informativeText = "Another app uses the same key combination. You can still open KeyCrib from the keyboard icon in the menu bar."
            alert.runModal()
        }
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)  // no Dock icon, menu bar only
app.run()

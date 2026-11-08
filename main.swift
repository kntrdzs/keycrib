// KeyCrib – lebegő karakterpuska, Option + Ő-re előjön / eltűnik.
// Nem kér Accessibility-engedélyt (a globális gyorsbillentyű Carbon hotkey),
// és nem kapcsolódik a netre: a puska HTML-je az app bundle-ben van.

import Cocoa
import Carbon.HIToolbox
import ServiceManagement
import WebKit

final class CheatPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override func cancelOperation(_ sender: Any?) { orderOut(nil) }  // Esc bezárja
}

final class AppDelegate: NSObject, NSApplicationDelegate, WKScriptMessageHandler {
    var panel: CheatPanel!
    var statusItem: NSStatusItem!
    var hotKeyRef: EventHotKeyRef?
    var loginItem: NSMenuItem!

    func applicationDidFinishLaunching(_ note: Notification) {
        buildPanel()
        buildMenu()
        registerHotKey()
    }

    // Ha a már futó appot újra elindítod (Spotlight, Finder), előhozza a puskát.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        toggle()
        return false
    }

    // MARK: Ablak

    func buildPanel() {
        panel = CheatPanel(
            contentRect: NSRect(x: 0, y: 0, width: 820, height: 680),
            styleMask: [.titled, .closable, .resizable, .utilityWindow, .nonactivatingPanel],
            backing: .buffered, defer: false)
        panel.title = "KeyCrib"
        panel.level = .floating
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isReleasedWhenClosed = false
        // Alapméret: 1061×704, ebben 4 csempe fér el egymás mellett.
        panel.setFrame(NSRect(x: 0, y: 0, width: 1061, height: 704), display: false)
        panel.center()
        panel.setFrameAutosaveName("KeyCribPanel")

        let config = WKWebViewConfiguration()
        // A kattintásos másolás a WebView-ban a natív vágólapra menjen.
        let js = """
        Object.defineProperty(navigator, 'clipboard', { configurable: true, value: {
          writeText: t => { window.webkit.messageHandlers.copy.postMessage(String(t)); return Promise.resolve(); }
        }});
        """
        config.userContentController.addUserScript(
            WKUserScript(source: js, injectionTime: .atDocumentStart, forMainFrameOnly: true))
        config.userContentController.add(self, name: "copy")

        let web = WKWebView(frame: panel.contentView!.bounds, configuration: config)
        web.autoresizingMask = [.width, .height]
        if let url = Bundle.main.url(forResource: "index", withExtension: "html") {
            web.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
        }
        panel.contentView!.addSubview(web)
    }

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

    // MARK: Menüsor

    func buildMenu() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "keyboard", accessibilityDescription: "KeyCrib")
        }
        let menu = NSMenu()
        let show = NSMenuItem(title: "KeyCrib mutatása / elrejtése", action: #selector(toggle), keyEquivalent: "ő")
        show.keyEquivalentModifierMask = [.option]
        menu.addItem(show)
        menu.addItem(.separator())
        loginItem = NSMenuItem(title: "Indítás bejelentkezéskor", action: #selector(toggleLogin), keyEquivalent: "")
        loginItem.state = SMAppService.mainApp.status == .enabled ? .on : .off
        menu.addItem(loginItem)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Kilépés", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        for item in menu.items where item.action != #selector(NSApplication.terminate(_:)) { item.target = self }
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
            alert.messageText = "Nem sikerült beállítani"
            alert.informativeText = "Add hozzá kézzel: Rendszerbeállítások → Általános → Bejelentkezési elemek.\n\n\(error.localizedDescription)"
            alert.runModal()
        }
        loginItem.state = SMAppService.mainApp.status == .enabled ? .on : .off
    }

    // MARK: Gyorsbillentyű: Option + Ő (alapból a ¨ jelet írná, ezt veszi át)

    func registerHotKey() {
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, _, userData in
            let me = Unmanaged<AppDelegate>.fromOpaque(userData!).takeUnretainedValue()
            DispatchQueue.main.async { me.toggle() }
            return noErr
        }, 1, &spec, Unmanaged.passUnretained(self).toOpaque(), nil)

        let id = EventHotKeyID(signature: OSType(0x5055534B), id: 1)  // 'PUSK'
        let status = RegisterEventHotKey(UInt32(kVK_ANSI_LeftBracket), UInt32(optionKey), id,
                                         GetApplicationEventTarget(), 0, &hotKeyRef)
        if status != noErr {
            let alert = NSAlert()
            alert.messageText = "Az Option + Ő már foglalt"
            alert.informativeText = "A puskát a menüsor billentyűzet-ikonjáról tudod megnyitni."
            alert.runModal()
        }
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)  // nincs Dock-ikon, csak a menüsorban
app.run()

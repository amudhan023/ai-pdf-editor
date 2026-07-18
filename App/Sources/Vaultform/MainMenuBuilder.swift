import AppKit

/// Builds the full menu bar (File/Edit/View/Annotate/Window/Help) — this
/// executable has no storyboard/xib, so the tree that Xcode normally
/// generates for free is assembled by hand here (same "no `.xcodeproj`"
/// constraint as the rest of `App/`, see its `CLAUDE.md`).
///
/// Edit and Window mostly wire to AppKit's own standard, formally-declared
/// selectors (`cut(_:)`, `performMiniaturize(_:)`, …) with a `nil` target so
/// the responder chain resolves them — this is the same mechanism an
/// Xcode-generated main menu nib relies on, not a custom re-implementation.
/// Annotate is a structural placeholder: its tools land with P1-04
/// (concurrent, separate primary package `DocEngineHost`/`DocumentSession`)
/// — items exist so the menu tree is complete per this task's Requirements,
/// but stay disabled rather than fabricating annotation behavior this
/// package doesn't own.
@MainActor
enum MainMenuBuilder {
    static func build(target: AppDelegate) -> NSMenu {
        let mainMenu = NSMenu()

        mainMenu.addItem(withSubmenu: appMenu(target: target))
        mainMenu.addItem(withSubmenu: fileMenu(target: target))
        mainMenu.addItem(withSubmenu: editMenu())
        mainMenu.addItem(withSubmenu: viewMenu(target: target))
        mainMenu.addItem(withSubmenu: annotateMenu())
        let windowMenu = windowMenu()
        mainMenu.addItem(withSubmenu: windowMenu)
        mainMenu.addItem(withSubmenu: helpMenu())

        NSApp.windowsMenu = windowMenu
        return mainMenu
    }

    private static func appMenu(target: AppDelegate) -> NSMenu {
        let menu = NSMenu(title: "Vaultform")
        menu.addItem(withTitle: "About Vaultform", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Set as Default PDF Viewer…", action: #selector(AppDelegate.showSetAsDefaultInstructions(_:)), keyEquivalent: "", target: target)
        menu.addItem(.separator())
        menu.addItem(withTitle: "Hide Vaultform", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        let hideOthers = menu.addItem(withTitle: "Hide Others", action: #selector(NSApplication.hideOtherApplications(_:)), keyEquivalent: "h")
        hideOthers.keyEquivalentModifierMask = [.command, .option]
        menu.addItem(withTitle: "Show All", action: #selector(NSApplication.unhideAllApplications(_:)), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit Vaultform", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        return menu
    }

    private static func fileMenu(target: AppDelegate) -> NSMenu {
        let menu = NSMenu(title: "File")
        menu.addItem(withTitle: "New Window", action: #selector(AppDelegate.newDocumentWindow(_:)), keyEquivalent: "n", target: target)
        menu.addItem(withTitle: "New Tab", action: #selector(AppDelegate.newTab(_:)), keyEquivalent: "t", target: target)
        menu.addItem(withTitle: "Open…", action: #selector(AppDelegate.openDocument(_:)), keyEquivalent: "o", target: target)

        let recentsItem = NSMenuItem(title: "Open Recent", action: nil, keyEquivalent: "")
        let recentsMenu = NSMenu(title: "Open Recent")
        recentsMenu.delegate = target.recentDocumentsMenuDelegate
        recentsItem.submenu = recentsMenu
        menu.addItem(recentsItem)

        menu.addItem(.separator())
        menu.addItem(withTitle: "Close Window", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        return menu
    }

    private static func editMenu() -> NSMenu {
        let menu = NSMenu(title: "Edit")
        menu.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        let redo = menu.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "Z")
        redo.keyEquivalentModifierMask = [.command, .shift]
        menu.addItem(.separator())
        menu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        menu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        menu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        menu.addItem(withTitle: "Delete", action: #selector(NSText.delete(_:)), keyEquivalent: "")
        menu.addItem(withTitle: "Select All", action: #selector(NSResponder.selectAll(_:)), keyEquivalent: "a")
        return menu
    }

    private static func viewMenu(target: AppDelegate) -> NSMenu {
        let menu = NSMenu(title: "View")
        menu.addItem(withTitle: "Zoom In", action: #selector(AppDelegate.zoomIn(_:)), keyEquivalent: "+", target: target)
        menu.addItem(withTitle: "Zoom Out", action: #selector(AppDelegate.zoomOut(_:)), keyEquivalent: "-", target: target)
        menu.addItem(withTitle: "Actual Size", action: #selector(AppDelegate.zoomActualSize(_:)), keyEquivalent: "0", target: target)
        menu.addItem(.separator())
        menu.addItem(withTitle: "Fit Width", action: #selector(AppDelegate.zoomFitWidth(_:)), keyEquivalent: "9", target: target)
        menu.addItem(withTitle: "Fit Page", action: #selector(AppDelegate.zoomFitPage(_:)), keyEquivalent: "8", target: target)
        return menu
    }

    /// Disabled placeholders — see the type doc comment.
    private static func annotateMenu() -> NSMenu {
        let menu = NSMenu(title: "Annotate")
        for title in ["Highlight", "Underline", "Strikethrough", "Squiggly"] {
            let item = menu.addItem(withTitle: title, action: nil, keyEquivalent: "")
            item.isEnabled = false
        }
        return menu
    }

    private static func windowMenu() -> NSMenu {
        let menu = NSMenu(title: "Window")
        menu.addItem(withTitle: "Minimize", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        menu.addItem(withTitle: "Zoom", action: #selector(NSWindow.performZoom(_:)), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Bring All to Front", action: #selector(NSApplication.arrangeInFront(_:)), keyEquivalent: "")
        menu.addItem(.separator())
        return menu
    }

    private static func helpMenu() -> NSMenu {
        let menu = NSMenu(title: "Help")
        let item = menu.addItem(withTitle: "Vaultform Help", action: nil, keyEquivalent: "")
        item.isEnabled = false
        return menu
    }
}

private extension NSMenu {
    func addItem(withSubmenu submenu: NSMenu) {
        let item = NSMenuItem()
        item.submenu = submenu
        addItem(item)
    }

    @discardableResult
    func addItem(withTitle title: String, action: Selector?, keyEquivalent: String, target: AnyObject?) -> NSMenuItem {
        let item = addItem(withTitle: title, action: action, keyEquivalent: keyEquivalent)
        item.target = target
        return item
    }
}

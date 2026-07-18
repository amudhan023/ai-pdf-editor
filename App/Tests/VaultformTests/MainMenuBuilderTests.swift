import XCTest
@testable import Vaultform

/// Pins the menu tree's shape (this task's Requirements: "full menu tree
/// (File/Edit/View/Annotate/Window/Help)") rather than exercising AppKit's
/// own dispatch, which XCTest can't drive without a running event loop.
@MainActor
final class MainMenuBuilderTests: XCTestCase {
    func testTopLevelMenuTitlesMatchTheRequiredTree() {
        let delegate = AppDelegate()
        let mainMenu = MainMenuBuilder.build(target: delegate)

        let titles = mainMenu.items.compactMap { $0.submenu?.title }
        XCTAssertEqual(titles, ["Vaultform", "File", "Edit", "View", "Annotate", "Window", "Help"])
    }

    func testFileMenuHasNewWindowNewTabAndOpenRecent() {
        let delegate = AppDelegate()
        let mainMenu = MainMenuBuilder.build(target: delegate)
        let fileMenu = mainMenu.items[1].submenu!

        XCTAssertTrue(fileMenu.items.contains { $0.title == "New Window" })
        XCTAssertTrue(fileMenu.items.contains { $0.title == "New Tab" })
        let recentsItem = fileMenu.items.first { $0.title == "Open Recent" }
        XCTAssertNotNil(recentsItem?.submenu)
    }

    func testBuildSetsTheApplicationWindowsMenu() {
        let delegate = AppDelegate()
        let mainMenu = MainMenuBuilder.build(target: delegate)
        let windowMenu = mainMenu.items.first { $0.submenu?.title == "Window" }?.submenu

        XCTAssertTrue(NSApp.windowsMenu === windowMenu)
    }
}

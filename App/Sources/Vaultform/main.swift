import AppKit

// Composition root entry point. Kept a plain `main.swift` (not `@main
// struct ...App: App`) so the DI wiring below (`AppDelegate.init`) runs
// before `NSApplication` starts pumping events — matches the pattern
// `Services/DocEngineService/main.swift` uses for the same reason.
let delegate = AppDelegate()
let application = NSApplication.shared
application.delegate = delegate
application.setActivationPolicy(.regular)
application.run()

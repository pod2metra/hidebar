import AppKit

// An explicit bootstrap: `@main` on a delegate without a nib would never create the delegate.
let delegate = AppDelegate()
NSApplication.shared.delegate = delegate
NSApplication.shared.run()

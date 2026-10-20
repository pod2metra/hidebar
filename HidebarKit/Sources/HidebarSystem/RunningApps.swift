import AppKit

/// Process-to-bundle lookup shared by the window list and the Accessibility reader.
public enum RunningApps {
    public static func bundleID(ofPID pid: Int) -> String? {
        NSRunningApplication(processIdentifier: pid_t(pid))?.bundleIdentifier
    }
}

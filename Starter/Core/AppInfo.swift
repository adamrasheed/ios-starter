import Foundation

/// Read-only facts about the running build.
///
/// Centralised because these Info.plist keys are easy to typo and the failure mode is a
/// silently wrong version string in your Settings screen and your support emails.
enum AppInfo {
    /// Marketing version, e.g. "1.2". Set via `MARKETING_VERSION` in project.yml.
    static var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0"
    }

    /// Build number, e.g. "14". Set via `CURRENT_PROJECT_VERSION` in project.yml.
    static var build: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "0"
    }

    /// "1.2 (14)": what to show in Settings and paste into a bug report.
    static var displayVersion: String { "\(version) (\(build))" }

    static var bundleID: String {
        Bundle.main.bundleIdentifier ?? "com.example.starter"
    }

    static var displayName: String {
        (Bundle.main.infoDictionary?["CFBundleDisplayName"] as? String)
            ?? (Bundle.main.infoDictionary?["CFBundleName"] as? String)
            ?? "Starter"
    }

    /// True in a debug build. Use to expose developer affordances that must never ship.
    static var isDebugBuild: Bool {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }
}

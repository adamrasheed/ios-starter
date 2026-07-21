import OSLog

/// Logging categories built on `os.Logger`.
///
/// `os.Logger` over `print`, for three concrete reasons: it costs almost nothing when nobody is
/// listening (arguments are not even evaluated), it survives into Console.app and `log collect`
/// so you can debug a TestFlight build on someone else's device, and it enforces a decision
/// about privacy at every interpolation.
///
/// That last point matters more than it sounds. String interpolation in a Logger call is
/// REDACTED by default in release builds: you get `<private>` unless you explicitly write
/// `privacy: .public`. That default is what keeps a user's email out of a log a support
/// engineer might read. Mark values `.public` only when they cannot identify a person.
enum AppLog {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.example.starter"

    /// Launch, scene phase, lifecycle.
    static let app = Logger(subsystem: subsystem, category: "app")
    /// Purchases and entitlements. The first place you look when someone says "I paid and it
    /// didn't unlock".
    static let store = Logger(subsystem: subsystem, category: "store")
    /// Persistence: container setup, migrations, sync.
    static let data = Logger(subsystem: subsystem, category: "data")
    /// Network requests and responses.
    static let network = Logger(subsystem: subsystem, category: "network")
    /// Analytics events.
    static let analytics = Logger(subsystem: subsystem, category: "analytics")
    /// Navigation and view lifecycle.
    static let ui = Logger(subsystem: subsystem, category: "ui")
}

// Reading these logs from a connected device:
//   log stream --predicate 'subsystem == "com.example.starter"' --level debug
//
// From a sysdiagnose or a TestFlight tester's device:
//   log show --predicate 'subsystem == "com.example.starter"' --last 1h

import AppKit
import UniformTypeIdentifiers

/// Checking / claiming the system default-browser role.
enum DefaultBrowser {
    static var isDefault: Bool {
        guard let probe = URL(string: "https://example.com"),
              let handler = NSWorkspace.shared.urlForApplication(toOpen: probe),
              let id = Bundle(url: handler)?.bundleIdentifier
        else { return false }
        return id == Bundle.main.bundleIdentifier
    }

    /// The app currently handling https (for display).
    static var currentName: String? {
        guard let probe = URL(string: "https://example.com"),
              let handler = NSWorkspace.shared.urlForApplication(toOpen: probe)
        else { return nil }
        return FileManager.default.displayName(atPath: handler.path).replacingOccurrences(of: ".app", with: "")
    }

    /// Asks macOS to make us the default browser. macOS shows its own
    /// confirmation dialog; `completion` runs after the user answers.
    static func claim(completion: @escaping (Bool) -> Void = { _ in }) {
        let me = Bundle.main.bundleURL
        NSWorkspace.shared.setDefaultApplication(at: me, toOpenURLsWithScheme: "http") { error in
            if let error { Log.error("set default (http) failed: \(error)") }
            NSWorkspace.shared.setDefaultApplication(at: me, toOpenURLsWithScheme: "https") { _ in
                NSWorkspace.shared.setDefaultApplication(at: me, toOpen: .html) { _ in
                    DispatchQueue.main.async { completion(isDefault) }
                }
            }
        }
    }
}

import Foundation
import InfraKit

/// Compiling the regex dominates matching cost, so compiled patterns
/// are cached. Invalid patterns compile to nil and never match,
/// exactly like String.range(of:options:.regularExpression).
private let globCache = Locked([String: NSRegularExpression?]())

func matchesGlobPattern(name: String, pattern: String) -> Bool {
    let regex = globCache.withLock { cache -> NSRegularExpression? in
        if let cached = cache[pattern] {
            return cached
        }
        let compiled = try? NSRegularExpression(
            pattern: "^"
                + pattern
                .replacingOccurrences(of: ".", with: "\\.")
                .replacingOccurrences(of: "*", with: ".*")
                .replacingOccurrences(of: "?", with: ".") + "$",
        )
        cache[pattern] = compiled
        return compiled
    }
    guard let regex else { return false }
    return regex.firstMatch(in: name, range: NSRange(name.startIndex..., in: name)) != nil
}

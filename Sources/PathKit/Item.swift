public import Foundation

/// Extensions can't hold stored properties, so the table lives here
/// instead of being rebuilt on every `extension` call.
private let compoundExtensions = ["tar.gz", "tar.bz", "tar.bz2", "tar.xz"]

public protocol Item: Hashable, Comparable, Sendable {
    var string: String { get }
}

public extension Item {
    var url: URL {
        URL(filePath: string, directoryHint: string.hasSuffix("/") ? .isDirectory : .notDirectory)
    }

    var parent: Path {
        guard let index = string.lastIndex(of: "/"), index != string.startIndex else {
            return Path(string: "/")
        }
        return Path(string: String(string[string.startIndex ..< index]))
    }

    var `extension`: String {
        if let compound = compoundExtensions.first(where: { string.hasSuffix(".\($0)") }) {
            return compound
        }
        guard let slash = string.lastIndex(of: "/"),
              let dot = string.lastIndex(of: "."), slash < dot
        else { return "" }
        return String(string[string.index(after: dot)...])
    }

    var components: [String] {
        string.split(separator: "/").map(String.init)
    }

    func appending(component: some StringProtocol) -> Path {
        Path(string: Path.join(string, component.split(separator: "/")))
    }

    static func / (lhs: Self, rhs: some StringProtocol) -> Path {
        lhs.appending(component: rhs)
    }

    func relative(to base: some Item) -> String {
        let pathComponents = components
        let baseComponents = base.components
        if pathComponents.starts(with: baseComponents) {
            return pathComponents.dropFirst(baseComponents.count).joined(separator: "/")
        }
        let common = zip(pathComponents, baseComponents).prefix { $0.0 == $0.1 }.count
        return (
            Array(repeating: "..", count: baseComponents.count - common)
                + pathComponents.dropFirst(common),
        ).joined(separator: "/")
    }

    func baseName(dropExtension: Bool = false) -> String {
        let component =
            string.lastIndex(of: "/")
                .map { String(string[string.index(after: $0)...]) }
                ?? string
        guard dropExtension else { return component }
        let ext = self.extension
        return ext.isEmpty ? component : String(component.dropLast(ext.count + 1))
    }

    static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.string.compare(rhs.string, locale: .current) == .orderedAscending
    }
}

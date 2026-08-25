public import Foundation

public protocol Item: Hashable, Comparable, Sendable {
    var string: String { get }
}

public struct Path: Item, Sendable {
    public let string: String

    public init(string: String) {
        assert(string.first == "/")
        assert(string.last != "/" || string == "/")
        assert(!string.split(separator: "/").contains(".."))
        self.string = string
    }

    public init?(_ description: some StringProtocol) {
        var components = description.split(separator: "/")
        switch description.first {
        case "/":
            if description.hasPrefix("/private/var/automount") {
                components.removeFirst(3)
            } else if description.hasPrefix("/var/automount") {
                components.removeFirst(2)
            } else if description.hasPrefix("/private") {
                components.removeFirst(1)
            }
            string = Self.join("/", components)

        case "~":
            if description == "~" {
                string = Self.home.string
                return
            }
            guard description.hasPrefix("~/") else { return nil }
            components.remove(at: 0)
            string = Self.join(Self.home.string, components)

        default:
            return nil
        }
    }

    public init?(url: URL) {
        guard url.scheme == "file" else { return nil }
        self.init(url.path)
    }

    public init?(url: NSURL) {
        guard url.scheme == "file", let path = url.path else { return nil }
        self.init(string: path)
    }

    public init(_ path: some Item) {
        string = path.string
    }
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
        switch true {
        case string.hasSuffix(".tar.gz"): return "tar.gz"
        case string.hasSuffix(".tar.bz"): return "tar.bz"
        case string.hasSuffix(".tar.bz2"): return "tar.bz2"
        case string.hasSuffix(".tar.xz"): return "tar.xz"

        default:
            guard let slash = string.lastIndex(of: "/"),
                  let dot = string.lastIndex(of: "."), slash < dot
            else { return "" }
            return String(string[string.index(after: dot)...])
        }
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
        var remainingPath = ArraySlice(pathComponents)
        var remainingBase = ArraySlice(baseComponents)
        while remainingPath.first == remainingBase.first {
            remainingPath = remainingPath.dropFirst()
            remainingBase = remainingBase.dropFirst()
        }
        return (Array(repeating: "..", count: remainingBase.count) + remainingPath).joined(
            separator: "/",
        )
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

public extension Path {
    static var root: DynamicPath {
        .init(string: "/")
    }

    static var cwd: DynamicPath {
        .init(string: FileManager.default.currentDirectoryPath)
    }

    static var home: DynamicPath {
        .init(string: FileManager.default.homeDirectoryForCurrentUser.path)
    }

    static func sourceLocation(for filePath: String = #filePath) -> (
        file: DynamicPath, directory: DynamicPath,
    ) {
        let file = DynamicPath(string: filePath)
        return (file, DynamicPath(file.parent))
    }
}

@dynamicMemberLookup
public struct DynamicPath: Item, Sendable {
    public let string: String

    init(string: String) {
        assert(string.hasPrefix("/"))
        self.string = string
    }

    public init(_ path: some Item) {
        string = path.string
    }

    public subscript(dynamicMember component: String) -> Self {
        Self(string: Path.join(string, component.split(separator: "/")))
    }
}

public extension Bundle {
    func path(forResource: String, ofType: String?) -> Path? {
        let lookup: (String?, String?) -> String? = path(forResource:ofType:)
        return lookup(forResource, ofType).flatMap(Path.init)
    }

    func path(forResource: String, ofType: String?, inDirectory: String?) -> Path? {
        let lookup: (String?, String?, String?) -> String? = path(forResource:ofType:inDirectory:)
        return lookup(forResource, ofType, inDirectory).flatMap(Path.init)
    }

    var sharedFrameworks: DynamicPath {
        sharedFrameworksPath.flatMap(DynamicPath.init) ?? defaultSharedFrameworksPath
    }

    var privateFrameworks: DynamicPath {
        privateFrameworksPath.flatMap(DynamicPath.init) ?? defaultSharedFrameworksPath
    }

    var resources: DynamicPath {
        resourcePath.flatMap(DynamicPath.init) ?? defaultResourcesPath
    }

    var path: DynamicPath {
        DynamicPath(string: bundlePath)
    }

    var executable: DynamicPath? {
        executablePath.flatMap(DynamicPath.init)
    }

    private var defaultSharedFrameworksPath: DynamicPath {
        #if os(macOS)
            path.Contents.Frameworks
        #else
            path.Frameworks
        #endif
    }

    private var defaultResourcesPath: DynamicPath {
        #if os(macOS)
            path.Contents.Resources
        #else
            path
        #endif
    }
}

extension Path: CustomStringConvertible {
    public var description: String {
        string
    }
}

extension Path: CustomDebugStringConvertible {
    public var debugDescription: String {
        "Path(\(string))"
    }
}

extension DynamicPath: CustomStringConvertible {
    public var description: String {
        string
    }
}

extension DynamicPath: CustomDebugStringConvertible {
    public var debugDescription: String {
        "DynamicPath(\(string))"
    }
}

extension Path {
    static func join(_ prefix: String, _ components: some Sequence<some StringProtocol>) -> String {
        assert(prefix.first == "/")
        var result = prefix
        for component in components {
            assert(!component.contains("/"))
            switch component {
            case "..":
                if let index = result.lastIndex(of: "/"), index != result.startIndex {
                    result = String(result[result.startIndex ..< index])
                } else {
                    result = "/"
                }

            case ".":
                break

            default:
                result = result == "/" ? "/\(component)" : "\(result)/\(component)"
            }
        }
        return result
    }
}

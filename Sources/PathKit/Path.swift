public import Foundation

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

    public init(_ path: some Item) {
        string = path.string
    }
}

extension Path {
    public static var root: DynamicPath {
        .init(string: "/")
    }

    public static var cwd: DynamicPath {
        .init(string: FileManager.default.currentDirectoryPath)
    }

    public static var home: DynamicPath {
        #if os(macOS)
            .init(string: FileManager.default.homeDirectoryForCurrentUser.path)
        #else
            .init(string: NSHomeDirectory())
        #endif
    }

    public static func sourceLocation(for filePath: String = #filePath) -> (
        file: DynamicPath, directory: DynamicPath,
    ) {
        let file = DynamicPath(string: filePath)
        return (file, DynamicPath(file.parent))
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

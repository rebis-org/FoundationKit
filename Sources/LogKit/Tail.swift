import Foundation

struct Tail: Encodable {
    private static let marker = " [LogKit:v1] "

    let file: String
    let function: String
    let line: UInt32
    let context: [String: String]
    let kind: String?
    let app: String?
    let version: String?

    private enum CodingKeys: CodingKey {
        case file, function, line, context, kind, app, version
    }

    init(
        at location: Location, context: [String: String] = [:], kind: String? = nil, app: String? = nil,
        version: String? = nil,
    ) {
        #if DEBUG
            file = location.filePath
        #else
            file = location.fileID
        #endif
        function = location.function
        line = location.line
        self.context = context
        self.kind = kind
        self.app = app
        self.version = version
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(file, forKey: .file)
        try container.encode(function, forKey: .function)
        try container.encode(line, forKey: .line)
        if !context.isEmpty {
            try container.encode(context, forKey: .context)
        }
        try container.encodeIfPresent(kind, forKey: .kind)
        try container.encodeIfPresent(app, forKey: .app)
        try container.encodeIfPresent(version, forKey: .version)
    }

    func encoded() -> String {
        guard let data = try? JSONEncoder().encode(self), let json = String(data: data, encoding: .utf8)
        else { return "" }
        return Self.marker + json
    }
}

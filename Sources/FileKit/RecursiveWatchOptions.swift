public enum RecursiveWatchBackend: Equatable, Sendable {
    case automatic
    case dispatchSource
    case fsevents
}

public struct RecursiveWatchOptions: Sendable {
    public var maxDepth: Int?
    public var followSymlinks: Bool
    public var excludePatterns: [String]
    public var maxWatchedDirectories: Int
    public var backend: RecursiveWatchBackend

    public init(
        maxDepth: Int? = nil,
        followSymlinks: Bool = false,
        excludePatterns: [String] = [],
        maxWatchedDirectories: Int = 256,
        backend: RecursiveWatchBackend = .dispatchSource,
    ) {
        self.maxDepth = maxDepth
        self.followSymlinks = followSymlinks
        self.excludePatterns = excludePatterns
        self.maxWatchedDirectories = maxWatchedDirectories
        self.backend = backend
    }
}

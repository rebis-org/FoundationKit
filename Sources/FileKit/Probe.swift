public import Foundation
public import PathKit

public struct Probe: Sequence {
    public let root: Path
    public let volume: any Volume
    public let depth: ClosedRange<Int>
    public let types: Set<EntryType>
    public let extensions: Set<String>
    public let hidden: Bool

    public init(root: Path, volume: any Volume) {
        self.root = root
        self.volume = volume
        depth = 1 ... .max
        types = []
        extensions = []
        hidden = true
    }

    init(
        root: Path, volume: any Volume, depth: ClosedRange<Int>, types: Set<EntryType>,
        extensions: Set<String>, hidden: Bool,
    ) {
        self.root = root
        self.volume = volume
        self.depth = depth
        self.types = types
        self.extensions = extensions
        self.hidden = hidden
    }

    public func makeIterator() -> ProbeIterator {
        ProbeIterator(probe: self)
    }

    public func depth(max: Int) -> Self {
        Self(
            root: root, volume: volume, depth: Swift.min(max, depth.lowerBound) ... max, types: types,
            extensions: extensions, hidden: hidden,
        )
    }

    public func depth(min: Int) -> Self {
        Self(
            root: root, volume: volume, depth: min ... Swift.max(depth.upperBound, min), types: types,
            extensions: extensions, hidden: hidden,
        )
    }

    public func depth(_ range: Range<Int>) -> Self {
        Self(
            root: root, volume: volume, depth: range.lowerBound ... (range.upperBound - 1), types: types,
            extensions: extensions, hidden: hidden,
        )
    }

    public func depth(_ range: ClosedRange<Int>) -> Self {
        Self(
            root: root, volume: volume, depth: range, types: types, extensions: extensions, hidden: hidden,
        )
    }

    public func type(_ type: EntryType) -> Self {
        var types = types
        types.insert(type)
        return Self(
            root: root, volume: volume, depth: depth, types: types, extensions: extensions, hidden: hidden,
        )
    }

    public func `extension`(_ fileExtension: String) -> Self {
        var extensions = extensions
        extensions.insert(fileExtension)
        return Self(
            root: root, volume: volume, depth: depth, types: types, extensions: extensions, hidden: hidden,
        )
    }

    public func hidden(_ hidden: Bool) -> Self {
        Self(
            root: root, volume: volume, depth: depth, types: types, extensions: extensions, hidden: hidden,
        )
    }

    public enum ControlFlow {
        case skip, abort, `continue`
    }

    public func execute(_ body: (Path) throws -> ControlFlow) rethrows {
        var iterator = makeIterator()
        while let path = iterator.next() {
            switch try body(path) {
            case .skip: iterator.skipDescendants()
            case .abort: return
            case .continue: continue
            }
        }
    }
}

public struct ProbeIterator: IteratorProtocol {
    private let probe: Probe
    private var enumerator: FileManager.DirectoryEnumerator?

    public init(probe: Probe) {
        self.probe = probe
        enumerator = probe.volume.enumerator(at: probe.root)
    }

    public mutating func next() -> Path? {
        guard let enumerator else { return nil }
        while let url = enumerator.nextObject() as? URL {
            guard let path = Path(url: url) else { continue }
            if enumerator.level > probe.depth.upperBound {
                enumerator.skipDescendants()
                continue
            }
            if enumerator.level < probe.depth.lowerBound {
                continue
            }
            if !probe.hidden, path.baseName().hasPrefix(".") {
                if (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true {
                    enumerator.skipDescendants()
                }
                continue
            }
            if let type = probe.volume.type(at: path), !probe.types.isEmpty, !probe.types.contains(type) {
                continue
            }
            if !probe.extensions.isEmpty, !probe.extensions.contains(path.extension) {
                continue
            }
            return path
        }
        return nil
    }

    public mutating func skipDescendants() {
        enumerator?.skipDescendants()
    }
}

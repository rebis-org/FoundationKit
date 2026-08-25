public import Foundation
import InfraKit

#if os(macOS)
    import CoreServices
#endif

@safe
public final class RecursiveWatch: Sendable {
    public let rootURL: URL
    public let options: RecursiveWatchOptions
    public let option: WatcherOption

    private struct State: Sendable {
        var isStarted = false
        var eventContinuations: [UUID: AsyncStream<FileSystemEvent>.Continuation] = [:]
        var errorContinuations: [UUID: AsyncStream<FileSystemError>.Continuation] = [:]
        var watchers: [URL: Watch] = [:]
        var tooManyWatchersReported = false
        #if os(macOS)
            var fseventsBackend: FSEvents?
        #endif
    }

    private let state: Locked<State>

    public init(
        url: URL,
        options: RecursiveWatchOptions = RecursiveWatchOptions(),
        option: WatcherOption = WatcherOption(),
    ) throws {
        let values = try? url.resourceValues(forKeys: [.isDirectoryKey])
        guard values != nil else {
            throw FileSystemError.directoryNotFound(url)
        }
        guard values?.isDirectory == true else {
            throw FileSystemError.invalidConfiguration("The URL is not a directory: \(url.path)")
        }

        rootURL = url
        self.options = options
        self.option = option
        state = Locked(State())
    }

    deinit {
        stop()
    }

    public var events: AsyncStream<FileSystemEvent> {
        AsyncStream { continuation in
            let id = UUID()

            self.state.withLock { state in
                state.eventContinuations[id] = continuation
            }

            continuation.onTermination = { [weak self] _ in
                guard let self else { return }
                state.withLock { state in
                    _ = state.eventContinuations.removeValue(forKey: id)
                }
            }
        }
    }

    public var errors: AsyncStream<FileSystemError> {
        AsyncStream { continuation in
            let id = UUID()

            self.state.withLock { state in
                state.errorContinuations[id] = continuation
            }

            continuation.onTermination = { [weak self] _ in
                guard let self else { return }
                state.withLock { state in
                    _ = state.errorContinuations.removeValue(forKey: id)
                }
            }
        }
    }

    @unsafe
    public func start(on queue: DispatchQueue = .global(qos: .utility)) {
        queue.async { [weak self] in
            unsafe self?.performStart()
        }
    }

    @unsafe
    public func startAsync(on queue: DispatchQueue = .global(qos: .utility)) async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            queue.async { [weak self] in
                unsafe self?.performStart()
                continuation.resume()
            }
        }
    }

    public func stop() {
        #if os(macOS)
            let (watchers, backend, eventContinuations, errorContinuations) = state.withLock { state in
                state.isStarted = false
                let watchers = state.watchers
                state.watchers.removeAll()
                let backend = state.fseventsBackend
                state.fseventsBackend = nil
                let eventContinuations = state.eventContinuations
                let errorContinuations = state.errorContinuations
                state.eventContinuations.removeAll()
                state.errorContinuations.removeAll()
                return (watchers, backend, eventContinuations, errorContinuations)
            }

            for watcher in watchers.values {
                watcher.stop()
            }

            backend?.stop()
        #else
            let (watchers, eventContinuations, errorContinuations) = state.withLock { state in
                state.isStarted = false
                let watchers = state.watchers
                state.watchers.removeAll()
                let eventContinuations = state.eventContinuations
                let errorContinuations = state.errorContinuations
                state.eventContinuations.removeAll()
                state.errorContinuations.removeAll()
                return (watchers, eventContinuations, errorContinuations)
            }

            for watcher in watchers.values {
                watcher.stop()
            }
        #endif

        for continuation in eventContinuations.values {
            continuation.finish()
        }
        for continuation in errorContinuations.values {
            continuation.finish()
        }
    }

    @unsafe
    private func performStart() {
        let shouldStart = state.withLock { state -> Bool in
            guard !state.isStarted else { return false }
            state.isStarted = true
            state.tooManyWatchersReported = false
            return true
        }
        guard shouldStart else { return }

        let backend = resolveBackend()
        switch backend {
        case .dispatchSource:
            unsafe scanAndWatch(at: rootURL, currentDepth: 0)

        case .fsevents:
            #if os(macOS)
                let backend = FSEvents(
                    watcher: self,
                    rootURL: rootURL,
                    options: options,
                    option: option,
                )
                state.withLock { state in
                    state.fseventsBackend = backend
                }
                unsafe backend.start()
            #else
                unsafe scanAndWatch(at: rootURL, currentDepth: 0)
            #endif

        case .automatic:
            break
        }
    }

    private func resolveBackend() -> RecursiveWatchBackend {
        switch options.backend {
        case .automatic:
            #if os(macOS)
                return options.followSymlinks ? .dispatchSource : .fsevents
            #else
                return .dispatchSource
            #endif

        case .dispatchSource:
            return .dispatchSource

        case .fsevents:
            #if os(macOS)
                return .fsevents
            #else
                emitError(
                    .invalidConfiguration(
                        "FSEvents is available only on macOS. DispatchSource is used instead.",
                    ),
                )
                return .dispatchSource
            #endif
        }
    }

    @unsafe
    private func scanAndWatch(at url: URL, currentDepth: Int) {
        var stack: [(URL, Int)] = [(url, currentDepth)]

        while let (currentURL, depth) = stack.popLast() {
            if let maxDepth = options.maxDepth, depth > maxDepth {
                continue
            }

            let directoryName = currentURL.lastPathComponent
            if options.excludePatterns.contains(where: { pattern in
                matchesGlobPattern(name: directoryName, pattern: pattern)
            }) {
                continue
            }

            let outcome = unsafe watchDirectory(currentURL)
            switch outcome {
            case .limitReached:
                return

            case .alreadyWatching, .started, .failed:
                break
            }

            do {
                let contents = try FileManager.default.contentsOfDirectory(
                    at: currentURL,
                    includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey],
                    options: [.skipsHiddenFiles],
                )

                for item in contents {
                    let resourceValues = try? item.resourceValues(forKeys: [.isSymbolicLinkKey])
                    let isSymlink = resourceValues?.isSymbolicLink ?? false

                    if isSymlink, !options.followSymlinks {
                        continue
                    }

                    let itemValues = try? item.resourceValues(forKeys: [.isDirectoryKey])
                    if itemValues?.isDirectory == true {
                        stack.append((item, depth + 1))
                    }
                }
            } catch {
                emitError(.failedToWatch(currentURL, underlying: error))
            }
        }
    }

    private enum WatchOutcome {
        case alreadyWatching
        case started
        case limitReached
        case failed
    }

    @unsafe
    private func watchDirectory(_ url: URL) -> WatchOutcome {
        let (outcome, error) = state.withLock { state -> (WatchOutcome, FileSystemError?) in
            if state.watchers[url] != nil {
                return (.alreadyWatching, nil)
            }

            if state.watchers.count >= options.maxWatchedDirectories {
                let limit = options.maxWatchedDirectories
                let alreadyReported = state.tooManyWatchersReported
                state.tooManyWatchersReported = true
                let error: FileSystemError? =
                    alreadyReported
                        ? nil
                        : .tooManyWatchers(limit: limit)
                return (.limitReached, error)
            }

            do {
                var config = option
                config.scansChangedDirectoriesForFilteredEvents = false
                let watcher = try Watch(url: url, option: config)

                Task { [weak self] in
                    for await event in watcher.events {
                        self?.emitEvent(event)
                    }
                }
                Task { [weak self] in
                    for await error in watcher.errors {
                        self?.emitError(error)
                    }
                }

                unsafe watcher.start()
                state.watchers[url] = watcher
                return (.started, nil)
            } catch {
                return (.failed, .failedToWatch(url, underlying: error))
            }
        }

        if let error {
            emitError(error)
        }
        return outcome
    }

    func emitEvent(_ event: FileSystemEvent) {
        let continuations = state.withLock { state in
            Array(state.eventContinuations.values)
        }

        for continuation in continuations {
            continuation.yield(event)
        }
    }

    func emitError(_ error: FileSystemError) {
        let continuations = state.withLock { state in
            Array(state.errorContinuations.values)
        }

        for continuation in continuations {
            continuation.yield(error)
        }
    }

    private func matchesGlobPattern(name: String, pattern: String) -> Bool {
        var regexPattern =
            pattern
                .replacingOccurrences(of: ".", with: "\\.")
                .replacingOccurrences(of: "*", with: ".*")
                .replacingOccurrences(of: "?", with: ".")
        regexPattern = "^" + regexPattern + "$"
        return name.range(of: regexPattern, options: .regularExpression) != nil
    }
}

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
        var watchers: [URL: Watch] = [:]
        var tooManyWatchersReported = false
        #if os(macOS)
            var fseventsBackend: FSEvents?
        #endif
    }

    private let state: Locked<State>
    private let eventHub = StreamHub<FileSystemEvent>()
    private let errorHub = StreamHub<FileSystemError>()

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
            throw FileSystemError.invalidConfiguration("url is not a directory: '\(url.path)'")
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
        eventHub.stream
    }

    public var errors: AsyncStream<FileSystemError> {
        errorHub.stream
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
            let (watchers, backend) = state.withLock { state in
                state.isStarted = false
                let watchers = state.watchers
                state.watchers.removeAll()
                let backend = state.fseventsBackend
                state.fseventsBackend = nil
                return (watchers, backend)
            }

            for watcher in watchers.values {
                watcher.stop()
            }

            backend?.stop()
        #else
            let watchers = state.withLock { state in
                state.isStarted = false
                let watchers = state.watchers
                state.watchers.removeAll()
                return watchers
            }

            for watcher in watchers.values {
                watcher.stop()
            }
        #endif

        eventHub.finish()
        errorHub.finish()
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
                        "fsevents backend is available only on macOS; dispatch source is used instead",
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
        guard option.predicate.matches(event.url) else { return }
        eventHub.yield(event)
    }

    func emitError(_ error: FileSystemError) {
        errorHub.yield(error)
    }
}

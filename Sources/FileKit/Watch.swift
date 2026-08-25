public import Foundation
import InfraKit

public final class Watch: Sendable {
    public let url: URL
    public let option: WatcherOption

    /// DispatchWorkItem is not Sendable on the deployment target, so the whole state is unchecked.
    private struct State: @unchecked Sendable {
        var fileDescriptor: Int32 = -1
        var source: (any DispatchSourceFileSystemObject)?
        var eventContinuations: [UUID: AsyncStream<FileSystemEvent>.Continuation] = [:]
        var errorContinuations: [UUID: AsyncStream<FileSystemError>.Continuation] = [:]
        var pendingWorkItem: DispatchWorkItem?
    }

    private let state: Locked<State>

    public init(url: URL, option: WatcherOption = WatcherOption()) throws {
        let values = try? url.resourceValues(forKeys: [.isDirectoryKey])
        guard values != nil else {
            throw FileSystemError.directoryNotFound(url)
        }
        guard values?.isDirectory == true else {
            throw FileSystemError.invalidConfiguration("The URL is not a directory: \(url.path)")
        }

        self.url = url
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
    public func start() {
        let url = url
        let option = option
        let openError = state.withLock { state -> FileSystemError? in
            guard state.source == nil else { return nil }

            let descriptor = unsafe open(url.path, O_EVTONLY)
            guard descriptor >= 0 else {
                return .cannotOpenDirectory(url)
            }

            state.fileDescriptor = descriptor
            let source = DispatchSource.makeFileSystemObjectSource(
                fileDescriptor: descriptor,
                eventMask: option.eventMask.dispatchSourceMask,
                queue: option.queue,
            )

            source.setEventHandler { [weak self] in
                self?.handleEvent()
            }

            source.setCancelHandler { [weak self] in
                guard let self else { return }
                self.state.withLock { state in
                    if state.fileDescriptor >= 0 {
                        close(state.fileDescriptor)
                        state.fileDescriptor = -1
                    }
                }
            }

            source.resume()
            state.source = source
            return nil
        }

        if let openError {
            emitError(openError)
        }
    }

    public func stop() {
        let (source, eventContinuations, errorContinuations) = state.withLock { state in
            state.pendingWorkItem?.cancel()
            state.pendingWorkItem = nil
            let source = state.source
            state.source = nil
            state.fileDescriptor = -1
            let eventContinuations = state.eventContinuations
            let errorContinuations = state.errorContinuations
            state.eventContinuations.removeAll()
            state.errorContinuations.removeAll()
            return (source, eventContinuations, errorContinuations)
        }

        source?.cancel()

        for continuation in eventContinuations.values {
            continuation.finish()
        }
        for continuation in errorContinuations.values {
            continuation.finish()
        }
    }

    private func handleEvent() {
        state.withLock { state in
            state.pendingWorkItem?.cancel()

            let workItem = DispatchWorkItem { [weak self] in
                self?.emitDirectoryEvent()
            }
            state.pendingWorkItem = workItem

            option.queue.asyncAfter(
                deadline: .now() + option.debounceInterval,
                execute: workItem,
            )
        }
    }

    private func emitDirectoryEvent() {
        let event = FileSystemEvent(
            url: url,
            change: .modified,
            itemKind: .directory,
        )

        guard option.predicate.matches(event.url) else { return }

        let continuations = state.withLock { state in
            Array(state.eventContinuations.values)
        }

        for continuation in continuations {
            continuation.yield(event)
        }
    }

    private func emitError(_ error: FileSystemError) {
        let continuations = state.withLock { state in
            Array(state.errorContinuations.values)
        }

        for continuation in continuations {
            continuation.yield(error)
        }
    }
}

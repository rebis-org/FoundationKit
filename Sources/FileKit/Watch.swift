public import Foundation
import InfraKit

public final class Watch: Sendable {
    public let url: URL
    public let option: WatcherOption

    /// DispatchWorkItem is not Sendable on the deployment target, so the whole state is unchecked.
    private struct State: @unchecked Sendable {
        var fileDescriptor: Int32 = -1
        var source: (any DispatchSourceFileSystemObject)?
        var pendingWorkItem: DispatchWorkItem?
    }

    private let state: Locked<State>
    private let eventHub = StreamHub<FileSystemEvent>()
    private let errorHub = StreamHub<FileSystemError>()

    public init(url: URL, option: WatcherOption = WatcherOption()) throws {
        let values = try? url.resourceValues(forKeys: [.isDirectoryKey])
        guard values != nil else {
            throw FileSystemError.directoryNotFound(url)
        }
        guard values?.isDirectory == true else {
            throw FileSystemError.invalidConfiguration("url is not a directory: '\(url.path)'")
        }

        self.url = url
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
        let source = state.withLock { state in
            state.pendingWorkItem?.cancel()
            state.pendingWorkItem = nil
            let source = state.source
            state.source = nil
            state.fileDescriptor = -1
            return source
        }

        source?.cancel()
        eventHub.finish()
        errorHub.finish()
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
        eventHub.yield(event)
    }

    private func emitError(_ error: FileSystemError) {
        errorHub.yield(error)
    }
}

#if os(macOS)
    import CoreServices
    import Foundation

    // swiftformat:disable unusedArguments
    @unsafe
    private func fsEventsCallback(
        streamRef _: FSEventStreamRef,
        info: UnsafeMutableRawPointer?,
        numEvents: Int,
        eventPaths: UnsafeMutableRawPointer,
        eventFlags: UnsafePointer<FSEventStreamEventFlags>,
        eventIds: UnsafePointer<FSEventStreamEventId>,
    ) {
        guard let info = unsafe info else { return }
        let backend = unsafe Unmanaged<FSEvents>.fromOpaque(info).takeUnretainedValue()
        let cfArray = unsafe unsafeBitCast(eventPaths, to: CFArray.self)
        let paths = cfArray as? [String] ?? []
        unsafe backend.handleFSEvents(
            paths: paths, flags: eventFlags, eventIds: eventIds, count: numEvents,
        )
    }

    // swiftformat:enable unusedArguments

    @safe
    final class FSEvents: @unchecked Sendable {
        private weak var watcher: RecursiveWatch?
        private let rootURL: URL
        private let options: RecursiveWatchOptions
        private let option: WatcherOption

        // NSLock is used instead of Locked because the FSEventStreamRef pointer makes the state unsafe under strict memory safety.
        private let lock = NSLock()
        @unsafe private var eventStream: FSEventStreamRef?
        private var pendingDirectories: Set<URL> = []
        private var pendingFileEvents: [URL: FileSystemEvent] = [:]
        private var pendingWorkItem: DispatchWorkItem?

        init(
            watcher: RecursiveWatch,
            rootURL: URL,
            options: RecursiveWatchOptions,
            option: WatcherOption,
        ) {
            self.watcher = watcher
            self.rootURL = rootURL
            self.options = options
            self.option = option
        }

        @unsafe
        func start() {
            if options.followSymlinks {
                emitError(
                    .invalidConfiguration(
                        "FSEvents cannot follow symbolic links to directories. Use DispatchSource instead.",
                    ),
                )
            }

            lock.lock()
            guard unsafe eventStream == nil else {
                lock.unlock()
                return
            }
            lock.unlock()

            let callback: FSEventStreamCallback = unsafe fsEventsCallback
            var context = unsafe FSEventStreamContext(
                version: 0,
                info: UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque()),
                retain: nil,
                release: nil,
                copyDescription: nil,
            )

            let flags =
                FSEventStreamCreateFlags(kFSEventStreamCreateFlagFileEvents)
                    | FSEventStreamCreateFlags(kFSEventStreamCreateFlagNoDefer)
                    | FSEventStreamCreateFlags(kFSEventStreamCreateFlagUseCFTypes)
                    | FSEventStreamCreateFlags(kFSEventStreamCreateFlagWatchRoot)
            let latency = max(0.05, min(option.debounceInterval, 1.0))

            guard
                let stream = unsafe FSEventStreamCreate(
                    kCFAllocatorDefault,
                    callback,
                    &context,
                    [rootURL.standardizedFileURL.path] as CFArray,
                    FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
                    latency,
                    flags,
                )
            else {
                emitError(.systemResourcesUnavailable)
                return
            }

            unsafe FSEventStreamSetDispatchQueue(stream, option.queue)
            guard unsafe FSEventStreamStart(stream) else {
                unsafe FSEventStreamInvalidate(stream)
                unsafe FSEventStreamRelease(stream)
                emitError(.failedToWatch(rootURL, underlying: FileSystemError.systemResourcesUnavailable))
                return
            }

            lock.lock()
            unsafe eventStream = stream
            lock.unlock()
        }

        func stop() {
            lock.lock()
            pendingWorkItem?.cancel()
            pendingWorkItem = nil
            pendingDirectories.removeAll()
            pendingFileEvents.removeAll()
            let stream = unsafe eventStream
            unsafe eventStream = nil
            lock.unlock()

            guard let stream = unsafe stream else { return }
            unsafe FSEventStreamStop(stream)
            unsafe FSEventStreamInvalidate(stream)
            unsafe FSEventStreamRelease(stream)
        }

        @unsafe
        func handleFSEvents(
            paths: [String],
            flags: UnsafePointer<FSEventStreamEventFlags>,
            eventIds: UnsafePointer<FSEventStreamEventId>,
            count: Int,
        ) {
            var changedDirectories: Set<URL> = []
            var fileEvents: [FileSystemEvent] = []

            for index in 0 ..< min(paths.count, count) {
                let eventFlags = unsafe flags[index]
                guard shouldProcessFSEvent(eventFlags) else { continue }

                let event = unsafe makeEvent(
                    path: paths[index],
                    flags: eventFlags,
                    eventID: UInt64(eventIds[index]),
                )
                let depthURL = event.itemKind == .file ? event.url.deletingLastPathComponent() : event.url

                guard isWithinRoot(depthURL),
                      isWithinDepth(depthURL),
                      !isExcluded(event.url)
                else {
                    continue
                }

                if event.itemKind == .file {
                    fileEvents.append(event)
                    changedDirectories.insert(event.url.deletingLastPathComponent().standardizedFileURL)
                } else {
                    changedDirectories.insert(directoryURL(for: event))
                }
            }

            guard !changedDirectories.isEmpty || !fileEvents.isEmpty else { return }
            enqueueFSEvents(changedDirectories, fileEvents: fileEvents)
        }

        private func shouldProcessFSEvent(_ flags: FSEventStreamEventFlags) -> Bool {
            let ignoredFlags =
                FSEventStreamEventFlags(kFSEventStreamEventFlagHistoryDone)
                    | FSEventStreamEventFlags(kFSEventStreamEventFlagMount)
                    | FSEventStreamEventFlags(kFSEventStreamEventFlagUnmount)
            return flags & ignoredFlags == 0
        }

        private func makeEvent(path: String, flags: FSEventStreamEventFlags, eventID: UInt64)
            -> FileSystemEvent
        {
            let url = URL(fileURLWithPath: path).standardizedFileURL
            return FileSystemEvent(
                url: url,
                change: eventChange(for: flags),
                itemKind: itemKind(for: url, flags: flags),
                requiresRescan: requiresFullRescan(flags),
                rawFlags: UInt32(flags),
                eventID: eventID,
            )
        }

        private func directoryURL(for event: FileSystemEvent) -> URL {
            if event.requiresRescan {
                return rootURL.standardizedFileURL
            }
            if event.itemKind == .directory {
                return event.url.standardizedFileURL
            }
            return event.url.deletingLastPathComponent().standardizedFileURL
        }

        private func itemKind(for url: URL, flags: FSEventStreamEventFlags) -> FileSystemEvent.ItemKind {
            if flags & FSEventStreamEventFlags(kFSEventStreamEventFlagItemIsFile) != 0 {
                return .file
            }
            if flags & FSEventStreamEventFlags(kFSEventStreamEventFlagItemIsDir) != 0 {
                return .directory
            }
            if flags & FSEventStreamEventFlags(kFSEventStreamEventFlagItemIsSymlink) != 0 {
                return .symbolicLink
            }

            let values = try? url.resourceValues(forKeys: [.isDirectoryKey])
            guard let isDirectory = values?.isDirectory else {
                return .unknown
            }
            return isDirectory ? .directory : .file
        }

        private func eventChange(for flags: FSEventStreamEventFlags) -> FileSystemEvent.Change {
            if flags & FSEventStreamEventFlags(kFSEventStreamEventFlagItemCreated) != 0 {
                return .created
            }
            if flags & FSEventStreamEventFlags(kFSEventStreamEventFlagItemRemoved) != 0 {
                return .deleted
            }
            if flags & FSEventStreamEventFlags(kFSEventStreamEventFlagItemRenamed) != 0 {
                return .renamed
            }
            let modifiedFlags =
                FSEventStreamEventFlags(kFSEventStreamEventFlagItemModified)
                    | FSEventStreamEventFlags(kFSEventStreamEventFlagItemInodeMetaMod)
                    | FSEventStreamEventFlags(kFSEventStreamEventFlagItemFinderInfoMod)
                    | FSEventStreamEventFlags(kFSEventStreamEventFlagItemChangeOwner)
                    | FSEventStreamEventFlags(kFSEventStreamEventFlagItemXattrMod)
            if flags & modifiedFlags != 0 {
                return .modified
            }
            return .unknown
        }

        private func requiresFullRescan(_ flags: FSEventStreamEventFlags) -> Bool {
            let rescanFlags =
                FSEventStreamEventFlags(kFSEventStreamEventFlagMustScanSubDirs)
                    | FSEventStreamEventFlags(kFSEventStreamEventFlagUserDropped)
                    | FSEventStreamEventFlags(kFSEventStreamEventFlagKernelDropped)
                    | FSEventStreamEventFlags(kFSEventStreamEventFlagEventIdsWrapped)
                    | FSEventStreamEventFlags(kFSEventStreamEventFlagRootChanged)
            return flags & rescanFlags != 0
        }

        private func isWithinRoot(_ url: URL) -> Bool {
            let rootPath = canonicalPath(rootURL)
            let path = canonicalPath(url)
            return path == rootPath || path.hasPrefix(rootPath + "/")
        }

        private func isWithinDepth(_ url: URL) -> Bool {
            guard let maxDepth = options.maxDepth else { return true }
            return fseventsDepth(for: url) <= maxDepth
        }

        private func isExcluded(_ url: URL) -> Bool {
            guard !options.excludePatterns.isEmpty else { return false }
            let rootComponents = canonicalPath(rootURL).split(separator: "/")
            let components = canonicalPath(url).split(separator: "/")
            guard components.count >= rootComponents.count else { return false }

            let relativeComponents = components.dropFirst(rootComponents.count)
            for component in relativeComponents {
                for pattern in options.excludePatterns
                    where matchesGlobPattern(name: String(component), pattern: pattern)
                {
                    return true
                }
            }
            return false
        }

        private func fseventsDepth(for url: URL) -> Int {
            let rootPath = canonicalPath(rootURL)
            let path = canonicalPath(url)
            guard path != rootPath else { return 0 }
            let relativePath = path.dropFirst(rootPath.count).drop { $0 == "/" }
            return relativePath.split(separator: "/").count
        }

        private func canonicalPath(_ url: URL) -> String {
            url.resolvingSymlinksInPath().standardizedFileURL.path
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

        private func enqueueFSEvents(_ directories: Set<URL>, fileEvents: [FileSystemEvent]) {
            lock.lock()
            pendingDirectories.formUnion(directories)
            for event in fileEvents {
                pendingFileEvents[event.url] = event
            }
            pendingWorkItem?.cancel()

            let workItem = DispatchWorkItem { [weak self] in
                self?.flushFSEvents()
            }
            pendingWorkItem = workItem
            lock.unlock()

            option.queue.asyncAfter(
                deadline: .now() + option.debounceInterval, execute: workItem,
            )
        }

        private func flushFSEvents() {
            lock.lock()
            let directories = pendingDirectories
            let fileEvents = Array(pendingFileEvents.values)
            pendingDirectories.removeAll()
            pendingFileEvents.removeAll()
            pendingWorkItem = nil
            lock.unlock()

            let sortedFileEvents = fileEvents.sorted { $0.url.path < $1.url.path }
            for event in sortedFileEvents {
                emitEvent(event)
            }

            for directory in directories.sorted(by: { $0.path < $1.path }) {
                let event = FileSystemEvent(
                    url: directory,
                    change: .modified,
                    itemKind: .directory,
                )
                emitEvent(event)
            }
        }

        private func emitEvent(_ event: FileSystemEvent) {
            watcher?.emitEvent(event)
        }

        private func emitError(_ error: FileSystemError) {
            watcher?.emitError(error)
        }
    }
#endif

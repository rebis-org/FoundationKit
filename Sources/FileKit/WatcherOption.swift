public import Foundation
public import InfraKit

public struct WatcherOption: Sendable {
    public var qos: Priority
    public var debounceInterval: TimeInterval
    public var eventMask: FileSystemEventMask
    public var predicate: InfraKit.Predicate<URL>
    public var scansChangedDirectoriesForFilteredEvents: Bool

    public init(
        qos: Priority = .utility,
        debounceInterval: TimeInterval = 0.5,
        eventMask: FileSystemEventMask = [.write, .extend, .delete, .rename],
        predicate: InfraKit.Predicate<URL> = .always,
        scansChangedDirectoriesForFilteredEvents: Bool = true,
    ) {
        self.qos = qos
        self.debounceInterval = debounceInterval
        self.eventMask = eventMask
        self.predicate = predicate
        self.scansChangedDirectoriesForFilteredEvents = scansChangedDirectoriesForFilteredEvents
    }

    var queue: DispatchQueue {
        .global(qos: qos.dispatchQoS.qosClass)
    }
}

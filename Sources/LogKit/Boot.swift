import Foundation

public func boot(subsystem: String? = nil) {
    let info = Bundle.main.infoDictionary
    let app = (info?["CFBundleName"] as? String) ?? ProcessInfo.processInfo.processName
    let marketingVersion = (info?["CFBundleShortVersionString"] as? String) ?? "?"
    let build = (info?["CFBundleVersion"] as? String) ?? "?"
    let version = "\(marketingVersion) (\(build))"

    let location = Location(fileID: #fileID, filePath: #filePath, function: #function, line: #line)
    let tail = Tail(at: location, kind: "appLaunch", app: app, version: version)

    Log<OSLogSink>.osLog(identity: Identity(subsystem: subsystem ?? app, category: "launch")).log(
        .osLog(message: "\(app) launched", tail: tail.encoded()),
        level: .notice,
        location: location,
        metadata: ["kind": "appLaunch", "app": app, "version": version],
    )
}

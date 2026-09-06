public import Foundation

public extension Bundle {
    func path(forResource: String, ofType: String?) -> Path? {
        let lookup: (String?, String?) -> String? = path(forResource:ofType:)
        return lookup(forResource, ofType).flatMap(Path.init)
    }

    func path(forResource: String, ofType: String?, inDirectory: String?) -> Path? {
        let lookup: (String?, String?, String?) -> String? = path(forResource:ofType:inDirectory:)
        return lookup(forResource, ofType, inDirectory).flatMap(Path.init)
    }

    var sharedFrameworks: DynamicPath {
        sharedFrameworksPath.flatMap(DynamicPath.init) ?? defaultSharedFrameworksPath
    }

    var privateFrameworks: DynamicPath {
        privateFrameworksPath.flatMap(DynamicPath.init) ?? defaultSharedFrameworksPath
    }

    var resources: DynamicPath {
        resourcePath.flatMap(DynamicPath.init) ?? defaultResourcesPath
    }

    var path: DynamicPath {
        DynamicPath(string: bundlePath)
    }

    var executable: DynamicPath? {
        executablePath.flatMap(DynamicPath.init)
    }

    private var defaultSharedFrameworksPath: DynamicPath {
        #if os(macOS)
            path.Contents.Frameworks
        #else
            path.Frameworks
        #endif
    }

    private var defaultResourcesPath: DynamicPath {
        #if os(macOS)
            path.Contents.Resources
        #else
            path
        #endif
    }
}

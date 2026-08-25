import CryptoKit
import Foundation

/// ErrSnapshot remains a final class to avoid the Swift 6.4 IRGen crash for recursive value structs.
public final class ErrSnapshot: Sendable {
    public let typeName: String
    public let caseName: String?
    public let caseDescription: String?
    public let kindName: String
    public let domain: String
    public let code: Int
    public let localizedDescription: String
    public let failureReason: String?
    public let recoverySuggestion: String?
    public let helpAnchor: String?
    public let underlyingError: ErrSnapshot?

    public init(error: some Error) {
        let mirror = Mirror(reflecting: error)
        let localized = error as? any LocalizedError
        let nsError = error as NSError

        typeName = String(describing: type(of: error))
        if mirror.displayStyle == .enum {
            caseName = mirror.children.first?.label
            caseDescription = String(describing: error)
            kindName = "Enum"
        } else {
            caseName = nil
            caseDescription = nil
            kindName = type(of: error) is AnyClass ? "Class" : "Struct"
        }
        domain = nsError.domain
        code = nsError.code
        localizedDescription = localized?.errorDescription ?? nsError.localizedDescription
        failureReason = localized?.failureReason
        recoverySuggestion = localized?.recoverySuggestion
        helpAnchor = localized?.helpAnchor
        underlyingError = error.underlyingError.map { Self(error: $0) }
    }
}

extension ErrSnapshot {
    public var chainDescription: String {
        snapshots.enumerated().map { index, snapshot in
            let indent = String(repeating: "  ", count: index)
            let heading = "\(indent)\(snapshot.formattedType)"
            guard snapshot.underlyingError != nil else {
                return "\(heading)\n\(indent)  \(snapshot.localizedDescription)"
            }
            return heading
        }.joined(separator: "\n")
    }

    public var signature: String {
        String(sha256(typeChain).prefix(6))
    }

    private var snapshots: [ErrSnapshot] {
        Array(sequence(first: self, next: \.underlyingError))
    }

    private var typeChain: String {
        snapshots.map(\.label).joined(separator: " -> ")
    }

    private var label: String {
        caseName.map { "\(typeName).\($0)" } ?? typeName
    }

    private var formattedType: String {
        if caseName != nil, let caseDescription {
            return "\(typeName).\(caseDescription)"
        }
        return "\(typeName) [\(kindName)]"
    }
}

private func sha256(_ string: String) -> String {
    SHA256.hash(data: Data(string.utf8))
        .map { String($0 >> 4, radix: 16) + String($0 & 0x0F, radix: 16) }
        .joined()
}

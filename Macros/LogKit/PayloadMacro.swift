public import SwiftSyntax
public import SwiftSyntaxMacros
import SwiftCompilerPlugin
import SwiftSyntaxBuilder

public struct PayloadMacro: ExpressionMacro {
    public static func expansion(
        of node: some FreestandingMacroExpansionSyntax,
        in _: some MacroExpansionContext,
    ) throws -> ExprSyntax {
        guard node.arguments.count == 1, let message = node.arguments.first?.expression else {
            throw MacroError.requiresSingleArgument
        }

        return ExprSyntax(
            """
            Payload(emit: { logger, type in
              logger.log(level: type, \(message))
            })
            """,
        )
    }
}

@main
struct LogKitMacrosPlugin: CompilerPlugin {
    let providingMacros: [any Macro.Type] = [PayloadMacro.self]
}

enum MacroError: Error {
    case requiresSingleArgument
}

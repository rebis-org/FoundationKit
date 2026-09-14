@freestanding(expression)
public macro payload(_ message: Any) -> Payload =
    #externalMacro(module: "LogKitMacros", type: "PayloadMacro")

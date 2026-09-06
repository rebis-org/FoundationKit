public func failure(_ verb: String, _ target: String, because cause: String) -> String {
    "Failed to \(verb) '\(target)': \(cause)"
}

public func failure(_ verb: String, _ target: String, because cause: any Error) -> String {
    failure(verb, target, because: cause.localizedDescription)
}

public func failure(_ verb: String, _ target: String) -> String {
    "Failed to \(verb) '\(target)'"
}

public func failure(_ verb: String, because cause: String) -> String {
    "Failed to \(verb): \(cause)"
}

public func failure(_ verb: String, because cause: any Error) -> String {
    failure(verb, because: cause.localizedDescription)
}

public func failure(_ verb: String) -> String {
    "Failed to \(verb)"
}

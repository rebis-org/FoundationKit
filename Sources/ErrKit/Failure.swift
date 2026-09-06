package func failure(_ verb: String, _ target: String, because cause: String) -> String {
    "Failed to \(verb) '\(target)': \(cause)"
}

package func failure(_ verb: String, _ target: String, because cause: any Error) -> String {
    failure(verb, target, because: cause.localizedDescription)
}

package func failure(_ verb: String, _ target: String) -> String {
    "Failed to \(verb) '\(target)'"
}

package func failure(_ verb: String, because cause: String) -> String {
    "Failed to \(verb): \(cause)"
}

package func failure(_ verb: String, because cause: any Error) -> String {
    failure(verb, because: cause.localizedDescription)
}

package func failure(_ verb: String) -> String {
    "Failed to \(verb)"
}

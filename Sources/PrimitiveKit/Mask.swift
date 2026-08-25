public func mask(_ value: String, using hashFunction: some Hasher = FNV1a()) -> String {
    guard !value.isEmpty else { return "[empty]" }
    let digest = hashFunction.hash(value)
    return "‹\(String(digest, radix: 16).prefix(10))›"
}

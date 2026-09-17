public func mask(_ value: String, using hashFunction: some Hasher = Checksum()) -> String {
    if value.isEmpty { "[empty]" } else { "‹\(Hex.encode(hashFunction.hash(value), truncatedTo: 10))›" }
}

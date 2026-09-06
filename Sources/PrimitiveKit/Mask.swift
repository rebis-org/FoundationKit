public func mask(_ value: String, using hashFunction: some Hasher = Checksum()) -> String {
    value.isEmpty ? "[empty]" : "‹\(Hex.encode(hashFunction.hash(value), truncatedTo: 10))›"
}

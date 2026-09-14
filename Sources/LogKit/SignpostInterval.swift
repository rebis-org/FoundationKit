public struct SignpostInterval: Sendable, ~Copyable {
    private let finish: @Sendable () -> Void

    init(finish: @escaping @Sendable () -> Void) {
        self.finish = finish
    }

    public consuming func end() {
        finish()
    }
}

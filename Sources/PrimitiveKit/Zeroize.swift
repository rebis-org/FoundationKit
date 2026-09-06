import Darwin

public import Foundation

/// memset_s cannot be optimized away, so cleared secrets do not linger
/// in RAM the way memset-cleared copies can.
public enum Zeroize: Sendable {
    public static func erase(_ pointer: UnsafeMutableRawPointer, byteCount: Int) {
        guard byteCount > 0 else {
            return
        }
        unsafe _ = memset_s(pointer, byteCount, 0, byteCount)
    }

    public static func erase(_ buffer: UnsafeMutableRawBufferPointer) {
        guard let baseAddress = buffer.baseAddress else {
            return
        }
        unsafe erase(baseAddress, byteCount: buffer.count)
    }

    public static func erase(_ data: inout Data) {
        unsafe data.withUnsafeMutableBytes { raw in
            unsafe erase(raw)
        }
    }

    public static func erase(_ elements: inout [some FixedWidthInteger & UnsignedInteger]) {
        elements.withUnsafeMutableBytes { raw in
            unsafe erase(raw)
        }
    }

    public static func erase(_ elements: inout ContiguousArray<some FixedWidthInteger & UnsignedInteger>) {
        elements.withUnsafeMutableBytes { raw in
            unsafe erase(raw)
        }
    }

    public static func erase<Element: FixedWidthInteger & UnsignedInteger>(_ buffer: UnsafeMutableBufferPointer<Element>) {
        guard !buffer.isEmpty, let baseAddress = buffer.baseAddress else {
            return
        }
        let (byteCount, overflow) = buffer.count.multipliedReportingOverflow(
            by: MemoryLayout<Element>.stride,
        )
        precondition(!overflow, "Byte count overflow.")
        unsafe erase(
            UnsafeMutableRawBufferPointer(
                start: UnsafeMutableRawPointer(baseAddress),
                count: byteCount,
            ),
        )
    }
}

public extension UnsafeMutableRawBufferPointer {
    func zeroize() {
        unsafe Zeroize.erase(self)
    }
}

public extension Array where Element: FixedWidthInteger & UnsignedInteger {
    mutating func zeroize() {
        Zeroize.erase(&self)
    }
}

public extension ContiguousArray where Element: FixedWidthInteger & UnsignedInteger {
    mutating func zeroize() {
        Zeroize.erase(&self)
    }
}

public extension Data {
    mutating func zeroize() {
        Zeroize.erase(&self)
    }
}

public extension UnsafeMutableBufferPointer where Element: FixedWidthInteger & UnsignedInteger {
    func zeroize() {
        unsafe Zeroize.erase(self)
    }
}

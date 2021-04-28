// Copyright (c) 2021 Cunningo S.L.U.

import Foundation

extension String {
    static func fromBytesRepairing(
        bytes: Data,
        encoding: String.Encoding
    ) -> (result: String, repairsMade: Bool) {
        switch encoding {
        case .utf32BigEndian:
            return fromBytesRepairing(bytes: bytes, encoding: UTF32.self, endianness: .big)
        case .utf32LittleEndian:
            return fromBytesRepairing(bytes: bytes, encoding: UTF32.self, endianness: .little)
        case .utf16BigEndian:
            return fromBytesRepairing(bytes: bytes, encoding: UTF16.self, endianness: .big)
        case .utf16LittleEndian:
            return fromBytesRepairing(bytes: bytes, encoding: UTF16.self, endianness: .little)
        case .utf8:
            return bytes.withUnsafeBytes {
                return fromBytesRepairing(
                    codeUnits: $0.bindMemory(to: UInt8.self),
                    encoding: UTF8.self,
                    hasTrailingBytes: false
                )
            }
        default:
            preconditionFailure()
        }
    }
}

private extension String {
    static func fromBytesRepairing<Encoding: Unicode.Encoding>(
        bytes: Data,
        encoding: Encoding.Type,
        endianness: Endianness
    ) -> (result: String, repairsMade: Bool) {
        return bytes.withUnsafeBytes {
            let codeUnits = IntegerBufferView<Encoding.CodeUnit>($0, endianness: endianness)
            return fromBytesRepairing(
                codeUnits: codeUnits,
                encoding: encoding,
                hasTrailingBytes: codeUnits.hasTrailingBytes
            )
        }
    }

    static func fromBytesRepairing<CodeUnits: Collection, Encoding: Unicode.Encoding>(
        codeUnits: CodeUnits,
        encoding: Encoding.Type,
        hasTrailingBytes: Bool
    ) -> (result: String, repairsMade: Bool)
    where CodeUnits.Element == Encoding.CodeUnit {
        var validationResult = Unicode.validate(input: codeUnits, encoding: encoding)
        var string = String(decoding: codeUnits, as: encoding)
        if hasTrailingBytes {
            string.unicodeScalars.append(Encoding.decode(Encoding.encodedReplacementCharacter))
            validationResult = .invalid
        }
        switch validationResult {
        case .valid:
            return (result: string, repairsMade: false)
        case .invalid:
            return (result: string, repairsMade: true)
        }
    }
}

private enum Endianness {
    case big
    case little
}

private struct IntegerBufferView<T: FixedWidthInteger>: RandomAccessCollection {
    private let buffer: UnsafeRawBufferPointer
    private let endianness: Endianness
    let hasTrailingBytes: Bool

    let count: Int
    let startIndex: Int = 0
    var endIndex: Index { count }

    init(_ buffer: UnsafeRawBufferPointer, endianness: Endianness) {
        let elementSize = MemoryLayout<Element>.size
        count = buffer.count / elementSize
        hasTrailingBytes = !buffer.count.isMultiple(of: elementSize)
        let wholeElementPrefix = UnsafeRawBufferPointer(
            rebasing: buffer[..<(count * elementSize)]
        )
        self.buffer = wholeElementPrefix
        self.endianness = endianness
    }

    subscript(index: Int) -> T {
        get {
            var value: T = 0
            withUnsafeMutableBytes(of: &value) { valuePtr in
                let elementSize = MemoryLayout<Element>.size
                let byteIndex = index * elementSize
                let range = byteIndex..<(byteIndex &+ elementSize)
                valuePtr.copyMemory(from: UnsafeRawBufferPointer(rebasing: buffer[range]))
            }
            switch endianness {
            case .big:
                return T(bigEndian: value)
            case .little:
                return T(littleEndian: value)
            }
        }
    }
}

//------------------------------------------------------------------------------
// Copyright (c) 2021 Cunningo S.L.U. and the project authors
//
// Licensed under the Apache License, Version 2.0
// See LICENSE.txt for license information:
// https://github.com/cunningo/StringsFile/blob/main/LICENSE.txt
//------------------------------------------------------------------------------

extension Unicode {
    /// Byte Order Mark defining the Unicode encoding form and byte order.
    /// See https://unicode.org/faq/utf_bom.html#BOM
    struct BOM {
        let encoding: String.Encoding

        /// Detect a BOM in the prefix of a byte sequence.
        init?<Bytes: Collection>(bytes: Bytes) where Bytes.Element == UInt8 {
            var bytesIterator = bytes.makeIterator()
            let bom0to4 = (
                bytesIterator.next(),
                bytesIterator.next(),
                bytesIterator.next(),
                bytesIterator.next()
            )
            switch bom0to4 {
            case (0x00, 0x00, 0xFE, 0xFF):
                encoding = .utf32BigEndian
            case (0xFF, 0xFE, 0x00, 0x00):
                encoding = .utf32LittleEndian
            case (0xFE, 0xFF, _, _):
                encoding = .utf16BigEndian
            case (0xFF, 0xFE, _, _):
                encoding = .utf16LittleEndian
            case (0xEF, 0xBB, 0xBF, _):
                encoding = .utf8
            default:
                return nil
            }
        }

        /// The number of bytes in the mark.
        var byteCount: Int {
            switch encoding {
            case String.Encoding.utf32BigEndian, String.Encoding.utf32LittleEndian:
                return 4
            case String.Encoding.utf16BigEndian, String.Encoding.utf16LittleEndian:
                return 2
            case String.Encoding.utf8:
                return 3
            default:
                preconditionFailure()
            }
        }
    }
}

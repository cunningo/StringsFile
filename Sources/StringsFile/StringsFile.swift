//------------------------------------------------------------------------------
// Copyright (c) 2021 Cunningo S.L.U. and the project authors
//
// Licensed under the Apache License, Version 2.0
// See LICENSE.txt for license information:
// https://github.com/cunningo/StringsFile/blob/main/LICENSE.txt
//------------------------------------------------------------------------------

import Foundation

/// A `strings` file.
public struct StringsFile {

    /// An entry in a `strings` file.
    public struct Entry: Equatable {
        public var key: String
        public var value: String
        public var comment: String?
    }

    public struct FileReadError: Error {
        let underlyingError: Error
    }

    public struct UnicodeDecodingError: Error {}

    public struct DeserializationError: Error {
        enum Kind {
            case unexpectedEndOfFile
            case unexpectedCharacter
            case unterminatedComment
            case unterminatedString
            case unsupportedEscapeSequenceOctalNextStepLatin
            case expectedSemicolonOrEqualsSignAfterKey
            case expectedSemicolonAfterKeyValue
            case stringEscapeSequenceInvalidUTF16Surrogate
        }

        /// A location in the input string.
        struct Location {
            /// The unicode scalar index
            let unicodeScalarIndex: Int
            /// Line number (zero-based)
            let line: Int
            /// The index of the Unicode scalar value, from the start of the line
            let column: Int
        }

        let kind: Kind
        let location: Location
    }

    public struct SerializationError: Error {
        enum Kind {
            case commentContainsEndOfComment
        }

        let kind: Kind
        let entryIndex: Array<Entry>.Index
    }

    public var entries: [Entry]

    /// Create an empty `StringsFile`
    public init() {
        entries = []
    }

    /// Create a `StringsFile` from a file in the `strings` file format.
    ///
    /// - Throws: `FileReadError` if an error occurs reading the file.
    /// - Throws: `UnicodeDecodingError` if an invalid unicode encoding sequence is detected.
    /// - Throws: `DeserializationError` if a syntactic error is detected.
    public init(contentsOf fileUrl: URL) throws {
        let data: Data
        do {
            data = try Data(contentsOf: fileUrl)
        } catch {
            throw FileReadError(underlyingError: error)
        }
        try self.init(data: data)
    }

    /// Create a `StringsFile` by decoding the bytes of the data buffer.
    ///
    /// The data buffer may start with a Unicode BOM that defines the Unicode encoding form of the
    /// following `strings` data. If no marker is present UTF-8 is assumed.
    ///
    /// - Throws: `UnicodeDecodingError` if an invalid unicode encoding sequence is detected.
    /// - Throws: `DeserializationError` if a syntactic error is detected.
    public init(data: Data) throws {
        let bom = Unicode.BOM(bytes: data)
        let dataAfterBOM = data.suffix(from: bom?.byteCount ?? 0)
        let encoding = bom?.encoding ?? .utf8
        let (string, repairsMade) = String.fromBytesRepairing(
            bytes: dataAfterBOM,
            encoding: encoding
        )
        if repairsMade {
            throw UnicodeDecodingError()
        } else {
            try self.init(string: string)
        }
    }

    /// Create a `StringsFile`from a string containing text in the`strings` file format.
    ///
    /// - Throws: `DeserializationError` if a syntactic error is detected.
    public init(string: String) throws {
        do {
            entries = try Self.parse(scalars: string.unicodeScalars)
        } catch let error as InternalDeserializationError {
            throw DeserializationError(
                kind: error.kind,
                location: Self.makeErrorLocation(
                    string: string,
                    errorIndex: error.index
                )
            )
        }
    }

    /// Returns a data buffer with the serialized `strings` file, in UTF-8 encoding.
    public func serializedRepresentation() throws -> Data {
        var output = String.UnicodeScalarView()
        for (entryIndex, entry) in entries.enumerated() {
            if let comment = entry.comment {
                let containsEndOfComment = comment.unicodeScalars[...]
                    .containsPair((.asterisk, .forwardSlash))
                guard !containsEndOfComment else {
                    throw SerializationError(
                        kind: .commentContainsEndOfComment,
                        entryIndex: entryIndex
                    )
                }
                output.append(.forwardSlash)
                output.append(.asterisk)
                output.append(.space)
                output.append(contentsOf: comment.unicodeScalars)
                output.append(.space)
                output.append(.asterisk)
                output.append(.forwardSlash)
                output.append(.lineFeed)
            }
            output.append(.doubleQuotationMark)
            appendEscaping(entry.key, to: &output)
            output.append(.doubleQuotationMark)
            output.append(.space)
            output.append(.equalsSign)
            output.append(.space)
            output.append(.doubleQuotationMark)
            appendEscaping(entry.value, to: &output)
            output.append(.doubleQuotationMark)
            output.append(.semicolon)
            output.append(.lineFeed)
            output.append(.lineFeed)
        }
        return String(output).data(using: .utf8)!
    }
}

private extension StringsFile {

    struct InternalDeserializationError: Error {
        let kind: DeserializationError.Kind
        let index: String.Index
    }

    static func parse(scalars: String.UnicodeScalarView) throws -> [Entry] {
        var buf = scalars[...]
        var entries: [Entry] = []
        while !buf.isEmpty {
            let lastComment = try skipWhitespaceAndComments(&buf)
            if !buf.isEmpty {
                let (key, value) = try parseKeyValue(&buf)
                let trimmedComment = lastComment.map {
                    $0.trimmingCharacters(in: .whitespaces)
                }
                let entry = Entry(key: key, value: value, comment: trimmedComment)
                entries.append(entry)
            }
        }
        return entries
    }

    static func parseComment(
        _ buf: inout String.UnicodeScalarView.SubSequence
    ) throws -> Substring? {
        let startIndex = buf.startIndex
        let next = buf.index(after: startIndex)
        guard next < buf.endIndex else { return nil }
        switch buf[next] {
        case .forwardSlash:
            buf.removeFirst(2)
            return Substring(buf.take(until: { $0.isPLNewline }))
        case .asterisk:
            buf.removeFirst(2)
            var (prefix, rest) = buf.seek(until: { $0 == .asterisk && $1 == .forwardSlash })
            if rest.isEmpty {
                throw InternalDeserializationError(kind: .unterminatedComment, index: startIndex)
            } else {
                rest.removeFirst(2)
                buf = rest
                return Substring(prefix)
            }
        default:
            return nil
        }
    }

    static func skipWhitespaceAndComments(
        _ buf: inout String.UnicodeScalarView.SubSequence
    ) throws -> Substring? {
        var lastComment: Substring?
        while !buf.isEmpty {
            _ = buf.take(until: { $0 == .forwardSlash || !$0.isPLWhitespace })
            if buf.first == .forwardSlash {
                if let comment = try parseComment(&buf) {
                    lastComment = comment
                } else {
                    break
                }
            } else {
                break
            }
        }
        return lastComment
    }

    static func parseKeyValue(
        _ buf: inout String.UnicodeScalarView.SubSequence
    ) throws -> (String, String) {
        let key = try parseString(&buf)
        _ = try skipWhitespaceAndComments(&buf)
        switch buf.first {
        case UnicodeScalar.semicolon:
            // shortcut format
            buf.removeFirst()
            return (key, key)
        case UnicodeScalar.equalsSign:
            buf.removeFirst()
            _ = try skipWhitespaceAndComments(&buf)
            let value = try parseString(&buf)
            _ = try skipWhitespaceAndComments(&buf)
            if buf.first == UnicodeScalar.semicolon {
                buf.removeFirst()
                return (key, value)
            } else {
                throw InternalDeserializationError(
                    kind: .expectedSemicolonAfterKeyValue,
                    index: buf.startIndex
                )
            }
        default:
            throw InternalDeserializationError(
                kind: .expectedSemicolonOrEqualsSignAfterKey,
                index: buf.startIndex
            )
        }
    }

    static func parseString(
        _ buf: inout String.UnicodeScalarView.SubSequence
    ) throws -> String {
        switch buf.first {
        case UnicodeScalar.singleQuotationMark, UnicodeScalar.doubleQuotationMark:
            return try parseQuotedString(&buf)
        case let scalar? where scalar.isPLValidUnquoted:
            return try parseUnquotedString(&buf)
        case .some:
            throw InternalDeserializationError(
                kind: .unexpectedCharacter,
                index: buf.startIndex
            )
        case nil:
            throw InternalDeserializationError(
                kind: .unexpectedEndOfFile,
                index: buf.startIndex
            )
        }
    }

    static func parseQuotedString(
        _ buf: inout String.UnicodeScalarView.SubSequence
    ) throws -> String {
        let startIndex = buf.startIndex
        let quote = buf.removeFirst().value
        // Switch to parsing utf16 code units while in quoted string,
        // since escape sequences may result in utf16 surrogates.
        let bufUtf16 = Substring(buf).utf16
        var acc = [UTF16.CodeUnit]()
        var cur = bufUtf16.startIndex
        var pendingToAppendStart = cur
        while cur < buf.endIndex {
            switch UInt32(bufUtf16[cur]) {
            case quote:
                defer {
                    buf = buf[buf.index(after: cur)...]
                }
                if acc.isEmpty {
                    // Fast path, no escape sequences
                    return String(buf[buf.startIndex..<cur])
                } else {
                    acc.append(contentsOf: bufUtf16[pendingToAppendStart..<cur])
                    guard case .valid = Unicode.validate(input: acc, encoding: UTF16.self) else {
                        throw InternalDeserializationError(
                            kind: .stringEscapeSequenceInvalidUTF16Surrogate,
                            index: startIndex
                        )
                    }
                    return String(decoding: acc, as: UTF16.self)
                }
            case UnicodeScalar.backslash.value:
                acc.append(contentsOf: bufUtf16[pendingToAppendStart..<cur])
                if buf.index(after: cur) < buf.endIndex {
                    let (utf16, rest) = try parseEscapedChar(bufUtf16[cur...])
                    acc.append(utf16)
                    pendingToAppendStart = rest.startIndex
                    cur = rest.startIndex
                }
            default:
                cur = buf.index(after: cur)
            }
        }
        throw InternalDeserializationError(kind: .unterminatedString, index: startIndex)
    }

    static func parseEscapedChar(
        _ buf: Substring.UTF16View.SubSequence
    ) throws -> (utf16: Unicode.UTF16.CodeUnit, rest: String.UTF16View.SubSequence) {
        let buf = buf.dropFirst()
        let first = buf.first!
        switch UInt32(first) {
        case UnicodeScalar("0").value...UnicodeScalar("9").value:
            throw InternalDeserializationError(
                kind: .unsupportedEscapeSequenceOctalNextStepLatin,
                index: buf.startIndex
            )
        case UnicodeScalar("U").value:
            let buf = buf.dropFirst()
            let hexDigits = buf.prefix(4).prefix(while: {
                UnicodeScalar($0)?.properties.isASCIIHexDigit == true
            })
            let utf16 = UInt16(Substring(hexDigits), radix: 16)!
            return (utf16, buf.dropFirst(hexDigits.count))
        case UnicodeScalar("a").value:
            return (UInt16(UnicodeScalar.bell.value), buf.dropFirst())
        case UnicodeScalar("b").value:
            return (UInt16(UnicodeScalar.backspace.value), buf.dropFirst())
        case UnicodeScalar("f").value:
            return (UInt16(UnicodeScalar.formFeed.value), buf.dropFirst())
        case UnicodeScalar("n").value:
            return (UInt16(UnicodeScalar.lineFeed.value), buf.dropFirst())
        case UnicodeScalar("r").value:
            return (UInt16(UnicodeScalar.carriageReturn.value), buf.dropFirst())
        case UnicodeScalar("t").value:
            return (UInt16(UnicodeScalar.horizontalTab.value), buf.dropFirst())
        case UnicodeScalar("v").value:
            return (UInt16(UnicodeScalar.verticalTab.value), buf.dropFirst())
        default:
            return (first, buf.dropFirst())
        }
    }

    static func parseUnquotedString(
        _ buf: inout String.UnicodeScalarView.SubSequence
    ) throws -> String {
        String(buf.take(until: { !$0.isPLValidUnquoted }))
    }

    static func makeErrorLocation(
        string: String,
        errorIndex: String.Index
    ) -> DeserializationError.Location {
        let errorIndex = errorIndex.samePosition(in: string)!
        let stringUpToErrorIndex = string[string.startIndex..<errorIndex]
        let unicodeScalarIndex = stringUpToErrorIndex.unicodeScalars.count

        let lineColumn = stringUpToErrorIndex.reduce(
            into: (line: 0, column: 0)
        ) { result, char in
            if char.isNewline {
                result.line += 1
                result.column = 0
            } else {
                result.column += char.unicodeScalars.count
            }
        }

        return DeserializationError.Location(
            unicodeScalarIndex: unicodeScalarIndex,
            line: lineColumn.line,
            column: lineColumn.column
        )
    }
}

private extension StringsFile {
    func appendEscaping(_ string: String, to output: inout String.UnicodeScalarView) {
        for char in string.unicodeScalars {
            if char == .doubleQuotationMark || char == .backslash {
                output.append(.backslash)
            }
            output.append(char)
        }
    }
}

private extension Unicode.Scalar {
    static let backspace: UnicodeScalar = "\u{08}"
    static let bell: UnicodeScalar = "\u{07}"
    static let carriageReturn: UnicodeScalar = "\u{0D}"
    static let formFeed: UnicodeScalar = "\u{0C}"
    static let horizontalTab: UnicodeScalar = "\u{09}"
    static let lineFeed: UnicodeScalar = "\u{0A}"
    static let verticalTab: UnicodeScalar = "\u{0B}"

    static let asterisk: UnicodeScalar = "*"
    static let backslash: UnicodeScalar = "\\"
    static let doubleQuotationMark: UnicodeScalar = "\""
    static let equalsSign: UnicodeScalar = "="
    static let forwardSlash: UnicodeScalar = "/"
    static let semicolon: UnicodeScalar = ";"
    static let singleQuotationMark: UnicodeScalar = "'"
    static let space: UnicodeScalar = "\u{20}"

    static let unicodeLineSeparator: UnicodeScalar = "\u{2028}"
    static let unicodeParagraphSeparator: UnicodeScalar = "\u{2029}"

    /// Whether the scalar is a whitespace character.
    var isPLWhitespace: Bool {
        switch self {
        case .horizontalTab, .verticalTab, .formFeed, .space:
            return true
        case let scalar where scalar.isPLNewline:
            return true
        default:
            return false
        }
    }

    /// Whether the scalar is a newline character.
    var isPLNewline: Bool {
        switch self {
        case .lineFeed,
            .carriageReturn,
            .unicodeLineSeparator,
            .unicodeParagraphSeparator:
            return true
        default:
            return false
        }
    }

    /// Whether the scalar is valid in an unquoted string.
    var isPLValidUnquoted: Bool {
        switch self {
        case "a"..."z", "A"..."Z", "0"..."9":
            return true
        case "_", "$", "/", ":", ".", "-":
            return true
        default:
            return false
        }
    }
}

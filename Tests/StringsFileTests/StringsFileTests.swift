// Copyright (c) 2021 Cunningo S.L.U.

import XCTest

@testable import StringsFile

final class StringsFileTests: XCTestCase {

    // MARK: - Valid input

    func testEmpty() throws {
        let input = ""
        let expectedEntries: [StringsFile.Entry] = []

        let stringsFile = try testSubstepDeserialize(input: input, expectedEntries: expectedEntries)
        try testSubstepSerialize(stringsFile: stringsFile, expectedOutputString: input)
    }

    func testCommentAndWhitespaceOnly() throws {
        let input = #"""
            /* comment */
            // comment

            """#

        let expectedEntries: [StringsFile.Entry] = []

        let output = ""

        let stringsFile = try testSubstepDeserialize(input: input, expectedEntries: expectedEntries)
        try testSubstepSerialize(stringsFile: stringsFile, expectedOutputString: output)
    }

    func testSingleEntry() throws {
        let input = #"""
            "key0" = "value0";


            """#

        let expectedEntries: [StringsFile.Entry] = [
            .init(key: "key0", value: "value0", comment: nil)
        ]

        let stringsFile = try testSubstepDeserialize(input: input, expectedEntries: expectedEntries)
        try testSubstepSerialize(stringsFile: stringsFile, expectedOutputString: input)
    }

    func testKeyShortcut() throws {
        let input = #"""
            "key0";
            """#

        let expectedEntries: [StringsFile.Entry] = [
            .init(key: "key0", value: "key0", comment: nil)
        ]

        _ = try testSubstepDeserialize(input: input, expectedEntries: expectedEntries)
    }

    func testUnquotedKeyValue() throws {
        let input = #"""
            aA0_$/:.- = /aA0_$:.-;
               key1  =  value1  ;
            """#

        let expectedEntries: [StringsFile.Entry] = [
            .init(key: "aA0_$/:.-", value: "/aA0_$:.-", comment: nil),
            .init(key: "key1", value: "value1", comment: nil),
        ]

        _ = try testSubstepDeserialize(input: input, expectedEntries: expectedEntries)
    }

    func testSupplementaryMultilingualPlaneCharacter() throws {
        let input = #"""
            "key0" = "\#u{1F30D}";


            """#

        let expectedEntries: [StringsFile.Entry] = [
            .init(key: "key0", value: "\u{1F30D}", comment: nil)
        ]

        let stringsFile = try testSubstepDeserialize(input: input, expectedEntries: expectedEntries)
        try testSubstepSerialize(stringsFile: stringsFile, expectedOutputString: input)
    }

    func testKeyValueSpanningMultipleLines() throws {
        let input = #"""
            "key
            0" = "value
            0";


            """#

        let expectedEntries: [StringsFile.Entry] = [
            .init(key: "key\n0", value: "value\n0", comment: nil)
        ]

        let stringsFile = try testSubstepDeserialize(input: input, expectedEntries: expectedEntries)
        try testSubstepSerialize(stringsFile: stringsFile, expectedOutputString: input)
    }

    func testEscapedChar() throws {
        let input = #"""
            "\a\b\f\n\r\t\v\'\"\\" = "value0";


            """#

        let output = #"""
            "\#u{7}\#u{8}\#u{C}\#u{A}\#u{D}\#u{9}\#u{B}'\"\\" = "value0";


            """#

        let expectedEntries: [StringsFile.Entry] = [
            .init(key: "\u{7}\u{8}\u{C}\u{A}\u{D}\u{9}\u{B}'\"\\", value: "value0", comment: nil)
        ]

        let stringsFile = try testSubstepDeserialize(input: input, expectedEntries: expectedEntries)
        try testSubstepSerialize(stringsFile: stringsFile, expectedOutputString: output)
    }

    func testUnicodeEscape() throws {
        let input = #"""
            "\U00f1" = "";
            "\U00f11" = "";
            "\U00fg" = "";
            "\U0" = "";
            """#

        let expectedEntries: [StringsFile.Entry] = [
            .init(key: "ñ", value: "", comment: nil),
            .init(key: "ñ1", value: "", comment: nil),
            .init(key: "\u{00f}g", value: "", comment: nil),
            .init(key: "\u{0}", value: "", comment: nil),
        ]

        _ = try testSubstepDeserialize(input: input, expectedEntries: expectedEntries)
    }

    func testUnicodeEscapeUTF16SurrogatePair() throws {
        let input = #"""
            "\UD83C\UDF0D" = "";
            """#

        let expectedEntries: [StringsFile.Entry] = [
            .init(key: "\u{1F30D}", value: "", comment: nil)
        ]

        let output = #"""
            "\#u{1F30D}" = "";


            """#

        let stringsFile = try testSubstepDeserialize(input: input, expectedEntries: expectedEntries)
        try testSubstepSerialize(stringsFile: stringsFile, expectedOutputString: output)
    }

    func testMultipleEntriesNoComments() throws {
        let input = #"""
            "key0" = "value0";

            "key1" = "value1";


            """#

        let expectedEntries: [StringsFile.Entry] = [
            .init(key: "key0", value: "value0", comment: nil),
            .init(key: "key1", value: "value1", comment: nil),
        ]

        let stringsFile = try testSubstepDeserialize(input: input, expectedEntries: expectedEntries)
        try testSubstepSerialize(stringsFile: stringsFile, expectedOutputString: input)
    }

    func testEntryMultilineComment() throws {
        let input = #"""
            /* comment 0
            on multiple lines */
            "key0" = "value0";

            /* comment 1
            on multiple lines
             */
            "key1" = "value1";


            """#

        let expectedEntries: [StringsFile.Entry] = [
            .init(key: "key0", value: "value0", comment: "comment 0\non multiple lines"),
            .init(key: "key1", value: "value1", comment: "comment 1\non multiple lines\n"),
        ]

        let stringsFile = try testSubstepDeserialize(input: input, expectedEntries: expectedEntries)
        try testSubstepSerialize(stringsFile: stringsFile, expectedOutputString: input)
    }

    func testEntrySingleLineComment() throws {
        let input = #"""
            // comment 0
            "key0" = "value0";

            "key1" = "value1";


            """#

        let expectedEntries: [StringsFile.Entry] = [
            .init(key: "key0", value: "value0", comment: "comment 0"),
            .init(key: "key1", value: "value1", comment: nil),
        ]

        let output = #"""
            /* comment 0 */
            "key0" = "value0";

            "key1" = "value1";


            """#

        let stringsFile = try testSubstepDeserialize(input: input, expectedEntries: expectedEntries)
        try testSubstepSerialize(stringsFile: stringsFile, expectedOutputString: output)
    }

    func testMultiplePrecedingComments() throws {
        let input = #"""
            // comment 0
            // comment 1
            "key0" = "value0";
            """#

        let expectedEntries: [StringsFile.Entry] = [
            .init(key: "key0", value: "value0", comment: "comment 1")
        ]

        _ = try testSubstepDeserialize(input: input, expectedEntries: expectedEntries)
    }

    func testInlineComments() throws {
        let input = #"""
            "key0" /**/ = /**/ "value0" /**/ ; /**/

            "key1" = "value1";
            /**/
            """#

        let expectedEntries: [StringsFile.Entry] = [
            .init(key: "key0", value: "value0", comment: nil),
            .init(key: "key1", value: "value1", comment: ""),
        ]

        _ = try testSubstepDeserialize(input: input, expectedEntries: expectedEntries)
    }

    // MARK: - Data input

    private func testInitFromData(encoding: String.Encoding, bomBytes: [UInt8]? = nil) throws {
        let input = #"""
            "key0" = "\#u{1F30D}";
            """#

        let expectedEntries: [StringsFile.Entry] = [
            .init(key: "key0", value: "\u{1F30D}", comment: nil)
        ]

        var inputData = bomBytes.map { Data($0) } ?? encoding.BOMBytes
        inputData.append(contentsOf: input.data(using: encoding)!)

        _ = try testSubstepDeserialize(
            input: inputData,
            expectedEntries: expectedEntries
        )
    }

    func testInitFromUTF8WithoutBOM() throws {
        try testInitFromData(encoding: .utf8, bomBytes: [])
    }

    func testInitFromUTF8WithBOM() throws {
        try testInitFromData(encoding: .utf8)
    }

    func testInitFromMalformedUTF8Data() throws {
        let invalidUtf8ByteSequence: [UInt8] = [0xC0, 0xAF]
        let inputData = Data(String("a").utf8) + Data(invalidUtf8ByteSequence)

        XCTAssertThrowsError(try StringsFile(data: inputData)) { error in
            let unicodeDecodingError = error as? StringsFile.UnicodeDecodingError
            XCTAssertNotNil(unicodeDecodingError, "Unexpected error type: \(type(of: error))")
        }
    }

    func testInitFromUTF16LittleEndian() throws {
        try testInitFromData(encoding: .utf16LittleEndian)
    }

    func testInitFromUTF16LittleEndianMalformedSurrogate() throws {
        let leadSurrogate: UInt16 = 0xD800
        let utf16CodeUnits = Array(String("a").utf16) + [leadSurrogate]
        var inputData = Data([0xFF, 0xFE])
        inputData.append(contentsOf: utf16CodeUnits.littleEndianByteArray)

        XCTAssertThrowsError(try StringsFile(data: inputData)) { error in
            let unicodeDecodingError = error as? StringsFile.UnicodeDecodingError
            XCTAssertNotNil(unicodeDecodingError, "Unexpected error type: \(type(of: error))")
        }
    }

    func testInitFromUTF16LittleEndianMalformedTrailingByte() throws {
        let utf16CodeUnits = Array(String("a").utf16)

        var inputData = Data([0xFF, 0xFE])
        inputData.append(contentsOf: utf16CodeUnits.littleEndianByteArray)
        inputData.append(0x0)

        XCTAssertThrowsError(try StringsFile(data: inputData)) { error in
            let unicodeDecodingError = error as? StringsFile.UnicodeDecodingError
            XCTAssertNotNil(unicodeDecodingError, "Unexpected error type: \(type(of: error))")
        }
    }

    func testInitFromUTF16BigEndian() throws {
        try testInitFromData(encoding: .utf16BigEndian)
    }

    func testInitFromUTF32LittleEndian() throws {
        try testInitFromData(encoding: .utf32LittleEndian)
    }

    func testInitFromUTF32BigEndian() throws {
        try testInitFromData(encoding: .utf32BigEndian)
    }

    // MARK: - File input

    func testInitFromFile() throws {
        let input = #"""
            "key0" = "value0";
            """#

        let fileUrl = makeTeardownedTempFileUrl()
        try input.data(using: .utf8)!.write(to: fileUrl)

        _ = try StringsFile(contentsOf: fileUrl)
    }

    // MARK: - Error location

    func testErrorLocationLineColumn() throws {
        let input = #"""

              *
            """#

        XCTAssertThrowsError(try StringsFile(string: input)) { error in
            let deserializationError = error as? StringsFile.DeserializationError
            XCTAssertEqual(deserializationError?.location.line, 1)
            XCTAssertEqual(deserializationError?.location.column, 2)
        }
    }

    // MARK: - Malformed input

    func testMissingSemicolonAfterValue() throws {
        let input = #"""
            "key" = "value"
            """#

        XCTAssertThrowsError(try StringsFile(string: input)) { error in
            let deserializationError = error as? StringsFile.DeserializationError
            XCTAssertEqual(deserializationError?.kind, .expectedSemicolonAfterKeyValue)
            XCTAssertEqual(deserializationError?.location.line, 0)
            XCTAssertEqual(deserializationError?.location.column, 15)
        }
    }

    func testDuplicateSemicolonAfterValue() throws {
        let input = #"""
            "key0" = "value0";;
            "key1" = "value1";
            """#

        XCTAssertThrowsError(try StringsFile(string: input)) { error in
            let deserializationError = error as? StringsFile.DeserializationError
            XCTAssertEqual(deserializationError?.kind, .unexpectedCharacter)
            XCTAssertEqual(deserializationError?.location.line, 0)
            XCTAssertEqual(deserializationError?.location.column, 18)
        }
    }

    func testMissingSemicolonAfterKeyShortcut() throws {
        let input = #"""
            "key"
            """#

        XCTAssertThrowsError(try StringsFile(string: input)) { error in
            let deserializationError = error as? StringsFile.DeserializationError
            XCTAssertEqual(deserializationError?.kind, .expectedSemicolonOrEqualsSignAfterKey)
            XCTAssertEqual(deserializationError?.location.line, 0)
            XCTAssertEqual(deserializationError?.location.column, 5)
        }
    }

    func testMissingValueAtEndOfFile() throws {
        let input = #"""
            "key" =
            """#

        XCTAssertThrowsError(try StringsFile(string: input)) { error in
            let deserializationError = error as? StringsFile.DeserializationError
            XCTAssertEqual(deserializationError?.kind, .unexpectedEndOfFile)
            XCTAssertEqual(deserializationError?.location.line, 0)
            XCTAssertEqual(deserializationError?.location.column, 7)
        }
    }

    func testUnterminatedMultilineComment() throws {
        let input = #"""
            /*
            """#

        XCTAssertThrowsError(try StringsFile(string: input)) { error in
            let deserializationError = error as? StringsFile.DeserializationError
            XCTAssertEqual(deserializationError?.kind, .unterminatedComment)
            XCTAssertEqual(deserializationError?.location.line, 0)
            XCTAssertEqual(deserializationError?.location.column, 0)
        }
    }

    func testHalfTerminatedMultilineComment() throws {
        let input = #"""
            /**
            """#

        XCTAssertThrowsError(try StringsFile(string: input)) { error in
            let deserializationError = error as? StringsFile.DeserializationError
            XCTAssertEqual(deserializationError?.kind, .unterminatedComment)
            XCTAssertEqual(deserializationError?.location.line, 0)
            XCTAssertEqual(deserializationError?.location.column, 0)
        }
    }

    func testSingleLineCommentMissingSlash() throws {
        let input = #"""
            / a comment
            "key" = "value"
            """#

        XCTAssertThrowsError(try StringsFile(string: input)) { error in
            let deserializationError = error as? StringsFile.DeserializationError
            // A single forward slash is a valid unquoted string, so it's diagnosed as
            // an error after a key.
            XCTAssertEqual(deserializationError?.kind, .expectedSemicolonOrEqualsSignAfterKey)
            XCTAssertEqual(deserializationError?.location.line, 0)
            XCTAssertEqual(deserializationError?.location.column, 2)
        }
    }

    func testStraySlashAtEndOfFile() throws {
        let input = #"""
            /
            """#

        XCTAssertThrowsError(try StringsFile(string: input)) { error in
            let deserializationError = error as? StringsFile.DeserializationError
            // A single forward slash is a valid unquoted string, so it's diagnosed as
            // an error after a key.
            XCTAssertEqual(deserializationError?.kind, .expectedSemicolonOrEqualsSignAfterKey)
            XCTAssertEqual(deserializationError?.location.line, 0)
            XCTAssertEqual(deserializationError?.location.column, 1)
        }
    }

    func testStrayUnquotedCharacter() throws {
        let input = #"""
            =
            "key" = "value"
            """#

        XCTAssertThrowsError(try StringsFile(string: input)) { error in
            let deserializationError = error as? StringsFile.DeserializationError
            XCTAssertEqual(deserializationError?.kind, .unexpectedCharacter)
            XCTAssertEqual(deserializationError?.location.line, 0)
            XCTAssertEqual(deserializationError?.location.column, 0)
        }
    }

    func testInvalidUnicodeEscapeUTF16SurrogatePair() throws {
        let input = #"""
            "\UD800" = "value"
            """#

        XCTAssertThrowsError(try StringsFile(string: input)) { error in
            let deserializationError = error as? StringsFile.DeserializationError
            XCTAssertEqual(deserializationError?.kind, .stringEscapeSequenceInvalidUTF16Surrogate)
            XCTAssertEqual(deserializationError?.location.line, 0)
            XCTAssertEqual(deserializationError?.location.column, 0)
        }
    }

    func testUnsupportedEscapeSequenceOctalNextStepLatin() throws {
        let input = #"""
            "\000" = "value"
            """#

        XCTAssertThrowsError(try StringsFile(string: input)) { error in
            let deserializationError = error as? StringsFile.DeserializationError
            XCTAssertEqual(deserializationError?.kind, .unsupportedEscapeSequenceOctalNextStepLatin)
            XCTAssertEqual(deserializationError?.location.line, 0)
            XCTAssertEqual(deserializationError?.location.column, 2)
        }
    }

    // MARK: - Malformed input

    func testSerializedRepresentationWithCommentContainingEndOfComment() throws {
        var stringsFile = StringsFile()
        let entry = StringsFile.Entry(key: "key", value: "value", comment: "*/")
        stringsFile.entries.append(entry)

        XCTAssertThrowsError(try stringsFile.serializedRepresentation()) { error in
            let deserializationError = error as? StringsFile.SerializationError
            XCTAssertEqual(deserializationError?.kind, .commentContainsEndOfComment)
            XCTAssertEqual(deserializationError?.entryIndex, 0)
        }
    }
}

// MARK: - Substep activities

private extension StringsFileTests {

    func testSubstepDeserialize(
        input: String,
        expectedEntries: [StringsFile.Entry]
    ) throws -> StringsFile {
        try XCTContext.runActivity(named: "deserialize") { activity in
            let inputAttachment: XCTAttachment = {
                let attachment = XCTAttachment(
                    data: input.data(using: .utf8)!,
                    uniformTypeIdentifier: UTI.strings
                )
                attachment.name = "input.strings"
                return attachment
            }()
            activity.add(inputAttachment)

            let stringsFile = try StringsFile(string: input)
            XCTAssertEqual(stringsFile.entries, expectedEntries)
            return stringsFile
        }
    }

    func testSubstepDeserialize(
        input: Data,
        expectedEntries: [StringsFile.Entry]
    ) throws -> StringsFile {
        try XCTContext.runActivity(named: "deserialize") { activity in
            let inputAttachment = XCTAttachment.make(
                name: "input.strings",
                stringsFileData: input
            )
            activity.add(inputAttachment)

            let stringsFile = try StringsFile(data: input)
            XCTAssertEqual(stringsFile.entries, expectedEntries)
            return stringsFile
        }
    }

    func testSubstepSerialize(stringsFile: StringsFile, expectedOutputString: String) throws {
        try XCTContext.runActivity(named: "serialize") { activity in
            let stringsFileData = try stringsFile.serializedRepresentation()
            let outputAttachment = XCTAttachment.make(
                name: "output.strings",
                stringsFileData: stringsFileData
            )
            activity.add(outputAttachment)

            let expectedAttachment = XCTAttachment.make(
                name: "expected.strings",
                stringsFileData: expectedOutputString.data(using: .utf8)!
            )
            activity.add(expectedAttachment)

            XCTAssertEqual(
                try XCTUnwrap(String(data: stringsFileData, encoding: .utf8)),
                expectedOutputString
            )
        }
    }
}

// MARK: - Helpers

private extension StringsFileTests {
    func makeTeardownedTempFileUrl() -> URL {
        let directory = NSTemporaryDirectory()
        let filename = UUID().uuidString
        let fileURL = URL(fileURLWithPath: directory).appendingPathComponent(filename)

        addTeardownBlock {
            do {
                let fileManager = FileManager.default
                try fileManager.removeItem(at: fileURL)
            } catch {
                XCTFail("Error deleting temporary file: \(error)")
            }
        }

        return fileURL
    }
}

private extension XCTAttachment {
    static func make(name: String, stringsFileData: Data) -> XCTAttachment {
        let attachment = XCTAttachment(
            data: stringsFileData,
            uniformTypeIdentifier: UTI.strings
        )
        attachment.name = name
        return attachment
    }
}

private enum UTI {
    static let strings = "com.apple.xcode.strings-text"
}

private extension String.Encoding {
    var BOMBytes: Data {
        String("\u{FEFF}").data(using: self)!
    }
}

private extension Array where Element: FixedWidthInteger {
    var littleEndianByteArray: [UInt8] {
        reduce(into: []) { result, element in
            let value = element.littleEndian
            Swift.withUnsafeBytes(of: value, { result.append(contentsOf: $0) })
        }
    }
}

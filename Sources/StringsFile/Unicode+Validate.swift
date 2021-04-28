// Copyright (c) 2021 Cunningo S.L.U.

extension Unicode {

    enum ValidationResult {
        case valid
        case invalid
    }

    static func validate<Input: Sequence, Encoding: Unicode.Encoding>(
        input: Input,
        encoding: Encoding.Type
    ) -> ValidationResult
    where Input.Element == Encoding.CodeUnit {
        var inputIterator = input.makeIterator()
        var parser = Encoding.ForwardParser()
        while true {
            switch parser.parseScalar(from: &inputIterator) {
            case .valid(_):
                break
            case .error(length: _):
                return .invalid
            case .emptyInput:
                return .valid
            }
        }
    }
}

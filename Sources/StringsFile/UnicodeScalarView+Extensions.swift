// Copyright (c) 2021 Cunningo S.L.U.

extension String.UnicodeScalarView.SubSequence {
    mutating func take(until predicate: (Element) -> Bool) -> SubSequence {
        let (prefix, rest) = self.seek(until: predicate)
        defer {
            self = rest
        }
        return prefix
    }

    func seek(
        until predicate: (Element) -> Bool
    ) -> (prefix: SubSequence, rest: SubSequence) {
        guard let point = self.firstIndex(where: predicate) else {
            return (self[...], self[endIndex...])
        }
        return (self[..<point], self[point...])
    }

    func seek(
        until predicate: (Element, Element) -> Bool
    ) -> (prefix: SubSequence, rest: SubSequence) {
        let point = indices.first {
            if let next = index($0, offsetBy: 1, limitedBy: endIndex), next != endIndex {
                return predicate(self[$0], self[next])
            } else {
                return false
            }
        }
        guard let point = point else {
            return (self[...], self[endIndex...])
        }
        return (self[..<point], self[point...])
    }

    func containsPair(_ pair: (UnicodeScalar, UnicodeScalar)) -> Bool {
        !seek { s0, s1 in s0 == pair.0 && s1 == pair.1 }.rest.isEmpty
    }
}

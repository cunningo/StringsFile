# StringsFile

![](https://img.shields.io/badge/Swift-5.5%20|%205.4-orange.svg) [![](https://img.shields.io/badge/SwiftPM-compatible-brightgreen.svg?style=flat)](https://swift.org/package-manager)

**StringsFile** is a library for serialization and deserialization of [`.strings`](https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/LoadingResources/Strings/Strings.html) files.

```
/* comment */
"key" = "value";
```

## Features

- [X] Read all relevant syntax-variants supported by `Foundation.PropertyListSerialization`
    - Comments, escape sequences, multi-line strings, unquoted strings, ...
- [X] Deserialize and serialize comments
- [X] Strict validation of unicode encoding and syntax

## Examples

Deserialize and iterate over the entries in a `.strings` file:
```swift
import StringsFile

for entry in try StringsFile(contentsOf: stringsFileUrl).entries {
    print("key: \(entry.key), value: \(entry.value), comment: \(entry.comment)")
}
```

Modify an entry and write back to the file:
```swift
var stringsFile = try StringsFile(contentsOf: stringsFileUrl)
stringsFile.entries[0].value = "new value"
stringsFile.entries[0].comment = "new comment"
try stringsFile.serializedRepresentation().write(to: stringsFileUrl)
```

## Adding StringsFile as a Dependency
To use the `StringsFile` library in a SwiftPM project,  add the following line to the dependencies in your `Package.swift` file:

```swift
.package(url: "https://github.com/cunningo/StringsFile", .upToNextMinor(from: "0.1.0")),
```

Include `"StringsFile"` as a dependency for your target:

```swift
.target(name: "<target>", dependencies: [
    .product(name: "StringsFile", package: "StringsFile"),
]),
```

Finally, add `import StringsFile` to your source code.

### Source Stability

`StringsFile` is under active development, and source-stability is only guaranteed within minor versions (e.g. between `0.1.0` and `0.1.1`). Use the `upToNextMinor` dependency specification, as indicated above, to avoid potentially source-breaking package updates.

## The `.strings` file format

The `.strings` file format is a subset of the "Open Step Property List" (also known as a "Old NeXT-style property list") format where 
* the top-level object is a dictionary with the opening/closing curly braces omitted
* all the dictionary values are strings

 To our knowledge there exists no byte-level specification of this format, but the [CoreFoundation implementation in the swift-corelibs-foundation project](https://github.com/apple/swift-corelibs-foundation/blob/558c1d526f14544da43fa77292e6d4155325c4b1/CoreFoundation/Parsing.subproj/CFOldStylePList.c) serves as a reference implementation.

### Potential incompatibilities

The `StringsList` library has the following differences in deserializing a `.strings` file, compared to `Foundation`:
* `StringsList` preserves all entries, even those with duplicate keys, in order of occurrence in the file.
* `StringsList` strictly validates the unicode encoding. Upon detecting an invalid encoding sequence, an error is thrown, rather than replacing the invalid sequence with the replacement character `U+FFFD`.
* `StringsList` throws an error upon encountering an invalid construct that follows a valid entry, rather than silently stopping parsing at that point and returning a partial result.
  - `Foundation` has infamous bug where an extra semicolon after an entry, for example `"key" = "value";;`, causes all subsequent entries in the file to be ignored.
* `StringsList` throws an error upon encountering an octal escape sequences on the form `\111`. In `Foundation` the value is interpreted as a character in the "NextStep/OpenStep" character set.

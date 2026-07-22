import Foundation

/// Hand-rolled, Foundation-only RTF plain-text extractor (ADR-017) — no
/// compression involved (RTF is already plain ASCII-safe text), just enough
/// of the control-word grammar to strip formatting: groups `{}`, control
/// words `\foo123`, control symbols `\X` (single non-letter), `\'hh` hex
/// escapes, and the handful of non-visible-text destination groups
/// (`\fonttbl`, `\colortbl`, `\stylesheet`, `\info`, `\*...` "ignorable"
/// destinations) whose content must be skipped rather than emitted as text.
///
/// **Scope cut:** treats `\'hh` bytes as Windows-1252/Latin-1 (RTF's
/// historical default codepage) rather than implementing full `\ansicpg`/
/// Unicode `\uN` codepage negotiation — correct for the plain-ASCII test
/// fixtures and the overwhelmingly common case, documented rather than
/// silently assumed perfect for every RTF producer.
enum RtfTextExtractor {
    private static let nonTextDestinations: Set<String> = [
        "fonttbl", "colortbl", "stylesheet", "info", "generator",
        "pict", "object", "themedata", "colorschememapping"
    ]

    static func extractPlainText(from data: Data) throws -> String {
        guard let scalars = String(data: data, encoding: .isoLatin1)?.unicodeScalars else {
            throw IngestionError.corruptInput(.rtf, reason: "not decodable as Latin-1/ASCII text")
        }
        let chars = Array(scalars)
        guard chars.first == "{" else {
            throw IngestionError.corruptInput(.rtf, reason: "does not start with a group")
        }

        var output = String.UnicodeScalarView()
        var index = 0
        var skipDepth: Int? // group depth at which a non-text destination started, nil = not skipping
        var groupDepth = 0

        while index < chars.count {
            let char = chars[index]
            switch char {
            case "{":
                groupDepth += 1
                index += 1
            case "}":
                if let depth = skipDepth, groupDepth <= depth { skipDepth = nil }
                groupDepth -= 1
                guard groupDepth >= 0 else {
                    throw IngestionError.corruptInput(.rtf, reason: "unbalanced closing brace")
                }
                index += 1
            case "\\":
                index += 1
                guard index < chars.count else {
                    throw IngestionError.corruptInput(.rtf, reason: "truncated control sequence")
                }
                let next = chars[index]
                if next == "'" {
                    index += 1
                    guard index + 2 <= chars.count else {
                        throw IngestionError.corruptInput(.rtf, reason: "truncated \\'hh hex escape")
                    }
                    var hex = ""
                    hex.unicodeScalars.append(chars[index])
                    hex.unicodeScalars.append(chars[index + 1])
                    guard let byte = UInt8(hex, radix: 16) else {
                        throw IngestionError.corruptInput(.rtf, reason: "malformed \\'hh hex escape")
                    }
                    if skipDepth == nil { output.append(Unicode.Scalar(byte)) }
                    index += 2
                } else if next == "\\" || next == "{" || next == "}" {
                    if skipDepth == nil { output.append(next) }
                    index += 1
                } else if CharacterSet.letters.contains(next) {
                    let word = readControlWord(chars, from: &index)
                    if word == "par" || word == "line" {
                        if skipDepth == nil { output.append("\n") }
                    } else if word == "*" {
                        if skipDepth == nil { skipDepth = groupDepth }
                    } else if nonTextDestinations.contains(word), skipDepth == nil {
                        skipDepth = groupDepth
                    }
                    consumeOptionalTrailingSpace(chars, at: &index)
                } else {
                    // Control symbol (single non-letter, non-digit,
                    // non-quote punctuation) - consume and drop, not text.
                    index += 1
                }
            default:
                if skipDepth == nil { output.append(char) }
                index += 1
            }
        }
        guard groupDepth == 0 else {
            throw IngestionError.corruptInput(.rtf, reason: "unbalanced opening brace")
        }
        return collapseWhitespace(String(output))
    }

    /// A control word is letters followed by an optional signed numeric
    /// parameter; a single trailing space (if present) is the word's
    /// delimiter, not text — consumed separately by the caller.
    private static func readControlWord(_ chars: [Unicode.Scalar], from index: inout Int) -> String {
        var word = ""
        while index < chars.count, CharacterSet.letters.contains(chars[index]) {
            word.unicodeScalars.append(chars[index])
            index += 1
        }
        if index < chars.count, chars[index] == "-" {
            index += 1
        }
        while index < chars.count, CharacterSet.decimalDigits.contains(chars[index]) {
            index += 1
        }
        return word
    }

    private static func consumeOptionalTrailingSpace(_ chars: [Unicode.Scalar], at index: inout Int) {
        if index < chars.count, chars[index] == " " {
            index += 1
        }
    }

    private static func collapseWhitespace(_ text: String) -> String {
        text.split(whereSeparator: { $0 == " " || $0 == "\t" })
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

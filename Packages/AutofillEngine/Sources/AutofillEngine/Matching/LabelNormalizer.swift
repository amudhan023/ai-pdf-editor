import Foundation

/// Deterministic label normalization so a form's exact wording ("First
/// Name:", "First  Name", "FIRST NAME*") and a dictionary's curated key
/// ("first name") compare equal. Runs ahead of both the dictionary lookup
/// and the embedding fallback, so both rungs see the same cleaned text.
public enum LabelNormalizer {
    /// Common abbreviations expanded as whole words only (never as a
    /// substring match) — e.g. "addr" -> "address", but "address" itself
    /// is left alone rather than being mangled by a naive substring pass.
    private static let abbreviations: [String: String] = [
        "dob": "date of birth",
        "addr": "address",
        "addr1": "address line 1",
        "addr2": "address line 2",
        "tel": "phone",
        "fname": "first name",
        "lname": "last name",
        "mi": "middle initial",
        "dl": "drivers license"
    ]

    public static func normalize(_ raw: String) -> String {
        let lowered = raw.lowercased()
        let strippedPunctuation = lowered.map { char -> Character in
            char.isLetter || char.isNumber || char.isWhitespace ? char : " "
        }
        let collapsed = String(strippedPunctuation)
            .split(separator: " ", omittingEmptySubsequences: true)
            .joined(separator: " ")
        let expandedWords = collapsed.split(separator: " ").map { word -> String in
            abbreviations[String(word)] ?? String(word)
        }
        return expandedWords.joined(separator: " ")
    }
}

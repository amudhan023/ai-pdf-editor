// Synthetic identity-document data generator (P0-08).
//
// Produces structured JSON records for passports, ID-card-style documents
// ("licenses"), and resumes — NO real PII (Constitution Art. 15). Output is
// deterministic: the same --seed always produces byte-identical JSON, which
// is what Scripts/bench.sh generator-determinism checks.
//
// PDFium is not buildable on this machine yet (tasks/escalations/
// E-004-pdfium-build-infeasible-on-this-machine.md), so this generator
// cannot render a visual PDF/image artifact — see Fixtures/documents/README.md
// for that limitation. It emits the underlying data a renderer would need.
//
// MRZ check digits follow ICAO Doc 9303 (the public passport/travel-document
// standard): weighted mod-10 over weights [7,3,1] cycling, char values
// '0'-'9' = 0-9, 'A'-'Z' = 10-35, '<' = 0. TD3 (passport, 2x44) and TD1
// (ID-card, 3x30) layouts are both implemented per that spec.
//
// Issuing state/nationality is fixed to "UTO" (Utopia), the ICAO-reserved
// fictitious country code used in the standard's own specimen documents —
// an unambiguous signal that these are synthetic, not real, travel documents.
//
// Usage:
//   swift Fixtures/documents/generate.swift --kind passport --count 10 --seed 42 --out <dir>
//   swift Fixtures/documents/generate.swift --kind license  --count 10 --seed 42 --out <dir>
//   swift Fixtures/documents/generate.swift --kind resume   --count 10 --seed 42 --out <dir>

import Foundation

// MARK: - Deterministic PRNG

/// SplitMix64 — a small, well-known, seedable generator. Foundation's
/// SystemRandomNumberGenerator is intentionally not seedable, so it cannot
/// satisfy the determinism requirement (same seed -> same output).
struct SplitMix64: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { self.state = seed }
    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var mixed = state
        mixed = (mixed ^ (mixed >> 30)) &* 0xBF58476D1CE4E5B9
        mixed = (mixed ^ (mixed >> 27)) &* 0x94D049BB133111EB
        return mixed ^ (mixed >> 31)
    }
}

/// Picks a uniformly-random element from a known-non-empty static array
/// without SwiftLint's force_unwrapping rule tripping on `.randomElement()!`
/// (root CLAUDE.md SS4: no force-unwraps outside tests).
func pick<Element>(_ items: [Element], using rng: inout SplitMix64) -> Element {
    items[Int.random(in: 0..<items.count, using: &rng)]
}

/// Replaces (year, month, day) tuples so return/parameter types stay under
/// SwiftLint's 2-member tuple limit.
struct CalendarDate {
    let year: Int
    let month: Int
    let day: Int
}

func isoDate(_ date: CalendarDate) -> String {
    String(format: "%04d-%02d-%02d", date.year, date.month, date.day)
}

func randomDate(_ rng: inout SplitMix64, yearRange: ClosedRange<Int>) -> CalendarDate {
    CalendarDate(
        year: Int.random(in: yearRange, using: &rng),
        month: Int.random(in: 1...12, using: &rng),
        day: Int.random(in: 1...28, using: &rng)
    )
}

// MARK: - MRZ (ICAO 9303)

enum MRZ {
    static func charValue(_ character: Character) -> Int {
        if character == "<" { return 0 }
        if character.isNumber, let digitValue = character.wholeNumberValue { return digitValue }
        if character.isASCII, character.isLetter, let scalarValue = character.uppercased().unicodeScalars.first?.value {
            return Int(scalarValue) - Int(Unicode.Scalar("A").value) + 10
        }
        return 0
    }

    static func checkDigit(_ text: String) -> Int {
        let weights = [7, 3, 1]
        var total = 0
        for (position, character) in text.enumerated() {
            total += charValue(character) * weights[position % 3]
        }
        return total % 10
    }

    /// Uppercases, strips to [A-Z0-9], replaces everything else (spaces,
    /// punctuation) with the MRZ filler character.
    static func sanitize(_ text: String) -> String {
        var out = ""
        for character in text.uppercased() {
            if (character.isLetter && character.isASCII) || character.isNumber { out.append(character) } else { out.append("<") }
        }
        return out
    }

    static func pad(_ text: String, to length: Int) -> String {
        if text.count >= length { return String(text.prefix(length)) }
        return text + String(repeating: "<", count: length - text.count)
    }

    static func dateField(_ date: CalendarDate) -> String {
        String(format: "%02d%02d%02d", date.year % 100, date.month, date.day)
    }

    static func nameField(surname: String, given: String) -> String {
        sanitize(surname) + "<<" + sanitize(given)
    }

    struct TD3Input {
        let surname: String
        let given: String
        let issuingState: String
        let nationality: String
        let sex: String
        let birth: CalendarDate
        let expiry: CalendarDate
        let documentNumber: String
        let personalNumber: String
    }

    struct TD3Output {
        let line1: String
        let line2: String
    }

    /// TD3 — passport, 2 lines x 44 chars.
    static func td3(_ input: TD3Input) -> TD3Output {
        let line1 = pad("P<" + pad(input.issuingState, to: 3) + nameField(surname: input.surname, given: input.given), to: 44)

        let docNum = pad(sanitize(input.documentNumber), to: 9)
        let docCheck = checkDigit(docNum)
        let birthStr = dateField(input.birth)
        let birthCheck = checkDigit(birthStr)
        let expiryStr = dateField(input.expiry)
        let expiryCheck = checkDigit(expiryStr)
        let persNum = pad(sanitize(input.personalNumber), to: 14)
        let persCheck = checkDigit(persNum)

        let composite = docNum + "\(docCheck)" + birthStr + "\(birthCheck)" + expiryStr + "\(expiryCheck)" + persNum + "\(persCheck)"
        let compositeCheck = checkDigit(composite)

        let line2 = docNum + "\(docCheck)" + pad(input.nationality, to: 3)
            + birthStr + "\(birthCheck)" + input.sex + expiryStr + "\(expiryCheck)"
            + persNum + "\(persCheck)" + "\(compositeCheck)"
        return TD3Output(line1: line1, line2: pad(line2, to: 44))
    }

    struct TD1Input {
        let documentCode: String
        let issuingState: String
        let documentNumber: String
        let birth: CalendarDate
        let sex: String
        let expiry: CalendarDate
        let nationality: String
        let surname: String
        let given: String
    }

    struct TD1Output {
        let line1: String
        let line2: String
        let line3: String
    }

    /// TD1 — ID-card-style document, 3 lines x 30 chars. Some countries
    /// print this on national ID cards / ID-card-format driver's licenses;
    /// US state driver's licenses use a PDF417 barcode instead (no MRZ) —
    /// see Fixtures/documents/README.md for why this generator models the
    /// TD1 form rather than a specific US state's barcode encoding.
    static func td1(_ input: TD1Input) -> TD1Output {
        let docNum = pad(sanitize(input.documentNumber), to: 9)
        let docCheck = checkDigit(docNum)
        let opt1 = pad("", to: 15)
        let line1 = pad(input.documentCode, to: 2) + pad(input.issuingState, to: 3) + docNum + "\(docCheck)" + opt1

        let birthStr = dateField(input.birth)
        let birthCheck = checkDigit(birthStr)
        let expiryStr = dateField(input.expiry)
        let expiryCheck = checkDigit(expiryStr)
        let opt2 = pad("", to: 11)

        let composite = docNum + "\(docCheck)" + opt1 + birthStr + "\(birthCheck)" + expiryStr + "\(expiryCheck)" + opt2
        let compositeCheck = checkDigit(composite)

        let line2 = birthStr + "\(birthCheck)" + input.sex + expiryStr + "\(expiryCheck)" + pad(input.nationality, to: 3) + opt2 + "\(compositeCheck)"
        let line3 = pad(nameField(surname: input.surname, given: input.given), to: 30)
        return TD1Output(line1: line1, line2: line2, line3: line3)
    }
}

// MARK: - Synthetic data pools (obviously-fake tokens; Constitution Art. 15)

enum Pool {
    static let givenNames = [
        "Alex", "Jordan", "Morgan", "Riley", "Taylor", "Casey",
        "Drew", "Jamie", "Rowan", "Skyler", "Quinn", "Reese"
    ]
    static let surnames = [
        "Fixtureworth", "Sampleford", "Testley", "Vaultbourne", "Corpusman",
        "Placeholt", "Synthfield", "Mockleton", "Stubwright", "Dummond"
    ]
    static let companies = [
        "Fixture Dynamics", "Sample Industries", "Testware Solutions",
        "Corpus Logistics Co", "Placeholder & Partners", "Synthfield Group"
    ]
    static let schools = ["Sample State University", "Fixture Institute of Technology", "Testcase Community College"]
    static let titles = ["Operations Analyst", "Field Technician", "Program Coordinator", "Data Clerk", "Support Specialist"]
    static let skills = ["Scheduling", "Inventory tracking", "Customer intake", "Report drafting", "Basic bookkeeping", "Equipment maintenance"]
    static let streets = ["Fixture Ln", "Sample Ave", "Testcase Blvd", "Corpus Way", "Placeholder St", "Mock Cir"]
    static let emailDomains = ["example.com", "example.org", "example.net"] // IANA-reserved, RFC 2606

    // NANP reserves 555-0100..555-0199 for fictional use (film/TV/testing).
    static func phone(_ rng: inout SplitMix64) -> String { "555-01\(String(format: "%02d", Int.random(in: 0...99, using: &rng)))" }

    static func email(_ given: String, _ surname: String, _ rng: inout SplitMix64) -> String {
        let domain = pick(emailDomains, using: &rng)
        return "\(given.lowercased()).\(surname.lowercased())@\(domain)"
    }
}

// MARK: - Record models (Codable, deterministic JSON via .sortedKeys)

struct PassportRecord: Codable {
    let recordId: String
    let seed: UInt64
    let givenNames: String
    let surname: String
    let sex: String
    let nationality: String
    let issuingState: String
    let birthDate: String
    let issueDate: String
    let expiryDate: String
    let documentNumber: String
    let mrzLine1: String
    let mrzLine2: String
}

struct LicenseRecord: Codable {
    let recordId: String
    let seed: UInt64
    let givenNames: String
    let surname: String
    let sex: String
    let nationality: String
    let issuingState: String
    let birthDate: String
    let expiryDate: String
    let documentNumber: String
    let mrzLine1: String
    let mrzLine2: String
    let mrzLine3: String
    let formatNote: String
}

struct EmploymentEntry: Codable {
    let company: String
    let title: String
    let startDate: String
    let endDate: String
}

struct ResumeRecord: Codable {
    let recordId: String
    let seed: UInt64
    let fullName: String
    let email: String
    let phone: String
    let addressStreet: String
    let addressCity: String
    let addressState: String
    let addressZip: String
    let school: String
    let graduationYear: Int
    let employment: [EmploymentEntry]
    let skills: [String]
}

// MARK: - Generation

func randomDigits(_ rng: inout SplitMix64, count: Int) -> String {
    (0..<count).map { _ in String(Int.random(in: 0...9, using: &rng)) }.joined()
}

func generatePassport(index: Int, seed: UInt64) -> PassportRecord {
    var rng = SplitMix64(seed: seed &+ UInt64(index))
    let given = pick(Pool.givenNames, using: &rng)
    let surname = pick(Pool.surnames, using: &rng)
    let sex = pick(["M", "F"], using: &rng)
    let birth = randomDate(&rng, yearRange: 1955...2005)
    let issue = randomDate(&rng, yearRange: 2018...2024)
    let expiry = CalendarDate(year: issue.year + 10, month: issue.month, day: issue.day)
    let docNumber = "P" + randomDigits(&rng, count: 8)

    let mrz = MRZ.td3(MRZ.TD3Input(
        surname: surname, given: given, issuingState: "UTO", nationality: "UTO",
        sex: sex, birth: birth, expiry: expiry, documentNumber: docNumber, personalNumber: ""
    ))

    return PassportRecord(
        recordId: String(format: "passport-%04d", index),
        seed: seed,
        givenNames: given,
        surname: surname,
        sex: sex,
        nationality: "UTO",
        issuingState: "UTO",
        birthDate: isoDate(birth),
        issueDate: isoDate(issue),
        expiryDate: isoDate(expiry),
        documentNumber: docNumber,
        mrzLine1: mrz.line1,
        mrzLine2: mrz.line2
    )
}

func generateLicense(index: Int, seed: UInt64) -> LicenseRecord {
    var rng = SplitMix64(seed: seed &+ UInt64(index) &+ 0x1000)
    let given = pick(Pool.givenNames, using: &rng)
    let surname = pick(Pool.surnames, using: &rng)
    let sex = pick(["M", "F"], using: &rng)
    let birth = randomDate(&rng, yearRange: 1955...2007)
    let issue = randomDate(&rng, yearRange: 2020...2024)
    let expiry = CalendarDate(year: issue.year + 5, month: issue.month, day: issue.day)
    let docNumber = "L" + randomDigits(&rng, count: 8)

    let mrz = MRZ.td1(MRZ.TD1Input(
        documentCode: "ID", issuingState: "UTO", documentNumber: docNumber,
        birth: birth, sex: sex, expiry: expiry, nationality: "UTO",
        surname: surname, given: given
    ))

    let format = "Modeled as an ICAO TD1 MRZ-bearing ID-card document, not a specific "
        + "US state's PDF417-barcode driver's license (no MRZ) — see Fixtures/documents/README.md."

    return LicenseRecord(
        recordId: String(format: "license-%04d", index),
        seed: seed,
        givenNames: given,
        surname: surname,
        sex: sex,
        nationality: "UTO",
        issuingState: "UTO",
        birthDate: isoDate(birth),
        expiryDate: isoDate(expiry),
        documentNumber: docNumber,
        mrzLine1: mrz.line1,
        mrzLine2: mrz.line2,
        mrzLine3: mrz.line3,
        formatNote: format
    )
}

func generateResume(index: Int, seed: UInt64) -> ResumeRecord {
    var rng = SplitMix64(seed: seed &+ UInt64(index) &+ 0x2000)
    let given = pick(Pool.givenNames, using: &rng)
    let surname = pick(Pool.surnames, using: &rng)
    let street = pick(Pool.streets, using: &rng)
    let houseNumber = Int.random(in: 100...9999, using: &rng)
    let zipCode = String(format: "%05d", Int.random(in: 10000...99998, using: &rng))
    let school = pick(Pool.schools, using: &rng)
    let graduationYear = Int.random(in: 1990...2023, using: &rng)

    var employment: [EmploymentEntry] = []
    let jobCount = Int.random(in: 1...3, using: &rng)
    var yearCursor = graduationYear
    for _ in 0..<jobCount {
        let company = pick(Pool.companies, using: &rng)
        let title = pick(Pool.titles, using: &rng)
        let startYear = yearCursor
        let duration = Int.random(in: 1...4, using: &rng)
        let endYear = startYear + duration
        employment.append(EmploymentEntry(company: company, title: title,
                                           startDate: "\(startYear)-01", endDate: "\(endYear)-01"))
        yearCursor = endYear
    }

    let skillCount = Int.random(in: 2...4, using: &rng)
    let skills = Array(Pool.skills.shuffled(using: &rng).prefix(skillCount))

    return ResumeRecord(
        recordId: String(format: "resume-%04d", index),
        seed: seed,
        fullName: "\(given) \(surname)",
        email: Pool.email(given, surname, &rng),
        phone: Pool.phone(&rng),
        addressStreet: "\(houseNumber) \(street)",
        addressCity: "Sampleton",
        addressState: "XX",
        addressZip: zipCode,
        school: school,
        graduationYear: graduationYear,
        employment: employment,
        skills: skills
    )
}

// MARK: - CLI

struct CLIOptions {
    let kind: String
    let count: Int
    let seed: UInt64
    let out: String
}

func parseArgs() -> CLIOptions {
    var kind = "passport"
    var count = 10
    var seed: UInt64 = 42
    var out = "."
    var arguments = CommandLine.arguments.dropFirst().makeIterator()
    while let argument = arguments.next() {
        switch argument {
        case "--kind": kind = arguments.next() ?? kind
        case "--count": count = Int(arguments.next() ?? "") ?? count
        case "--seed": seed = UInt64(arguments.next() ?? "") ?? seed
        case "--out": out = arguments.next() ?? out
        default: break
        }
    }
    return CLIOptions(kind: kind, count: count, seed: seed, out: out)
}

func writeJSON<Value: Encodable>(_ value: Value, to path: String) throws {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys, .prettyPrinted]
    let data = try encoder.encode(value)
    try data.write(to: URL(fileURLWithPath: path))
}

func run() throws {
    let options = parseArgs()
    try FileManager.default.createDirectory(atPath: options.out, withIntermediateDirectories: true)

    switch options.kind {
    case "passport":
        for index in 1...options.count {
            let record = generatePassport(index: index, seed: options.seed)
            try writeJSON(record, to: "\(options.out)/\(record.recordId).json")
        }
    case "license":
        for index in 1...options.count {
            let record = generateLicense(index: index, seed: options.seed)
            try writeJSON(record, to: "\(options.out)/\(record.recordId).json")
        }
    case "resume":
        for index in 1...options.count {
            let record = generateResume(index: index, seed: options.seed)
            try writeJSON(record, to: "\(options.out)/\(record.recordId).json")
        }
    default:
        FileHandle.standardError.write(Data("unknown --kind '\(options.kind)' (expected passport|license|resume)\n".utf8))
        exit(2)
    }
    print("generate.swift: wrote \(options.count) \(options.kind) record(s) to \(options.out) (seed=\(options.seed))")
}

try run()

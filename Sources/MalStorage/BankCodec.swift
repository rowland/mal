import Foundation
import MalCore
import Yams

public struct ValidationFailure: Error, LocalizedError {
    public let problems: [String]
    public var errorDescription: String? { problems.joined(separator: "\n") }
    public init(_ problems: [String]) { self.problems = problems }
}
public enum BankCodec {
    public static func decode(_ text: String, allowBuiltIn: Bool = false) throws -> Bank {
        guard text.utf8.count <= 20_000_000 else { throw ValidationFailure(["Bank exceeds 20 MB."]) }
        let bank = try YAMLDecoder().decode(Bank.self, from: text)
        let errors = validate(bank, allowBuiltIn: allowBuiltIn)
        guard errors.isEmpty else { throw ValidationFailure(errors) }
        return bank
    }
    public static func validate(_ bank: Bank, allowBuiltIn: Bool = false) -> [String] {
        var errors: [String] = []
        func require(_ valid: Bool, _ message: String) { if !valid { errors.append(message) } }
        let idPattern = #"^[a-zA-Z0-9][a-zA-Z0-9._-]*$"#
        require(bank.schemaVersion == 1, "Unsupported schemaVersion: \(bank.schemaVersion)")
        require(bank.contentVersion > 0, "contentVersion must be positive.")
        require(bank.id.range(of: idPattern, options: .regularExpression) != nil, "Invalid bank ID.")
        require(allowBuiltIn || !bank.id.hasPrefix("mal."), "The mal. namespace is reserved for built-in banks.")
        require(!bank.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, "Bank title is required.")
        require(!bank.provenance.source.isEmpty && !bank.provenance.license.isEmpty, "Source and license are required.")
        require(!bank.entries.isEmpty, "Bank must contain entries.")
        var ids = Set<String>()
        for entry in bank.entries {
            let prefix = "Entry \(entry.id): "
            require(ids.insert(entry.id).inserted, prefix + "duplicate ID.")
            require(entry.id.hasPrefix(bank.id + ".") && entry.id.range(of: idPattern, options: .regularExpression) != nil, prefix + "ID must be namespaced under \(bank.id).")
            require(!entry.lemma.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, prefix + "lemma is required.")
            require(!entry.english.isEmpty && entry.english.allSatisfy { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }, prefix + "English meanings must be nonempty.")
            require(entry.koreanForms.allSatisfy { !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }, prefix + "Korean forms must be nonempty.")
            require(["draft", "checked", "verified"].contains(entry.verification), prefix + "verification must be draft, checked, or verified.")
        }
        return errors
    }
}

import Foundation
import MalCore
import MalStorage

@main struct BankValidator {
    static func main() {
        let args = Array(CommandLine.arguments.dropFirst())
        let paths = args.filter { !$0.hasPrefix("--") }
        guard !paths.isEmpty else { print("Usage: mal-bank [--built-in] [--release] file.yaml …"); exit(2) }
        var failed = false
        var ids = Set<String>()
        for path in paths {
            do {
                let bank = try BankCodec.decode(String(contentsOfFile: path, encoding: .utf8), allowBuiltIn: args.contains("--built-in"))
                for entry in bank.entries where !ids.insert(entry.id).inserted { throw ValidationFailure(["Duplicate cross-bank ID: \(entry.id)"]) }
                let pending = bank.entries.filter { $0.verification != "verified" }.count
                if args.contains("--release") && (bank.entries.count != 500 || pending != 0) { throw ValidationFailure(["Release requires 500 verified entries; found \(bank.entries.count) entries, \(pending) awaiting verification."]) }
                print("\(bank.title): \(bank.entries.count) entries; \(pending) awaiting independent verification. Valid YAML v1.")
            } catch { failed = true; print("\(path): \(error.localizedDescription)") }
        }
        if failed { exit(1) }
    }
}

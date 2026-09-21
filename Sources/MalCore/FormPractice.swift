import Foundation

public enum KoreanPracticeStyle: String, Codable, CaseIterable, Sendable {
    case dictionary, casual, polite, formalPolite, plain, attributive, honorificPolite, honorificFormal
    public var label: String {
        switch self {
        case .dictionary: "Dictionary / any answer"
        case .casual: "Casual · 해체"
        case .polite: "Everyday polite · 해요체"
        case .formalPolite: "Formal polite · 합니다체"
        case .plain: "Plain statement · 해라체"
        case .attributive: "Noun-modifying"
        case .honorificPolite: "Polite + subject honorific"
        case .honorificFormal: "Formal + subject honorific"
        }
    }
    public var explanation: String {
        switch self {
        case .dictionary: "Vocabulary practice: all listed Korean forms are accepted."
        case .attributive: "Use the present noun-modifying form, as before a noun."
        case .honorificPolite, .honorificFormal: "Present affirmative form honoring the subject, not merely speaking politely to the listener."
        default: "Present affirmative form. Write-in answers must match this style."
        }
    }
}

public enum FormPractice {
    public static func canRememberAlias(_ entry: Entry, direction: Direction, style: KoreanPracticeStyle) -> Bool {
        direction == .koreanToEnglish || style == .dictionary || !applies(entry, style: style)
    }
    public static func applies(_ entry: Entry, style: KoreanPracticeStyle) -> Bool {
        entry.partOfSpeech == .verb || entry.partOfSpeech == .adjective ||
        (style == .attributive && entry.koreanForms.contains { $0.attributive == true })
    }
    public static func forms(_ entry: Entry, style: KoreanPracticeStyle) -> [String] {
        guard style != .dictionary, applies(entry, style: style) else { return [entry.lemma] }
        var seen = Set<String>()
        return entry.koreanForms.filter { form in
            let honorific = form.honorific == true
            switch style {
            case .dictionary: return false
            case .attributive: return form.attributive == true && !honorific
            case .casual: return form.attributive != true && !honorific && form.speechLevel == "informal"
            case .polite: return form.attributive != true && !honorific && form.speechLevel == "informal-polite"
            case .formalPolite: return form.attributive != true && !honorific && form.speechLevel == "formal-polite"
            case .plain: return form.attributive != true && !honorific && form.speechLevel == "formal"
            case .honorificPolite: return form.attributive != true && honorific && form.speechLevel == "informal-polite"
            case .honorificFormal: return form.attributive != true && honorific && form.speechLevel == "formal-polite"
            }
        }.map { $0.text.precomposedStringWithCanonicalMapping }.filter { seen.insert($0).inserted }
    }
    public static func key(_ entry: Entry, direction: Direction, mode: AnswerMode, style: KoreanPracticeStyle) -> CardKey {
        CardKey(entry.id, direction, mode, formStyle: style != .dictionary && applies(entry, style: style) ? style : nil)
    }
    public static func accepted(_ entry: Entry, direction: Direction, style: KoreanPracticeStyle, pool: [Entry], displayedKorean: String? = nil, aliases: [String: [String]] = [:]) -> Set<String> {
        if direction == .englishToKorean {
            func meaning(_ value: String, for sense: Entry) -> String {
                let normalized = Grader.normalize(value, direction: .koreanToEnglish)
                return sense.partOfSpeech == .adjective && normalized.hasPrefix("be ") ? String(normalized.dropFirst(3)) : normalized
            }
            let promptMeaning = meaning(entry.english.first ?? "", for: entry)
            let cue = Grader.normalize(entry.promptCue ?? "", direction: .koreanToEnglish)
            let equivalents = pool.filter { candidate in
                (cue.isEmpty || candidate.partOfSpeech == entry.partOfSpeech) &&
                Grader.normalize(candidate.promptCue ?? "", direction: .koreanToEnglish) == cue &&
                Grader.accepted(candidate, direction: .koreanToEnglish, optionalEnglishHints: false).contains { meaning($0, for: candidate) == promptMeaning }
            }
            return (equivalents + [entry]).reduce(into: Set<String>()) { result, candidate in
                if style != .dictionary && applies(candidate, style: style) {
                    // Unlabelled personal aliases cannot establish a requested conjugation.
                    result.formUnion(forms(candidate, style: style).map { Grader.normalize($0, direction: direction) })
                } else {
                    result.formUnion(Grader.accepted(candidate, direction: direction, aliases: aliases[candidate.id] ?? []))
                }
            }
        }
        var accepted = Grader.promptAnswers(entry, direction: direction, pool: pool, aliases: aliases)
        if direction == .koreanToEnglish {
            let displayed = Grader.normalize(displayedKorean ?? forms(entry, style: style).first ?? entry.lemma, direction: .englishToKorean)
            for candidate in pool where candidate.partOfSpeech == entry.partOfSpeech {
                if forms(candidate, style: style).contains(where: { Grader.normalize($0, direction: .englishToKorean) == displayed }) {
                    accepted.formUnion(Grader.accepted(candidate, direction: direction, aliases: aliases[candidate.id] ?? []))
                }
            }
        }
        return accepted
    }
    public static func displayForms<R: RandomNumberGenerator>(_ entries: [Entry], style: KoreanPracticeStyle, using random: inout R) -> [String: String] {
        Dictionary(uniqueKeysWithValues: entries.compactMap { entry in
            forms(entry, style: style).randomElement(using: &random).map { (entry.id, $0) }
        })
    }
}

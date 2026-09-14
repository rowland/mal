import Foundation

public enum Grader {
    public static func normalize(_ text: String, direction: Direction) -> String {
        let value = text.precomposedStringWithCanonicalMapping.trimmingCharacters(in: .whitespacesAndNewlines)
        return direction == .koreanToEnglish ? value.lowercased(with: Locale(identifier: "en_US_POSIX")) : value
    }
    public static func accepted(_ entry: Entry, direction: Direction, aliases: [String] = []) -> Set<String> {
        let values = direction == .englishToKorean ? [entry.lemma] + entry.koreanForms.map(\.text) : entry.english
        return Set((values + aliases).map { normalize($0, direction: direction) })
    }
    // With no sense cue, all catalogued meanings of the displayed lemma/POS are valid.
    public static func promptAnswers(_ entry: Entry, direction: Direction, pool: [Entry], aliases: [String: [String]] = [:]) -> Set<String> {
        let senses = direction == .koreanToEnglish ? pool.filter {
            $0.lemma.precomposedStringWithCanonicalMapping == entry.lemma.precomposedStringWithCanonicalMapping && $0.partOfSpeech == entry.partOfSpeech
        } : []
        return (senses + [entry]).reduce(into: Set<String>()) { result, sense in
            result.formUnion(accepted(sense, direction: direction, aliases: aliases[sense.id] ?? []))
        }
    }
    public static func isCorrect(_ answer: String, entry: Entry, direction: Direction, aliases: [String] = []) -> Bool {
        accepted(entry, direction: direction, aliases: aliases).contains(normalize(answer, direction: direction))
    }
}
public enum ChoiceBuilder {
    public static func choices<R: RandomNumberGenerator>(target: Entry, pool: [Entry], direction: Direction, count: Int, sensePool: [Entry]? = nil, aliases: [String: [String]] = [:], using random: inout R) -> [String] {
        let targetAnswers = Grader.promptAnswers(target, direction: direction, pool: sensePool ?? pool, aliases: aliases)
        // Exclude equivalent senses in either language, even when their preferred gloss differs.
        let targetEnglish = Grader.accepted(target, direction: .koreanToEnglish)
        let targetKorean = Grader.accepted(target, direction: .englishToKorean)
        let candidates = pool.filter { entry in
            entry.id != target.id &&
            targetAnswers.isDisjoint(with: Grader.accepted(entry, direction: direction, aliases: aliases[entry.id] ?? [])) &&
            targetEnglish.isDisjoint(with: Grader.accepted(entry, direction: .koreanToEnglish)) &&
            targetKorean.isDisjoint(with: Grader.accepted(entry, direction: .englishToKorean))
        }
        let preferred = candidates.filter { $0.partOfSpeech == target.partOfSpeech }.shuffled(using: &random)
        let others = candidates.filter { $0.partOfSpeech != target.partOfSpeech }.shuffled(using: &random)
        var result = [target.answer(direction)]
        var seen = Set(result.map { Grader.normalize($0, direction: direction) })
        for entry in preferred + others where result.count < max(2, count) {
            let value = entry.answer(direction)
            if seen.insert(Grader.normalize(value, direction: direction)).inserted { result.append(value) }
        }
        return result.shuffled(using: &random)
    }
}
public enum Scheduler {
    public static func grade(_ prior: LearningState, correct: Bool, mode: AnswerMode, now: Date, sequence: Int) -> LearningState {
        var state = prior
        state.recent = Array((state.recent + [correct]).suffix(20))
        if correct { state.totalCorrect += 1 } else { state.totalWrong += 1 }
        state.retryAfterSequence = 0
        if !correct {
            state.step = 0
            if state.phase == .review || state.phase == .relearning {
                state.phase = .relearning; state.due = now.addingTimeInterval(600)
            } else {
                state.due = now.addingTimeInterval(60); state.retryAfterSequence = sequence + 3
            }
            return state
        }
        switch state.phase {
        case .learning:
            state.step += 1
            if state.step >= 3 { state.phase = .review; state.graduated = true; state.interval = 3 * 86400; state.due = now.addingTimeInterval(state.interval) }
            else { state.due = now.addingTimeInterval(state.step == 1 ? 600 : 86400) }
        case .relearning:
            state.step += 1
            if state.step >= 2 { state.phase = .review; state.interval = 3 * 86400; state.due = now.addingTimeInterval(state.interval) }
            else { state.due = now.addingTimeInterval(86400) }
        case .review:
            let accuracy = Double(state.recent.filter { $0 }.count + 1) / Double(state.recent.count + 2)
            let multiplier = mode == .writeIn ? 1.5 + accuracy : 1.2 + 0.5 * accuracy
            state.interval = min(365 * 86400, max(86400, state.interval * multiplier))
            state.due = now.addingTimeInterval(state.interval)
        }
        return state
    }
}
public enum StudyQueue {
    public static func select(entries: [Entry], states: [CardKey: LearningState], settings: StudySettings, context: QueueContext, activeEntryIDs: Set<String>? = nil) -> Selection? {
        let key: (Entry) -> CardKey = { CardKey($0.id, settings.direction, settings.mode) }
        let eligible = entries.filter { settings.parts.contains($0.partOfSpeech) && $0.id != context.previousSense }
        // Count the entire mode/direction pool, including filtered and deselected banks.
        let active = states.filter { $0.key.direction == settings.direction && $0.key.mode == settings.mode && $0.value.phase != .review && (activeEntryIDs?.contains($0.key.entryID) ?? true) }.count
        let due = eligible.filter { states[key($0)].map { $0.due <= context.now } ?? false }.sorted {
            let a = states[key($0)]!, b = states[key($1)]!
            let rank: (LearningState) -> Int = { $0.phase == .relearning ? 0 : $0.phase == .review ? 1 : 2 }
            if rank(a) != rank(b) { return rank(a) < rank(b) }
            return a.due == b.due ? $0.id < $1.id : a.due < b.due
        }
        let ready = due.filter { states[key($0)]!.retryAfterSequence <= context.sequence }
        var unseen = eligible.filter { states[key($0)] == nil }
        if settings.mode == .writeIn {
            unseen = unseen.enumerated().sorted { a, b in
                let recognizedA = states[CardKey(a.element.id, settings.direction, .multipleChoice)]?.graduated == true
                let recognizedB = states[CardKey(b.element.id, settings.direction, .multipleChoice)]?.graduated == true
                return recognizedA == recognizedB ? a.offset < b.offset : recognizedA
            }.map(\.element)
        }
        // The pool target controls mixing, never blocks continuous study.
        // When no review is ready, introduce unseen vocabulary even above target.
        if let new = unseen.first, ready.isEmpty || (active < settings.learningLimit && context.answersSinceIntroduction >= 5) {
            return Selection(new.id, isNew: true)
        }
        if let next = ready.first { return Selection(next.id, isNew: false) }
        // Intervening cards are unavailable; the minimum retry time still applies.
        if let next = due.first { return Selection(next.id, isNew: false) }
        return nil
    }
}

public enum InputRules {
    public static func shouldSubmit(composingAtKeyDown: Bool, currentlyComposing: Bool, isRepeat: Bool) -> Bool {
        !composingAtKeyDown && !currentlyComposing && !isRepeat
    }
}

extension InputRules {
    public static func ignoreRepeatedStudyKey(isRepeat: Bool, modified: Bool, key: String, multipleChoice: Bool, waitingForContinue: Bool) -> Bool {
        guard isRepeat, !modified else { return false }
        if key == "\r" || key == "\n" { return waitingForContinue || multipleChoice }
        return multipleChoice && key.count == 1 && "0123456789".contains(key)
    }
}

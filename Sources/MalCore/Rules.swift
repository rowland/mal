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
    public static func choices<R: RandomNumberGenerator>(target: Entry, pool: [Entry], direction: Direction, count: Int, koreanAnswers: [String: String] = [:], acceptedAnswers: Set<String>? = nil, sensePool: [Entry]? = nil, aliases: [String: [String]] = [:], using random: inout R) -> [String] {
        let targetAnswers = acceptedAnswers ?? Grader.promptAnswers(target, direction: direction, pool: sensePool ?? pool, aliases: aliases)
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
        var result = [direction == .englishToKorean ? (koreanAnswers[target.id] ?? target.lemma) : target.answer(direction)]
        var seen = Set(result.map { Grader.normalize($0, direction: direction) })
        for entry in preferred + others where result.count < max(2, count) {
            let value = direction == .englishToKorean ? (koreanAnswers[entry.id] ?? entry.lemma) : entry.answer(direction)
            if seen.insert(Grader.normalize(value, direction: direction)).inserted { result.append(value) }
        }
        return result.shuffled(using: &random)
    }
}
public enum Scheduler {
    public static let learningTimes: [TimeInterval] = [60, 300, 1200, 21600, 86400]
    public static let learningAnswers = [3, 8, 20, 50, 100]
    public static func isDue(_ state: LearningState, now: Date, sequence: Int) -> Bool {
        state.due <= now || state.dueSequence.map { sequence >= $0 } == true
    }
    public static func upgrade(_ prior: LearningState, sequence: Int) -> LearningState {
        guard prior.scheduleVersion != 3 else { return prior }
        var state = prior
        if state.phase == .learning {
            state.step = state.step >= 2 ? 4 : state.step
        }
        state.answerInterval = state.phase == .maintenance ? 200 : state.phase == .relearning ? 3 : learningAnswers[max(0, min(4, state.step - 1))]
        state.dueSequence = sequence + state.answerInterval!
        state.reinforceAfterSequence = nil; state.retryAfterSequence = 0
        state.scheduleVersion = 3; state.graduated = state.phase == .maintenance
        return state
    }
    public static func grade(_ prior: LearningState, correct: Bool, mode: AnswerMode, now: Date, sequence: Int, introducedCount: Int = 0) -> LearningState {
        var state = upgrade(prior, sequence: sequence - 1)
        state.recent = Array((state.recent + [correct]).suffix(20))
        if correct { state.totalCorrect += 1 } else { state.totalWrong += 1 }
        state.lastAnsweredSequence = sequence
        func schedule(_ seconds: TimeInterval, _ answers: Int) {
            state.due = now.addingTimeInterval(seconds)
            state.dueSequence = sequence + answers
            state.answerInterval = answers
        }
        if !correct {
            if state.phase == .maintenance {
                state.lapseTimeInterval = state.interval
                state.lapseAnswerInterval = state.answerInterval
                state.phase = .relearning; state.step = 0
            } else if state.phase == .relearning { state.step = 0 }
            else { state.step = max(0, state.step - 2) }
            state.graduated = false
            schedule(30, 3)
            return state
        }
        switch state.phase {
        case .learning:
            state.step += 1
            if state.step >= 6 {
                state.phase = .maintenance; state.graduated = true; state.interval = 3 * 86400
                schedule(state.interval, 200)
            } else { schedule(learningTimes[state.step - 1], learningAnswers[state.step - 1]) }
        case .relearning:
            state.step += 1
            if state.step == 1 { schedule(300, 8) }
            else if state.step == 2 { schedule(1200, 20) }
            else {
                state.phase = .maintenance; state.graduated = true
                state.interval = min(180 * 86400, max(86400, (state.lapseTimeInterval ?? state.interval) / 2))
                schedule(state.interval, max(50, Int(ceil(Double(state.lapseAnswerInterval ?? 200) / 2))))
                state.lapseTimeInterval = nil; state.lapseAnswerInterval = nil
            }
        case .maintenance:
            let accuracy = Double(state.recent.filter { $0 }.count + 1) / Double(state.recent.count + 2)
            let multiplier = mode == .writeIn ? 1.5 + accuracy : 1.2 + 0.5 * accuracy
            state.interval = min(180 * 86400, max(86400, state.interval * multiplier))
            let answers = min(max(1000, 4 * introducedCount), Int(ceil(Double(state.answerInterval ?? 200) * multiplier)))
            schedule(state.interval, answers)
        }
        return state
    }
}
public enum StudyQueue {
    public static func select(entries: [Entry], states: [CardKey: LearningState], settings: StudySettings, context: QueueContext, activeEntryIDs: Set<String>? = nil, activeEntries: [Entry]? = nil) -> Selection? {
        let style = settings.formStyle ?? .dictionary
        let key: (Entry) -> CardKey = { FormPractice.key($0, direction: settings.direction, mode: settings.mode, style: style) }
        let candidates = entries.filter { settings.parts.contains($0.partOfSpeech) && !FormPractice.forms($0, style: style).isEmpty }
        let eligible = candidates.count > 1 ? candidates.filter { $0.id != context.previousSense } : candidates
        let activeKeys = Set(entries.filter { settings.parts.contains($0.partOfSpeech) }.map(key))
        let awaiting = states.filter { activeKeys.contains($0.key) && $0.value.phase == .learning && $0.value.step <= 1 && $0.value.totalCorrect + $0.value.totalWrong > 0 && (activeEntryIDs?.contains($0.key.entryID) ?? true) }
        let firstLimit = max(1, settings.firstRepeatLimit ?? 4)
        func count(_ entry: Entry, _ state: LearningState) -> Int {
            context.trackSequences.map { $0[state.clockTrackID ?? key(entry).trackID, default: 0] } ?? context.sequence
        }
        let ready = eligible.filter { entry in
            states[key(entry)].map { Scheduler.isDue($0, now: context.now, sequence: count(entry, $0)) } ?? false
        }.sorted {
            let a = states[key($0)]!, b = states[key($1)]!
            let rank: (LearningState) -> Int = { $0.phase == .relearning ? 0 : $0.phase == .maintenance ? 1 : 2 }
            if rank(a) != rank(b) { return rank(a) < rank(b) }
            let overdueA = max(context.now.timeIntervalSince(a.due) / max(30, a.interval), Double(count($0, a) - (a.dueSequence ?? Int.max)) / Double(max(1, a.answerInterval ?? 1)))
            let overdueB = max(context.now.timeIntervalSince(b.due) / max(30, b.interval), Double(count($1, b) - (b.dueSequence ?? Int.max)) / Double(max(1, b.answerInterval ?? 1)))
            return overdueA == overdueB ? $0.id < $1.id : overdueA > overdueB
        }
        var unseen = eligible.filter { states[key($0)] == nil }
        if settings.mode == .writeIn {
            unseen = unseen.enumerated().sorted { a, b in
                let recognizedA = states[FormPractice.key(a.element, direction: settings.direction, mode: .multipleChoice, style: style)]?.phase == .maintenance
                let recognizedB = states[FormPractice.key(b.element, direction: settings.direction, mode: .multipleChoice, style: style)]?.phase == .maintenance
                return recognizedA == recognizedB ? a.offset < b.offset : recognizedA
            }.map(\.element)
        }
        if let new = unseen.first, awaiting.count < firstLimit,
           ready.isEmpty || context.answersSinceIntroduction >= 5 {
            return Selection(new.id, isNew: true)
        }
        if let next = ready.first { return Selection(next.id, isNew: false) }
        if awaiting.count >= firstLimit || unseen.isEmpty {
            let pending = eligible.filter { awaiting[key($0)] != nil }.min {
                let a = states[key($0)]!, b = states[key($1)]!
                return (a.lastAnsweredSequence ?? 0) == (b.lastAnsweredSequence ?? 0) ? $0.id < $1.id : (a.lastAnsweredSequence ?? 0) < (b.lastAnsweredSequence ?? 0)
            }
            if let pending { return Selection(pending.id, isNew: false) }
        }
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

public enum PronunciationRules {
    public static func automaticSequence(enabled: Bool, direction: Direction, lemma: String, submittedAnswer: String? = nil, correct: Bool? = nil) -> [String] {
        guard let text = automaticText(enabled: enabled, direction: direction, lemma: lemma, submittedAnswer: submittedAnswer) else { return [] }
        if direction == .englishToKorean, correct == false {
            let question = text.trimmingCharacters(in: CharacterSet(charactersIn: "?!？！.。")) + "?"
            return [question, lemma]
        }
        return [text]
    }

    public static func automaticText(enabled: Bool, direction: Direction, lemma: String, submittedAnswer: String? = nil) -> String? {
        guard enabled else { return nil }
        if direction == .koreanToEnglish { return submittedAnswer == nil ? lemma : nil }
        guard let answer = submittedAnswer?.trimmingCharacters(in: .whitespacesAndNewlines), !answer.isEmpty else { return nil }
        return answer
    }
}

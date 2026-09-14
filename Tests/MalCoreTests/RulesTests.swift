import Foundation
import Testing
@testable import MalCore

private let epoch = Date(timeIntervalSince1970: 1_800_000_000)
private func entry(_ id: String, _ lemma: String, _ english: String, _ pos: PartOfSpeech = .noun) -> Entry {
    Entry(id: id, lemma: lemma, partOfSpeech: pos, english: [english], verification: "checked")
}
private let red = Entry(id: "red", lemma: "빨갛다", partOfSpeech: .adjective, english: ["red", "be red"], koreanForms: [KoreanForm("빨간", attributive: true), KoreanForm("빨개"), KoreanForm("빨개요"), KoreanForm("빨갛습니다"), KoreanForm("빨가세요", honorific: true)])
private struct Seeded: RandomNumberGenerator {
    var state: UInt64 = 42
    mutating func next() -> UInt64 { state = state &* 6364136223846793005 &+ 1442695040888963407; return state }
}
@Test func koreanFormsAndStrictness() {
    for answer in ["빨갛다", "빨간", "빨개", "빨개요", "빨갛습니다", " 빨개요\n", "빨개요".decomposedStringWithCanonicalMapping] {
        #expect(Grader.isCorrect(answer, entry: red, direction: .englishToKorean))
    }
    for answer in ["빨갰다", "안 빨개요", "빨갛요", "빨개 요", "red", ""] {
        #expect(!Grader.isCorrect(answer, entry: red, direction: .englishToKorean))
    }
    #expect(Grader.isCorrect(" RED ", entry: red, direction: .koreanToEnglish))
    #expect(!Grader.isCorrect("reddish", entry: red, direction: .koreanToEnglish))
    #expect(Grader.isCorrect("붉다", entry: red, direction: .englishToKorean, aliases: ["붉다"]))
}
@Test(arguments: [4, 5, 6, 8, 10]) func requestedChoices(_ count: Int) {
    let pool = (0..<30).map { entry("\($0)", "단어\($0)", "word \($0)") }
    var rng = Seeded()
    let values = ChoiceBuilder.choices(target: pool[0], pool: pool, direction: .englishToKorean, count: count, using: &rng)
    #expect(values.count == count)
    #expect(Set(values).count == count)
    #expect(values.contains(pool[0].lemma))
    // No states are supplied: every unused word is a viable distractor.
}
@Test func excludesSynonymsBothDirectionsAndPrefersPartOfSpeech() {
    let synonym = Entry(id: "crimson", lemma: "붉다", partOfSpeech: .adjective, english: ["crimson", "red"])
    let white = entry("white", "하얗다", "white", .adjective)
    let blue = entry("blue", "파랗다", "blue", .adjective)
    let dog = entry("dog", "개", "dog")
    var rng = Seeded()
    for direction in Direction.allCases {
        let values = ChoiceBuilder.choices(target: red, pool: [red, synonym, white, blue, dog], direction: direction, count: 3, using: &rng)
        #expect(Set(values) == Set([red.answer(direction), white.answer(direction), blue.answer(direction)]))
    }
    let duplicate = entry("white2", "하얗다", "white")
    #expect(ChoiceBuilder.choices(target: red, pool: [red, white, duplicate], direction: .englishToKorean, count: 8, using: &rng).count == 2)
    #expect(ChoiceBuilder.choices(target: red, pool: [red, synonym], direction: .englishToKorean, count: 8, using: &rng) == [red.lemma])
}
@Test func personalAliasesExcludeDistractors() {
    let other = entry("other", "붉다", "crimson", .adjective)
    var rng = Seeded()
    #expect(ChoiceBuilder.choices(target: red, pool: [red, other], direction: .englishToKorean, count: 8, aliases: [red.id: ["붉다"]], using: &rng).count == 1)
}
@Test func promptCueIsNotRequiredInAnswer() {
    var hat = entry("hat", "쓰다", "wear", .verb); hat.promptCue = "a hat"
    #expect(hat.prompt(.englishToKorean) == "wear (a hat)")
    #expect(Grader.isCorrect("wear", entry: hat, direction: .koreanToEnglish))
}
@Test func learningGraduationAndRelearning() {
    var state = LearningState(due: epoch)
    state = Scheduler.grade(state, correct: true, mode: .writeIn, now: epoch, sequence: 1)
    #expect(state.step == 1 && state.due == epoch.addingTimeInterval(600))
    state = Scheduler.grade(state, correct: true, mode: .writeIn, now: state.due, sequence: 2)
    #expect(state.step == 2 && state.due == epoch.addingTimeInterval(600 + 86400))
    state = Scheduler.grade(state, correct: true, mode: .writeIn, now: state.due, sequence: 3)
    #expect(state.phase == .review && state.graduated && state.interval == 3 * 86400)
    let wrongTime = state.due
    state = Scheduler.grade(state, correct: false, mode: .writeIn, now: wrongTime, sequence: 4)
    #expect(state.phase == .relearning && state.due == wrongTime.addingTimeInterval(600))
    #expect(state.totalCorrect == 3 && state.totalWrong == 1 && state.graduated)
    state = Scheduler.grade(state, correct: true, mode: .writeIn, now: state.due, sequence: 5)
    #expect(state.phase == .relearning && state.step == 1)
    state = Scheduler.grade(state, correct: true, mode: .writeIn, now: state.due, sequence: 6)
    #expect(state.phase == .review && state.interval == 3 * 86400)
}
@Test func failedLearningResetsAndDelays() {
    var prior = LearningState(due: epoch); prior.step = 2
    let state = Scheduler.grade(prior, correct: false, mode: .multipleChoice, now: epoch, sequence: 10)
    #expect(state.step == 0 && state.phase == .learning)
    #expect(state.due == epoch.addingTimeInterval(60))
    #expect(state.retryAfterSequence == 13)
}
@Test func modeSpecificIntervalsAndHistoryCap() {
    var state = LearningState(due: epoch); state.phase = .review; state.interval = 3 * 86400; state.recent = Array(repeating: true, count: 20)
    let typed = Scheduler.grade(state, correct: true, mode: .writeIn, now: epoch, sequence: 1)
    let choice = Scheduler.grade(state, correct: true, mode: .multipleChoice, now: epoch, sequence: 1)
    #expect(typed.interval > choice.interval)
    #expect(typed.recent.count == 20)
    #expect(abs(typed.interval - state.interval * (1.5 + 21.0 / 22.0)) < 0.001)
    state.interval = 365 * 86400
    #expect(Scheduler.grade(state, correct: true, mode: .writeIn, now: epoch, sequence: 1).interval == 365 * 86400)
}
@Test func independentTracksAndRecognizedPriority() {
    let a = entry("a", "가", "a"), b = entry("b", "나", "b")
    var graduated = LearningState(due: epoch.addingTimeInterval(99999)); graduated.phase = .review; graduated.graduated = true
    let states = [CardKey(b.id, .englishToKorean, .multipleChoice): graduated]
    var settings = StudySettings(); settings.mode = .writeIn
    #expect(StudyQueue.select(entries: [a,b], states: states, settings: settings, context: .init(now: epoch)) == Selection(b.id, isNew: true))
    settings.direction = .koreanToEnglish
    #expect(StudyQueue.select(entries: [a,b], states: states, settings: settings, context: .init(now: epoch)) == Selection(a.id, isNew: true))
    #expect(states[CardKey(b.id, .englishToKorean, .writeIn)] == nil)
}
@Test func filtersPreserveProgressWithoutBlockingUnseenWords() {
    let noun = entry("noun", "개", "dog"), verb = entry("verb", "가다", "go", .verb)
    var settings = StudySettings(); settings.parts = [.verb]; settings.learningLimit = 1
    let states = [CardKey(noun.id, settings.direction, settings.mode): LearningState(due: epoch)]
    #expect(StudyQueue.select(entries: [noun, verb], states: states, settings: settings, context: .init(now: epoch)) == Selection(verb.id, isNew: true))
    #expect(states.count == 1)
    settings.learningLimit = 2
    #expect(StudyQueue.select(entries: [noun, verb], states: states, settings: settings, context: .init(now: epoch)) == Selection(verb.id, isNew: true))
}
@Test func priorityAndNewCadence() {
    let entries = (0..<4).map { entry("\($0)", "단어\($0)", "word \($0)") }
    let settings = StudySettings()
    var review = LearningState(due: epoch.addingTimeInterval(-100)); review.phase = .review
    var relearning = LearningState(due: epoch); relearning.phase = .relearning
    let states = [CardKey("0", settings.direction, settings.mode): review, CardKey("1", settings.direction, settings.mode): relearning]
    #expect(StudyQueue.select(entries: entries, states: states, settings: settings, context: .init(now: epoch, answersSinceIntroduction: 0))?.entryID == "1")
    #expect(StudyQueue.select(entries: entries, states: states, settings: settings, context: .init(now: epoch, answersSinceIntroduction: 5)) == Selection("2", isNew: true))
    #expect(StudyQueue.select(entries: entries, states: states, settings: settings, context: .init(now: epoch, answersSinceIntroduction: 0, previousSense: "1"))?.entryID == "0")
}
@Test func futureCardsAndClockRollback() {
    let a = entry("a", "가", "a"); let settings = StudySettings()
    let states = [CardKey(a.id, settings.direction, settings.mode): LearningState(due: epoch.addingTimeInterval(600))]
    for offset in [-1000.0, 0, 599] {
        #expect(StudyQueue.select(entries: [a], states: states, settings: settings, context: .init(now: epoch.addingTimeInterval(offset))) == nil)
    }
    #expect(StudyQueue.select(entries: [a], states: states, settings: settings, context: .init(now: epoch.addingTimeInterval(600))) != nil)
}
@Test func interveningCardsAndSmallPoolFallback() {
    let a = entry("a", "가", "a"), b = entry("b", "나", "b"); let settings = StudySettings()
    var failed = LearningState(due: epoch); failed.retryAfterSequence = 10
    let states = [CardKey(a.id, settings.direction, settings.mode): failed, CardKey(b.id, settings.direction, settings.mode): LearningState(due: epoch)]
    #expect(StudyQueue.select(entries: [a,b], states: states, settings: settings, context: .init(now: epoch, sequence: 8))?.entryID == "b")
    #expect(StudyQueue.select(entries: [a], states: states, settings: settings, context: .init(now: epoch, sequence: 8))?.entryID == "a")
}
@Test func retiredCardsDoNotConsumeLearningCapacity() {
    let a = entry("a", "가", "a")
    var settings = StudySettings(); settings.learningLimit = 1
    let states = [CardKey("retired", settings.direction, settings.mode): LearningState(due: epoch)]
    #expect(StudyQueue.select(entries: [a], states: states, settings: settings, context: .init(now: epoch), activeEntryIDs: [a.id]) == Selection(a.id, isNew: true))
}
@Test func returnCompositionAndRepeatGuard() {
    #expect(InputRules.shouldSubmit(composingAtKeyDown: false, currentlyComposing: false, isRepeat: false))
    #expect(!InputRules.shouldSubmit(composingAtKeyDown: true, currentlyComposing: false, isRepeat: false))
    #expect(!InputRules.shouldSubmit(composingAtKeyDown: false, currentlyComposing: true, isRepeat: false))
    #expect(!InputRules.shouldSubmit(composingAtKeyDown: false, currentlyComposing: false, isRepeat: true))
}
@Test func repeatedChoiceKeysDoNotCascadeGrades() {
    #expect(InputRules.ignoreRepeatedStudyKey(isRepeat: true, modified: false, key: "8", multipleChoice: true, waitingForContinue: false))
    #expect(!InputRules.ignoreRepeatedStudyKey(isRepeat: false, modified: false, key: "8", multipleChoice: true, waitingForContinue: false))
    #expect(!InputRules.ignoreRepeatedStudyKey(isRepeat: true, modified: false, key: "8", multipleChoice: false, waitingForContinue: false))
    #expect(!InputRules.ignoreRepeatedStudyKey(isRepeat: true, modified: true, key: "8", multipleChoice: true, waitingForContinue: false))
    #expect(InputRules.ignoreRepeatedStudyKey(isRepeat: true, modified: false, key: "\r", multipleChoice: false, waitingForContinue: true))
}
@Test func reversePromptDoesNotRevealEnglishAnswer() {
    var government = entry("gov", "정부", "government"); government.promptCue = "national government"
    #expect(government.prompt(.koreanToEnglish) == "정부")
    #expect(government.prompt(.englishToKorean) == "government (national government)")
    var hat = entry("wear", "쓰다", "wear", .verb); hat.promptCue = "a hat"
    #expect(hat.prompt(.koreanToEnglish) == "쓰다")
}

@Test(arguments: Direction.allCases, AnswerMode.allCases)
func speedRunContinuesPastPoolAndFormerBatchLimits(direction: Direction, mode: AnswerMode) throws {
    let entries = (0..<120).map { entry("speed.\($0)", "단어\($0)", "word \($0)") }
    var settings = StudySettings(); settings.direction = direction; settings.mode = mode
    var states: [CardKey: LearningState] = [:]
    var previous: String?
    for (index, expected) in entries.enumerated() {
        // Fixed clock: all successful cards remain in their 10-minute waiting step.
        let selection = try #require(StudyQueue.select(entries: entries, states: states, settings: settings,
            context: .init(now: epoch, sequence: index, answersSinceIntroduction: 1, previousSense: previous)))
        #expect(selection == Selection(expected.id, isNew: true))
        states[CardKey(expected.id, direction, mode)] = Scheduler.grade(LearningState(due: epoch), correct: true, mode: mode, now: epoch, sequence: index + 1)
        previous = expected.id
    }
    #expect(states.count == 120)
    #expect(StudyQueue.select(entries: entries, states: states, settings: settings, context: .init(now: epoch, previousSense: previous)) == nil)
    #expect(states.values.allSatisfy { !$0.graduated && $0.due == epoch.addingTimeInterval(600) })
}

@Test func fullPoolStillPrioritizesDueFailuresOverUnseenWords() {
    let entries = (0..<12).map { entry("failure.\($0)", "단어\($0)", "word \($0)") }
    let settings = StudySettings()
    var states: [CardKey: LearningState] = [:]
    for e in entries.prefix(10) { states[CardKey(e.id, settings.direction, settings.mode)] = LearningState(due: epoch.addingTimeInterval(600)) }
    var failed = LearningState(due: epoch); failed.phase = .relearning
    states[CardKey(entries[0].id, settings.direction, settings.mode)] = failed
    #expect(StudyQueue.select(entries: entries, states: states, settings: settings, context: .init(now: epoch, answersSinceIntroduction: 5)) == Selection(entries[0].id, isNew: false))
}

@Test func uncuedMeaningsAndDistractors() {
    var target = entry("a", "눈", "eye")
    target.promptCue = "vision organ"
    let other = entry("b", "눈", "snow")
    let synonym = entry("c", "다른말", "snow")
    let unrelated = entry("d", "집", "house")
    let wrongPOS = entry("e", "눈", "unrelated", .adverb)
    let pool = [target, other, synonym, unrelated, wrongPOS]
    #expect(target.prompt(.koreanToEnglish) == "눈")
    #expect(target.prompt(.englishToKorean) == "eye (vision organ)")
    let accepted = Grader.promptAnswers(target, direction: .koreanToEnglish, pool: pool)
    #expect(accepted == ["eye", "snow"])
    #expect(Grader.promptAnswers(target, direction: .englishToKorean, pool: pool) == ["눈"])
    var rng = Seeded()
    let choices = ChoiceBuilder.choices(target: target, pool: [target, synonym, unrelated], direction: .koreanToEnglish, count: 5, sensePool: pool, using: &rng)
    #expect(Set(choices) == ["eye", "house"])
}

@Test func automaticPronunciationTiming() {
    #expect(PronunciationRules.automaticText(enabled: false, direction: .koreanToEnglish, lemma: "집") == nil)
    #expect(PronunciationRules.automaticText(enabled: true, direction: .koreanToEnglish, lemma: "집") == "집")
    #expect(PronunciationRules.automaticText(enabled: true, direction: .koreanToEnglish, lemma: "집", submittedAnswer: "house") == nil)
    #expect(PronunciationRules.automaticText(enabled: true, direction: .englishToKorean, lemma: "집") == nil)
    #expect(PronunciationRules.automaticText(enabled: true, direction: .englishToKorean, lemma: "집", submittedAnswer: " 물 ") == "물")
    #expect(PronunciationRules.automaticText(enabled: true, direction: .englishToKorean, lemma: "집", submittedAnswer: " ") == nil)
}

@Test func incorrectKoreanSpeechSequence() {
    #expect(PronunciationRules.automaticSequence(enabled: true, direction: .englishToKorean, lemma: "집", submittedAnswer: " 물 ", correct: false) == ["물?", "집"])
    #expect(PronunciationRules.automaticSequence(enabled: true, direction: .englishToKorean, lemma: "집", submittedAnswer: "집", correct: true) == ["집"])
    #expect(PronunciationRules.automaticSequence(enabled: false, direction: .englishToKorean, lemma: "집", submittedAnswer: "물", correct: false).isEmpty)
    #expect(PronunciationRules.automaticSequence(enabled: true, direction: .koreanToEnglish, lemma: "집", submittedAnswer: "water", correct: false).isEmpty)
    #expect(PronunciationRules.automaticSequence(enabled: true, direction: .koreanToEnglish, lemma: "집") == ["집"])
}

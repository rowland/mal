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
    for step in 1...6 {
        let now = state.due
        state = Scheduler.grade(state, correct: true, mode: .writeIn, now: now, sequence: step)
        #expect(state.step == step)
        if step < 6 {
            #expect(state.due == now.addingTimeInterval(Scheduler.learningTimes[step - 1]))
            #expect(state.dueSequence == step + Scheduler.learningAnswers[step - 1])
        }
    }
    #expect(state.phase == .maintenance && state.interval == 3 * 86400 && state.answerInterval == 200)
    let wrongTime = state.due
    state = Scheduler.grade(state, correct: false, mode: .writeIn, now: wrongTime, sequence: 7)
    #expect(state.phase == .relearning && state.due == wrongTime.addingTimeInterval(30))
    #expect(state.totalCorrect == 6 && state.totalWrong == 1 && !state.graduated)
    for step in 1...3 { state = Scheduler.grade(state, correct: true, mode: .writeIn, now: state.due, sequence: 7 + step) }
    #expect(state.phase == .maintenance && state.interval == 1.5 * 86400 && state.answerInterval == 100)
}

@Test func failedLearningResetsAndDelays() {
    var prior = LearningState(due: epoch); prior.step = 2; prior.scheduleVersion = 3
    let state = Scheduler.grade(prior, correct: false, mode: .multipleChoice, now: epoch, sequence: 10)
    #expect(state.step == 0 && state.phase == .learning)
    #expect(state.due == epoch.addingTimeInterval(30))
    #expect(state.dueSequence == 13)
}
@Test func modeSpecificIntervalsAndHistoryCap() {
    var state = LearningState(due: epoch); state.phase = .maintenance; state.interval = 3 * 86400; state.recent = Array(repeating: true, count: 20)
    let typed = Scheduler.grade(state, correct: true, mode: .writeIn, now: epoch, sequence: 1)
    let choice = Scheduler.grade(state, correct: true, mode: .multipleChoice, now: epoch, sequence: 1)
    #expect(typed.interval > choice.interval)
    #expect(typed.recent.count == 20)
    #expect(abs(typed.interval - state.interval * (1.5 + 21.0 / 22.0)) < 0.001)
    state.interval = 365 * 86400
    #expect(Scheduler.grade(state, correct: true, mode: .writeIn, now: epoch, sequence: 1).interval == 180 * 86400)
}
@Test func independentTracksAndRecognizedPriority() {
    let a = entry("a", "가", "a"), b = entry("b", "나", "b")
    var graduated = LearningState(due: epoch.addingTimeInterval(99999)); graduated.phase = .maintenance; graduated.graduated = true
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
@Test func dueCardsAlwaysPrecedeIntroductions() {
    let entries = (0..<4).map { entry("\($0)", "단어\($0)", "word \($0)") }
    let settings = StudySettings()
    var review = LearningState(due: epoch.addingTimeInterval(-100)); review.phase = .maintenance
    var relearning = LearningState(due: epoch); relearning.phase = .relearning
    let states = [CardKey("0", settings.direction, settings.mode): review, CardKey("1", settings.direction, settings.mode): relearning]
    #expect(StudyQueue.select(entries: entries, states: states, settings: settings, context: .init(now: epoch, answersSinceIntroduction: 0))?.entryID == "1")
    #expect(StudyQueue.select(entries: entries, states: states, settings: settings, context: .init(now: epoch, answersSinceIntroduction: 5)) == Selection("1", isNew: false))
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
@Test func eitherClockTriggersWithoutWaitingForTheOther() {
    let state = Scheduler.grade(LearningState(due: epoch), correct: false, mode: .writeIn, now: epoch, sequence: 10)
    #expect(!Scheduler.isDue(state, now: epoch, sequence: 12))
    #expect(Scheduler.isDue(state, now: epoch, sequence: 13))
    #expect(Scheduler.isDue(state, now: epoch.addingTimeInterval(30), sequence: 10))
    #expect(Scheduler.isDue(state, now: epoch.addingTimeInterval(-1000), sequence: 13))
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
    var introductions = 0
    var repetitions = 0
    var sinceNew = 5
    for index in 0..<1500 {
        guard let selection = StudyQueue.select(entries: entries, states: states, settings: settings,
            context: .init(now: epoch, sequence: index, answersSinceIntroduction: sinceNew, previousSense: previous)) else { break }
        if selection.isNew { introductions += 1; sinceNew = 0 } else { repetitions += 1 }
        sinceNew += 1
        if index == 4 { #expect(selection == Selection(entries[0].id, isNew: false)) }
        let key = CardKey(selection.entryID, direction, mode)
        states[key] = Scheduler.grade(states[key] ?? LearningState(due: epoch), correct: true, mode: mode, now: epoch, sequence: index + 1)
        #expect(states.values.filter { $0.phase == .learning && $0.step <= 1 }.count <= 4)
        previous = selection.entryID
        if introductions == 120 { break }
    }
    #expect(introductions == 120)
    #expect(repetitions > 120)
    #expect(states.count == 120)

}

@Test func fullPoolStillPrioritizesDueFailuresOverUnseenWords() {
    let entries = (0..<12).map { entry("failure.\($0)", "단어\($0)", "word \($0)") }
    let settings = StudySettings()
    var states: [CardKey: LearningState] = [:]
    for e in entries.prefix(10) { states[CardKey(e.id, settings.direction, settings.mode)] = Scheduler.grade(LearningState(due: epoch), correct: true, mode: settings.mode, now: epoch, sequence: 1) }
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

@Test func dualDeadlinesSurviveEncodingAndAdvanceOneStep() throws {
    var state = Scheduler.grade(LearningState(due: epoch), correct: true, mode: .writeIn, now: epoch, sequence: 1)
    #expect(state.dueSequence == 4)
    #expect(!Scheduler.isDue(state, now: epoch, sequence: 3))
    #expect(Scheduler.isDue(state, now: epoch, sequence: 4))
    state = try JSONDecoder().decode(LearningState.self, from: JSONEncoder().encode(state))
    state = Scheduler.grade(state, correct: true, mode: .writeIn, now: epoch, sequence: 1000)
    #expect(state.step == 2 && state.dueSequence == 1008)
    #expect(state.due == epoch.addingTimeInterval(300))
}

@Test func failedReinforcementResetsWithoutGraduation() {
    let first = Scheduler.grade(LearningState(due: epoch), correct: true, mode: .multipleChoice, now: epoch, sequence: 1)
    let failed = Scheduler.grade(first, correct: false, mode: .multipleChoice, now: epoch, sequence: 5)
    #expect(failed.step == 0 && failed.reinforceAfterSequence == nil)
    #expect(failed.due == epoch.addingTimeInterval(30))
    #expect(!failed.graduated && failed.totalWrong == 1)
}

@Test func maintenanceContinuesAndCapsBothClocks() {
    var state = LearningState(due: epoch)
    state.scheduleVersion = 3; state.phase = .maintenance
    state.interval = 180 * 86400; state.answerInterval = 1000
    let small = Scheduler.grade(state, correct: true, mode: .writeIn, now: epoch, sequence: 10)
    #expect(small.phase == .maintenance && small.interval == 180 * 86400)
    #expect(small.answerInterval == 1000 && small.dueSequence == 1010)
    let large = Scheduler.grade(state, correct: true, mode: .writeIn, now: epoch, sequence: 10, introducedCount: 500)
    #expect(large.answerInterval == 2000)
}
@Test func queueUsesTheStatesOwnClock() {
    let word = entry("a", "가", "a")
    let key = CardKey(word.id, .englishToKorean, .multipleChoice)
    var state = Scheduler.grade(LearningState(due: epoch), correct: true, mode: key.mode, now: epoch, sequence: 1)
    state.phase = .maintenance; state.clockTrackID = key.trackID
    let states = [key: state]
    let settings = StudySettings()
    #expect(StudyQueue.select(entries: [word], states: states, settings: settings, context: .init(now: epoch, sequence: 999, trackSequences: [key.trackID: 1])) == nil)
    #expect(StudyQueue.select(entries: [word], states: states, settings: settings, context: .init(now: epoch, trackSequences: [key.trackID: 4]))?.entryID == word.id)
}


@Test(arguments: [Phase.learning, .relearning, .maintenance], [false, true])
func introductionsResumeOnlyAfterDueCardsClear(phase: Phase, iterationDue: Bool) {
    let words = [entry("old", "집", "house"), entry("new", "책", "book")]
    let settings = StudySettings()
    let key = CardKey("old", settings.direction, settings.mode)
    var state = LearningState(due: epoch.addingTimeInterval(iterationDue ? 600 : -1))
    state.phase = phase; state.step = 2; state.dueSequence = iterationDue ? 10 : 100
    let context = QueueContext(now: epoch, sequence: 10, answersSinceIntroduction: 1000)
    #expect(StudyQueue.select(entries: words, states: [key: state], settings: settings, context: context) == Selection("old", isNew: false))
    state.due = epoch.addingTimeInterval(600); state.dueSequence = 100
    #expect(StudyQueue.select(entries: words, states: [key: state], settings: settings, context: context) == Selection("new", isNew: true))
}

@Test func semicolonMeaningsAcceptIndividualAnswersAndOptionalHints() {
    let meet = Entry(id: "meet", lemma: "만나다", partOfSpeech: .verb, english: ["meet; to see (someone)", "to meet; to see (someone)"], koreanForms: [KoreanForm("만나요", speechLevel: "informal-polite")])
    let accepted = FormPractice.accepted(meet, direction: .koreanToEnglish, style: .polite, pool: [meet], displayedKorean: "만나요")
    for text in ["see", "to see", "meet", "to meet", "see (someone)", "to see (someone)", "meet; to see (someone)"] { #expect(accepted.contains(text)) }
    for text in ["someone", "meet to see", "not meet"] { #expect(!accepted.contains(text)) }
    let qualified = Entry(id: "q", lemma: "말", partOfSpeech: .noun, english: ["speech (formal; informal); language", "a long, detailed explanation"])
    let meanings = Grader.accepted(qualified, direction: .koreanToEnglish)
    #expect(meanings.contains("language"))
    #expect(!meanings.contains("informal)"))
    #expect(!meanings.contains("detailed explanation"))
    var rng = Seeded()
    let choices = ChoiceBuilder.choices(target: meet, pool: [meet, entry("same", "대면하다", "meet", .verb), entry("other", "가다", "go", .verb)], direction: .koreanToEnglish, count: 5, using: &rng)
    #expect(!choices.contains("meet"))
    #expect(choices.count == 2)
}

@Test func englishAliasesAreAvailableInEveryFormStyle() {
    for style in KoreanPracticeStyle.allCases {
        #expect(FormPractice.canRememberAlias(red, direction: .koreanToEnglish, style: style))
        #expect(FormPractice.accepted(red, direction: .koreanToEnglish, style: style, pool: [red], aliases: [red.id: ["reddish"]]).contains("reddish"))
    }
    #expect(!FormPractice.canRememberAlias(red, direction: .englishToKorean, style: .polite))
    #expect(FormPractice.canRememberAlias(red, direction: .englishToKorean, style: .dictionary))
}

@Test func parentheticalEnglishHintsAreOptionalButNotAnswers() {
    let light = Entry(id: "light", lemma: "가볍다", partOfSpeech: .adjective, english: ["light (not heavy)"])
    for value in ["light", " LIGHT ", "light (not heavy)"] {
        #expect(Grader.isCorrect(value, entry: light, direction: .koreanToEnglish))
    }
    for value in ["heavy", "not heavy", "", "light (bright)"] {
        #expect(!Grader.isCorrect(value, entry: light, direction: .koreanToEnglish))
    }
    let nested = Entry(id: "nested", lemma: "예", partOfSpeech: .verb, english: ["to take (an object (not a person)); to carry (by hand)", "be (very) light", "(hint only)", "broken (hint"])
    let accepted = Grader.accepted(nested, direction: .koreanToEnglish)
    #expect(accepted.contains("take") && accepted.contains("carry") && accepted.contains("be light"))
    #expect(!accepted.contains("") && !accepted.contains("broken"))
    #expect(!Grader.isCorrect("가볍다 (hint)", entry: light, direction: .englishToKorean))
    // Optional English answers must not erase distinctions for Korean prompts.
    let bare = Entry(id: "bare", lemma: "빛", partOfSpeech: .noun, english: ["light"])
    #expect(FormPractice.accepted(bare, direction: .englishToKorean, style: .dictionary, pool: [bare, light]) == ["빛"])
}

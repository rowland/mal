import Foundation
import Testing
@testable import MalCore

private let go = Entry(id: "test.go", lemma: "가다", partOfSpeech: .verb, english: ["go"], koreanForms: [
    .init("가", speechLevel: "informal"), .init("가요", speechLevel: "informal-polite"),
    .init("갑니다", speechLevel: "formal-polite"), .init("간다", speechLevel: "formal"),
    .init("가세요", speechLevel: "informal-polite", honorific: true),
    .init("가십니다", speechLevel: "formal-polite", honorific: true), .init("가는", attributive: true)
])
private struct FormRandom: RandomNumberGenerator { mutating func next() -> UInt64 { 42 } }

@Test func formCategoriesAreExplicitAndStrict() {
    let expectations: [KoreanPracticeStyle: String] = [.dictionary: "가다", .casual: "가", .polite: "가요", .formalPolite: "갑니다", .plain: "간다", .attributive: "가는", .honorificPolite: "가세요", .honorificFormal: "가십니다"]
    for (style, text) in expectations {
        #expect(FormPractice.forms(go, style: style) == [text])
        let accepted = FormPractice.accepted(go, direction: .englishToKorean, style: style, pool: [go], aliases: [go.id: ["가다", "갔어요"]])
        if style != .dictionary { #expect(accepted == [text]) }
        #expect(FormPractice.accepted(go, direction: .koreanToEnglish, style: style, pool: [go]) == ["go"])
    }
}
@Test func variantsAndIrregularFormsRemainExplicit() {
    let red = Entry(id: "test.red", lemma: "빨갛다", partOfSpeech: .adjective, english: ["red"], koreanForms: [
        .init("빨개요", speechLevel: "informal-polite"), .init("붉어요", speechLevel: "informal-polite"),
        .init("빨간", attributive: true), .init("붉은", attributive: true)
    ])
    #expect(FormPractice.forms(red, style: .polite) == ["빨개요", "붉어요"])
    #expect(FormPractice.forms(red, style: .attributive) == ["빨간", "붉은"])
    #expect(FormPractice.forms(red, style: .formalPolite).isEmpty)
    let accepted = FormPractice.accepted(red, direction: .englishToKorean, style: .polite, pool: [red])
    #expect(accepted.contains(Grader.normalize(" 빨개요\n".decomposedStringWithCanonicalMapping, direction: .englishToKorean)))
    #expect(!accepted.contains("빨갰어요"))
    #expect(!accepted.contains("빨갛다"))
}
@Test func ordinaryNounsKeepTheirExistingTrack() {
    let house = Entry(id: "test.house", lemma: "집", partOfSpeech: .noun, english: ["house"])
    for style in KoreanPracticeStyle.allCases {
        #expect(FormPractice.forms(house, style: style) == ["집"])
        #expect(FormPractice.key(house, direction: .englishToKorean, mode: .writeIn, style: style) == CardKey(house.id, .englishToKorean, .writeIn))
    }
}
@Test func formChoicesUseSelectedStyle() {
    let come = Entry(id: "test.come", lemma: "오다", partOfSpeech: .verb, english: ["come"], koreanForms: [.init("와요", speechLevel: "informal-polite")])
    var random = FormRandom()
    let display = FormPractice.displayForms([go, come], style: .polite, using: &random)
    let choices = ChoiceBuilder.choices(target: go, pool: [go, come], direction: .englishToKorean, count: 5, koreanAnswers: display, using: &random)
    #expect(Set(choices) == ["가요", "와요"])
    #expect(display[go.id] == "가요")
}
@Test func formTracksDoNotInheritDictionaryMastery() throws {
    let now = Date(timeIntervalSince1970: 1000)
    var graduated = LearningState(due: now.addingTimeInterval(1000)); graduated.graduated = true; graduated.phase = .review
    let oldKey = CardKey(go.id, .englishToKorean, .multipleChoice)
    let politeKey = FormPractice.key(go, direction: .englishToKorean, mode: .multipleChoice, style: .polite)
    #expect(oldKey != politeKey)
    #expect(oldKey.storageID == "test.go|englishToKorean|multipleChoice")
    let decoded = try JSONDecoder().decode(CardKey.self, from: Data(#"{"entryID":"test.go","direction":"englishToKorean","mode":"multipleChoice"}"#.utf8))
    #expect(decoded == oldKey)
    var settings = StudySettings(); settings.formStyle = .polite
    #expect(StudyQueue.select(entries: [go], states: [oldKey: graduated], settings: settings, context: .init(now: now)) == Selection(go.id, isNew: true))
    #expect(StudyQueue.select(entries: [go], states: [politeKey: graduated], settings: settings, context: .init(now: now)) == nil)
}
@Test func recognizedPriorityUsesMatchingFormOnly() {
    var second = go; second.id = "test.second"
    let now = Date(timeIntervalSince1970: 1000)
    var mastered = LearningState(due: now); mastered.graduated = true; mastered.phase = .review
    var settings = StudySettings(); settings.formStyle = .polite; settings.mode = .writeIn
    let otherStyle = FormPractice.key(second, direction: settings.direction, mode: .multipleChoice, style: .casual)
    #expect(StudyQueue.select(entries: [go, second], states: [otherStyle: mastered], settings: settings, context: .init(now: now))?.entryID == go.id)
    let matching = FormPractice.key(second, direction: settings.direction, mode: .multipleChoice, style: .polite)
    #expect(StudyQueue.select(entries: [go, second], states: [matching: mastered], settings: settings, context: .init(now: now))?.entryID == second.id)
}
@Test func missingFormIsSkippedWithoutDictionaryFallback() {
    let missing = Entry(id: "test.missing", lemma: "하다", partOfSpeech: .verb, english: ["do"])
    var settings = StudySettings(); settings.formStyle = .polite
    #expect(StudyQueue.select(entries: [missing], states: [:], settings: settings, context: .init(now: Date())) == nil)
}
@Test func identicalConjugationsDoNotCreateUnfairReverseCards() {
    let hear = Entry(id: "test.hear", lemma: "듣다", partOfSpeech: .verb, english: ["hear"], koreanForms: [.init("들어요", speechLevel: "informal-polite")])
    let lift = Entry(id: "test.lift", lemma: "들다", partOfSpeech: .verb, english: ["lift"], koreanForms: [.init("들어요", speechLevel: "informal-polite")])
    let synonym = Entry(id: "test.raise", lemma: "올리다", partOfSpeech: .verb, english: ["lift"], koreanForms: [.init("올려요", speechLevel: "informal-polite")])
    let pool = [hear, lift, synonym, go]
    let accepted = FormPractice.accepted(hear, direction: .koreanToEnglish, style: .polite, pool: pool, displayedKorean: "들어요")
    #expect(accepted == ["hear", "lift"])
    #expect(FormPractice.accepted(hear, direction: .koreanToEnglish, style: .dictionary, pool: pool, displayedKorean: "듣다") == ["hear"])
    var random = FormRandom()
    let choices = ChoiceBuilder.choices(target: hear, pool: pool, direction: .koreanToEnglish, count: 5, acceptedAnswers: accepted, using: &random)
    #expect(Set(choices) == ["hear", "go"])
}

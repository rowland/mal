import Testing
import MalCore

@Test func spokenAlternativesAndConsonantConfusions() {
    #expect(SpokenGrader.decide(heard: "한국과", alternatives: ["한국어"], accepted: ["한국어"]) == .correct("한국어"))
    for (heard, target) in [("발리", "빨리"), ("자요", "짜요"), ("다요", "따요"), ("가요", "까요"), ("사요", "싸요")] {
        #expect(SpokenGrader.decide(heard: heard, alternatives: [], accepted: [target]) == .correct(target))
    }
}
@Test func uncertainSpeechNeedsConfirmationAndDoesNotLoosenTypedGrading() {
    #expect(SpokenGrader.decide(heard: "한국과", alternatives: [], accepted: ["한국어"]) == .confirm("한국어"))
    #expect(SpokenGrader.decide(heard: "아", alternatives: [], accepted: ["어"]) == .confirm("어"))
    #expect(SpokenGrader.decide(heard: "안 가요", alternatives: [], accepted: ["가요"]) == .confirm("가요"))
    #expect(SpokenGrader.decide(heard: "갔어요", alternatives: [], accepted: ["가요"]) == .confirm("가요"))
    #expect(SpokenGrader.decide(heard: "", alternatives: [], accepted: ["가요"]) == .incorrect)
    #expect(SpokenGrader.decide(heard: "발리", alternatives: [], accepted: ["빨리", "발리"]) == .correct("발리"))
    let entry = Entry(id: "fast", lemma: "빨리", partOfSpeech: .adverb, english: ["quickly"])
    #expect(!Grader.isCorrect("발리", entry: entry, direction: .englishToKorean))
}

@Test func unmatchedSpeechCannotAutomaticallyRecordFailure() {
    #expect(SpokenGrader.decide(heard: "이뻐요", alternatives: [], accepted: ["입어요"]) == .confirm("입어요"))
    for heard in ["입 어요", "이뻐요.", "unrelated", "먹어요"] {
        #expect(SpokenGrader.decide(heard: heard, alternatives: [], accepted: ["입어요"]) == .confirm("입어요"))
    }
    #expect(SpokenGrader.decide(heard: "unrelated", alternatives: [], accepted: ["가요", "입어요"], preferredAnswer: "입어요") == .confirm("입어요"))
    let wear = Entry(id: "wear", lemma: "입다", partOfSpeech: .verb, english: ["wear"], koreanForms: [KoreanForm("입어요", speechLevel: "informal-polite")])
    #expect(!Grader.isCorrect("이뻐요", entry: wear, direction: .englishToKorean))
}

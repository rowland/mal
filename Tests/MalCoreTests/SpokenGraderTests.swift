import Foundation
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
    #expect(SpokenGrader.decide(heard: "안 가요", alternatives: [], accepted: ["가요"]) == .correct("가요"))
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

@Test func recognitionConfirmationOffersEveryAcceptedSynonym() {
    let accepted: Set<String> = ["빨개요", "붉어요"]
    let decision = SpokenGrader.decide(heard: "불까요", alternatives: [], accepted: accepted, preferredAnswer: "빨개요")
    guard case .confirm(let preferred) = decision else { Issue.record("Expected confirmation"); return }
    let options = SpokenGrader.confirmationOptions(accepted: accepted, preferred: preferred)
    #expect(Set(options) == accepted)
    #expect(options.count == 2)
    #expect(SpokenGrader.confirmationOptions(accepted: accepted, preferred: "invalid") == accepted.sorted())
}

@Test func liveSpeechMatchesIntersectionAcrossHypothesesAndSynonyms() {
    let accepted: Set<String> = ["빨개요", "붉어요"]
    #expect(SpokenGrader.matches(heard: "불까요", alternatives: [], accepted: accepted).isEmpty)
    #expect(SpokenGrader.matches(heard: "불까요", alternatives: ["붉어요!", "빨개요", "붉어요"], accepted: accepted) == accepted)
    // A fuzzy match must not interrupt a still-developing live answer.
    #expect(SpokenGrader.matches(heard: "발리", alternatives: [], accepted: ["빨리"]).isEmpty)
}

@Test func spokenSelfCorrectionsAndWordBoundaries() {
    #expect(SpokenGrader.decide(heard: "한국아, I mean 한국어!", alternatives: [], accepted: ["한국어"]) == .correct("한국어"))
    #expect(SpokenGrader.matches(heard: "한국아", alternatives: ["아, 한국어!"], accepted: ["한국어"]) == ["한국어"])
    for text in ["한국어학", "한국어로", "대한민국", "", "..."] {
        #expect(SpokenGrader.matches(heard: text, alternatives: [], accepted: ["한국어", "한"]).isEmpty)
    }
    #expect(SpokenGrader.matches(heard: "저는 할 수 있어요!", alternatives: [], accepted: ["할 수 있어요"]) == ["할 수 있어요"])
    #expect(SpokenGrader.matches(heard: "할 다른 수 있어요", alternatives: [], accepted: ["할 수 있어요"]).isEmpty)
    #expect(SpokenGrader.matches(heard: "한국어".decomposedStringWithCanonicalMapping, alternatives: [], accepted: ["한국어"]) == ["한국어"])
    let entry = Entry(id: "language", lemma: "한국어", partOfSpeech: .noun, english: ["Korean"])
    #expect(!Grader.isCorrect("한국아, I mean 한국어!", entry: entry, direction: .englishToKorean))
}

@Test func speechVowelRuleCoversReportedAppleResults() {
    let alternatives = ["하예요.", "하게요.", "하이예요.", "하 예요.", "하에요."]
    #expect(SpokenGrader.liveMatch(heard: "하예요", alternatives: alternatives, accepted: ["하얘요", "희어요"]) == "하얘요")
    #expect(SpokenGrader.decide(heard: "하예요", alternatives: alternatives, accepted: ["하얘요", "희어요"]) == .correct("하얘요"))
    for (a, b) in [("하예요", "하얘요"), ("네", "내"), ("얘", "예"), ("네예", "내얘")] {
        #expect(SpeechMatchingRule.vowelPairs.matches(a, b))
        #expect(SpeechMatchingRule.vowelPairs.matches(b, a))
    }
    let evidence = SpeechMatchingRules.evaluate(heard: "아, 하예요!", alternatives: [], accepted: ["하얘요"])
    #expect(evidence.first?.rule == .vowelPairs)
    #expect(evidence.first?.candidate == "하예요")
    #expect(SpeechMatchingRules.evaluate(heard: "하예요", alternatives: [], accepted: ["하얘요"], rules: []).isEmpty)
}

@Test func speechRulesDoNotComposeOrChangeTypedSpelling() {
    for wrong in ["하게요", "하이예요", "하에요", "하 예요", "하예욧", "하예요로", "하예", "하얬어요"] {
        #expect(SpokenGrader.liveMatch(heard: wrong, alternatives: [], accepted: ["하얘요"]) == nil)
    }
    #expect(SpeechMatchingRules.evaluate(heard: "게", alternatives: [], accepted: ["깨"]).isEmpty)
    #expect(SpokenGrader.liveMatch(heard: "발리", alternatives: [], accepted: ["빨리"]) == "빨리")
    #expect(SpokenGrader.decide(heard: "발리", alternatives: [], accepted: ["빨리"]) == .correct("빨리"))
    #expect(SpokenGrader.liveMatch(heard: "하예요".decomposedStringWithCanonicalMapping, alternatives: [], accepted: ["하얘요"]) == "하얘요")
    let entry = Entry(id: "white", lemma: "하얗다", partOfSpeech: .adjective, english: ["white"], koreanForms: [KoreanForm("하얘요", speechLevel: "informal-polite")])
    #expect(!Grader.isCorrect("하예요", entry: entry, direction: .englishToKorean))
}

@Test func speechRuleAmbiguityAndExactPrecedence() {
    let accepted: Set<String> = ["내예", "네얘"]
    #expect(SpokenGrader.liveMatch(heard: "네예", alternatives: [], accepted: accepted) == nil)
    guard case .confirm = SpokenGrader.decide(heard: "네예", alternatives: [], accepted: accepted) else {
        Issue.record("Ambiguous rule matches must require confirmation"); return
    }
    #expect(SpokenGrader.decide(heard: "네예", alternatives: ["내예"], accepted: accepted) == .correct("내예"))
    #expect(SpokenGrader.liveMatch(heard: "네", alternatives: ["예"], accepted: ["내", "얘"]) == nil)
}

@Test func livePlainDoubleConsonantsPreserveOtherSoundsAndAmbiguity() {
    for (plain, tense) in [("가요", "까요"), ("다요", "따요"), ("받아요", "빧아요"), ("사요", "싸요"), ("자요", "짜요")] {
        #expect(SpokenGrader.liveMatch(heard: plain, alternatives: [], accepted: [tense]) == tense)
        #expect(SpokenGrader.liveMatch(heard: tense, alternatives: [], accepted: [plain]) == plain)
        #expect(SpokenGrader.liveMatch(heard: "음", alternatives: [tense + "!"], accepted: [plain]) == plain)
    }
    // The contextual rule explicitly covers the reported coda and onset combination.
    #expect(SpokenGrader.liveMatch(heard: "빨아요", alternatives: [], accepted: ["받아요"]) == "받아요")
    #expect(SpokenGrader.decide(heard: "빨아요", alternatives: [], accepted: ["받아요"]) == .correct("받아요"))
    #expect(SpokenGrader.liveMatch(heard: "가요", alternatives: ["사요"], accepted: ["까요", "싸요"]) == nil)
    #expect(SpokenGrader.liveMatch(heard: "가요", alternatives: [], accepted: ["가요", "까요"]) == "가요")
    #expect(SpokenGrader.liveMatch(heard: "카요", alternatives: [], accepted: ["가요"]) == nil)
    #expect(SpokenGrader.liveMatch(heard: "빧아요로", alternatives: [], accepted: ["받아요"]) == nil)
}

@Test func contextualCodaRuleIsBoundedAndSpeechOnly() {
    let rule = SpeechMatchingRule.rieulDigeutBeforeVowel
    for (heard, target) in [("빨아요", "받아요"), ("발아요", "받아요"), ("걸어요", "걷어요")] {
        #expect(rule.matches(heard, target))
        #expect(rule.matches(target, heard))
        #expect(SpokenGrader.liveMatch(heard: "음", alternatives: [heard + "!"], accepted: [target]) == target)
    }
    for (heard, target) in [("발", "받"), ("발이", "받이"), ("발애", "받애"), ("발에", "받에"), ("발고", "받고"), ("발 아요", "받 아요"), ("팔아요", "받아요"), ("빨어요", "받아요"), ("빨아", "받아요")] {
        #expect(!rule.matches(heard, target))
    }
    #expect(SpokenGrader.liveMatch(heard: "빨아요", alternatives: [], accepted: ["받아요", "발아요"]) == nil)
    #expect(SpokenGrader.liveMatch(heard: "빨아요", alternatives: [], accepted: ["빨아요", "받아요"]) == "빨아요")
    let entry = Entry(id: "receive", lemma: "받다", partOfSpeech: .verb, english: ["receive"], koreanForms: [KoreanForm("받아요", speechLevel: "informal-polite")])
    #expect(!Grader.isCorrect("빨아요", entry: entry, direction: .englishToKorean))
    #expect(SpeechMatchingRules.evaluate(heard: "빨아요", alternatives: [], accepted: ["받아요"]).first?.rule == rule)
}

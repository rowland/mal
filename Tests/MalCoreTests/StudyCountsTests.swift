import Foundation
import Testing
import MalCore

@Test func studyCountsIncludeFutureReviewsAndIsolateAnswerTracks() {
    let now = Date(timeIntervalSince1970: 1000)
    let learningKey = CardKey("learning", .koreanToEnglish, .writeIn)
    let reviewKey = CardKey("review", .koreanToEnglish, .writeIn)
    let relearningKey = CardKey("relearning", .koreanToEnglish, .writeIn)
    let otherMode = CardKey("other", .koreanToEnglish, .multipleChoice)
    var future = LearningState(due: now.addingTimeInterval(1000)); future.phase = .maintenance
    var retry = LearningState(due: now.addingTimeInterval(1000)); retry.phase = .relearning; retry.dueSequence = 5
    let states = [learningKey: LearningState(due: now), reviewKey: future, relearningKey: retry, otherMode: future]
    let counts = StudyCounts.calculate(keys: [learningKey, reviewKey, relearningKey], states: states, sequences: [learningKey.trackID: 5], now: now)
    #expect(counts.total == 3 && counts.learning == 2 && counts.review == 1 && counts.due == 2)
    let filtered = StudyCounts.calculate(keys: [reviewKey], states: states, sequences: [:], now: now)
    #expect(filtered.total == 1 && filtered.review == 1 && filtered.due == 0)
    #expect(states.count == 4)
}
@Test func currentIntroductionCountsOnceWithoutCreatingDueState() {
    let key = CardKey("new", .englishToKorean, .multipleChoice)
    let now = Date(timeIntervalSince1970: 1000)
    let before = StudyCounts.calculate(keys: [key], states: [:], sequences: [:], now: now, introduction: key)
    #expect(before.total == 1 && before.learning == 1 && before.due == 0)
    let state = Scheduler.grade(LearningState(due: now), correct: true, mode: .multipleChoice, now: now, sequence: 1)
    let after = StudyCounts.calculate(keys: [key], states: [key: state], sequences: [:], now: now, introduction: key)
    #expect(after.total == 1 && after.learning == 1 && after.due == 0)
    let hidden = StudyCounts.calculate(keys: [], states: [key: state], sequences: [:], now: now, introduction: key)
    #expect(hidden.total == 0)
}

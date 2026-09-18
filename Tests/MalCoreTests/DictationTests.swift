import Foundation
import Testing
import MalCore

@Test func dictationRejectsStaleCallbacksAndKeepsDraftAfterStop() {
    var draft = DictationDraft()
    let first = UUID(), second = UUID()
    draft.begin(id: first)
    let initial = draft.receive("가요", id: first); #expect(initial)
    draft.end()
    let late = draft.receive("늦은 결과", id: first); #expect(!late)
    #expect(draft.text == "가요")
    draft.begin(id: second)
    #expect(draft.text == nil)
    let stale = draft.receive("이전 단어", id: first); #expect(!stale)
    let blank = draft.receive("  ", id: second); #expect(!blank)
    let current = draft.receive("먹어요", id: second); #expect(current)
    #expect(draft.text == "먹어요")
}

@Test func dictationCleansSentencePunctuationWithoutChangingWords() {
    var draft = DictationDraft(); let id = UUID(); draft.begin(id: id)
    let accepted = draft.receive("  안 가요.  ", id: id)
    #expect(accepted && draft.text == "안 가요")
    let punctuation = draft.receive("?!", id: id)
    #expect(!punctuation && draft.text == "안 가요")
}

@Test func spokenReturnAndEscapeDoNotInterceptEditingOrRepeatedKeys() {
    #expect(InputRules.spokenAnswerKey("\r", enabled: true, editing: false, isRepeat: false, modified: false) == .submit)
    #expect(InputRules.spokenAnswerKey("\u{1b}", enabled: true, editing: false, isRepeat: false, modified: false) == .edit)
    #expect(InputRules.spokenAnswerKey("\r", enabled: true, editing: false, isRepeat: true, modified: false) == .ignore)
    #expect(InputRules.spokenAnswerKey("\r", enabled: true, editing: true, isRepeat: false, modified: false) == .unhandled)
    #expect(InputRules.spokenAnswerKey("\r", enabled: false, editing: false, isRepeat: false, modified: false) == .unhandled)
    #expect(InputRules.spokenAnswerKey("\r", enabled: true, editing: false, isRepeat: false, modified: true) == .unhandled)
}
@Test func endingSpeechRejectsFinalResultsAfterManualSubmissionOrEscape() {
    var draft = DictationDraft(); let id = UUID(); draft.begin(id: id)
    let partial = draft.receive("집", id: id); #expect(partial)
    draft.end()
    let final = draft.receive("집입니다", id: id)
    #expect(!final && draft.text == "집")
}

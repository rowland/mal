import Testing
import MalNative

@Test @MainActor func inputSourceFollowsLanguageAndRestoresPrevious() {
    var selected = "english"
    let sources = [AnswerInputSource(id: "english", languages: ["en"]), AnswerInputSource(id: "korean2", languages: ["ko"]), AnswerInputSource(id: "korean3", languages: ["ko"])]
    let switcher = AnswerInputSourceSwitcher(available: { sources }, current: { selected }, select: { selected = $0 })
    switcher.begin(language: "ko", composing: false)
    #expect(selected == "korean2")
    selected = "korean3" // A manual choice must survive view refreshes.
    switcher.begin(language: "ko", composing: false)
    #expect(selected == "korean3")
    switcher.end(composing: false)
    #expect(selected == "english")
    switcher.begin(language: "ko", composing: false)
    #expect(selected == "korean3")
    switcher.begin(language: "en", composing: false)
    #expect(selected == "english")
    switcher.end(composing: false)
    #expect(selected == "english")
}
@Test @MainActor func inputSourceLeavesCompositionAndMissingLanguagesAlone() {
    var selected = "english"
    let sources = [AnswerInputSource(id: "english", languages: ["en"]), AnswerInputSource(id: "korean", languages: ["ko"])]
    let switcher = AnswerInputSourceSwitcher(available: { sources }, current: { selected }, select: { selected = $0 })
    switcher.begin(language: "ko", composing: true)
    #expect(selected == "english")
    switcher.begin(language: "ko", composing: false)
    switcher.end(composing: true)
    #expect(selected == "korean")
    switcher.end(composing: false)
    #expect(selected == "english")
    switcher.begin(language: "fr", composing: false)
    #expect(selected == "english")
    switcher.end(composing: false)
    selected = "korean"
    switcher.begin(language: "en", composing: false)
    #expect(selected == "english")
    switcher.end(composing: false)
    #expect(selected == "korean")
}

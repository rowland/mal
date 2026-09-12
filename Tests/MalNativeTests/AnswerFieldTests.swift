import AppKit
import Testing
@testable import MalNative

@Test @MainActor func customFieldEditorPreservesMarkedText() throws {
    _ = NSApplication.shared
    let field = NSTextField()
    let cell = AnswerCell(textCell: "")
    let editor = try #require(cell.fieldEditor(for: field) as? AnswerEditor)
    #expect(editor.isFieldEditor)
    editor.setMarkedText("지", selectedRange: NSRange(location: 1, length: 0), replacementRange: NSRange(location: NSNotFound, length: 0))
    #expect(editor.hasMarkedText())
    #expect(!editor.canSubmit)
    editor.unmarkText()
    #expect(editor.canSubmit)
    #expect(editor.string == "지")
    #expect(!editor.isAutomaticSpellingCorrectionEnabled)
}

import AppKit
import MalCore

/// Captures composition BEFORE AppKit/IME handling, which may unmark the text
/// before the control delegate receives insertNewline. An IME commit Return
/// must never become a grade in the same event.
@MainActor public class AnswerEditor: NSTextView {
    public private(set) var returnBeganDuringComposition = false
    public private(set) var returnIsRepeat = false
    public var canSubmit: Bool {
        InputRules.shouldSubmit(composingAtKeyDown: returnBeganDuringComposition, currentlyComposing: hasMarkedText(), isRepeat: returnIsRepeat)
    }
    public override func keyDown(with event: NSEvent) {
        let isReturn = event.keyCode == 36 || event.keyCode == 76
        returnBeganDuringComposition = isReturn && hasMarkedText()
        returnIsRepeat = isReturn && event.isARepeat
        defer { returnBeganDuringComposition = false; returnIsRepeat = false }
        if returnIsRepeat { return }
        super.keyDown(with: event)
    }
}
@MainActor public final class AnswerCell: NSTextFieldCell {
    private lazy var editor: AnswerEditor = {
        let editor = AnswerEditor()
        editor.isFieldEditor = true
        editor.isAutomaticSpellingCorrectionEnabled = false
        editor.isAutomaticTextReplacementEnabled = false
        editor.isAutomaticQuoteSubstitutionEnabled = false
        editor.isAutomaticDashSubstitutionEnabled = false
        return editor
    }()
    public override func fieldEditor(for controlView: NSView) -> NSTextView? { editor }
}

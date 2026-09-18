import AppKit
import MalCore

/// Captures composition BEFORE AppKit/IME handling, which may unmark the text
/// before the control delegate receives insertNewline. An IME commit Return
/// must never become a grade in the same event.
@MainActor public class AnswerEditor: NSTextView {
    public var answerLanguage = "ko"
    private lazy var sourceSwitcher = AnswerInputSourceSwitcher.system()
    private var observingFocus = false
    @objc private func windowLostFocus(_ notification: Notification) {
        guard (notification.object as? NSWindow) === window else { return }
        restoreAnswerInputSource()
    }
    @objc private func windowGainedFocus(_ notification: Notification) {
        guard (notification.object as? NSWindow) === window else { return }
        updateAnswerInputSource()
    }
    public override func becomeFirstResponder() -> Bool {
        if !observingFocus {
            observingFocus = true
            NotificationCenter.default.addObserver(self, selector: #selector(windowLostFocus(_:)), name: NSWindow.didResignKeyNotification, object: nil)
            NotificationCenter.default.addObserver(self, selector: #selector(windowGainedFocus(_:)), name: NSWindow.didBecomeKeyNotification, object: nil)
        }
        let accepted = super.becomeFirstResponder()
        if accepted { DispatchQueue.main.async { [weak self] in self?.updateAnswerInputSource() } }
        return accepted
    }
    public override func resignFirstResponder() -> Bool {
        let accepted = super.resignFirstResponder()
        if accepted { restoreAnswerInputSource() }
        return accepted
    }
    public func updateAnswerInputSource() {
        guard window?.isKeyWindow == true, window?.firstResponder === self else { return }
        sourceSwitcher.begin(language: answerLanguage, composing: hasMarkedText())
    }
    public func restoreAnswerInputSource() { sourceSwitcher.end(composing: hasMarkedText()) }
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
    public var answerLanguage = "ko" {
        didSet { editor.answerLanguage = answerLanguage; editor.updateAnswerInputSource() }
    }
    public func restoreAnswerInputSource() { editor.restoreAnswerInputSource() }
    private lazy var editor: AnswerEditor = {
        let editor = AnswerEditor()
        editor.answerLanguage = answerLanguage
        editor.isFieldEditor = true
        editor.isAutomaticSpellingCorrectionEnabled = false
        editor.isAutomaticTextReplacementEnabled = false
        editor.isAutomaticQuoteSubstitutionEnabled = false
        editor.isAutomaticDashSubstitutionEnabled = false
        return editor
    }()
    public override func fieldEditor(for controlView: NSView) -> NSTextView? { editor }
}

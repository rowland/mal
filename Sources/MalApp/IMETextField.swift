import SwiftUI
import AppKit
import MalNative

// The custom editor remembers whether Return began inside IME composition.
// The control delegate submits only an independent, unmarked Return.
struct IMETextField: NSViewRepresentable {
    @Binding var text: String
    var enabled: Bool
    var onSubmit: () -> Void
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    func makeNSView(context: Context) -> NSTextField {
        let field = NSTextField(string: "")
        field.cell = AnswerCell(textCell: "")
        field.isBezeled = true
        field.isEditable = true
        field.placeholderString = "Type your answer"
        field.font = .systemFont(ofSize: 24)
        field.bezelStyle = .roundedBezel
        field.delegate = context.coordinator
        field.setAccessibilityLabel("Your answer")
        return field
    }
    func updateNSView(_ field: NSTextField, context: Context) {
        context.coordinator.parent = self
        if (field.currentEditor() as? NSTextView)?.hasMarkedText() != true, field.stringValue != text { field.stringValue = text }
        field.isEnabled = enabled
        if enabled, field.window?.firstResponder is NSTextView == false {
            DispatchQueue.main.async { if field.window?.isKeyWindow == true { field.window?.makeFirstResponder(field) } }
        }
    }
    final class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: IMETextField
        init(_ parent: IMETextField) { self.parent = parent }
        func controlTextDidChange(_ notification: Notification) {
            if let field = notification.object as? NSTextField { parent.text = field.stringValue }
        }
        func control(_ control: NSControl, textView: NSTextView, doCommandBy selector: Selector) -> Bool {
            if selector == #selector(NSResponder.insertNewline(_:)) {
                guard (textView as? AnswerEditor)?.canSubmit ?? !textView.hasMarkedText() else { return true }
                parent.text = control.stringValue; parent.onSubmit(); return true
            }
            return false
        }
    }
}

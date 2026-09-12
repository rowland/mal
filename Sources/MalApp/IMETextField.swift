import SwiftUI
import AppKit

// AppKit consumes Return while marked text exists. The delegate submits only
// a later Return after composition has committed, avoiding accidental grading.
struct IMETextField: NSViewRepresentable {
    @Binding var text: String
    var enabled: Bool
    var onSubmit: () -> Void
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    func makeNSView(context: Context) -> NSTextField {
        let field = NSTextField(string: "")
        field.placeholderString = "Type your answer"
        field.font = .systemFont(ofSize: 24)
        field.bezelStyle = .roundedBezel
        field.delegate = context.coordinator
        field.setAccessibilityLabel("Your answer")
        return field
    }
    func updateNSView(_ field: NSTextField, context: Context) {
        context.coordinator.parent = self
        if field.stringValue != text { field.stringValue = text }
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
            if selector == #selector(NSResponder.insertNewline(_:)), !textView.hasMarkedText() {
                parent.text = control.stringValue; parent.onSubmit(); return true
            }
            return false
        }
    }
}

import AppKit
import Carbon

public struct AnswerInputSource: Equatable {
    public let id: String
    public let languages: [String]
    public init(id: String, languages: [String]) { self.id = id; self.languages = languages }
}

/// Focus-scoped switching, injectable so tests never change the machine's keyboard.
@MainActor public final class AnswerInputSourceSwitcher {
    private let available: () -> [AnswerInputSource]
    private let current: () -> String?
    private let select: (String) -> Void
    private var original: String?
    private var language: String?
    private var preferred: [String: String] = [:]
    public init(available: @escaping () -> [AnswerInputSource], current: @escaping () -> String?, select: @escaping (String) -> Void) {
        self.available = available; self.current = current; self.select = select
    }
    public func begin(language: String, composing: Bool) {
        guard !composing, self.language != language else { return }
        if self.language != nil { end(composing: false) }
        self.language = language; original = current()
        let matching = available().filter { $0.languages.contains { $0 == language || $0.hasPrefix(language + "-") } }
        // Keep the user's current matching layout (e.g. Korean 3-set versus 2-set).
        if matching.contains(where: { $0.id == original }) { return }
        if let target = matching.first(where: { $0.id == preferred[language] }) ?? matching.first { select(target.id) }
    }
    public func end(composing: Bool) {
        guard !composing, let language else { return }
        if let chosen = current(), available().contains(where: { $0.id == chosen && $0.languages.contains(language) }) {
            preferred[language] = chosen
        }
        if let original, original != current(), available().contains(where: { $0.id == original }) { select(original) }
        original = nil; self.language = nil
    }
    public static func system() -> AnswerInputSourceSwitcher {
        func sources() -> [TISInputSource] {
            let properties = [kTISPropertyInputSourceIsSelectCapable as String: true,
                              kTISPropertyInputSourceIsEnabled as String: true] as CFDictionary
            return TISCreateInputSourceList(properties, false).takeRetainedValue() as? [TISInputSource] ?? []
        }
        func property<T>(_ source: TISInputSource, _ name: CFString) -> T? {
            guard let value = TISGetInputSourceProperty(source, name) else { return nil }
            return Unmanaged<AnyObject>.fromOpaque(value).takeUnretainedValue() as? T
        }
        return AnswerInputSourceSwitcher(available: {
            sources().compactMap { source in
                guard let id: String = property(source, kTISPropertyInputSourceID) else { return nil }
                return AnswerInputSource(id: id, languages: property(source, kTISPropertyInputSourceLanguages) ?? [])
            }
        }, current: {
            guard let source = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue() else { return nil }
            return property(source, kTISPropertyInputSourceID)
        }, select: { id in
            if let source = sources().first(where: { (property($0, kTISPropertyInputSourceID) as String?) == id }) { _ = TISSelectInputSource(source) }
        })
    }
}

import SwiftUI
import MalCore

@main struct MalApp: App {
    @State private var model = StudyModel()
    var body: some Scene {
        WindowGroup("Mal · 말") {
            ContentView(model: model).frame(minWidth: 840, minHeight: 620)
        }
        .defaultSize(width: 1050, height: 760)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Import Word Bank…", action: model.importBank).keyboardShortcut("i", modifiers: [.command, .shift])
                Button("Back Up Progress…", action: model.backup)
                Button("Restore Backup…", action: model.restore)
            }
            CommandGroup(replacing: .undoRedo) { Button("Undo Last Grade", action: model.undo).keyboardShortcut("z") }
            CommandMenu("Study") {
                Button("Show Word Bank") { model.showLibrary = true }.keyboardShortcut("l")
                Button("Show History") { model.showHistory = true }
                Button("Pronounce Word") { if let entry = model.current { model.speak(entry) } }.keyboardShortcut("p")
            }
        }
        Settings { SettingsView(model: model).padding(24).frame(width: 420) }
    }
}
struct ContentView: View {
    @Bindable var model: StudyModel
    var body: some View {
        NavigationSplitView {
            List {
                Section("WORD BANKS") {
                    ForEach(model.banks) { bank in
                        Toggle(isOn: Binding(get: { model.settings.bankIDs.contains(bank.id) }, set: { value in
                            if value { model.settings.bankIDs.insert(bank.id) } else { model.settings.bankIDs.remove(bank.id) }
                            model.changeSettings()
                        })) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(bank.title)
                                Text("\(bank.entries.count) words" + (bank.entries.contains { $0.verification != "verified" } ? " · under review" : "")).font(.caption).foregroundStyle(.secondary)
                            }
                        }.toggleStyle(.checkbox).padding(.vertical, 3)
                    }
                }
                Section("WORD FOCUS") {
                    Button("All parts of speech") { model.settings.parts = Set(PartOfSpeech.allCases); model.changeSettings() }
                    ForEach(PartOfSpeech.allCases, id: \.self) { part in
                        Toggle(part.label, isOn: Binding(get: { model.settings.parts.contains(part) }, set: { value in
                            if value { model.settings.parts.insert(part) } else { model.settings.parts.remove(part) }; model.changeSettings()
                        })).toggleStyle(.checkbox)
                    }
                }
                Section {
                    Button("Browse words…") { model.showLibrary = true }
                    Button("Import bank…", action: model.importBank)
                    Button("Review history…") { model.showHistory = true }
                }
            }.navigationTitle("말  Mal").navigationSplitViewColumnWidth(min: 230, ideal: 250)
        } detail: {
            VStack(alignment: .leading, spacing: 24) {
                HStack {
                    Picker("Direction", selection: $model.settings.direction) { ForEach(Direction.allCases, id: \.self) { Text($0.label).tag($0) } }.labelsHidden()
                    Picker("Answer mode", selection: $model.settings.mode) { ForEach(AnswerMode.allCases, id: \.self) { Text($0.label).tag($0) } }.labelsHidden()
                }
                .onChange(of: model.settings.direction) { _, _ in model.changeSettings() }
                .onChange(of: model.settings.mode) { _, _ in model.changeSettings() }
                HStack(spacing: 18) {
                    Label("\(model.dueCount) due", systemImage: "clock")
                    Text("\(model.learningCount) learning")
                    Text("\(model.recognizedCount) recognized")
                    Spacer()
                }.font(.callout).foregroundStyle(.secondary)
                Divider()
                if let entry = model.current {
                    ScrollView { studyCard(entry) }.scrollIndicators(.hidden)
                } else {
                    ContentUnavailableView {
                        Label("Nothing ready right now", systemImage: "cup.and.saucer")
                    } description: {
                        if let due = model.nextDue { Text("Next review: \(due.formatted(date: .abbreviated, time: .shortened))") }
                        Text("No unseen words remain in the selected banks and categories. Select more vocabulary, or return when a review is due.")
                    } actions: { Button("Check again", action: model.checkAgain) }
                }
                Spacer(minLength: 0)
                Divider()
                HStack {
                    Text(model.feedback.isEmpty ? "A little Korean, at your pace." : model.feedback).font(.callout).textSelection(.enabled)
                    Spacer()
                    Button("Undo", action: model.undo).disabled(model.history.allSatisfy(\.undone))
                }.frame(minHeight: 36)
            }.padding(32)
        }
        .alert("Mal", isPresented: Binding(get: { model.error != nil }, set: { if !$0 { model.error = nil } })) { Button("OK") { model.error = nil } } message: { Text(model.error ?? "") }
        .sheet(isPresented: $model.showLibrary) { LibraryView(model: model) }
        .sheet(isPresented: $model.showHistory) { HistoryView(model: model) }
    }
    @ViewBuilder private func studyCard(_ entry: Entry) -> some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack {
                Text(entry.partOfSpeech.label.uppercased()).font(.caption).tracking(1.5).foregroundStyle(.secondary)
                Spacer()
                Button { model.speak(entry) } label: { Image(systemName: "speaker.wave.2") }.help("Pronounce Korean · ⌘P")
            }
            Text(entry.prompt(model.settings.direction)).font(.system(size: 38, weight: .medium)).textSelection(.enabled)
                .accessibilityIdentifier("studyPrompt")
            if !model.waiting && model.settings.mode == .multipleChoice {
                if model.choices.count < 2 {
                    Text("This bank has no distinct distractor. Switch to write-in or select another bank.").foregroundStyle(.secondary)
                } else {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                        ForEach(Array(model.choices.enumerated()), id: \.offset) { index, choice in
                            Button { model.submit(choice) } label: {
                                HStack { Text(index == 9 ? "0" : String(index + 1)).font(.caption.monospaced()).foregroundStyle(.secondary); Text(choice).font(.system(size: 30)).multilineTextAlignment(.leading).fixedSize(horizontal: false, vertical: true); Spacer() }.padding(10).frame(maxWidth: .infinity, minHeight: 48)
                            }.buttonStyle(.bordered).keyboardShortcut(KeyEquivalent(Character(index == 9 ? "0" : String(index + 1))), modifiers: []).disabled(model.waiting)
                        }
                    }
                    if model.choices.count < model.settings.choiceCount { Text("\(model.choices.count) distinct choices available in the selected banks.").font(.caption).foregroundStyle(.secondary) }
                }
            } else if !model.waiting {
                IMETextField(text: $model.answer, enabled: !model.waiting) { model.submit() }.frame(height: 48)
                if !model.waiting { Text("Return to submit · Hangul spelling matters").font(.caption).foregroundStyle(.secondary) }
            }
            if model.waiting {
                VStack(alignment: .leading, spacing: 12) {
                    Label("Incorrect", systemImage: "xmark.circle.fill").font(.headline).foregroundStyle(.red)
                    Text("Your answer: " + model.answer).foregroundStyle(.secondary).textSelection(.enabled)
                    Text(entry.answer(model.settings.direction)).font(.system(size: 30)).textSelection(.enabled)
                    if let notes = entry.notes?.components(separatedBy: "\n").filter({ !$0.hasPrefix("Source:") && !$0.hasPrefix("Source sense:") }).joined(separator: "\n"), !notes.isEmpty { Text(notes).font(.callout).foregroundStyle(.secondary) }
                    HStack {
                        Button("Continue", action: model.next).buttonStyle(.borderedProminent).keyboardShortcut(.defaultAction)
                        Spacer()
                        Menu {
                            Button("Count my answer as correct") { model.saveAlias = false; model.acceptAnswer() }
                            Button("Count as correct and remember this answer") { model.saveAlias = true; model.acceptAnswer() }
                        } label: { Image(systemName: "ellipsis") }
                        .menuStyle(.borderlessButton).fixedSize().help("Answer options").accessibilityLabel("Answer options")
                    }
                }.padding().background(.quaternary, in: RoundedRectangle(cornerRadius: 10))
            }
        }
    }
}
struct SettingsView: View {
    @Bindable var model: StudyModel
    var body: some View {
        Form {
            Picker("Multiple-choice answers", selection: $model.settings.choiceCount) { ForEach([4,6,8,10], id: \.self) { Text("\($0)").tag($0) } }
            Stepper("Learning pool target: \(model.settings.learningLimit)", value: $model.settings.learningLimit, in: 1...100)
            Text("The pool target limits new-word mixing while reviews are ready. When nothing is due, new words continue automatically. Each direction and answer mode keeps separate progress.").font(.caption).foregroundStyle(.secondary)
            Button("Back Up Progress…", action: model.backup)
        }.onChange(of: model.settings) { _, _ in model.changeSettings() }
    }
}
struct LibraryView: View {
    @Bindable var model: StudyModel
    var body: some View {
        VStack(alignment: .leading) {
            HStack { Text("Word banks").font(.title); Spacer(); Button("Done") { model.showLibrary = false }.keyboardShortcut(.cancelAction) }
            TextField("Search Korean or English", text: $model.search)
            List(model.filteredLibrary) { entry in
                VStack(alignment: .leading, spacing: 5) {
                    HStack { Text(entry.lemma).font(.title3); Text(entry.english.joined(separator: "; ")); Spacer(); Text(entry.verification).font(.caption).foregroundStyle(.secondary); Button { model.speak(entry) } label: { Image(systemName: "speaker.wave.2") } }
                    Text(entry.koreanForms.map(\.text).joined(separator: " · ")).foregroundStyle(.secondary)
                    if let cue = entry.promptCue { Text(cue).font(.caption) }
                    if let notes = entry.notes { Text(notes).font(.caption) }
                }.textSelection(.enabled).padding(.vertical, 4)
            }
            Text("Content status is shown per entry. ‘Checked’ means editorially reviewed; ‘verified’ requires independent source review.").font(.caption).foregroundStyle(.secondary)
        }.padding(24).frame(width: 800, height: 600)
    }
}
struct HistoryView: View {
    @Bindable var model: StudyModel
    var body: some View {
        VStack {
            HStack { Text("Recent answers").font(.title); Spacer(); Button("Done") { model.showHistory = false }.keyboardShortcut(.cancelAction) }
            List(model.history) { item in
                HStack {
                    Image(systemName: item.undone ? "arrow.uturn.backward" : item.correct ? "checkmark" : "xmark")
                    VStack(alignment: .leading) {
                        Text(item.answer)
                        Text("\(item.key.direction.label) · \(item.key.mode.label) · \(item.key.entryID)").font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer(); Text(item.timestamp, style: .date); Text(item.timestamp, style: .time)
                }
            }
        }.padding(24).frame(width: 800, height: 550)
    }
}

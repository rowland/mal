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
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Picker("Direction", selection: $model.settings.direction) { ForEach(Direction.allCases, id: \.self) { Text($0.label).tag($0) } }.labelsHidden()
                    Picker("Answer mode", selection: $model.settings.mode) { ForEach(AnswerMode.allCases, id: \.self) { Text($0.label).tag($0) } }.labelsHidden()
                    Picker("Practice form", selection: Binding(get: { model.practiceStyle }, set: { model.settings.formStyle = $0; model.changeSettings() })) {
                        ForEach(KoreanPracticeStyle.allCases, id: \.self) { Text($0.label).tag($0) }
                    }.labelsHidden().fixedSize().help(model.practiceStyle.explanation)
                }
                .onChange(of: model.settings.direction) { _, _ in model.changeSettings() }
                .onChange(of: model.settings.mode) { _, _ in model.changeSettings() }
                if model.unavailableFormCount > 0 {
                    Text("\(model.unavailableFormCount) words have no listed form for this style and are skipped.").font(.caption).foregroundStyle(.secondary)
                }
                HStack(spacing: 18) {
                    Label("\(model.dueCount) due", systemImage: "clock").help("Ready by elapsed time or intervening answers, whichever comes first.")
                    Text("\(model.learningCount) learning")
                    Text("\(model.recognizedCount) recognized").help("Words in ongoing multiple-choice review, including those due again. Recognition never ends review.")
                    Spacer()
                }.font(.callout).foregroundStyle(.secondary)
                Divider()
                if let entry = model.current {
                    ScrollView { studyCard(entry).frame(maxWidth: .infinity, alignment: .leading) }
                } else {
                    ContentUnavailableView {
                        Label("Nothing ready right now", systemImage: "cup.and.saucer")
                    } description: {
                        if let due = model.nextDue { Text("Next review: \(due.formatted(date: .abbreviated, time: .shortened))") }
                        Text("No unseen words remain in the selected banks and categories. Select more vocabulary, or return when a review is due.")
                    } actions: { Button("Check again", action: model.checkAgain) }
                }
                Divider()
                HStack {
                    if !model.waiting {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(model.feedback.isEmpty ? "A little Korean, at your pace." : model.feedback).font(.callout).textSelection(.enabled)
                            if let next = model.nextCheckDescription { Text(next).font(.caption).foregroundStyle(.secondary) }
                        }
                    }
                    Spacer()
                    if model.waiting {
                        Menu("Grading options") {
                            Button("Count my answer as correct") { model.saveAlias = false; model.acceptAnswer() }
                            if !model.focusedForm { Button("Count as correct and remember this answer") { model.saveAlias = true; model.acceptAnswer() } }
                        }.menuStyle(.borderlessButton).fixedSize()
                            .foregroundStyle(.secondary)
                    }
                    Button("Undo", action: model.undo).disabled(model.history.allSatisfy(\.undone))
                }.frame(minHeight: 24)
            }.padding(.horizontal, 24).padding(.vertical, 16)
        }
        .alert("Mal", isPresented: Binding(get: { model.error != nil }, set: { if !$0 { model.error = nil } })) { Button("OK") { model.error = nil } } message: { Text(model.error ?? "") }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didResignActiveNotification)) { _ in model.pauseDictation() }
        .onChange(of: model.showLibrary) { _, shown in model.pauseDictation(); if !shown { model.beginSpokenAnswer() } }
        .onChange(of: model.showHistory) { _, shown in model.pauseDictation(); if !shown { model.beginSpokenAnswer() } }
        .onDisappear { model.pauseDictation() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in model.beginSpokenAnswer() }
        .sheet(isPresented: $model.showLibrary) { LibraryView(model: model) }
        .sheet(isPresented: $model.showHistory) { HistoryView(model: model) }
    }
    @ViewBuilder private func studyCard(_ entry: Entry) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(entry.partOfSpeech.label.uppercased()).font(.caption).tracking(1.5).foregroundStyle(.secondary)
                Spacer()
                Toggle("Auto", isOn: Binding(get: { model.settings.automaticPronunciation == true }, set: { model.setAutomaticPronunciation($0) }))
                    .toggleStyle(.checkbox).fixedSize()
                    .help("Automatically speak Korean prompts or your selected/entered Korean answer")
                    .accessibilityLabel("Automatic Korean pronunciation")
                Button { model.speak(entry) } label: { Image(systemName: "speaker.wave.2") }.help("Pronounce Korean · ⌘P")
            }
            if model.introducing {
                Text(model.reintroducing ? "LET’S REVIEW" : "INTRODUCTION").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            }
            Text(model.introducing ? model.koreanText(entry) : model.studyPrompt(entry)).font(.system(size: 38, weight: .medium)).textSelection(.enabled)
                .accessibilityIdentifier("studyPrompt")
            if model.focusedForm {
                Text(model.practiceStyle.label + (model.practiceStyle == .attributive ? " · before a noun" : " · present affirmative"))
                    .font(.callout).foregroundStyle(.secondary)
                    .help(model.practiceStyle.explanation)
            }
            if !model.introducing && model.settings.direction == .koreanToEnglish, let cue = entry.promptCue, !cue.isEmpty {
                if model.hintRevealed || model.waiting {
                    Text("Hint: " + cue).font(.callout).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Button("Show hint") { model.hintRevealed = true }
                        .buttonStyle(.borderless).font(.callout)
                }
            }
            if model.introducing {
                VStack(alignment: .leading, spacing: 16) {
                    Text(entry.english.joined(separator: "; "))
                        .font(.system(size: 30)).textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                    if model.koreanText(entry) != entry.lemma {
                        Text("Dictionary form: " + entry.lemma).font(.callout).foregroundStyle(.secondary)
                    }
                    if let cue = entry.promptCue, !cue.isEmpty {
                        Text(cue).font(.callout).foregroundStyle(.secondary)
                    }
                    Text(model.reintroducing ? "Review this word, then continue. We’ll ask again later." : "Take a moment to learn this word, then continue to practice.")
                        .font(.callout).foregroundStyle(.secondary)
                    HStack(spacing: 12) {
                        Button("Continue", action: model.continueIntroduction)
                            .buttonStyle(.borderedProminent).controlSize(.large)
                            .keyboardShortcut(.defaultAction)
                        Text("Press Return ↵").font(.callout).foregroundStyle(.secondary)
                    }
                }.padding(.top, 8)
            } else if !model.waiting && model.settings.mode == .multipleChoice {
                if model.choices.count < 2 {
                    Text("This bank has no distinct distractor. Switch to write-in or select another bank.").foregroundStyle(.secondary)
                } else {
                    VStack(spacing: 8) {
                        ForEach(model.choices.indices, id: \.self) { index in
                        let key = index == 9 ? "0" : String(index + 1)
                        Button { model.submit(model.choices[index]) } label: {
                            HStack(alignment: .firstTextBaseline, spacing: 14) {
                                Text(key).font(.system(size: 28, weight: .semibold, design: .monospaced))
                                    .frame(minWidth: 24)
                                Text(model.choices[index]).font(.system(size: 30))
                                    .lineLimit(nil).multilineTextAlignment(.leading)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .fixedSize(horizontal: false, vertical: true)
                                Spacer(minLength: 0)
                            }.padding(.horizontal, 14).padding(.vertical, 8)
                                .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
                                .background(.quaternary, in: RoundedRectangle(cornerRadius: 6))
                                .contentShape(RoundedRectangle(cornerRadius: 6))
                        }.buttonStyle(.plain)
                            .keyboardShortcut(KeyEquivalent(Character(key)), modifiers: [])
                            .accessibilityLabel("Choice \(key): \(model.choices[index])")
                        }
                    }.id(model.choices)
                    if model.choices.count < model.settings.choiceCount { Text("\(model.choices.count) distinct choices available in the selected banks.").font(.caption).foregroundStyle(.secondary) }
                }
            } else if !model.waiting {
                IMETextField(text: $model.answer, enabled: !model.waiting && (!model.spokenPractice || model.editingSpokenAnswer), answerLanguage: model.settings.direction == .englishToKorean ? "ko" : "en") { model.submit() }.frame(height: 48)
                if model.settings.direction == .englishToKorean {
                    Picker("Answer input", selection: Binding(get: { model.settings.spokenAnswers == true }, set: { model.setSpokenAnswers($0) })) {
                        Text("Write-in").tag(false)
                        Text("Speak Korean").tag(true)
                    }.pickerStyle(.segmented).fixedSize()
                    if model.spokenPractice {
                        HStack {
                            Text(model.editingSpokenAnswer ? "Editing this answer · Return submits" : "Return submits · Escape edits")
                                .font(.caption).foregroundStyle(.secondary)
                            Button(model.editingSpokenAnswer || !model.dictation.active ? "Resume listening" : "Edit answer", action: model.toggleDictation)
                                .keyboardShortcut("r", modifiers: [.command, .shift])
                        }
                    }
                    if model.dictation.needsDownload && !model.dictation.active {
                        Button("Download Korean speech model") { Task { await model.dictation.installModel(); model.beginSpokenAnswer() } }
                    }
                    if !model.dictation.status.isEmpty {
                        Text(model.dictation.status).font(.callout).foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                if !model.waiting { Text("Return to submit · Hangul spelling matters").font(.caption).foregroundStyle(.secondary) }
            }
            if !model.introducing && !model.waiting {
                Button("I don’t know", action: model.dontKnow)
                    .buttonStyle(.borderless).font(.callout)
                    .keyboardShortcut("k", modifiers: .command)
                    .help("Review the meaning and try again later · ⌘K")
            }
            if model.waiting {
                VStack(alignment: .leading, spacing: 18) {
                    Label("Incorrect", systemImage: "xmark.circle.fill")
                        .font(.system(size: 16, weight: .semibold)).foregroundStyle(.red)

                    VStack(alignment: .leading, spacing: 6) {
                        Label("Correct answer", systemImage: "checkmark.circle")
                            .font(.callout.weight(.semibold)).foregroundStyle(.secondary)
                        Text(model.correctAnswer(entry))
                            .font(.system(size: 34, weight: .medium))
                            .lineLimit(nil).fixedSize(horizontal: false, vertical: true)
                            .textSelection(.enabled)
                    }.frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                        .background(Color.accentColor.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Your answer").font(.callout).foregroundStyle(.secondary)
                        Text(model.answer).font(.system(size: 26))
                            .lineLimit(nil).fixedSize(horizontal: false, vertical: true)
                            .textSelection(.enabled)
                    }.padding(.horizontal, 16)

                    if let notes = entry.notes?.components(separatedBy: "\n").filter({ !$0.hasPrefix("Source:") && !$0.hasPrefix("Source sense:") }).joined(separator: "\n"), !notes.isEmpty {
                        Text(notes).font(.callout).foregroundStyle(.secondary)
                            .lineLimit(nil).fixedSize(horizontal: false, vertical: true)
                            .padding(.horizontal, 16)
                    }
                    HStack(spacing: 12) {
                        Button("Continue", action: model.next)
                            .buttonStyle(.borderedProminent).controlSize(.large)
                            .keyboardShortcut(.defaultAction)
                        Text("Press Return ↵").font(.callout).foregroundStyle(.secondary)
                        Spacer()
                    }
                }.padding(.top, 8)

            }
        }
    }
}
struct SettingsView: View {
    @Bindable var model: StudyModel
    var body: some View {
        Form {
            Picker("Multiple-choice answers", selection: $model.settings.choiceCount) { ForEach([4,5,6,8,10], id: \.self) { Text("\($0)").tag($0) } }
            Stepper("Words awaiting first repeat: \(model.settings.firstRepeatLimit ?? 4)", value: Binding(get: { model.settings.firstRepeatLimit ?? 4 }, set: { model.settings.firstRepeatLimit = $0 }), in: 1...20)
            Text("Words return when either their time or answer-count deadline arrives. New words are mixed gradually, with at most this many awaiting an early repeat. Recognized words remain in ongoing review. Each direction, form style and answer mode has its own answer clock.").font(.caption).foregroundStyle(.secondary)
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
                    if !entry.koreanForms.isEmpty {
                        DisclosureGroup("Listed forms") {
                            ForEach(KoreanPracticeStyle.allCases.filter { $0 != .dictionary && FormPractice.applies(entry, style: $0) }, id: \.self) { style in
                                let forms = FormPractice.forms(entry, style: style)
                                if !forms.isEmpty { Text(style.label + ": " + forms.joined(separator: " · ")).foregroundStyle(.secondary) }
                            }
                        }
                    }
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
                        Text(item.didNotKnow ? "I don’t know" : item.answer)
                        Text("\(item.key.direction.label) · \(item.key.mode.label) · \(item.key.formStyle?.label ?? "Vocabulary") · \(item.key.entryID)").font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer(); Text(item.timestamp, style: .date); Text(item.timestamp, style: .time)
                }
            }
        }.padding(24).frame(width: 800, height: 550)
    }
}

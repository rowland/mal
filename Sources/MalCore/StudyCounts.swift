import Foundation

public struct StudyCounts: Equatable, Sendable {
    public var learning = 0
    public var review = 0
    public var due = 0
    public var total: Int { learning + review }
    public static func calculate(keys: Set<CardKey>, states: [CardKey: LearningState], sequences: [String: Int], now: Date, introduction: CardKey? = nil) -> StudyCounts {
        var counts = StudyCounts()
        for key in keys {
            guard let state = states[key] else {
                if key == introduction { counts.learning += 1 }
                continue
            }
            if state.phase == .maintenance { counts.review += 1 } else { counts.learning += 1 }
            if Scheduler.isDue(state, now: now, sequence: sequences[state.clockTrackID ?? key.trackID, default: 0]) { counts.due += 1 }
        }
        return counts
    }
}

/// Current work completed in one track, not permanent mastery.
public struct CurrentCompletion: Equatable, Sendable {
    public let complete: Int
    public let possible: Int
    public static func calculate(keys: Set<CardKey>, states: [CardKey: LearningState], sequences: [String: Int], now: Date) -> CurrentCompletion {
        let complete = keys.filter { key in
            guard let state = states[key] else { return false }
            return !Scheduler.isDue(state, now: now, sequence: sequences[state.clockTrackID ?? key.trackID, default: 0])
        }.count
        return CurrentCompletion(complete: complete, possible: keys.count)
    }
}

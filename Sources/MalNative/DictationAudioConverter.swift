import Foundation
import AVFAudio

/// Converts microphone buffers into independent buffers suitable for asynchronous analysis.
/// The lock serializes converter access, including its synchronous input callback.
public final class DictationAudioConverter: @unchecked Sendable {
    private let converter: AVAudioConverter
    private let format: AVAudioFormat
    private let lock = NSLock()
    public init?(from source: AVAudioFormat, to destination: AVAudioFormat) {
        guard source.sampleRate > 0, source.channelCount > 0,
              let converter = AVAudioConverter(from: source, to: destination) else { return nil }
        self.converter = converter; format = destination
    }
    public func convert(_ buffer: AVAudioPCMBuffer) throws -> AVAudioPCMBuffer? {
        lock.lock(); defer { lock.unlock() }
        let capacity = AVAudioFrameCount(ceil(Double(buffer.frameLength) * format.sampleRate / buffer.format.sampleRate)) + 32
        guard let output = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: capacity) else { return nil }
        let supply = BufferSupply(buffer)
        var error: NSError?
        converter.convert(to: output, error: &error) { _, state in supply.take(state) }
        if let error { throw error }
        return output.frameLength > 0 ? output : nil
    }
}

// AVAudioConverter invokes this callback synchronously. Lock the one-shot delivery
// flag and keep the borrowed input alive for the duration of convert().
private final class BufferSupply: @unchecked Sendable {
    let buffer: AVAudioPCMBuffer
    private let lock = NSLock()
    private var supplied = false
    init(_ buffer: AVAudioPCMBuffer) { self.buffer = buffer }
    func take(_ status: UnsafeMutablePointer<AVAudioConverterInputStatus>) -> AVAudioBuffer? {
        lock.lock(); defer { lock.unlock() }
        guard !supplied else { status.pointee = .noDataNow; return nil }
        supplied = true; status.pointee = .haveData; return buffer
    }
}

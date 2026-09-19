import AVFAudio
import Foundation

public enum AudioLevel {
    public static func decibels(_ buffer: AVAudioPCMBuffer) -> Double {
        guard buffer.frameLength > 0 else { return -100 }
        var sum = 0.0, count = 0
        for audio in UnsafeMutableAudioBufferListPointer(buffer.mutableAudioBufferList) {
            guard let data = audio.mData else { continue }
            let samples = Int(buffer.frameLength) * Int(audio.mNumberChannels)
            for index in 0..<samples {
                let sample: Double
                switch buffer.format.commonFormat {
                case .pcmFormatFloat32: sample = Double(data.assumingMemoryBound(to: Float.self)[index])
                case .pcmFormatFloat64: sample = data.assumingMemoryBound(to: Double.self)[index]
                case .pcmFormatInt16: sample = Double(data.assumingMemoryBound(to: Int16.self)[index]) / 32768
                case .pcmFormatInt32: sample = Double(data.assumingMemoryBound(to: Int32.self)[index]) / 2147483648
                default: return -100
                }
                sum += sample * sample; count += 1
            }
        }
        guard count > 0 else { return -100 }
        return 20 * log10(max(0.00001, sqrt(sum / Double(count))))
    }
}

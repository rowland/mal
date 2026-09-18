import Testing
import AVFAudio
import MalNative

@Test func dictationConvertsStereoMicrophoneAudioToIndependentMonoBuffers() throws {
    let source = try #require(AVAudioFormat(standardFormatWithSampleRate: 48000, channels: 2))
    let destination = try #require(AVAudioFormat(standardFormatWithSampleRate: 16000, channels: 1))
    let converter = try #require(DictationAudioConverter(from: source, to: destination))
    let microphone = try #require(AVAudioPCMBuffer(pcmFormat: source, frameCapacity: 4800))
    microphone.frameLength = 4800
    for channel in 0..<2 {
        for frame in 0..<4800 { microphone.floatChannelData![channel][frame] = 0.25 }
    }
    let converted = try #require(try converter.convert(microphone))
    #expect(converted.format.sampleRate == 16000)
    #expect(converted.format.channelCount == 1)
    #expect(converted.frameLength > 1000 && converted.frameLength <= 1632)
    let value = converted.floatChannelData![0][500]
    #expect(abs(value - 0.25) < 0.01)
    microphone.floatChannelData![0][1500] = 0
    #expect(converted.floatChannelData![0][500] == value)
}

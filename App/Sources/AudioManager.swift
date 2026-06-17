import AVFoundation

/// Plays short synthesized sound effects. No audio asset files — each effect is
/// a generated tone/noise buffer. Gated by a persisted mute flag.
final class AudioManager {
    static let shared = AudioManager()
    enum SFX { case kick, goal, save, miss }

    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)!
    private var started = false

    var isMuted: Bool {
        didSet { UserDefaults.standard.set(isMuted, forKey: "audio.muted") }
    }

    private init() {
        isMuted = UserDefaults.standard.bool(forKey: "audio.muted")
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: format)
    }

    private func startIfNeeded() {
        guard !started else { return }
        try? AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
        try? engine.start()
        player.play()
        started = engine.isRunning
    }

    func play(_ sfx: SFX) {
        guard !isMuted else { return }
        startIfNeeded()
        guard engine.isRunning else { return }
        player.scheduleBuffer(buffer(for: sfx), at: nil, options: [], completionHandler: nil)
    }

    private func buffer(for sfx: SFX) -> AVAudioPCMBuffer {
        switch sfx {
        case .kick: return tone(freqs: [140], duration: 0.12, decay: 14, noise: 0.18)
        case .goal: return tone(freqs: [523, 659, 784], duration: 0.45, decay: 4)
        case .save: return tone(freqs: [320], duration: 0.16, decay: 10, noise: 0.6)
        case .miss: return tone(freqs: [196], duration: 0.30, decay: 5)
        }
    }

    private func tone(freqs: [Double], duration: Double, decay: Double,
                      noise: Double = 0) -> AVAudioPCMBuffer {
        let sr = 44_100.0
        let count = AVAudioFrameCount(duration * sr)
        let buf = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: count)!
        buf.frameLength = count
        let channel = buf.floatChannelData![0]
        for i in 0..<Int(count) {
            let t = Double(i) / sr
            var sample = 0.0
            for f in freqs { sample += sin(2 * .pi * f * t) }
            sample /= Double(freqs.count)
            if noise > 0 { sample = sample * (1 - noise) + noise * Double.random(in: -1...1) }
            channel[i] = Float(sample * exp(-t * decay) * 0.35)
        }
        return buf
    }
}

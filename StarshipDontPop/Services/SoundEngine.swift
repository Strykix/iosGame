import AVFoundation

/// 100% procedural audio: engine rumble from filtered noise + tiny synth voices for SFX.
/// No music, no copyrighted samples. Uses the `.ambient` session so players keep their own music.
@MainActor
final class SoundEngine {
    enum SFX {
        case ui
        case liftoff
        case separation
        case cleanStaging
        case nearMiss
        case heatWarning
        case tier
        case rud
        case splat
        case turtle
        case noSignal
        case pfff
        case orbit
    }

    var isEnabled = true {
        didSet {
            if !isEnabled { synth.setEngine(level: 0, brightness: 0) }
        }
    }

    private let engine = AVAudioEngine()
    private let synth = Synth()
    private var started = false

    func start() {
        guard !started else { return }
        do {
            try AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            #if DEBUG
            print("Audio session: \(error)")
            #endif
        }
        let format = engine.outputNode.inputFormat(forBus: 0)
        let sampleRate = format.sampleRate > 0 ? format.sampleRate : 44_100
        synth.sampleRate = sampleRate
        guard let monoFormat = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1) else { return }
        let synth = self.synth
        let node = AVAudioSourceNode(format: monoFormat) { _, _, frameCount, audioBufferList in
            synth.render(frameCount: Int(frameCount), bufferList: audioBufferList)
            return noErr
        }
        engine.attach(node)
        engine.connect(node, to: engine.mainMixerNode, format: monoFormat)
        engine.mainMixerNode.outputVolume = 0.8
        do {
            try engine.start()
            started = true
        } catch {
            #if DEBUG
            print("Audio engine: \(error)")
            #endif
        }
    }

    func setEngine(throttle: Bool, velocity: Double, active: Bool) {
        guard isEnabled else { return }
        let level = active ? (throttle ? 0.55 : 0.08) : 0
        synth.setEngine(level: level, brightness: min(1, max(0, velocity / 7)))
    }

    func play(_ sfx: SFX) {
        guard isEnabled, started else { return }
        switch sfx {
        case .ui:
            synth.add(Voice(wave: .sine, from: 880, to: 1100, duration: 0.06, gain: 0.25))
        case .liftoff:
            synth.add(Voice(wave: .noise, from: 200, to: 900, duration: 1.2, gain: 0.5))
            synth.add(Voice(wave: .sine, from: 55, to: 75, duration: 1.2, gain: 0.5))
        case .separation:
            synth.add(Voice(wave: .sine, from: 140, to: 60, duration: 0.25, gain: 0.7))
            synth.add(Voice(wave: .noise, from: 3000, to: 400, duration: 0.3, gain: 0.4))
        case .cleanStaging:
            for (index, note) in [523.25, 659.25, 783.99].enumerated() {
                synth.add(Voice(wave: .square, from: note, to: note, duration: 0.12, gain: 0.16, delay: Double(index) * 0.07))
            }
        case .nearMiss:
            synth.add(Voice(wave: .noise, from: 400, to: 4000, duration: 0.25, gain: 0.35))
        case .heatWarning:
            synth.add(Voice(wave: .square, from: 1200, to: 1200, duration: 0.07, gain: 0.12))
            synth.add(Voice(wave: .square, from: 1200, to: 1200, duration: 0.07, gain: 0.12, delay: 0.12))
        case .tier:
            synth.add(Voice(wave: .sine, from: 300, to: 600, duration: 0.3, gain: 0.3))
        case .rud:
            synth.add(Voice(wave: .noise, from: 6000, to: 150, duration: 1.1, gain: 0.9))
            synth.add(Voice(wave: .sine, from: 90, to: 30, duration: 0.9, gain: 0.8))
        case .splat:
            synth.add(Voice(wave: .sine, from: 400, to: 60, duration: 0.5, gain: 0.6))
            synth.add(Voice(wave: .noise, from: 800, to: 200, duration: 0.3, gain: 0.5, delay: 0.35))
        case .turtle:
            for (index, note) in [392.0, 369.99, 349.23, 329.63].enumerated() {
                synth.add(Voice(wave: .square, from: note, to: note * 0.98, duration: 0.22, gain: 0.14, delay: Double(index) * 0.25))
            }
        case .noSignal:
            synth.add(Voice(wave: .noise, from: 9000, to: 9000, duration: 1.0, gain: 0.35))
            synth.add(Voice(wave: .sine, from: 1000, to: 1000, duration: 0.8, gain: 0.15, delay: 0.2))
        case .pfff:
            synth.add(Voice(wave: .noise, from: 1500, to: 300, duration: 0.8, gain: 0.3))
            synth.add(Voice(wave: .sine, from: 220, to: 110, duration: 0.6, gain: 0.25, delay: 0.1))
        case .orbit:
            for (index, note) in [523.25, 659.25, 783.99, 1046.5, 1318.5].enumerated() {
                synth.add(Voice(wave: .square, from: note, to: note, duration: 0.18, gain: 0.14, delay: Double(index) * 0.1))
            }
        }
    }

    func play(for event: GameEvent) {
        switch event {
        case .liftoff: play(.liftoff)
        case .separation: play(.separation)
        case .staged(let clean): if clean { play(.cleanStaging) }
        case .nearMiss: play(.nearMiss)
        case .heatWarning: play(.heatWarning)
        case .tierChanged: play(.tier)
        case .orbit: play(.orbit)
        case .failed(let reason):
            switch reason {
            case .rud: play(.rud)
            case .bellyFlop: play(.splat)
            case .turtleMode: play(.turtle)
            case .livestreamEnded: play(.noSignal)
            case .outOfFuel: play(.pfff)
            }
        case .enteredStagingWindow, .spicy:
            play(.ui)
        }
    }
}

// MARK: - Synth (runs on the audio thread)

struct Voice {
    enum Wave {
        case sine
        case square
        case noise
    }

    var wave: Wave
    var from: Double
    var to: Double
    var duration: Double
    var gain: Double
    var delay: Double = 0
    var elapsed: Double = 0
    var phase: Double = 0
    var filter: Double = 0
}

private final class Synth: @unchecked Sendable {
    var sampleRate: Double = 44_100
    private let lock = NSLock()
    private var voices: [Voice] = []
    private var pending: [Voice] = []
    private var engineTarget = 0.0
    private var engineLevel = 0.0
    private var brightness = 0.0
    private var brown = 0.0
    private var lowpass = 0.0
    private var rumblePhase = 0.0
    private var rng: UInt64 = 0x1234_5678

    func add(_ voice: Voice) {
        lock.lock()
        pending.append(voice)
        lock.unlock()
    }

    func setEngine(level: Double, brightness: Double) {
        lock.lock()
        engineTarget = level
        self.brightness = brightness
        lock.unlock()
    }

    private func white() -> Double {
        rng ^= rng << 13
        rng ^= rng >> 7
        rng ^= rng << 17
        return Double(rng % 20_000) / 10_000 - 1
    }

    func render(frameCount: Int, bufferList: UnsafeMutablePointer<AudioBufferList>) {
        lock.lock()
        voices.append(contentsOf: pending)
        pending.removeAll(keepingCapacity: true)
        let target = engineTarget
        let bright = brightness
        lock.unlock()

        let buffers = UnsafeMutableAudioBufferListPointer(bufferList)
        let dt = 1 / sampleRate
        let cutoff = 0.02 + bright * 0.08

        for frame in 0..<frameCount {
            engineLevel += (target - engineLevel) * 0.0008
            let noise = white()
            brown = (brown + 0.02 * noise) / 1.02
            lowpass += (brown * 3.5 - lowpass) * cutoff
            rumblePhase += 2 * .pi * (42 + bright * 30) * dt
            if rumblePhase > 2 * .pi { rumblePhase -= 2 * .pi }
            var sample = (lowpass + sin(rumblePhase) * 0.25) * engineLevel

            for index in voices.indices {
                var voice = voices[index]
                if voice.delay > 0 {
                    voice.delay -= dt
                    voices[index] = voice
                    continue
                }
                let progress = min(voice.elapsed / voice.duration, 1)
                let frequency = voice.from + (voice.to - voice.from) * progress
                let envelope = min(1, voice.elapsed * 200) * (1 - progress) * (1 - progress)
                var value: Double
                switch voice.wave {
                case .sine:
                    value = sin(voice.phase)
                case .square:
                    value = sin(voice.phase) >= 0 ? 0.6 : -0.6
                case .noise:
                    let alpha = min(1, frequency / sampleRate * 2 * .pi)
                    voice.filter += (white() - voice.filter) * alpha
                    value = voice.filter
                }
                voice.phase += 2 * .pi * frequency * dt
                if voice.phase > 2 * .pi { voice.phase -= 2 * .pi }
                voice.elapsed += dt
                sample += value * envelope * voice.gain
                voices[index] = voice
            }

            let output = Float(tanh(sample * 0.9))
            for buffer in buffers {
                guard let data = buffer.mData?.assumingMemoryBound(to: Float.self) else { continue }
                data[frame] = output
            }
        }
        voices.removeAll { $0.elapsed >= $0.duration }
    }
}

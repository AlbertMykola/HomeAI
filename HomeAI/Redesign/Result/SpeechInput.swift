import Foundation
import AVFoundation
import Speech

/// On-device dictation for "Ask for a change" (SFSpeechRecognizer + mic level). Auto-stops after 2 s of silence.
final class SpeechInput {

    var onText: ((String) -> Void)?
    var onLevel: ((CGFloat) -> Void)?
    var onSilenceTimeout: (() -> Void)?

    private let engine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private let recognizer = SFSpeechRecognizer(locale: Locale.current) ?? SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var silenceTimer: Timer?

    func requestAccess(_ completion: @escaping (Bool) -> Void) {
        SFSpeechRecognizer.requestAuthorization { status in
            guard status == .authorized else {
                DispatchQueue.main.async { completion(false) }
                return
            }
            let done: (Bool) -> Void = { granted in DispatchQueue.main.async { completion(granted) } }
            if #available(iOS 17.0, *) {
                AVAudioApplication.requestRecordPermission(completionHandler: done)
            } else {
                AVAudioSession.sharedInstance().requestRecordPermission(done)
            }
        }
    }

    func start() throws {
        stop()
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.record, mode: .measurement, options: .duckOthers)
        try session.setActive(true, options: .notifyOthersOnDeactivation)
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        if recognizer?.supportsOnDeviceRecognition == true { request.requiresOnDeviceRecognition = true }
        self.request = request
        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            request.append(buffer)
            self?.report(level: buffer)
        }
        engine.prepare()
        try engine.start()
        task = recognizer?.recognitionTask(with: request) { [weak self] result, error in
            guard let self else { return }
            if let text = result?.bestTranscription.formattedString {
                DispatchQueue.main.async {
                    self.onText?(text)
                    self.restartSilenceTimer()
                }
            }
            if error != nil || result?.isFinal == true { self.stopAudio() }
        }
        DispatchQueue.main.async { self.restartSilenceTimer() }
    }

    func stop() {
        silenceTimer?.invalidate()
        task?.cancel()
        task = nil
        stopAudio()
    }

    private func stopAudio() {
        if engine.isRunning {
            engine.stop()
            engine.inputNode.removeTap(onBus: 0)
        }
        request?.endAudio()
        request = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func restartSilenceTimer() {
        silenceTimer?.invalidate()
        silenceTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { [weak self] _ in
            self?.onSilenceTimeout?()
        }
    }

    private func report(level buffer: AVAudioPCMBuffer) {
        guard let data = buffer.floatChannelData?[0] else { return }
        let n = Int(buffer.frameLength)
        guard n > 0 else { return }
        var sum: Float = 0
        for i in stride(from: 0, to: n, by: 8) { sum += data[i] * data[i] }
        let rms = sqrt(sum / Float(n / 8))
        let level = CGFloat(min(1, max(0, (20 * log10(max(rms, 0.0001)) + 50) / 40)))
        DispatchQueue.main.async { self.onLevel?(level) }
    }
}

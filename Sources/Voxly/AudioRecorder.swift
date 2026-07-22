import AVFoundation
import CoreAudio
import os

private let log = Logger(subsystem: "com.voxly.app", category: "AudioRecorder")

final class AudioRecorder {
    private let engine = AVAudioEngine()
    private var audioBuffer: [Float] = []
    private let targetSampleRate: Double = 16000
    private let lock = NSLock()

    /// UID of the input device to record from. `nil` or the system-default
    /// sentinel means "use the current system default input".
    var preferredDeviceUID: String?

    func start() throws {
        lock.lock()
        audioBuffer.removeAll()
        lock.unlock()

        let inputNode = engine.inputNode
        applyPreferredDevice(to: inputNode)
        let inputFormat = inputNode.outputFormat(forBus: 0)

        guard inputFormat.sampleRate > 0 else {
            throw AudioRecorderError.noInputDevice
        }
        log.notice("Input tap format: \(inputFormat.sampleRate, format: .fixed(precision: 0))Hz \(inputFormat.channelCount)ch")

        // Target format: 16kHz mono Float32
        guard let targetFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: targetSampleRate,
            channels: 1,
            interleaved: false
        ) else {
            throw AudioRecorderError.formatCreationFailed
        }

        guard let converter = AVAudioConverter(from: inputFormat, to: targetFormat) else {
            throw AudioRecorderError.converterCreationFailed
        }

        inputNode.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { [weak self] buffer, _ in
            self?.processBuffer(buffer, converter: converter, targetFormat: targetFormat)
        }

        engine.prepare()
        try engine.start()
    }

    func stop() {
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
    }

    /// Point the engine's input HAL unit at the user-selected device. Must run
    /// before reading `inputFormat` / installing the tap so the format reflects
    /// the chosen device. Falls back silently to the system default when the
    /// device is unset, unavailable, or the property set fails.
    private func applyPreferredDevice(to inputNode: AVAudioInputNode) {
        guard let uid = preferredDeviceUID,
              let deviceID = AudioDeviceEnumerator.deviceID(forUID: uid) else {
            return
        }
        guard let audioUnit = inputNode.audioUnit else {
            log.error("Input node has no audio unit; using default device")
            return
        }
        var mutableDeviceID = deviceID
        let status = AudioUnitSetProperty(
            audioUnit,
            kAudioOutputUnitProperty_CurrentDevice,
            kAudioUnitScope_Global,
            0,
            &mutableDeviceID,
            UInt32(MemoryLayout<AudioDeviceID>.size)
        )
        if status != noErr {
            log.error("Failed to set input device \(uid, privacy: .public): \(status)")
        }
    }

    func getAudioData() -> [Float] {
        lock.lock()
        let data = audioBuffer
        lock.unlock()
        return data
    }

    private func processBuffer(
        _ buffer: AVAudioPCMBuffer,
        converter: AVAudioConverter,
        targetFormat: AVAudioFormat
    ) {
        let frameCount = AVAudioFrameCount(
            Double(buffer.frameLength) * targetSampleRate / buffer.format.sampleRate
        )

        guard frameCount > 0,
              let convertedBuffer = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: frameCount)
        else { return }

        var error: NSError?
        var hasData = false

        converter.convert(to: convertedBuffer, error: &error) { _, outStatus in
            if hasData {
                outStatus.pointee = .noDataNow
                return nil
            }
            hasData = true
            outStatus.pointee = .haveData
            return buffer
        }

        if error != nil { return }

        guard let channelData = convertedBuffer.floatChannelData else { return }
        let frames = Int(convertedBuffer.frameLength)

        lock.lock()
        audioBuffer.append(contentsOf: UnsafeBufferPointer(start: channelData[0], count: frames))
        lock.unlock()
    }
}

enum AudioRecorderError: LocalizedError {
    case noInputDevice
    case formatCreationFailed
    case converterCreationFailed

    var errorDescription: String? {
        switch self {
        case .noInputDevice: return "No audio input device available"
        case .formatCreationFailed: return "Failed to create target audio format"
        case .converterCreationFailed: return "Failed to create audio converter"
        }
    }
}

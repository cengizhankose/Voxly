import AVFoundation
import CoreAudio
import os

private let log = Logger(subsystem: "com.voxly.app", category: "AudioInputDevice")

/// A selectable microphone input device.
///
/// `id` is the CoreAudio device UID — a stable string that survives reboots and
/// re-plugging, unlike the numeric `AudioDeviceID` which is reassigned by the
/// HAL. The UID is what we persist in `SettingsStore`.
struct AudioInputDevice: Identifiable, Hashable {
    let id: String
    let name: String
    let deviceID: AudioDeviceID

    /// Sentinel UID meaning "follow whatever the system default input is".
    static let systemDefaultUID = "__system_default__"
}

/// CoreAudio queries for enumerating input devices and resolving stored UIDs.
enum AudioDeviceEnumerator {
    /// Every device that currently exposes at least one input channel.
    static func inputDevices() -> [AudioInputDevice] {
        allDeviceIDs().compactMap { deviceID in
            guard inputChannelCount(deviceID) > 0,
                  let uid = stringProperty(deviceID, kAudioDevicePropertyDeviceUID),
                  let name = stringProperty(deviceID, kAudioObjectPropertyName)
            else { return nil }
            return AudioInputDevice(id: uid, name: name, deviceID: deviceID)
        }
    }

    /// Resolve a persisted UID to a live `AudioDeviceID`. Returns nil when the
    /// UID is the system-default sentinel or the device is not connected.
    static func deviceID(forUID uid: String) -> AudioDeviceID? {
        guard uid != AudioInputDevice.systemDefaultUID else { return nil }
        return inputDevices().first { $0.id == uid }?.deviceID
    }

    // MARK: CoreAudio plumbing

    private static func allDeviceIDs() -> [AudioDeviceID] {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var dataSize: UInt32 = 0
        var status = AudioObjectGetPropertyDataSize(
            AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &dataSize
        )
        guard status == noErr, dataSize > 0 else {
            if status != noErr { log.error("Device list size query failed: \(status)") }
            return []
        }

        let count = Int(dataSize) / MemoryLayout<AudioDeviceID>.size
        var deviceIDs = [AudioDeviceID](repeating: 0, count: count)
        status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &dataSize, &deviceIDs
        )
        guard status == noErr else {
            log.error("Device list query failed: \(status)")
            return []
        }
        return deviceIDs
    }

    private static func inputChannelCount(_ deviceID: AudioDeviceID) -> Int {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreamConfiguration,
            mScope: kAudioObjectPropertyScopeInput,
            mElement: kAudioObjectPropertyElementMain
        )
        var dataSize: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(deviceID, &address, 0, nil, &dataSize) == noErr,
              dataSize > 0
        else { return 0 }

        let bufferList = UnsafeMutableRawPointer.allocate(
            byteCount: Int(dataSize),
            alignment: MemoryLayout<AudioBufferList>.alignment
        )
        defer { bufferList.deallocate() }

        guard AudioObjectGetPropertyData(deviceID, &address, 0, nil, &dataSize, bufferList) == noErr
        else { return 0 }

        let ablPointer = UnsafeMutableAudioBufferListPointer(
            bufferList.assumingMemoryBound(to: AudioBufferList.self)
        )
        return ablPointer.reduce(0) { $0 + Int($1.mNumberChannels) }
    }

    private static func stringProperty(
        _ deviceID: AudioDeviceID,
        _ selector: AudioObjectPropertySelector
    ) -> String? {
        var address = AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var value: CFString?
        var dataSize = UInt32(MemoryLayout<CFString?>.size)
        let status = withUnsafeMutablePointer(to: &value) { pointer in
            AudioObjectGetPropertyData(deviceID, &address, 0, nil, &dataSize, pointer)
        }
        guard status == noErr, let value else { return nil }
        return value as String
    }
}

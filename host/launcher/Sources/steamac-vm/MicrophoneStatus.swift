import AppKit
import AVFoundation
import Combine
import CoreAudio

/// Permission and device state only. Opening Settings must not start a recording.
final class MicrophoneStatus: ObservableObject {
    @Published private(set) var permission = AVCaptureDevice.authorizationStatus(for: .audio)
    @Published private(set) var inputName: String?
    @Published private(set) var active = false
    @Published private(set) var requesting = false
    private var timer: Timer?

    init() {
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in self?.refresh() }
    }

    deinit { timer?.invalidate() }

    func refresh() {
        permission = AVCaptureDevice.authorizationStatus(for: .audio)
        var address = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDefaultInputDevice,
                                                mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
        var device = AudioObjectID(0), size = UInt32(MemoryLayout<AudioObjectID>.size)
        guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &device) == noErr,
              device != 0 else { inputName = nil; active = false; return }
        address.mSelector = kAudioObjectPropertyName
        var name: Unmanaged<CFString>?
        size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        if AudioObjectGetPropertyData(device, &address, 0, nil, &size, &name) == noErr {
            inputName = name?.takeRetainedValue() as String?
        } else { inputName = nil }
        address.mSelector = kAudioDevicePropertyDeviceIsRunningSomewhere
        var running: UInt32 = 0
        size = UInt32(MemoryLayout<UInt32>.size)
        active = AudioObjectGetPropertyData(device, &address, 0, nil, &size, &running) == noErr && running != 0
    }

    func requestPermission() {
        guard permission == .notDetermined, !requesting else { return }
        requesting = true
        AVCaptureDevice.requestAccess(for: .audio) { [weak self] _ in
            DispatchQueue.main.async { self?.requesting = false; self?.refresh() }
        }
    }

    func openPermissions() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") {
            NSWorkspace.shared.open(url)
        }
    }
}

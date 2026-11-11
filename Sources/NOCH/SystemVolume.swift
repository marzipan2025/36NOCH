import CoreAudio
import AudioToolbox

/// 맥의 기본 출력 장치 볼륨(0~1). 권한이 필요 없다.
/// 장치 전체 볼륨(가상 메인 볼륨)을 쓰고, 볼륨을 바꿀 수 없는 장치(일부 HDMI·USB)면 아무 일도 하지 않는다.
enum SystemVolume {
    private static var device: AudioDeviceID? {
        var id = AudioDeviceID(0)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        var address = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDefaultOutputDevice,
                                                 mScope: kAudioObjectPropertyScopeGlobal,
                                                 mElement: kAudioObjectPropertyElementMain)
        let status = AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &id)
        return status == noErr && id != 0 ? id : nil
    }

    private static var address = AudioObjectPropertyAddress(mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
                                                            mScope: kAudioDevicePropertyScopeOutput,
                                                            mElement: kAudioObjectPropertyElementMain)

    static func get() -> Float? {
        guard let device else { return nil }
        var value = Float32(0)
        var size = UInt32(MemoryLayout<Float32>.size)
        return AudioObjectGetPropertyData(device, &address, 0, nil, &size, &value) == noErr ? value : nil
    }

    static func set(_ volume: Float) {
        guard let device else { return }
        var settable: DarwinBoolean = false
        guard AudioObjectIsPropertySettable(device, &address, &settable) == noErr, settable.boolValue else { return }
        var value = Float32(min(1, max(0, volume)))
        AudioObjectSetPropertyData(device, &address, 0, nil, UInt32(MemoryLayout<Float32>.size), &value)
    }
}

import Foundation

/// Swift 包装层，隐藏 C FFI 细节。
class MicvolBridge {

    struct InputDevice: Identifiable {
        let id: UInt32
        let name: String
        let channels: UInt32
        let isDefault: Bool
    }

    /// 获取默认输入设备 ID 和名称。
    static func defaultInputDevice() throws -> InputDevice {
        var deviceId: UInt32 = 0
        var namePtr: UnsafeMutablePointer<CChar>?
        let err = micvol_default_input_device(&deviceId, &namePtr)
        guard err == MICVOL_OK else { throw MicvolError(code: err) }
        let name = namePtr.map { String(cString: $0) } ?? "Unknown"
        namePtr.flatMap { micvol_free_string($0) }
        return InputDevice(id: deviceId, name: name, channels: 0, isDefault: true)
    }

    /// 枚举所有输入设备。
    static func inputDevices() throws -> [InputDevice] {
        let maxDevices: UInt32 = 32
        var buf = [MicvolDeviceInfo](repeating: MicvolDeviceInfo(), count: Int(maxDevices))
        var count: UInt32 = 0
        let err = micvol_input_devices(&buf, maxDevices, &count)
        guard err == MICVOL_OK else { throw MicvolError(code: err) }

        var devices: [InputDevice] = []
        for i in 0..<Int(count) {
            let info = buf[i]
            let name = info.name.map { String(cString: $0) } ?? "Unknown"
            info.name.flatMap { micvol_free_string($0) }
            devices.append(InputDevice(
                id: info.device_id,
                name: name,
                channels: info.channels,
                isDefault: info.is_default != 0
            ))
        }
        return devices
    }

    /// 获取输入音量 (0.0-1.0)。
    static func getVolume(deviceId: UInt32) throws -> Float {
        var vol: Float = 0
        let err = micvol_get_volume(deviceId, &vol)
        guard err == MICVOL_OK else { throw MicvolError(code: err) }
        return vol
    }

    /// 设置输入音量。
    static func setVolume(deviceId: UInt32, volume: Float) throws {
        let err = micvol_set_volume(deviceId, volume)
        guard err == MICVOL_OK else { throw MicvolError(code: err) }
    }

    /// 获取静音状态。
    static func getMute(deviceId: UInt32) throws -> Bool {
        var muted: Int32 = 0
        let err = micvol_get_mute(deviceId, &muted)
        guard err == MICVOL_OK else { throw MicvolError(code: err) }
        return muted != 0
    }

    /// 拉满音量，返回 guard 句柄。
    static func guardMaximize(deviceId: UInt32) throws -> OpaquePointer {
        var guard_ptr: UnsafeMutableRawPointer?
        let err = micvol_guard_maximize(deviceId, &guard_ptr)
        guard err == MICVOL_OK, let ptr = guard_ptr else { throw MicvolError(code: err) }
        return OpaquePointer(ptr)
    }

    /// 恢复音量并释放 guard。
    static func guardRestore(_ guardHandle: OpaquePointer) throws {
        let err = micvol_guard_restore(UnsafeMutableRawPointer(guardHandle))
        guard err == MICVOL_OK else { throw MicvolError(code: err) }
    }
}

struct MicvolError: LocalizedError {
    let code: Int32
    var errorDescription: String? {
        switch code {
        case MICVOL_ERR_COREAUDIO: return "CoreAudio error"
        case MICVOL_ERR_DEVICE_NOT_FOUND: return "Device not found"
        case MICVOL_ERR_NO_DEFAULT_INPUT: return "No default input device"
        case MICVOL_ERR_VOLUME_OUT_OF_RANGE: return "Volume out of range"
        case MICVOL_ERR_NOT_SUPPORTED: return "Not supported"
        case MICVOL_ERR_NULL_POINTER: return "Null pointer"
        default: return "Unknown error (\(code))"
        }
    }
}

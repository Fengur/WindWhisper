/**
 * micvol — macOS microphone hardware input volume control.
 *
 * All functions return 0 on success, negative error codes on failure.
 * Strings returned by micvol must be freed with micvol_free_string().
 */

#ifndef MICVOL_H
#define MICVOL_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

/* Error codes */
#define MICVOL_OK                    0
#define MICVOL_ERR_COREAUDIO        -1
#define MICVOL_ERR_DEVICE_NOT_FOUND -2
#define MICVOL_ERR_NO_DEFAULT_INPUT -3
#define MICVOL_ERR_VOLUME_OUT_OF_RANGE -4
#define MICVOL_ERR_NOT_SUPPORTED    -5
#define MICVOL_ERR_NULL_POINTER     -6

/* Device info returned by micvol_input_devices. */
typedef struct {
    uint32_t device_id;
    char    *name;       /* free with micvol_free_string */
    uint32_t channels;
    int32_t  is_default; /* 1 = default, 0 = not */
} MicvolDeviceInfo;

/* Opaque handle for VolumeGuard. */
typedef void *MicvolGuard;

/* ── Device enumeration ─────────────────────────────────────────── */

/**
 * Get the default input device.
 * @param device_id  [out] receives the AudioDeviceID.
 * @param name       [out] receives a UTF-8 device name (free with micvol_free_string).
 */
int micvol_default_input_device(uint32_t *device_id, char **name);

/**
 * List all audio input devices.
 * @param buf      caller-allocated array of MicvolDeviceInfo.
 * @param buf_len  capacity of buf.
 * @param count    [out] number of devices written.
 */
int micvol_input_devices(MicvolDeviceInfo *buf, uint32_t buf_len, uint32_t *count);

/* ── Input volume control ───────────────────────────────────────── */

/** Get input volume scalar (0.0–1.0). */
int micvol_get_volume(uint32_t device_id, float *volume);

/** Set input volume scalar (0.0–1.0). */
int micvol_set_volume(uint32_t device_id, float volume);

/** Get mute state (0 = unmuted, 1 = muted). */
int micvol_get_mute(uint32_t device_id, int32_t *muted);

/** Set mute state (0 = unmuted, 1 = muted). */
int micvol_set_mute(uint32_t device_id, int32_t muted);

/* ── VolumeGuard (RAII-style maximize / restore) ────────────────── */

/**
 * Maximize input volume and return a guard handle.
 * Call micvol_guard_restore() to restore the original volume.
 */
int micvol_guard_maximize(uint32_t device_id, MicvolGuard *guard);

/**
 * Restore the original volume and release the guard.
 * The guard pointer is invalid after this call.
 */
int micvol_guard_restore(MicvolGuard guard);

/* ── Memory management ──────────────────────────────────────────── */

/** Free a string allocated by micvol. */
void micvol_free_string(char *s);

#ifdef __cplusplus
}
#endif

#endif /* MICVOL_H */

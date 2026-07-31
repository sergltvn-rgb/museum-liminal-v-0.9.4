# -*- coding: utf-8 -*-
# Batch 6 audio pass:
#   alarm.wav        <- "тревога что нужно но потише сделай.mp3", folded into a
#                       seamless loop (1 s equal-power fold), natural level kept
#                       (user: quieter than the old synth alarm, -15.3 RMS)
#   footstep1..3.wav <- 3 steps cut from "footsteps-on-stone", RMS-matched 1:1
#                       to the old synth files (-35.7 / -42.0 / -40.0 dBFS)
#   door_lock.wav    <- +5 dB with a soft limiter at -1.0 dBFS (was ~10 dB
#                       under the old file)
#   ambience_night.wav <- +3 dB with the same limiter (old file was -13.5 RMS)
# Originals are already backed up in %TEMP%\museum_audio_backup\audio_wav3\.
import os
import wave

import miniaudio
import numpy as np

ROOT = r"c:\Users\litvi\OneDrive\Документы\museum-liminal-v-0.9.4"
AUDIO = os.path.join(ROOT, "audio")
SRC = r"C:\Users\litvi\sound_candidates\20 шаги и сирена"
BACKUP = os.path.join(os.environ["TEMP"], "museum_audio_backup", "audio_wav3")
SR = 44100
CEIL = 10.0 ** (-1.0 / 20.0)  # soft-limiter ceiling: -1.0 dBFS


def db(v):
    return 20.0 * np.log10(max(float(v), 1e-9))


def decode(path):
    d = miniaudio.decode_file(path, output_format=miniaudio.SampleFormat.FLOAT32,
                              nchannels=2, sample_rate=SR)
    a = np.frombuffer(d.samples, dtype=np.float32).reshape(-1, 2).copy()
    return a


def stats(a, label):
    rms = np.sqrt(np.mean(a * a))
    peak = np.max(np.abs(a))
    print("%-34s %6.2fs  RMS %6.1f dBFS  peak %5.1f dBFS"
          % (label, len(a) / float(SR), db(rms), db(peak)))
    return db(rms), db(peak)


def envelope_limit(a, ceiling=CEIL, attack_s=0.002, release_s=0.100):
    # Envelope limiter: peak-hold detector with a slow release drives a gain
    # that ducks only while the signal is over the ceiling, so the waveform
    # shape survives (a per-sample squash flat-tops the transient instead).
    peak = np.max(np.abs(a), axis=1)
    rel = np.exp(-1.0 / (release_s * SR))
    env = np.empty_like(peak)
    e = 0.0
    for i, v in enumerate(peak):
        e = v if v > e else e * rel
        env[i] = e
    g = np.minimum(1.0, ceiling / np.maximum(env, ceiling))
    atk = np.exp(-1.0 / (attack_s * SR))
    gs = np.empty_like(g)
    gg = 1.0
    for i, v in enumerate(g):
        gg = v if v < gg else gg + (1.0 - atk) * (v - gg)
        gs[i] = gg
    return a * gs[:, None]


def write_wav(path, a):
    a = np.clip(a, -1.0, 1.0)
    pcm = (a * 32767.0).astype(np.int16)
    with wave.open(path, "wb") as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())


def fold_loop(a, fade_s=1.0):
    # Seamless loop: out[0] == the sample right after out[-1], because the first
    # `fade` frames carry the post-loop audio folded over the head.
    f = int(fade_s * SR)
    n = len(a)
    l = n - f
    out = a[:l].copy()
    t = np.arange(f, dtype=np.float32) / f
    w_in = np.sin(t * np.pi / 2.0)[:, None]
    w_out = np.cos(t * np.pi / 2.0)[:, None]
    out[:f] = a[:f] * w_in + a[l:l + f] * w_out
    return out


def main():
    # --- alarm: fold to a seamless loop, keep natural level ("потише" vs old -15.3)
    alarm = decode(os.path.join(SRC, "тревога что нужно но потише сделай.mp3"))
    stats(alarm, "alarm source (тревога)")
    loop = fold_loop(alarm, 1.0)
    stats(loop, "alarm loop, natural level")
    write_wav(os.path.join(AUDIO, "alarm.wav"), loop)

    # --- footsteps: 3 onsets from the stone recording, RMS-matched per slot
    steps = decode(os.path.join(SRC, "freesound_community-073303_footsteps-on-stone-39947.mp3"))
    stats(steps, "footsteps source (stone)")
    mono = steps.mean(axis=1)
    hop = int(0.005 * SR)
    env = np.sqrt(np.convolve(mono * mono, np.ones(hop) / hop, mode="same"))
    floor = np.percentile(env, 50) * 3.0
    onsets = []
    i = int(0.02 * SR)
    while i < len(env) - int(0.05 * SR):
        if env[i] > floor and env[i] == env[max(0, i - hop):i + hop].max():
            onsets.append(i)
            i += int(0.25 * SR)
        else:
            i += 1
    print("onsets (s):", [round(o / float(SR), 3) for o in onsets])
    targets = [-35.7, -42.0, -40.0]
    for slot, tgt in enumerate(targets, 1):
        o = onsets[slot - 1]
        start = max(0, o - int(0.010 * SR))
        seg = steps[start:start + int(0.30 * SR)].copy()
        if len(seg) < int(0.30 * SR):
            seg = np.vstack([seg, np.zeros((int(0.30 * SR) - len(seg), 2), np.float32)])
        fi = int(0.005 * SR)
        fo = int(0.060 * SR)
        seg[:fi] *= (np.arange(fi, dtype=np.float32) / fi)[:, None]
        tail = np.arange(fo, dtype=np.float32) / fo
        seg[-fo:] *= (0.5 + 0.5 * np.cos(tail * np.pi))[:, None]
        rms = np.sqrt(np.mean(seg * seg))
        seg *= 10.0 ** (tgt / 20.0) / rms
        stats(seg, "footstep%d -> target %.1f" % (slot, tgt))
        write_wav(os.path.join(AUDIO, "footstep%d.wav" % slot), seg)

    # --- door_lock: +5 dB, envelope limit at -1.0 dBFS (from the backup,
    # so rerunning this script never compounds gain)
    lock = decode(os.path.join(BACKUP, "door_lock.wav"))
    stats(lock, "door_lock before")
    lock = envelope_limit(lock * 10.0 ** (5.0 / 20.0))
    stats(lock, "door_lock after +5 dB + limiter")
    write_wav(os.path.join(AUDIO, "door_lock.wav"), lock)

    # --- ambience_night: +3 dB toward the old -13.5 RMS, envelope limit
    # (from the backup, same idempotence reason as door_lock)
    night = decode(os.path.join(BACKUP, "ambience_night.wav"))
    stats(night, "ambience_night before")
    night = envelope_limit(night * 10.0 ** (3.0 / 20.0))
    stats(night, "ambience_night after +3 dB + limiter")
    write_wav(os.path.join(AUDIO, "ambience_night.wav"), night)


if __name__ == "__main__":
    main()

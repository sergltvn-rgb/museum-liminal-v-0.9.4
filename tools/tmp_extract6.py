# -*- coding: utf-8 -*-
# Extracts the only real alarm candidates present in the downloaded Sonniss
# zips (parts 1/3/6) into C:\Users\litvi\sound_candidates\19_alarm\ and prints
# duration / RMS / peak for each, plus the same numbers for the current
# in-game alarm.wav and footstep1..3.wav as reference.
import os
import sys
import zipfile

import miniaudio
import numpy as np

BASE = r"c:\Users\litvi\OneDrive\Документы\museum-liminal-v-0.9.4"
OUT = r"C:\Users\litvi\sound_candidates\19_alarm"

CANDIDATES = [
    ("Sonniss.com-GDC2024-GameAudioBundle1of9.zip",
     "BluezoneCorp - Retrofuturistic Computer/Bluezone_BC0304_retrofuturistic_computer_alarm_005.wav",
     "bc0304_alarm_005.wav"),
    ("Sonniss.com-GDC2024-GameAudioBundle1of9.zip",
     "BluezoneCorp - Futuristic User Interface/Bluezone_BC0303_futuristic_user_interface_alert_003.wav",
     "bc0303_alert_003.wav"),
    ("Sonniss.com-GDC2024-GameAudioBundle3of9.zip",
     "Pole Position - Beechcraft Baron 58 1969/Beechcraft Baron 58 - t12 - VAR SFX - Stall Warning - MS Decoded - RSM191.wav",
     "beechcraft_stall_warning.wav"),
    ("Sonniss.com-GDC2024-GameAudioBundle6of9.zip",
     "Rescopic Sound - User Interaction/UIAlert_Confirm Middle 12_RSCPC_USIN.wav",
     "uialert_confirm_12.wav"),
]

REFERENCE = [
    "audio/alarm.wav",
    "audio/footstep1.wav",
    "audio/footstep2.wav",
    "audio/footstep3.wav",
]


def measure(path):
    dec = miniaudio.decode_file(path, output_format=miniaudio.SampleFormat.FLOAT32)
    data = np.frombuffer(dec.samples, dtype=np.float32)
    if dec.nchannels > 1:
        data = data.reshape(-1, dec.nchannels).mean(axis=1)
    dur = len(data) / float(dec.sample_rate)
    rms = float(np.sqrt(np.mean(data * data))) if len(data) else 0.0
    peak = float(np.max(np.abs(data))) if len(data) else 0.0
    db = lambda v: 20.0 * np.log10(max(v, 1e-9))
    return dur, db(rms), db(peak), dec.sample_rate, dec.nchannels


def main():
    os.makedirs(OUT, exist_ok=True)
    zdir = os.path.join(BASE, "audio", "generated", "новые звуки")
    for zip_name, inner, out_name in CANDIDATES:
        zp = os.path.join(zdir, zip_name)
        dst = os.path.join(OUT, out_name)
        with zipfile.ZipFile(zp) as z:
            with z.open(inner) as src, open(dst, "wb") as f:
                while True:
                    chunk = src.read(1 << 20)
                    if not chunk:
                        break
                    f.write(chunk)
        dur, rms, peak, sr, ch = measure(dst)
        print("CAND %-28s %6.2fs  RMS %6.1f dBFS  peak %5.1f dBFS  %d Hz x%d"
              % (out_name, dur, rms, peak, sr, ch))
    print("---")
    for rel in REFERENCE:
        p = os.path.join(BASE, rel)
        dur, rms, peak, sr, ch = measure(p)
        print("REF  %-28s %6.2fs  RMS %6.1f dBFS  peak %5.1f dBFS  %d Hz x%d"
              % (os.path.basename(p), dur, rms, peak, sr, ch))


if __name__ == "__main__":
    sys.exit(main())

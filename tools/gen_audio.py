#!/usr/bin/env python3
"""Génère toute la bande-son du jeu (effets + musiques) sans aucune dépendance.

Synthèse pure Python -> WAV 16 bits mono 22050 Hz, puis conversion en OGG via ffmpeg
(les .ogg sont lus tels quels par LÖVE 11 et LÖVE Potion 3DS).

Usage :  python3 tools/gen_audio.py
Sortie :  assets/audio/sfx/*.ogg  et  assets/audio/music/*.ogg
"""

import math
import os
import random
import shutil
import struct
import subprocess
import wave

RATE = 22050
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SFX_DIR = os.path.join(ROOT, "assets", "audio", "sfx")
MUSIC_DIR = os.path.join(ROOT, "assets", "audio", "music")

# ---------------------------------------------------------------------------
# Briques de synthèse
# ---------------------------------------------------------------------------

def silence(duration):
    return [0.0] * int(duration * RATE)


def osc(shape, freq, duration, phase=0.0, duty=0.5):
    n = int(duration * RATE)
    out = [0.0] * n
    step = freq / RATE
    p = phase
    rnd = random.Random(int(freq * 1000) & 0xFFFF)
    for i in range(n):
        if shape == "sine":
            out[i] = math.sin(2 * math.pi * p)
        elif shape == "square":
            out[i] = 1.0 if (p % 1.0) < duty else -1.0
        elif shape == "saw":
            out[i] = 2.0 * (p % 1.0) - 1.0
        elif shape == "tri":
            v = (p % 1.0)
            out[i] = 4.0 * v - 1.0 if v < 0.5 else 3.0 - 4.0 * v
        elif shape == "noise":
            out[i] = rnd.uniform(-1.0, 1.0)
        p += step
    return out


def sweep(shape, f0, f1, duration, duty=0.5):
    """Oscillateur à fréquence glissante (exponentielle)."""
    n = int(duration * RATE)
    out = [0.0] * n
    p = 0.0
    rnd = random.Random(1234)
    for i in range(n):
        t = i / max(1, n - 1)
        freq = f0 * ((f1 / f0) ** t) if f0 > 0 and f1 > 0 else f0 + (f1 - f0) * t
        if shape == "noise":
            out[i] = rnd.uniform(-1.0, 1.0)
        else:
            if shape == "sine":
                out[i] = math.sin(2 * math.pi * p)
            elif shape == "square":
                out[i] = 1.0 if (p % 1.0) < duty else -1.0
            elif shape == "saw":
                out[i] = 2.0 * (p % 1.0) - 1.0
            else:
                v = (p % 1.0)
                out[i] = 4.0 * v - 1.0 if v < 0.5 else 3.0 - 4.0 * v
        p += freq / RATE
    return out


def env(buf, attack=0.005, decay=0.0, sustain=1.0, release=0.05, hold=None):
    """Enveloppe ADSR appliquée en place."""
    n = len(buf)
    a = max(1, int(attack * RATE))
    d = int(decay * RATE)
    r = max(1, int(release * RATE))
    h = n - a - d - r if hold is None else int(hold * RATE)
    h = max(0, h)
    idx = 0
    for i in range(min(a, n)):
        buf[idx] *= i / a
        idx += 1
    for i in range(min(d, max(0, n - idx))):
        buf[idx] *= 1.0 + (sustain - 1.0) * (i / max(1, d))
        idx += 1
    for _ in range(min(h, max(0, n - idx))):
        buf[idx] *= sustain
        idx += 1
    rem = n - idx
    for i in range(max(0, rem)):
        buf[idx] *= sustain * max(0.0, 1.0 - i / max(1, rem))
        idx += 1
    return buf


def lowpass(buf, cutoff):
    """Filtre passe-bas 1 pôle."""
    rc = 1.0 / (2 * math.pi * cutoff)
    dt = 1.0 / RATE
    alpha = dt / (rc + dt)
    prev = 0.0
    for i, v in enumerate(buf):
        prev = prev + alpha * (v - prev)
        buf[i] = prev
    return buf


def mix(*buffers, gains=None):
    n = max(len(b) for b in buffers)
    out = [0.0] * n
    for k, b in enumerate(buffers):
        g = 1.0 if gains is None else gains[k]
        for i, v in enumerate(b):
            out[i] += v * g
    return out


def layer(base, add, offset=0.0, gain=1.0):
    start = int(offset * RATE)
    need = start + len(add)
    if need > len(base):
        base.extend([0.0] * (need - len(base)))
    for i, v in enumerate(add):
        base[start + i] += v * gain
    return base


def normalize(buf, peak=0.85):
    m = max(0.0001, max(abs(v) for v in buf))
    k = peak / m
    return [v * k for v in buf]


def save_wav(buf, path):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        frames = bytearray()
        for v in buf:
            s = int(max(-1.0, min(1.0, v)) * 32000)
            frames += struct.pack("<h", s)
        w.writeframes(bytes(frames))


def to_ogg(wav_path, ogg_path, quality="1"):
    if not shutil.which("ffmpeg"):
        return False
    subprocess.run(
        ["ffmpeg", "-y", "-loglevel", "error", "-i", wav_path, "-c:a", "libvorbis", "-q:a", quality, ogg_path],
        check=True,
    )
    os.remove(wav_path)
    return True


def emit(name, buf, directory, quality="1"):
    buf = normalize(buf)
    wav = os.path.join(directory, name + ".wav")
    ogg = os.path.join(directory, name + ".ogg")
    save_wav(buf, wav)
    if to_ogg(wav, ogg, quality):
        print("  " + os.path.relpath(ogg, ROOT))
    else:
        print("  " + os.path.relpath(wav, ROOT) + " (ffmpeg absent : WAV conservé)")


# ---------------------------------------------------------------------------
# Effets sonores
# ---------------------------------------------------------------------------
NOTE = {}
for i, base in enumerate(["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]):
    for octave in range(1, 8):
        NOTE["%s%d" % (base, octave)] = 440.0 * (2 ** ((i - 9) / 12.0 + (octave - 4)))


def tone(note, duration, shape="square", duty=0.5, **envargs):
    return env(osc(shape, NOTE[note], duration, duty=duty), **envargs)


def build_sfx():
    print("Effets sonores :")

    # Tir à l'arc : corde qui claque + souffle
    body = env(sweep("square", 900, 380, 0.10), attack=0.002, release=0.06)
    air = env(lowpass(osc("noise", 0, 0.08), 2600), attack=0.001, release=0.06)
    emit("shoot_bow", mix(body, air, gains=[0.7, 0.35]), SFX_DIR)

    # Tir lourd (arbalète / ballista)
    heavy = env(sweep("saw", 420, 150, 0.16), attack=0.003, release=0.10)
    thud = env(lowpass(osc("noise", 0, 0.12), 900), attack=0.001, release=0.10)
    emit("shoot_heavy", mix(heavy, thud, gains=[0.7, 0.4]), SFX_DIR)

    # Tir rapide (dagues)
    emit("shoot_fast", env(sweep("square", 1400, 700, 0.06), attack=0.001, release=0.04), SFX_DIR)

    # Impact sur un monstre
    hit = env(lowpass(osc("noise", 0, 0.09), 3200), attack=0.001, release=0.07)
    click = env(sweep("square", 700, 220, 0.05), attack=0.001, release=0.04)
    emit("hit", mix(hit, click, gains=[0.6, 0.5]), SFX_DIR)

    # Coup critique : impact + ping métallique
    crit = mix(
        env(lowpass(osc("noise", 0, 0.10), 4000), attack=0.001, release=0.08),
        env(osc("sine", NOTE["E6"], 0.22), attack=0.001, release=0.2),
        env(osc("sine", NOTE["B6"], 0.18), attack=0.001, release=0.16),
        gains=[0.5, 0.35, 0.25],
    )
    emit("crit", crit, SFX_DIR)

    # Mort d'un monstre
    die = mix(
        env(sweep("square", 520, 90, 0.28), attack=0.002, release=0.2),
        env(lowpass(osc("noise", 0, 0.22), 1500), attack=0.002, release=0.2),
        gains=[0.6, 0.4],
    )
    emit("monster_die", die, SFX_DIR)

    # Joueur touché
    hurt = mix(
        env(sweep("saw", 320, 110, 0.26), attack=0.002, release=0.2),
        env(lowpass(osc("noise", 0, 0.18), 800), attack=0.002, release=0.16),
        gains=[0.6, 0.4],
    )
    emit("player_hurt", hurt, SFX_DIR)

    # Ramassage : pièce, gemme, cœur
    coin = layer(list(tone("E6", 0.07, release=0.05)), tone("B6", 0.12, release=0.10), offset=0.05, gain=0.8)
    emit("pickup_coin", coin, SFX_DIR)
    gem = list(tone("G5", 0.07, release=0.05))
    layer(gem, tone("B5", 0.07, release=0.05), 0.06, 0.9)
    layer(gem, tone("E6", 0.14, release=0.12), 0.12, 0.9)
    emit("pickup_gem", gem, SFX_DIR)
    heart = list(tone("C5", 0.10, shape="sine", release=0.08))
    layer(heart, tone("G5", 0.20, shape="sine", release=0.16), 0.08, 0.9)
    emit("pickup_heart", heart, SFX_DIR)

    # Montée de niveau : arpège ascendant
    lvl = []
    for k, n in enumerate(["C5", "E5", "G5", "C6", "E6"]):
        layer(lvl if lvl else [0.0], tone(n, 0.30, release=0.26), 0.07 * k, 0.8) if lvl else lvl.extend(tone(n, 0.30, release=0.26))
    emit("level_up", lvl, SFX_DIR)

    # Ouverture de la porte : montée scintillante
    gate = mix(
        env(sweep("sine", 220, 880, 0.9), attack=0.05, release=0.4),
        env(sweep("square", 440, 1760, 0.9, duty=0.25), attack=0.1, release=0.5),
        gains=[0.6, 0.25],
    )
    emit("gate_open", gate, SFX_DIR)

    # Explosion (baril, météore, ultime)
    boom = mix(
        env(lowpass(osc("noise", 0, 0.55), 1200), attack=0.002, release=0.5),
        env(sweep("saw", 180, 40, 0.5), attack=0.002, release=0.45),
        gains=[0.6, 0.5],
    )
    emit("explosion", boom, SFX_DIR)

    # Urne brisée : éclats
    shards = [0.0] * int(0.30 * RATE)
    rnd = random.Random(7)
    for k in range(5):
        piece = env(lowpass(osc("noise", 0, 0.06), 5000 - k * 600), attack=0.001, release=0.05)
        layer(shards, piece, 0.03 * k + rnd.uniform(0, 0.02), 0.8 - k * 0.1)
    emit("pot_break", shards, SFX_DIR)

    # Esquive (dash)
    emit("dash", env(lowpass(sweep("noise", 0, 0, 0.22), 2400), attack=0.005, release=0.18), SFX_DIR)

    # Ultime : montée puis détonation
    ult = mix(
        env(sweep("saw", 200, 900, 0.5), attack=0.05, release=0.2),
        env(sweep("square", 400, 1800, 0.5, duty=0.3), attack=0.05, release=0.2),
        gains=[0.5, 0.3],
    )
    layer(ult, boom, 0.42, 0.9)
    emit("ultimate", ult, SFX_DIR)

    # Rugissement du boss enragé
    roar = mix(
        env(sweep("saw", 110, 60, 0.8), attack=0.03, release=0.5),
        env(lowpass(osc("noise", 0, 0.8), 700), attack=0.05, release=0.6),
        gains=[0.6, 0.45],
    )
    emit("boss_roar", roar, SFX_DIR)

    # Interface
    emit("ui_click", env(osc("square", NOTE["A5"], 0.05, duty=0.35), attack=0.001, release=0.04), SFX_DIR)
    conf = list(tone("E5", 0.07, release=0.05))
    layer(conf, tone("A5", 0.14, release=0.12), 0.06, 0.9)
    emit("ui_confirm", conf, SFX_DIR)
    canc = list(tone("A4", 0.07, release=0.05))
    layer(canc, tone("E4", 0.14, release=0.12), 0.06, 0.9)
    emit("ui_cancel", canc, SFX_DIR)
    emit("wheel_tick", env(osc("square", NOTE["D6"], 0.04, duty=0.2), attack=0.001, release=0.03), SFX_DIR)

    # Fin de partie
    win = []
    for k, n in enumerate(["C5", "E5", "G5", "C6"]):
        part = tone(n, 0.45, release=0.4)
        if not win:
            win = list(part)
        else:
            layer(win, part, 0.12 * k, 0.85)
    emit("victory", win, SFX_DIR)

    lose = []
    for k, n in enumerate(["G4", "E4", "C4", "G3"]):
        part = tone(n, 0.5, shape="tri", release=0.45)
        if not lose:
            lose = list(part)
        else:
            layer(lose, part, 0.18 * k, 0.85)
    emit("defeat", lose, SFX_DIR)


# ---------------------------------------------------------------------------
# Musiques (boucles chiptune)
# ---------------------------------------------------------------------------

def sequence(track, bpm, total_beats, shape="square", duty=0.5, gain=1.0, release=0.04):
    """track = liste de (beat, note, durée en beats). Renvoie un buffer complet."""
    spb = 60.0 / bpm
    out = [0.0] * int(total_beats * spb * RATE + RATE * 0.5)
    for beat, note, dur in track:
        if note is None:
            continue
        freq = NOTE[note]
        buf = env(osc(shape, freq, dur * spb, duty=duty), attack=0.006, release=release)
        layer(out, buf, beat * spb, gain)
    return out


def drums(pattern, bpm, total_beats, gain=1.0):
    spb = 60.0 / bpm
    out = [0.0] * int(total_beats * spb * RATE + RATE * 0.5)
    for beat, kind in pattern:
        if kind == "kick":
            buf = env(sweep("sine", 150, 45, 0.18), attack=0.002, release=0.14)
            g = 1.0
        elif kind == "snare":
            buf = mix(env(lowpass(osc("noise", 0, 0.16), 3000), attack=0.002, release=0.12),
                      env(sweep("tri", 320, 180, 0.12), attack=0.002, release=0.1), gains=[0.7, 0.3])
            g = 0.8
        else:  # hat
            buf = env(lowpass(osc("noise", 0, 0.05), 9000), attack=0.001, release=0.04)
            g = 0.35
        layer(out, buf, beat * spb, gain * g)
    return out


def build_music():
    print("Musiques :")

    # --- Hub : calme, majeur, 96 BPM, 16 temps
    bpm, beats = 96, 32
    lead = []
    melody = ["E5", "G5", "A5", "G5", "E5", "D5", "E5", None,
              "C5", "E5", "G5", "E5", "D5", "C5", "D5", None,
              "G5", "A5", "C6", "A5", "G5", "E5", "G5", None,
              "F5", "A5", "C6", "A5", "G5", "E5", "D5", None]
    for i, n in enumerate(melody):
        lead.append((i, n, 0.9))
    bass = []
    for i in range(0, beats, 2):
        bass.append((i, ["C3", "A2", "F2", "G2"][(i // 4) % 4], 1.8))
    pad = []
    for i in range(0, beats, 4):
        pad.append((i, ["C4", "A3", "F3", "G3"][(i // 4) % 4], 3.8))
    hub = mix(
        sequence(lead, bpm, beats, "square", 0.5, 0.55, release=0.12),
        sequence(bass, bpm, beats, "tri", 0.5, 0.6, release=0.2),
        sequence(pad, bpm, beats, "saw", 0.5, 0.18, release=0.5),
        drums([(i, "hat") for i in range(beats)] + [(i, "kick") for i in range(0, beats, 4)], bpm, beats, 0.5),
        gains=[1, 1, 1, 1],
    )
    emit("hub", hub, MUSIC_DIR, quality="2")

    # --- Combat : 140 BPM, mineur, 16 temps
    bpm, beats = 140, 32
    riff = []
    pattern = ["A4", "A4", "C5", "A4", "E5", "D5", "C5", "A4",
               "A4", "A4", "C5", "E5", "G5", "E5", "D5", "C5",
               "A4", "C5", "E5", "C5", "A4", "G4", "A4", "C5",
               "F4", "A4", "C5", "A4", "G4", "E4", "G4", "A4"]
    for i, n in enumerate(pattern):
        riff.append((i, n, 0.85))
    bassline = []
    for i in range(beats):
        bassline.append((i, ["A2", "A2", "F2", "G2"][(i // 4) % 4], 0.9))
    battle = mix(
        sequence(riff, bpm, beats, "square", 0.35, 0.5, release=0.08),
        sequence(bassline, bpm, beats, "saw", 0.5, 0.45, release=0.08),
        drums([(i * 0.5, "hat") for i in range(beats * 2)]
              + [(i, "kick") for i in range(0, beats, 2)]
              + [(i + 1, "snare") for i in range(0, beats, 4)], bpm, beats, 0.7),
        gains=[1, 1, 1],
    )
    emit("battle", battle, MUSIC_DIR, quality="2")

    # --- Boss : 160 BPM, sombre, 16 temps
    bpm, beats = 160, 32
    stabs = []
    dark = ["D4", "D4", "F4", "D4", "A4", "G#4", "G4", "F4",
            "D4", "D4", "F4", "A4", "C5", "A4", "G#4", "G4",
            "D5", "C5", "A4", "F4", "D4", "F4", "A4", "C5",
            "D5", "D5", "C5", "A4", "G#4", "G4", "F4", "D4"]
    for i, n in enumerate(dark):
        stabs.append((i, n, 0.8))
    low = []
    for i in range(beats):
        low.append((i, ["D2", "D2", "D2", "C2"][(i // 4) % 4], 0.95))
    boss = mix(
        sequence(stabs, bpm, beats, "saw", 0.5, 0.45, release=0.07),
        sequence(low, bpm, beats, "square", 0.25, 0.5, release=0.07),
        drums([(i * 0.5, "hat") for i in range(beats * 2)]
              + [(i, "kick") for i in range(beats)]
              + [(i + 2, "snare") for i in range(0, beats, 4)], bpm, beats, 0.8),
        gains=[1, 1, 1],
    )
    emit("boss", boss, MUSIC_DIR, quality="2")


if __name__ == "__main__":
    os.makedirs(SFX_DIR, exist_ok=True)
    os.makedirs(MUSIC_DIR, exist_ok=True)
    build_sfx()
    build_music()
    print("Terminé.")

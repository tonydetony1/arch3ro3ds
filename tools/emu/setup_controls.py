#!/usr/bin/env python3
"""
tools/emu/setup_controls.py
Configure les touches clavier d'Azahar (flatpak) pour jouer à Arch3ro sur PC (clavier AZERTY) :

    Z Q S D ........ Circle Pad (déplacement)      Maj : déplacement lent
    Flèches ........ Croix directionnelle
    K / J .......... A / B          I / U ........ X / Y
    A / E .......... L (ultime) / R (esquive)      1 / 2 ...... ZL / ZR
    Entrée ......... Start (pause)                  Retour arrière : Select
    8 4 5 6 ........ C-Stick

Option --cpu=N : vitesse du processeur émulé en % (300 ≈ New 3DS à 804 MHz ; Azahar
n'émule pas le changement de fréquence demandé par LÖVE Potion et reste à 268 MHz sinon).

L'émulateur doit être fermé (il réécrit sa configuration en quittant).
Une copie de sauvegarde est créée : qt-config.ini.avant-arch3ro
"""

import os
import re
import shutil
import sys

CONFIG = os.path.expanduser("~/.var/app/org.azahar_emu.Azahar/config/azahar-emu/qt-config.ini")

# Codes de touches Qt
KEY = {
    "up": 16777235, "down": 16777237, "left": 16777234, "right": 16777236,
    "return": 16777220, "backspace": 16777219, "shift": 16777248,
}


def code(ch):
    return KEY[ch] if ch in KEY else ord(ch.upper())


def button(ch):
    return f'"code:{code(ch)},engine:keyboard"'


def stick(up, left, down, right):
    def k(ch):
        return f"code$0{code(ch)}$1engine$0keyboard"
    return (f'"down:{k(down)},engine:analog_from_button,left:{k(left)},modifier:{k("shift")},'
            f'modifier_scale:0.500000,right:{k(right)},up:{k(up)}"')


MAPPING = {
    "circle_pad": stick("z", "q", "s", "d"),
    "c_stick": stick("8", "4", "5", "6"),
    "button_up": button("up"), "button_down": button("down"),
    "button_left": button("left"), "button_right": button("right"),
    "button_a": button("k"), "button_b": button("j"),
    "button_x": button("i"), "button_y": button("u"),
    "button_l": button("a"), "button_r": button("e"),
    "button_zl": button("1"), "button_zr": button("2"),
    "button_start": button("return"), "button_select": button("backspace"),
    "button_home": button("h"), "button_debug": button("o"),
    "button_gpio14": button("p"), "button_power": button("v"),
}


def set_key(text, section, key, value):
    """Remplace (ou ajoute) key=value dans [section], et marque la valeur comme non par défaut."""
    pattern = re.compile(rf"^{re.escape(key)}=.*$", re.M)
    default = re.compile(rf"^{re.escape(key)}\\default=.*$", re.M)
    if pattern.search(text):
        text = pattern.sub(lambda _: f"{key}={value}", text, count=1)
        if default.search(text):
            text = default.sub(lambda _: f"{key}\\default=false", text, count=1)
        return text
    head = f"[{section}]\n"
    i = text.index(head) + len(head)
    return text[:i] + f"{key}={value}\n{key}\\default=false\n" + text[i:]


def main():
    if not os.path.exists(CONFIG):
        sys.exit(f"Configuration Azahar introuvable : {CONFIG}")
    backup = CONFIG + ".avant-arch3ro"
    if not os.path.exists(backup):
        shutil.copyfile(CONFIG, backup)
        print(f"Sauvegarde : {backup}")

    with open(CONFIG, encoding="utf-8") as f:
        text = f.read()

    profile = "profiles\\1\\"
    for name, value in MAPPING.items():
        text = set_key(text, "Controls", profile + name, value)

    for arg in sys.argv[1:]:
        if arg.startswith("--cpu="):
            text = set_key(text, "Core", "cpu_clock_percentage", str(int(arg[6:])))
            print(f"Processeur émulé : {arg[6:]} %")

    with open(CONFIG, "w", encoding="utf-8") as f:
        f.write(text)
    print("Touches Arch3ro appliquées (ZQSD = déplacement). Relance Azahar.")


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""Injection d'entrées X (XTest) sur l'écran virtuel :5 (tests headless de l'émulateur).
Usage : xin.py click X Y | down X Y | up | move X Y | key NOM [durée] | keydown NOM | keyup NOM
Clic souris sur l'écran du bas d'Azahar = toucher de l'écran tactile."""
import ctypes
import sys
import time

x = ctypes.cdll.LoadLibrary("libX11.so.6")
t = ctypes.cdll.LoadLibrary("libXtst.so.6")
x.XOpenDisplay.restype = ctypes.c_void_p
x.XStringToKeysym.restype = ctypes.c_ulong
d = x.XOpenDisplay(b":5")
if not d:
    sys.exit("écran :5 introuvable")


def flush():
    x.XFlush(ctypes.c_void_p(d))


def move(px, py):
    t.XTestFakeMotionEvent(ctypes.c_void_p(d), -1, int(float(px)), int(float(py)), 0)
    flush()


def btn(down):
    t.XTestFakeButtonEvent(ctypes.c_void_p(d), 1, down, 0)
    flush()


def key(name, down):
    ks = x.XStringToKeysym(name.encode())
    kc = x.XKeysymToKeycode(ctypes.c_void_p(d), ctypes.c_ulong(ks))
    t.XTestFakeKeyEvent(ctypes.c_void_p(d), kc, down, 0)
    flush()


a = sys.argv[1:]
cmd = a[0]
if cmd == "click":
    move(a[1], a[2]); time.sleep(0.05); btn(1); time.sleep(0.15); btn(0)
elif cmd == "down":
    move(a[1], a[2]); time.sleep(0.05); btn(1)
elif cmd == "up":
    btn(0)
elif cmd == "move":
    move(a[1], a[2])
elif cmd == "key":
    hold = float(a[2]) if len(a) > 2 else 0.12
    key(a[1], 1); time.sleep(hold); key(a[1], 0)
elif cmd == "keydown":
    key(a[1], 1)
elif cmd == "keyup":
    key(a[1], 0)

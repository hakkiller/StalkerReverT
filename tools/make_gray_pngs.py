# -*- coding: utf-8 -*-
"""Серые версии PNG-карточек для галереи.
Запуск после добавления новых PNG в ui/cards/: python tools/make_gray_pngs.py
Цветные PNG художника -> ui/cards/gray/*.png (оттенки серого, чуть притушены).
"""
import glob, os
from PIL import Image, ImageEnhance

SRC = "ui/cards"
DST = os.path.join(SRC, "gray")
os.makedirs(DST, exist_ok=True)

n = 0
for path in glob.glob(os.path.join(SRC, "*.png")):
    name = os.path.basename(path)
    img = Image.open(path).convert("RGBA")
    gray = img.convert("LA").convert("RGBA")
    gray = ImageEnhance.Brightness(gray).enhance(0.82)
    # сохраняем альфу исходника
    gray.putalpha(img.split()[3])
    gray.save(os.path.join(DST, name))
    n += 1
    print("gray:", name)
print("done:", n)



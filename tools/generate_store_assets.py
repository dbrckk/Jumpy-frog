#!/usr/bin/env python3
"""Render original Google Play listing artwork; no AI stock images, or licensed fonts.
Run: python -m pip install pillow && python tools/generate_store_assets.py
"""
from pathlib import Path
import math
from PIL import Image, ImageDraw, ImageFont

OUT = Path("build/store")
OUT.mkdir(parents=True, exist_ok=True)

def font(size, bold=False):
    candidates = ([
        "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
        "/usr/share/fonts/truetype/liberation2/LiberationSans-Bold.ttf",
    ] if bold else [
        "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",
        "/usr/share/fonts/truetype/liberation2/LiberationSans-Regular.ttf",
    ])
    for path in candidates:
        try:
            return ImageFont.truetype(path, size)
        except OSError:
            pass
    return ImageFont.load_default()

def ellipse(draw, xy, fill, outline=None, width=1):
    draw.ellipse(tuple(int(v) for v in xy), fill=fill, outline=outline, width=width)

def capybara(draw, x, y, scale=1.0):
    def b(a,b,c,d):
        return (x+a*scale,y+b*scale,x+c*scale,y+d*scale)
    outline="#594642"
    ellipse(draw,b(-82,-90,-24,-20),"#a8785b",outline,5)
    ellipse(draw,b(24,-90,82,-20),"#a8785b",outline,5)
    ellipse(draw,b(-65,-80,-41,-45),"#dda884")
    ellipse(draw,b(41,-80,65,-45),"#dda884")
    ellipse(draw,b(-102,75,102,163),outline)
    ellipse(draw,b(-94,51,94,152),"#a7795c",outline,5)
    ellipse(draw,b(-74,-101,74,85),outline)
    ellipse(draw,b(-68,-96,68,80),"#b88766")
    ellipse(draw,b(-47,-15,47,57),"#ddae84")
    for side in (-1,1):
        eye_x=side*40
        ellipse(draw,b(eye_x-11,-35,eye_x+11,-12),"#3f363a")
        ellipse(draw,b(eye_x-7,-32,eye_x-1,-26),"#ffffff")
        ellipse(draw,b(side*61-14,2,side*61+14,18),"#dc9181")
    ellipse(draw,b(-20,4,20,24),"#815747")
    draw.arc(b(-19,12,19,47),0,170,fill=outline,width=max(2,int(4*scale)))

def lily(draw,x,y,r):
    ellipse(draw,(x-r-8,y-r*.58,x+r+8,y+r*.85),"#416b79")
    ellipse(draw,(x-r,y-r*.72,x+r,y+r*.68),"#91c76e", "#668f61",3)
    draw.polygon([(x,y),(x+r*.86,y-r*.58),(x+r*.22,y-r*.28)],fill="#7399a4")
    for side in (-1,1):
        draw.line((x,y,x+side*r*.70,y+r*.26),fill="#73a65b",width=3)

def background(w,h):
    img=Image.new("RGB",(w,h),"#a2c1b0")
    d=ImageDraw.Draw(img)
    d.polygon([(int(w*.28),0),(int(w*.83),0),(int(w*.78),h),(int(w*.22),h)], fill="#83a9c3")
    for j in range(26):
        y=j*h/25
        x=w*.3+math.sin(j*1.9)*w*.17
        d.arc((x,y,x+w*.16,y+h*.09),start=20,end=155,fill="#c4dde2",width=max(2,w//300))
    for j in range(22):
        y=j*h/21
        for side in (0,1):
            x=(w*.13 if side==0 else w*.85) + math.sin(j*1.1)*w*.025
            ellipse(d,(x-9,y-9,x+9,y+9), "#679d68")
            ellipse(d,(x-3,y-20,x+3,y+10),"#6a9c6b")
    return img

# High-resolution square store icon, PNG RGB, opaque, no misleading store badges.
icon=background(512,512)
di=ImageDraw.Draw(icon)
lily(di,257,388,177)
capybara(di,257,253,1.17)
icon.save(OUT/"play-icon-512.png",optimize=True)

# Google Play feature graphic 1024 x 500, original storybook illustration.
banner=background(1024,500)
d=ImageDraw.Draw(banner)
d.rounded_rectangle((32,68,548,423),radius=42,fill="#f9ead4",outline="#927c79",width=6)
d.text((74,112),"JUMPY",font=font(91,True),fill="#53586a",stroke_width=1,stroke_fill="#53586a")
d.text((76,215),"FROG",font=font(97,True),fill="#5e976a")
d.text((76,338),"HOP  •  RESCUE  •  ESCAPE",font=font(22,True),fill="#7c7476")
lily(d,810,392,180)
capybara(d,811,251,1.12)
for x,y,color in [(695,87,"#f4d28a"),(920,108,"#f1c4ba"),(975,237,"#f4d28a")]:
    ellipse(d,(x-8,y-8,x+8,y+8),color)
    d.line((x-12,y,x+12,y),fill="#fbf3e0",width=3)
    d.line((x,y-12,x,y+12),fill="#fbf3e0",width=3)
banner.save(OUT/"feature-graphic-1024x500.png",optimize=True)
print("STORE ASSETS:",*(str(p) for p in OUT.glob("*.png")))

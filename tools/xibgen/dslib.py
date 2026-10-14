"""Redesign building blocks shared by the specs (glass buttons, primary CTA, chips, title groups…)."""
from xibgen import *


def glass_button(id, symbol, outlet=None, action=None, size=44, icon=20, dark=False, collection=None,
                 accessibility=None, hidden=False):
    """Button/Glass · <symbol> — round, white 75 % (or black 30 % on photos/camera)."""
    ic = Image(id=f"{id}-icon", system=symbol, size=icon * 0.85, weight="semibold",
               tint="white" if dark else "dsTextPrimary")
    b = Control(id=id, cls="DSPressableControl", bg=("#000000", 0.3) if dark else "dsGlass", outlet=outlet,
                collection=collection, accessibility=accessibility, hidden=hidden,
                runtime={"pill": True, "borderWidth": 0.5,
                         "borderColor": ("#FFFFFF", 0.2) if dark else ("#FFFFFF", 0.9),
                         "shadowOpacity": 0.08, "shadowRadius": 7, "shadowOffsetY": 4},
                children=[ic])
    if action:
        b.on(action)
    square(b, size)
    center(ic)
    square(ic, icon)
    return b


def primary_button(id, title, outlet=None, action=None, icon=None, subtitle=None, height=56, title_outlet=None,
                   subtitle_outlet=None, icon_outlet=None, hidden=False):
    """Button/Primary — lime gradient pill (DSPrimaryButton)."""
    parts = []
    if icon:
        parts.append(Image(id=f"{id}-icon", system=icon, size=17, weight="semibold", tint="black",
                           outlet=icon_outlet))
    t = Label(title, id=f"{id}-title", font=("SemiBold", 17), align="center", outlet=title_outlet)
    if subtitle is not None:
        s = Label(subtitle, id=f"{id}-sub", font=("Regular", 12), color=("#000000", 0.7), align="center",
                  outlet=subtitle_outlet)
        parts.append(VStack([t, s], id=f"{id}-labels", spacing=1, align="center"))
    else:
        parts.append(t)
    row = HStack(parts, id=f"{id}-row", spacing=8, align="center")
    b = Control(id=id, cls="DSPrimaryButton", outlet=outlet, children=[row], hidden=hidden)
    if action:
        b.on(action)
    size(b, h=height)
    center(row)
    C(row, "leading", b, "leading", 16, rel="greaterThanOrEqual")
    if icon:
        square(parts[0], 20)
    return b


def secondary_button(id, title, outlet=None, action=None, height=48, bg="dsSurface", color="dsTextPrimary",
                     icon=None, font=("SemiBold", 15)):
    parts = []
    if icon:
        parts.append(Image(id=f"{id}-icon", system=icon, size=15, weight="semibold", tint=color))
    parts.append(Label(title, id=f"{id}-title", font=font, color=color, align="center"))
    row = HStack(parts, id=f"{id}-row", spacing=8, align="center")
    b = Control(id=id, cls="DSPressableControl", bg=bg, outlet=outlet, runtime={"pill": True}, children=[row])
    if action:
        b.on(action)
    size(b, h=height)
    center(row)
    if icon:
        square(parts[0], 18)
    return b


def ghost_button(id, title, outlet=None, action=None, height=44, color="dsTextPrimary"):
    return Button(title, id=id, font=("SemiBold", 15), color=color, outlet=outlet).on(action) if action else \
        Button(title, id=id, font=("SemiBold", 15), color=color, outlet=outlet)


def chip(id, text, selected=False, icon=None, outlet=None, collection=None, tag=None, action=None, height=36,
         label_collection=None):
    """Chip/Default (F2F2F2) or Chip/Selected (lime soft + lime border)."""
    parts = []
    if icon:
        parts.append(Image(id=f"{id}-icon", system=icon, size=13, weight="medium", tint="dsTextPrimary"))
    parts.append(Label(text, id=f"{id}-label", font=("Medium" if selected else "Regular", 14),
                       collection=label_collection, tag_value=tag))
    row = HStack(parts, id=f"{id}-row", spacing=6, align="center", margins=(0, 14, 0, 14))
    c = Control(id=id, cls="DSChipControl", outlet=outlet, collection=collection, tag_value=tag,
                runtime={"pill": True, "isChipSelected": selected}, children=[row])
    if action:
        c.on(action)
    size(c, h=height)
    pin(row)
    if icon:
        square(parts[0], 16)
    return c


def title_group(title, subtitle, id="title", title_outlet="titleLabel", subtitle_outlet="subtitleLabel"):
    t = Label(title, id=f"{id}-title", font=("SemiBold", 28), kern=-0.14, lines=0, outlet=title_outlet,
              resist=(750, 751))
    s = Label(subtitle, id=f"{id}-sub", font=("Regular", 15), color="dsTextSecondary", lines=0,
              lineHeight=1.12, outlet=subtitle_outlet)
    return VStack([t, s], id=f"{id}-group", spacing=6, align="fill", outlet=f"{id}Stack" if id != "title" else "titleStack")


def bottom_fade(id="fade", height=140):
    v = View(id=id, cls="DSGradientView", interaction=False,
             runtime={"startColor": ("#FFFFFF", 0.0), "midColor": "white", "endColor": "white", "angle": 180})
    return v


def sheet_grabber(id="grabber"):
    g = View(id=id, cls="DSView", bg=("#000000", 0.16), runtime={"cornerRadius": 2.5})
    size(g, 36, 5)
    return g

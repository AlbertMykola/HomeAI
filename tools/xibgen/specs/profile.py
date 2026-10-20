from xibgen import *
from dslib import *

DIVIDER = "dsDivider"
LANGUAGES = 15

# (tag, symbol, title, kind) kind: "value" | "chevron" | "toggle"
GROUPS = [
    [(0, "globe", "Language", "value"), (1, "sun.max", "Appearance", "value"), (2, "bell", "Notifications", "toggle")],
    [(3, "arrow.clockwise", "Restore purchases", "chevron")],
    [(5, "questionmark.circle", "Help & feedback", "chevron"), (6, "star", "Rate Rehomely", "chevron"),
     (7, "square.and.arrow.up", "Share with a friend", "chevron")],
    [(8, "checkmark.shield", "Privacy policy", "chevron"), (9, "doc.text", "Terms of use", "chevron")],
]


def settings_row(tag, symbol, title, kind):
    ic = Image(id=f"row{tag}-icon", system=symbol, size=15, weight="medium", tint="dsTextPrimary")
    box = View(id=f"row{tag}-box", cls="DSView", bg="dsCard", runtime={"cornerRadius": 9}, children=[ic])
    lb = Label(title, id=f"row{tag}-title", font=("Medium", 16), collection="rowTitleLabels", tag_value=tag,
               hug=(249, 251), minScale=0.8)
    parts = [box, lb]
    if kind == "value":
        parts.append(Label("English", id=f"row{tag}-value", font=("Regular", 15), color="dsTextTertiary",
                           outlet="languageValueLabel" if tag == 0 else "appearanceValueLabel", hug=(251, 251)))
    if kind == "toggle":
        parts.append(Switch(id=f"row{tag}-switch", on=True, onTint="#34C759", outlet="notificationsSwitch"
                            ).on("didToggleNotifications:", event="valueChanged"))
    else:
        chev = Image(id=f"row{tag}-chev", system="chevron.right", size=13, weight="semibold", tint="dsTextTertiary")
        square(chev, 18)
        parts.append(chev)
    row = HStack(parts, id=f"row{tag}-row", spacing=14, align="center", margins=(0, 16, 0, 16))
    if kind == "toggle":
        ctl = View(id=f"row{tag}", bg="clear", collection="rowViews", tag_value=tag, children=[row])
    else:
        ctl = Control(id=f"row{tag}", cls="DSPressableControl", bg="clear", collection="rowViews", tag_value=tag,
                      runtime={"pressedScale": 0.98, "hapticOnPress": False}, children=[row]).on("didTapRow:")
    size(ctl, h=56)
    pin(row)
    square(box, 32)
    center(ic)
    square(ic, 18)
    return ctl


def group(i, rows):
    items = []
    for j, r in enumerate(rows):
        items.append(settings_row(*r))
        if j < len(rows) - 1:
            div = View(id=f"g{i}-div{j}", bg=DIVIDER)
            size(div, h=1)
            items.append(div)
    g = View(id=f"group{i}", cls="DSView", bg="dsSurface", runtime={"cornerRadius": 20}, clips=True,
             collection="groupViews", tag_value=i, children=[VStack(items, id=f"group{i}-stack", align="fill")])
    pin(g.children[0])
    return g


def perk(i, text):
    ic = Image(id=f"perk{i}-icon", system="checkmark", size=10, weight="bold", tint="dsLime")
    lb = Label(text, id=f"perk{i}-label", font=("Medium", 12), color="white", collection="perkLabels", tag_value=i, lines=0, resist=(750, 1000))
    v = View(id=f"perk{i}", cls="DSView", bg=("#FFFFFF", 0.1), runtime={"cornerRadius": 14},
             children=[HStack([ic, lb], id=f"perk{i}-row", spacing=4, align="center", margins=(6, 10, 6, 10))])
    C(v, "height", const=28, rel="greaterThanOrEqual")
    pin(v.children[0])
    square(ic, 12)
    return v


@xib("HomeAI/Redesign/Profile/ProfileTabViewController.xib")
def profile():
    d = Doc("ProfileTabViewController", owner="ProfileTabViewController")
    root = d.root
    root.bg = "dsBackground"
    sa = d.safe_area

    title = Label("Profile", id="title", font=("SemiBold", 32), outlet="largeTitleLabel")

    # Free plan card
    f_title = Label("Free plan", id="free-title", font=("SemiBold", 20), color="black", outlet="freeTitleLabel", lines=0)
    f_sub = Label("2 of 3 free designs left", id="free-sub", font=("Regular", 14), color="#1F3A00",
                  outlet="freeSubtitleLabel", lines=0)
    f_texts = VStack([f_title, f_sub], id="free-texts", spacing=2, align="fill")
    f_icon = Image(id="free-icon-img", system="sparkles", size=18, weight="semibold", tint="black")
    f_icon_box = View(id="free-icon", cls="DSView", bg=("#FFFFFF", 0.5), runtime={"cornerRadius": 22},
                      children=[f_icon])
    f_head = HStack([f_texts, View(id="free-sp", bg="clear", hug=(1, 250)), f_icon_box], id="free-head",
                    align="center")
    track = View(id="track", cls="DSView", bg=("#000000", 0.1), clips=True, runtime={"cornerRadius": 4}, outlet="progressTrackView")
    fill = View(id="fill", cls="DSView", bg="black", runtime={"cornerRadius": 4}, outlet="progressFillView")
    track.add(fill)
    pro_label = Label("Get Pro", id="getpro-label", font=("SemiBold", 15), color="white", align="center",
                      outlet="getProLabel", lines=0)
    get_pro = Control(id="getpro", cls="DSPressableControl", bg="black", clips=True, runtime={"pill": True},
                      outlet="getProButton", children=[pro_label]).on("didTapGetPro:")
    f_bg = View(id="free-bg", cls="DSGradientView", interaction=False, runtime={"startColor": "#C4FA6A",
                                                                              "endColor": "dsLimeBottom",
                                                                              "angle": 154, "cornerRadius": 26})
    f_col = VStack([f_head, track, get_pro], id="free-col", spacing=14, align="fill")
    free_card = View(id="free-card", cls="DSView", bg="clear", outlet="freeCardView",
                     runtime={"cornerRadius": 26, "shadowColor": "#7BC41A", "shadowOpacity": 0.18, "shadowRadius": 12,
                              "shadowOffsetY": 8},
                     children=[f_bg, f_col])

    # Pro card
    p_title = Label("Rehomely Pro", id="pro-title", font=("SemiBold", 20), color="white", outlet="proTitleLabel", lines=0)
    p_sub = Label("Unlimited designs", id="pro-sub", font=("Regular", 13), color="#A1A1A6", outlet="proSubtitleLabel",
                  lines=0)
    p_texts = VStack([p_title, p_sub], id="pro-texts", spacing=2, align="fill", hug=(249, 250))
    crown = Image(id="crown", system="crown", size=18, weight="semibold", tint="black", outlet="crownImageView")
    crown_box = View(id="crown-box", cls="DSView", bg="dsLime", runtime={"cornerRadius": 22}, children=[crown])
    p_head = HStack([p_texts, crown_box], id="pro-head", align="center", spacing=12)
    perks = HStack([perk(i, t) for i, t in enumerate(["4K export", "No watermark", "All tools"])], id="perks",
                   spacing=8, align="fill", dist="fillEqually")
    perks_row = perks
    resub_label = Label("Resubscribe", id="resub-label", font=("SemiBold", 15), color="black", align="center")
    resub = Control(id="resub", cls="DSPrimaryButton", outlet="resubscribeButton", hidden=True,
                    children=[resub_label]).on("didTapGetPro:")
    size(resub, h=44)
    center(resub_label)
    p_col = VStack([p_head, perks_row, resub], id="pro-col", spacing=14, align="fill")
    pro_card = View(id="pro-card", cls="DSView", bg="dsInk", outlet="proCardView", hidden=True,
                    runtime={"cornerRadius": 26}, children=[p_col])

    # billing retry banner
    bill_icon = Image(id="bill-icon", system="exclamationmark.triangle.fill", size=14, weight="semibold",
                      tint="#B07A00")
    bill_label = Label("Update payment method", id="bill-label", font=("Medium", 14), outlet="billingLabel",
                       lines=2)
    billing = Control(id="billing", cls="DSPressableControl", bg="dsWarningSoft", outlet="billingBanner", hidden=True,
                      runtime={"cornerRadius": 16},
                      children=[HStack([bill_icon, bill_label], id="bill-row", spacing=10, align="center",
                                       margins=(12, 14, 12, 14))]).on("didTapManage:")
    pin(billing.children[0])
    square(bill_icon, 18)

    groups = [group(i, rows) for i, rows in enumerate(GROUPS)]
    version = Label("Rehomely 2.0 (214)", id="version", font=("Regular", 12), color="dsTextTertiary", align="center",
                    outlet="versionLabel")
    bottom = View(id="bottom-pad", bg="clear")
    size(bottom, h=24)
    content = VStack([title, free_card, pro_card, billing] + groups + [version, bottom], id="content", spacing=16,
                     align="fill", outlet="contentStack")
    scroll = Scroll([content], id="scroll", outlet="scrollView", indicators=False)

    fade = View(id="fade", cls="DSGradientView", interaction=False,
                runtime={"startColor": "dsBackgroundClear", "midColor": "dsBackground", "midLocation": 0.45,
                         "endColor": "dsBackground", "angle": 180})
    header_bg = Blur(id="header-bg", style="systemUltraThinMaterial", outlet="headerBackgroundView", alpha=0)
    compact = Label("Profile", id="compact", font=("SemiBold", 17), align="center", outlet="compactTitleLabel",
                    alpha=0)
    header = View(id="header", bg="clear", interaction=False, children=[compact])

    # Restore overlay (spinner)
    spin = Spinner(id="spin", style="large", outlet="restoreSpinner")
    spin_label = Label("Restoring purchases…", id="spin-label", font=("Medium", 15), align="center",
                       outlet="restoreLabel")
    spin_card = View(id="spin-card", cls="DSView", bg="dsCard", runtime={"cornerRadius": 22, "shadowOpacity": 0.12,
                                                                        "shadowRadius": 20, "shadowOffsetY": 8},
                     children=[VStack([spin, spin_label], id="spin-col", spacing=12, align="center")])
    overlay = View(id="overlay", bg=("#000000", 0.25), outlet="restoreOverlay", hidden=True, children=[spin_card])

    root.add(scroll, fade, header_bg, header, overlay)
    pin(scroll)
    pin(content, to=scroll.content, edges="lrb", inset=(0, 20, 0, 20))
    C(content, "top", scroll.content, "top", 8)
    equal(content, scroll.frame, "width", const=-40)

    pin(f_bg, to=free_card)
    pin(f_col, to=free_card, inset=20)
    square(f_icon_box, 44)
    center(f_icon)
    square(f_icon, 22)
    size(track, h=8)
    pin(fill, to=track, edges="ltb")
    C(fill, "width", const=200, outlet="progressFillWidthConstraint", prio=999)
    C(fill, "width", track, "width", rel="lessThanOrEqual")
    C(get_pro, "height", const=48, rel="greaterThanOrEqual")
    center(pro_label)
    C(pro_label, "leading", get_pro, "leading", 16, rel="greaterThanOrEqual")
    C(pro_label, "top", get_pro, "top", 8, rel="greaterThanOrEqual")
    pin(p_col, to=pro_card, inset=20)
    square(crown_box, 44)
    center(crown)
    square(crown, 22)

    pin(fade, edges="lrb")
    size(fade, h=150)
    pin(header_bg, edges="ltr")
    C(header_bg, "bottom", sa, "top", -44)
    pin(header, edges="lr")
    C(header, "top", sa, "top")
    size(header, h=44)
    center(compact)

    pin(overlay)
    center(spin_card)
    size(spin_card, w=220)
    pin(spin_card.children[0], inset=(24, 16, 22, 16))
    return d


@xib("HomeAI/Redesign/Profile/LanguageViewController.xib")
def language():
    d = Doc("LanguageViewController", owner="LanguageViewController")
    root = d.root
    root.bg = "dsBackground"
    sa = d.safe_area
    back = glass_button("back", "chevron.left", action="didTapBack:", accessibility="Back")
    nav_title = Label("Language", id="nav-title", font=("SemiBold", 17), align="center", outlet="navTitleLabel")
    nav = View(id="nav", bg="dsBackground", children=[back, nav_title])
    hint = Label("The app follows your iPhone language by default.", id="hint", font=("Regular", 14),
                 color="dsTextTertiary", lines=0, lineHeight=1.15, outlet="hintLabel")
    rows = []
    for i in range(LANGUAGES):
        native = Label("English", id=f"lang{i}-native", font=("Medium", 16), collection="nativeLabels", tag_value=i)
        eng = Label("English", id=f"lang{i}-en", font=("Regular", 12), color="dsTextTertiary",
                    collection="englishLabels", tag_value=i)
        texts = VStack([native, eng], id=f"lang{i}-texts", spacing=1, align="fill")
        check = Image(id=f"lang{i}-check", system="checkmark", size=15, weight="bold", tint="dsLink",
                      collection="checkViews", tag_value=i)
        square(check, 20)
        row = HStack([texts, check], id=f"lang{i}-row", spacing=12, align="center", margins=(0, 16, 0, 16))
        ctl = Control(id=f"lang{i}", cls="DSPressableControl", bg="clear", collection="languageRows", tag_value=i,
                      runtime={"pressedScale": 0.98, "hapticOnPress": False}, children=[row]).on("didTapLanguage:")
        size(ctl, h=56)
        pin(row)
        rows.append(ctl)
        if i < LANGUAGES - 1:
            div = View(id=f"ldiv{i}", bg=DIVIDER)
            size(div, h=1)
            rows.append(div)
    group_v = View(id="langs", cls="DSView", bg="dsSurface", runtime={"cornerRadius": 20}, clips=True,
                   children=[VStack(rows, id="langs-stack", align="fill")])
    pin(group_v.children[0])
    content = VStack([hint, group_v], id="content", spacing=12, align="fill", outlet="contentStack")
    scroll = Scroll([content], id="scroll", indicators=False)
    root.add(scroll, nav)
    pin(nav, edges="lr")
    C(nav, "top", sa, "top")
    size(nav, h=56)
    pin(back, edges="l", inset=16)
    center(back, x=False)
    center(nav_title)
    pin(scroll, edges="lrb")
    below(scroll, nav, 0)
    pin(content, to=scroll.content, edges="lrb", inset=(0, 20, 24, 20))
    C(content, "top", scroll.content, "top", 12)
    equal(content, scroll.frame, "width", const=-40)
    return d

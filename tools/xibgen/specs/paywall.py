from xibgen import *
from dslib import *

INK = "#0F1A08"
SOFT = "#F1F4EE"
CARD = "#F3F8EC"
MUTED = "#5B6650"
LINK = "#3E7A00"
RAIL = "#DDE7D2"


@xib("HomeAI/Redesign/Paywall/ProPaywallViewController.xib")
def pro_paywall():
    """A/02 · P1 Paywall (+ trial off, P4 processing). Light only (design has no dark variant)."""
    d = Doc("ProPaywallViewController", owner="ProPaywallViewController")
    root = d.root
    root.bg = "white"
    sa = d.safe_area

    close_icon = Image(id="close-icon", system="xmark", size=15, weight="semibold", tint=INK)
    close = Control(id="close", cls="DSPressableControl", bg=SOFT, runtime={"pill": True}, outlet="closeButton",
                    accessibility="Close", children=[close_icon]).on("didTapClose:")
    square(close, 44)
    center(close_icon)
    square(close_icon, 18)
    restore_label = Label("Restore", id="restore-label", font=("Medium", 16), color=INK, outlet="restoreLabel")
    restore = Control(id="restore", cls="DSPressableControl", bg=SOFT, runtime={"pill": True}, outlet="restoreButton",
                      children=[HStack([restore_label], id="restore-row", align="center", margins=(0, 16, 0, 16))]
                      ).on("didTapRestore:")
    size(restore, h=40)
    pin(restore.children[0])

    title = Label("Ready to go PRO?", id="title", font=("Bold", 31), color=INK, align="center", kern=-0.62,
                  outlet="titleLabel", minScale=0.7, resist=(750, 1000))
    subtitle = Label("Enjoy 3 days free — cancel anytime.", id="subtitle", font=("Regular", 17), color=INK,
                     align="center", outlet="subtitleLabel", minScale=0.7, resist=(750, 1000))

    diorama = Image(id="diorama", image="paywall_diorama", mode="scaleAspectFit", outlet="illustrationView",
                    hug=(250, 250), resist=(250, 250))
    sparkles = []
    for i, (x, y, s) in enumerate([(8, 24, 22), (312, 6, 18), (296, 128, 12), (30, 120, 12)]):
        sp = Image(id=f"sparkle{i}", image=f"paywall_sparkle_{i + 1}", collection="sparkleViews", tag_value=i)
        sparkles.append((sp, x, y, s))
    stage = View(id="stage", bg="clear", outlet="stageView", children=[diorama] + [s[0] for s in sparkles])

    card_title = Label("Rehomely PRO", id="card-title", font=("SemiBold", 21), color=INK, outlet="cardTitleLabel")
    card_body = Label("Unlimited AI redesigns for any room, real paint colors and HD export.", id="card-body",
                      font=("Regular", 15), color=MUTED, lines=0, lineHeight=1.12, outlet="cardBodyLabel")
    card_price = Label("3-day free trial, then $9.99/year", id="card-price", font=("Medium", 15), color=INK,
                       outlet="cardPriceLabel", minScale=0.7, resist=(750, 1000))
    card = View(id="card", cls="DSView", bg=CARD, runtime={"cornerRadius": 24}, outlet="cardView",
                children=[VStack([card_title, card_body, card_price], id="card-col", spacing=8, align="fill")])
    pin(card.children[0], inset=(18, 20, 18, 20))

    trial_label = Label("Free Trial Enabled", id="trial-label", font=("SemiBold", 17), color=INK,
                        outlet="trialLabel", minScale=0.7)
    seal = Image(id="seal", system="checkmark.seal.fill", size=26, weight="regular", tint="#7BC41A",
                 outlet="trialBadgeView")
    trial = Control(id="trial", cls="DSPressableControl", bg="dsLimeSoft", outlet="trialToggle",
                    runtime={"cornerRadius": 20, "borderWidth": 1.5, "borderColor": "dsLime", "pressedScale": 0.98},
                    children=[HStack([trial_label, View(id="trial-sp", bg="clear", hug=(1, 250)), seal],
                                     id="trial-row", align="center", margins=(0, 20, 0, 18))]).on("didTapTrial:")
    size(trial, h=60)
    pin(trial.children[0])
    square(seal, 30)

    # due timeline
    rail = View(id="rail", bg=RAIL, outlet="railView")
    rail_fill = View(id="rail-fill", bg=LINK, outlet="railFillView")
    dot_today = View(id="dot-today", cls="DSView", bg=LINK, runtime={"pill": True}, outlet="dotTodayView")
    dot_charge = View(id="dot-charge", cls="DSView", bg=INK, runtime={"pill": True}, outlet="dotChargeView")
    due_title = Label("Due today", id="due-title", font=("SemiBold", 17), color=INK, outlet="dueTodayLabel",
                      minScale=0.75, resist=(740, 750))
    due_free = Label("3 days free", id="due-free", font=("SemiBold", 16), color=LINK, outlet="dueFreeLabel",
                     minScale=0.7, resist=(745, 750))
    due_price = Label("$0.00", id="due-price", font=("SemiBold", 17), color=INK, outlet="dueTodayPriceLabel",
                      resist=(1000, 750))
    row1 = HStack([due_title, View(id="due-sp1", bg="clear", hug=(1, 250)), due_free, due_price], id="due-row1",
                  spacing=6, align="center")
    charge_title = Label("Due Oct 16, 2026", id="charge-title", font=("Regular", 17), color=INK,
                         outlet="chargeDateLabel", minScale=0.75)
    charge_price = Label("$9.99", id="charge-price", font=("Regular", 17), color=INK, outlet="chargePriceLabel",
                         resist=(1000, 750))
    row2 = HStack([charge_title, View(id="due-sp2", bg="clear", hug=(1, 250)), charge_price], id="due-row2",
                  align="center", outlet="chargeRow")
    timeline = View(id="timeline", bg="clear", outlet="timelineView",
                    children=[rail, rail_fill, dot_today, dot_charge, row1, row2])

    shield = Image(id="shield", system="checkmark.shield.fill", size=15, weight="regular", tint="#7BC41A")
    note = Label("No payment now", id="note", font=("Medium", 15), color=INK, outlet="noteLabel")
    note_row = HStack([shield, note], id="note-row", spacing=7, align="center", outlet="noteRow")
    square(shield, 18)
    note_wrap = View(id="note-wrap", bg="clear", children=[note_row])

    content = VStack([title, subtitle, stage, card, trial, timeline, note_wrap], id="content", spacing=12,
                     align="fill", outlet="contentStack")

    cta_label = Label("Start Free Trial", id="cta-label", font=("Bold", 18), color=INK, align="center",
                      outlet="ctaLabel")
    cta_spin = Spinner(id="cta-spin", style="medium", outlet="ctaSpinner", animating=False, hidden=True)
    cta_row = HStack([cta_spin, cta_label], id="cta-row", spacing=10, align="center")
    cta = Control(id="cta", cls="DSPrimaryButton", outlet="ctaButton", children=[cta_row]).on("didTapCTA:")
    size(cta, h=58)
    center(cta_row)

    terms = Button("Terms of Use", id="terms", font=("Regular", 14), color=LINK, outlet="termsButton").on("didTapTerms:")
    bar = Label("|", id="bar", font=("Regular", 14), color="#B5C2A8")
    privacy = Button("Privacy Policy", id="privacy", font=("Regular", 14), color=LINK,
                     outlet="privacyButton").on("didTapPrivacy:")
    footer = HStack([terms, bar, privacy], id="footer", spacing=12, align="center")

    root.add(content, cta, footer, close, restore)

    pin(close, edges="l", inset=16)
    C(close, "top", sa, "top", 4)
    pin(restore, edges="r", inset=16)
    center(restore, to=close, x=False)

    pin(content, edges="lr", inset=20)
    C(content, "top", close, "bottom", 8)
    C(cta, "top", content, "bottom", 12, rel="greaterThanOrEqual")
    # The illustration gives way first when the screen is short (title / prices never clip).
    C(stage, "height", const=214, prio=740, outlet="stageHeightConstraint")
    C(stage, "height", const=120, rel="greaterThanOrEqual")
    pin(diorama, to=stage, edges="tb")
    center(diorama, to=stage, y=False)
    size(diorama, w=340)
    for sp, x, y, s in sparkles:
        C(sp, "leading", diorama, "leading", x)
        C(sp, "top", stage, "top", y)
        square(sp, s)

    size(timeline, h=58)
    C(rail, "leading", timeline, "leading", 5)
    C(rail, "top", timeline, "top", 10)
    size(rail, 3, 34)
    C(rail_fill, "leading", rail, "leading")
    C(rail_fill, "top", rail, "top")
    C(rail_fill, "width", rail, "width")
    C(rail_fill, "height", const=34, outlet="railFillHeightConstraint")
    pin(dot_today, edges="l")
    C(dot_today, "top", timeline, "top", 4)
    square(dot_today, 13)
    pin(dot_charge, edges="l")
    C(dot_charge, "top", timeline, "top", 40)
    square(dot_charge, 13)
    pin(row1, edges="tr")
    C(row1, "leading", timeline, "leading", 22)
    pin(row2, edges="r")
    C(row2, "leading", timeline, "leading", 22)
    C(row2, "top", timeline, "top", 36)

    pin(note_row, to=note_wrap, edges="tb", inset=(10, 0, 0, 0))
    center(note_row, to=note_wrap, y=False)

    pin(cta, edges="lr", inset=20)
    below(footer, cta, 16)
    center(footer, y=False)
    C(sa, "bottom", footer, "bottom", 8)
    return d


@xib("HomeAI/Redesign/Paywall/WelcomeProViewController.xib")
def welcome_pro():
    """A/02 · P5 Welcome to Pro (confetti in code)."""
    d = Doc("WelcomeProViewController", owner="WelcomeProViewController")
    root = d.root
    root.bg = "white"
    sa = d.safe_area
    bg = View(id="bg", cls="DSGradientView", interaction=False,
              runtime={"startColor": "#D8FFA0", "midColor": "#F4FFE6", "midLocation": 0.55, "endColor": "white",
                       "angle": 180})
    crown = Image(id="crown", system="crown", size=48, weight="semibold", tint="dsLime")
    mark = View(id="mark", cls="DSView", bg="black", outlet="markView",
                runtime={"cornerRadius": 40, "shadowOpacity": 0.25, "shadowRadius": 20, "shadowOffsetY": 16},
                children=[crown])
    title = Label("Welcome to Pro", id="title", font=("SemiBold", 34), color="black", align="center", kern=-0.34,
                  outlet="titleLabel")
    sub = Label("Everything is unlocked. Go make every room yours.", id="sub", font=("Regular", 16),
                color="#404040", align="center", lines=0, lineHeight=1.17, outlet="subtitleLabel")
    items = []
    for i, text in enumerate(["Unlimited redesigns", "All 11 tools", "HD export without caption"]):
        ic = Image(id=f"item{i}-icon", system="checkmark.circle", size=17, weight="medium", tint="#3E7A00")
        lb = Label(text, id=f"item{i}-label", font=("Medium", 16), color="black", collection="itemLabels",
                   tag_value=i)
        square(ic, 22)
        items.append(HStack([ic, lb], id=f"item{i}", spacing=10, align="center"))
    lst = View(id="list", cls="DSView", bg=("#FFFFFF", 0.8), outlet="listView",
               runtime={"cornerRadius": 24, "shadowOpacity": 0.06, "shadowRadius": 12, "shadowOffsetY": 8},
               children=[VStack(items, id="list-col", spacing=12, align="fill")])
    cta = primary_button("start", "Start designing", outlet="startButton", action="didTapStart:", icon="sparkles",
                         title_outlet="startLabel")
    root.add(bg, mark, title, sub, lst, cta)
    pin(bg)
    center(mark, y=False)
    C(mark, "top", sa, "top", 166)
    square(mark, 120)
    center(crown)
    square(crown, 60)
    pin(title, edges="lr", inset=20)
    below(title, mark, 40)
    center(sub, y=False)
    below(sub, title, 12)
    C(sub, "width", const=300)
    pin(lst, edges="lr", inset=20)
    below(lst, sub, 30)
    pin(lst.children[0], inset=20)
    pin(cta, edges="lr", inset=20)
    C(sa, "bottom", cta, "bottom", 4)
    return d


@xib("HomeAI/Redesign/Paywall/ProFeatureSheetViewController.xib")
def pro_feature_sheet():
    """A/02 · P3 Pro feature: contextual upsell sheet."""
    d = Doc("ProFeatureSheetViewController", owner="ProFeatureSheetViewController", size=(393, 520))
    root = d.root
    root.bg = "dsBackground"
    close = glass_button("close", "xmark", action="didTapClose:", size=36, icon=16, accessibility="Close")
    crown = Image(id="crown", system="crown", size=26, weight="semibold", tint="black")
    hero = View(id="hero", cls="DSGradientView", outlet="heroView",
                runtime={"startColor": "dsLimeTop", "endColor": "dsLimeBottom", "angle": 180, "cornerRadius": 38},
                children=[crown])
    hero_wrap = View(id="hero-wrap", bg="clear", children=[hero])
    title = Label("Share without watermark", id="title", font=("SemiBold", 24), align="center", lines=0,
                  outlet="titleLabel")
    sub = Label("This is a Pro feature. Pro also unlocks:", id="sub", font=("Regular", 15), color="dsTextSecondary",
                align="center", lines=0, outlet="subtitleLabel")
    rows = []
    for i in range(4):
        ic = Image(id=f"b{i}-icon", system="checkmark", size=12, weight="bold", tint="#3E7A00")
        box = View(id=f"b{i}-box", cls="DSView", bg="dsLimeSoft", runtime={"cornerRadius": 14}, children=[ic])
        lb = Label("No watermark on shared images", id=f"b{i}-label", font=("Regular", 15), lines=0,
                   collection="benefitLabels", tag_value=i)
        square(box, 28)
        center(ic)
        square(ic, 16)
        rows.append(HStack([box, lb], id=f"b{i}", spacing=12, align="center", collection="benefitRows", tag_value=i))
    benefits = VStack(rows, id="benefits", spacing=12, align="fill", margins=(6, 4, 6, 4))
    price = Label("$19.99 / year · cancel anytime", id="price", font=("Regular", 13), color="dsTextTertiary",
                  align="center", outlet="priceLabel")
    see = primary_button("see", "See Pro plans", outlet="seeButton", action="didTapSee:", title_outlet="seeLabel")
    notnow = Button("Not now", id="notnow", font=("SemiBold", 17), color="dsTextPrimary",
                    outlet="notNowButton").on("didTapClose:")
    size(notnow, h=56)
    col = VStack([hero_wrap, title, sub, benefits, price, see, notnow], id="col", spacing=14, align="fill")
    root.add(col, close)
    pin(col, edges="lr", inset=20)
    C(col, "top", root, "top", 24)
    # Sheet height = content (custom detents already sit above the home indicator).
    C(d.safe_area, "bottom", col, "bottom", 4, prio=250)
    pin(hero, to=hero_wrap, edges="tb")
    center(hero, to=hero_wrap, y=False)
    square(hero, 76)
    center(crown)
    square(crown, 34)
    pin(close, edges="tr", inset=16)
    return d

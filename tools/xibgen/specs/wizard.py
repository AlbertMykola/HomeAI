from xibgen import *
from dslib import *


def nav_bar_slot(root, sa):
    """WizardNavBar (own XIB) placed under the status bar."""
    nav = View(id="nav", cls="WizardNavBar", bg="clear", outlet="navBar")
    root.add(nav)
    pin(nav, edges="lr")
    C(nav, "top", sa, "top", -4)
    size(nav, h=56)
    return nav


def cta_area(root, sa, button):
    fade = bottom_fade()
    root.add(fade, button)
    pin(fade, edges="lrb")
    size(fade, h=140)
    pin(button, edges="lr", inset=20)
    C(sa, "bottom", button, "bottom", 0)
    return fade


@xib("HomeAI/Redesign/Wizard/WizardNavBar.xib")
def wizard_nav_bar():
    d = Doc("WizardNavBar", owner="WizardNavBar", size=(393, 56))
    root = d.root
    root.bg = "clear"
    back = glass_button("back", "chevron.left", outlet="backButton", action="didTapWizardBack:",
                        accessibility="Back")
    close = glass_button("close", "xmark", outlet="closeButton", action="didTapWizardClose:",
                         accessibility="Close")
    steps = []
    for i in range(4):
        s = View(id=f"step{i}", cls="DSView", bg="dsStepOff", collection="stepViews", tag_value=i,
                 runtime={"cornerRadius": 3})
        steps.append(s)
    stepper = HStack(steps, id="stepper", spacing=6, align="center", outlet="stepperStack")
    root.add(back, close, stepper)
    pin(back, edges="l", inset=16)
    center(back, x=False)
    pin(close, edges="r", inset=16)
    center(close, x=False)
    center(stepper)
    for i, s in enumerate(steps):
        size(s, h=6)
        C(s, "width", const=8, outlet=None)
    return d


@xib("HomeAI/Redesign/Wizard/WizardPhotoViewController.xib")
def wizard_photo():
    d = Doc("WizardPhotoViewController", owner="WizardPhotoViewController")
    root = d.root
    root.bg = "white"
    sa = d.safe_area

    titles = title_group("Add a photo of your room", "One wide, well-lit photo works best.")

    def source(id, title, sub, symbol, dark, action, outlet):
        box_icon = Image(id=f"{id}-icon", system=symbol, size=21, weight="medium", tint="black")
        box = View(id=f"{id}-box", cls="DSView", bg="dsLime" if dark else "white", runtime={"cornerRadius": 18},
                   children=[box_icon])
        t = Label(title, id=f"{id}-t", font=("SemiBold", 18), color="white" if dark else "dsTextPrimary",
                  minScale=0.8, collection="sourceTitleLabels", tag_value=0 if dark else 1)
        s = Label(sub, id=f"{id}-s", font=("Regular", 13), color=("#FFFFFF", 0.7) if dark else "dsTextTertiary",
                  minScale=0.8, collection="sourceSubtitleLabels", tag_value=0 if dark else 1)
        texts = VStack([t, s], id=f"{id}-texts", spacing=3, align="fill")
        chev = Image(id=f"{id}-chev", system="chevron.right", size=15, weight="semibold",
                     tint="white" if dark else "dsTextTertiary")
        row = HStack([box, texts, chev], id=f"{id}-row", spacing=16, align="center", margins=(0, 20, 0, 20))
        card = Control(id=id, cls="DSPressableControl", bg="black" if dark else "dsSurface", outlet=outlet,
                       runtime={"cornerRadius": 28}, children=[row]).on(action)
        size(card, h=120)
        pin(row)
        square(box, 56)
        center(box_icon)
        square(box_icon, 26)
        square(chev, 20)
        return card

    take = source("take", "Take a photo", "Camera with a framing guide", "camera", True, "didTapTakePhoto:",
                  "takePhotoCard")
    library = source("library", "Choose from library", "Only the photo you pick is shared", "photo.on.rectangle",
                     False, "didTapLibrary:", "libraryCard")
    demo_title = Label("No photo handy? Try one of ours", id="demo-title", font=("SemiBold", 15),
                       outlet="demoTitleLabel")
    demos = []
    for i, n in enumerate(["living", "study", "kitchen"]):
        img = Image(id=f"demo-{n}-img", image=f"wizard_demo_{n}", mode="scaleAspectFill")
        c = Control(id=f"demo-{n}", cls="DSPressableControl", clips=True, bg="dsSurface", tag_value=i,
                    collection="demoControls", runtime={"cornerRadius": 20}, children=[img]).on("didTapDemo:")
        pin(img)
        demos.append(c)
    demo_row = HStack(demos, id="demo-row", spacing=10, dist="fillEqually")
    bulb = Image(id="tips-icon", system="lightbulb", size=15, weight="medium", tint="black", outlet="tipsIconView")
    tips_label = Label("Photo tips", id="tips-label", font=("Medium", 15), outlet="tipsLabel")
    tips = Control(id="tips", cls="DSPressableControl", bg="dsLimeSoft", outlet="tipsButton",
                   runtime={"pill": True},
                   children=[HStack([bulb, tips_label], id="tips-row", spacing=8, align="center",
                                    margins=(0, 14, 0, 16))]).on("didTapTips:")
    tips_wrap = View(id="tips-wrap", bg="clear", children=[tips])
    sources = VStack([take, library, View(id="gap1", bg="clear"), demo_title, demo_row, View(id="gap2", bg="clear"),
                      tips_wrap], id="sources", spacing=12, outlet="sourcesStack")

    # selected state
    photo = Image(id="photo", mode="scaleAspectFill", outlet="photoImageView")
    scan = View(id="scan", cls="DSGradientView", interaction=False, outlet="scanLineView", alpha=0,
                runtime={"startColor": ("#A5EE2F", 0.0), "midColor": ("#A5EE2F", 0.45), "endColor": "dsLime",
                         "midLocation": 0.97, "angle": 180})
    change_icon = Image(id="change-icon", system="arrow.clockwise", size=13, weight="semibold", tint="white")
    change_label = Label("Change", id="change-label", font=("Medium", 14), color="white", outlet="changeLabel")
    change = Control(id="change", cls="DSPressableControl", bg=("#000000", 0.35), outlet="changeButton",
                     runtime={"pill": True},
                     children=[HStack([change_icon, change_label], id="change-row", spacing=6, align="center",
                                      margins=(0, 14, 0, 14))]).on("didTapChange:")
    check_icon = Image(id="check-icon", system="checkmark.circle", size=15, weight="semibold", tint="dsLink",
                       outlet="checkIconView")
    check_label = Label("Living room · good light", id="check-label", font=("Medium", 14), outlet="checkLabel")
    check = View(id="check", cls="DSView", bg=("#FFFFFF", 0.85), outlet="checkBadgeView", runtime={"pill": True},
                 alpha=0,
                 children=[HStack([check_icon, check_label], id="check-row", spacing=6, align="center",
                                  margins=(0, 12, 0, 14))])
    preview = View(id="preview", cls="DSView", clips=True, bg="dsSurface", outlet="previewView", hidden=True,
                   runtime={"cornerRadius": 34}, children=[photo, scan, change, check])

    content = VStack([titles, sources, preview], id="content", spacing=40)
    scroll = Scroll([content], id="scroll", outlet="scrollView")
    root.add(scroll)
    nav = nav_bar_slot(root, sa)
    next_btn = primary_button("next", "Next", outlet="nextButton", action="didTapNext:", title_outlet="nextTitleLabel")
    cta_area(root, sa, next_btn)

    pin(scroll, edges="lrb")
    below(scroll, nav, 0)
    pin(content, to=scroll.content, edges="lr", inset=(0, 20, 0, 20))
    C(content, "top", scroll.content, "top", 8)
    C(scroll.content, "bottom", content, "bottom", 110)
    C(content, "width", scroll.frame, "width", -40)
    size(View(id="dummy", bg="clear"), None, None) if False else None
    size(sources.children[2], h=8)
    size(sources.children[5], h=16)
    size(demo_row, h=130)
    pin(tips, edges="ltb")
    size(tips, h=40)
    pin(tips.children[0])
    square(bulb, 18)
    size(preview, h=470)
    pin(photo)
    pin(scan, edges="lr")
    size(scan, h=90)
    C(scan, "bottom", preview, "top", 0, outlet="scanBottomConstraint")
    pin(change, edges="tr", inset=16)
    size(change, h=36)
    pin(change.children[0])
    square(change_icon, 16)
    pin(check, edges="lb", inset=16)
    size(check, h=36)
    pin(check.children[0])
    square(check_icon, 18)
    return d


@xib("HomeAI/Redesign/Wizard/WizardTileCell.xib")
def wizard_tile_cell():
    d = Doc("WizardTileCell", kind="collectionCell", cls="WizardTileCell", size=(109, 112), reuse="WizardTileCell")
    icon = Image(id="icon", outlet="iconView", tint="dsTextPrimary")
    label = Label("Living room", id="label", font=("Medium", 13), align="center", minScale=0.75, outlet="titleLabel")
    col = VStack([icon, label], id="col", spacing=8, align="center")
    check_icon = Image(id="check-icon", system="checkmark", size=11, weight="bold", tint="dsLime")
    check = View(id="check", cls="DSView", bg="black", outlet="checkView", alpha=0, runtime={"pill": True},
                 children=[check_icon])
    badge_label = Label("Detected", id="badge-label", font=("SemiBold", 10), outlet="badgeLabel")
    badge = View(id="badge", cls="DSView", bg="white", outlet="badgeView", hidden=True, runtime={"pill": True},
                 children=[badge_label])
    tile = View(id="tile", cls="DSView", bg="dsSurface", outlet="tileView", runtime={"cornerRadius": 24},
                children=[col, check, badge])
    d.cell(tile)
    pin(tile)
    center(col)
    C(col, "leading", tile, "leading", 4, rel="greaterThanOrEqual")
    size(icon, 40, 48)
    pin(check, edges="tr", inset=6)
    square(check, 24)
    center(check_icon)
    pin(badge, edges="lt", inset=7)
    size(badge, h=18)
    pin(badge_label, edges="lr", inset=(0, 7, 0, 7))
    center(badge_label, x=False)
    return d


def step_grid_screen(name, title, subtitle, cell_size, spacing, chips=None):
    d = Doc(name, owner=name)
    root = d.root
    root.bg = "white"
    sa = d.safe_area
    titles = title_group(title, subtitle)
    root.add(titles)
    nav = nav_bar_slot(root, sa)
    pin(titles, edges="lr", inset=20)
    below(titles, nav, 8)
    top_anchor = titles
    gap = 24
    if chips:
        chip_views = [chip(f"chip-{i}", t, selected=(i == 0), collection="filterChips", tag=i,
                           action="didTapFilter:") for i, t in enumerate(chips)]
        chip_stack = HStack(chip_views, id="chips", spacing=8, margins=(0, 20, 0, 20))
        chip_scroll = Scroll([chip_stack], id="chip-scroll", horizontal=True, outlet="chipScrollView")
        root.add(chip_scroll)
        pin(chip_scroll, edges="lr")
        below(chip_scroll, titles, 22)
        size(chip_scroll, h=36)
        pin(chip_stack, to=chip_scroll.content)
        equal(chip_stack, chip_scroll.frame, "height")
        top_anchor = chip_scroll
        gap = 16
    cv = Collection(id="grid", spacing=spacing, item=cell_size, insets=(0, 20, 120, 20), outlet="collectionView")
    root.add(cv)
    pin(cv, edges="lrb")
    below(cv, top_anchor, gap)
    fade = bottom_fade()
    root.add(fade)
    pin(fade, edges="lrb")
    size(fade, h=90)
    root.children.remove(nav)
    root.children.append(nav)
    return d


@xib("HomeAI/Redesign/Wizard/WizardRoomViewController.xib")
def wizard_room():
    return step_grid_screen("WizardRoomViewController", "Which room is it?",
                            "We guessed from your photo. Tap to confirm.", (109, 112), 13)


@xib("HomeAI/Redesign/Wizard/WizardStyleViewController.xib")
def wizard_style():
    return step_grid_screen("WizardStyleViewController", "Pick a style", "Swipe for more. You can mix styles later.",
                            (109, 159), 13, chips=["All", "Popular", "Cozy", "Minimal", "Seasonal"])


@xib("HomeAI/Redesign/Wizard/WizardStyleCell.xib")
def wizard_style_cell():
    d = Doc("WizardStyleCell", kind="collectionCell", cls="WizardStyleCell", size=(109, 159), reuse="WizardStyleCell")
    img = Image(id="img", mode="scaleAspectFill", outlet="previewImageView")
    pop_label = Label("Popular", id="pop-label", font=("SemiBold", 10))
    pop = View(id="pop", cls="DSView", bg=("#FFFFFF", 0.85), outlet="popularBadge", hidden=True,
               runtime={"pill": True}, children=[pop_label])
    # Custom tile content
    pen = Image(id="pen", system="pencil", size=17, weight="semibold", tint="black")
    pen_box = View(id="pen-box", cls="DSView", bg="dsLime", runtime={"pill": True}, children=[pen],
                   outlet="customIconBox")
    describe = Label("Describe", id="describe", font=("Medium", 12), color=("#FFFFFF", 0.8), outlet="describeLabel")
    custom = VStack([pen_box, describe], id="custom", spacing=6, align="center", outlet="customStack", hidden=True)
    check_icon = Image(id="check-icon", system="checkmark", size=12, weight="bold", tint="dsLime")
    check = View(id="check", cls="DSView", bg="black", outlet="checkView", alpha=0, runtime={"pill": True},
                 children=[check_icon])
    tile = View(id="tile", cls="DSView", clips=True, bg="dsSurface", outlet="tileView",
                runtime={"cornerRadius": 22}, children=[img, pop, custom, check])
    title = Label("Modern", id="title", font=("Medium", 13), minScale=0.75, outlet="titleLabel")
    d.cell(tile, title)
    pin(tile, edges="ltr")
    size(tile, h=136)
    below(title, tile, 6)
    pin(title, edges="lr")
    pin(img)
    pin(pop, edges="lt", inset=8)
    size(pop, h=20)
    pin(pop_label, edges="lr", inset=(0, 7, 0, 7))
    center(pop_label, x=False)
    center(custom)
    square(pen_box, 44)
    center(pen)
    pin(check, edges="tr", inset=5)
    square(check, 26)
    center(check_icon)
    return d


@xib("HomeAI/Redesign/Wizard/WizardFinalViewController.xib")
def wizard_final():
    d = Doc("WizardFinalViewController", owner="WizardFinalViewController")
    root = d.root
    root.bg = "white"
    sa = d.safe_area
    titles = title_group("Final touches", "Here's what we'll make. Tap any item to edit.")

    thumb = Image(id="thumb", mode="scaleAspectFill", cls="DSImageView", runtime={"cornerRadius": 16},
                  outlet="thumbImageView")
    room_chip = chip("room-chip", "Living room", icon="sofa", outlet="roomChip", action="didTapRoomChip:",
                     height=32, label_collection="summaryChipLabels", tag=0)
    style_chip = chip("style-chip", "Japandi", icon="paintpalette", outlet="styleChip", action="didTapStyleChip:",
                      height=32, label_collection="summaryChipLabels", tag=1)
    chip_row = HStack([room_chip, style_chip, View(id="chip-spacer", bg="clear", hug=(1, 250))], id="chip-row",
                      spacing=8, align="center")
    kind = Label("Interior redesign", id="kind", font=("Regular", 13), color="dsTextTertiary", outlet="kindLabel")
    chips_col = VStack([chip_row, kind], id="chips-col", spacing=8, align="fill")
    summary = View(id="summary", cls="DSView", bg="dsSurface", runtime={"cornerRadius": 24}, outlet="summaryView",
                   children=[HStack([thumb, chips_col], id="summary-row", spacing=12, align="center",
                                    margins=(12, 12, 12, 12))])

    structure_title = Label("Structure", id="structure-title", font=("SemiBold", 17), outlet="structureTitleLabel")
    seg_knob = View(id="seg-knob", cls="DSView", bg="white", outlet="segmentKnob",
                    runtime={"cornerRadius": 19, "shadowOpacity": 0.12, "shadowRadius": 3, "shadowOffsetY": 2})
    seg_keep = Control(id="seg-keep", cls="DSPressableControl", tag_value=0, collection="segmentControls",
                       runtime={"pressedScale": 0.98, "hapticOnPress": False},
                       children=[Label("Keep structure", id="seg-keep-label", font=("SemiBold", 14), align="center",
                                       collection="segmentLabels", tag_value=0)]).on("didTapSegment:")
    seg_free = Control(id="seg-free", cls="DSPressableControl", tag_value=1, collection="segmentControls",
                       runtime={"pressedScale": 0.98, "hapticOnPress": False},
                       children=[Label("More freedom", id="seg-free-label", font=("Medium", 14), color="dsTextSecondary",
                                       align="center", collection="segmentLabels", tag_value=1)]).on("didTapSegment:")
    seg_row = HStack([seg_keep, seg_free], id="seg-row", dist="fillEqually")
    segmented = View(id="segmented", cls="DSView", bg="dsSegment", runtime={"cornerRadius": 22},
                     children=[seg_knob, seg_row], outlet="segmentedView")
    shield = Image(id="shield", system="checkmark.shield", size=15, weight="medium", tint="dsLink",
                   outlet="modeIconView")
    explainer_label = Label("Walls, windows and furniture layout stay. Only the style changes.", id="explainer",
                            font=("Regular", 13), color="dsTextSecondary", lines=0, lineHeight=1.1,
                            outlet="modeExplainerLabel")
    explainer = HStack([shield, explainer_label], id="explainer-row", spacing=10, align="top")

    palette_title = Label("Color palette", id="palette-title", font=("SemiBold", 17), outlet="paletteTitleLabel")
    palettes = [("auto", "Auto", None), ("warm", "Warm", ["#E8D9C4", "#B98B64", "#6E5641"]),
                ("sage", "Sage", ["#DDE5D3", "#93A584", "#4F5F45"]), ("cool", "Cool", ["#E4E7EB", "#9AA3AD", "#4A525C"]),
                ("earthy", "Earthy", ["#E9D3B8", "#B5643C", "#5A3A26"]), ("bold", "Bold", ["#F2C14E", "#2F5D8A", "#C24D3C"])]
    pal_views = []
    for i, (key, title, colors) in enumerate(palettes):
        if colors:
            bands = [View(id=f"pal-{key}-c{j}", bg=c) for j, c in enumerate(colors)]
            swatch_inner = HStack(bands, id=f"pal-{key}-bands", dist="fillEqually")
        else:
            swatch_inner = Image(id=f"pal-{key}-icon", system="sparkles", size=18, weight="medium", tint="black")
        swatch = View(id=f"pal-{key}-swatch", cls="DSView", clips=True, bg="dsLimeSoft" if not colors else "clear",
                      runtime={"pill": True}, children=[swatch_inner], collection="paletteSwatches", tag_value=i)
        ring = View(id=f"pal-{key}-ring", cls="DSView", bg="clear", collection="paletteRings", tag_value=i,
                    runtime={"pill": True, "borderWidth": 2, "borderColor": "black"}, alpha=1 if i == 0 else 0,
                    interaction=False)
        lab = Label(title, id=f"pal-{key}-label", font=("SemiBold" if i == 0 else "Regular", 12), align="center",
                    collection="paletteLabels", tag_value=i, minScale=0.6)
        swatch_wrap = View(id=f"pal-{key}-wrap", bg="clear", children=[swatch, ring])
        col = VStack([swatch_wrap, lab], id=f"pal-{key}-col", spacing=6, align="center")
        ctrl = Control(id=f"pal-{key}", cls="DSPressableControl", tag_value=i, collection="paletteControls",
                       children=[col], accessibility=title).on("didTapPalette:")
        pal_views.append((ctrl, col, swatch_wrap, swatch, ring, swatch_inner, bool(colors)))
    pal_stack = HStack([p[0] for p in pal_views], id="pal-stack", spacing=12, margins=(0, 20, 0, 20))
    pal_scroll = Scroll([pal_stack], id="pal-scroll", horizontal=True, outlet="paletteScrollView", clips=False)

    details_title = Label("Anything specific? (optional)", id="details-title", font=("SemiBold", 17),
                          outlet="detailsTitleLabel")
    pencil = Image(id="pencil", system="pencil", size=15, weight="medium", tint="dsTextTertiary")
    field = TextField(placeholder="e.g. light oak floor, no rug", font=("Regular", 15), id="details-field",
                      outlet="detailsField")
    details = View(id="details", cls="DSView", bg="dsSurface", runtime={"cornerRadius": 18}, outlet="detailsBox",
                   children=[HStack([pencil, field], id="details-row", spacing=10, align="center",
                                    margins=(0, 16, 0, 16))])

    def inset(v, id, t=0):
        w = View(id=id, bg="clear", children=[v])
        pin(v, inset=(t, 20, 0, 20))
        return w

    content = VStack([
        inset(titles, "w-title"), inset(summary, "w-summary", 24), inset(structure_title, "w-structure", 16),
        inset(segmented, "w-seg", 12), inset(explainer, "w-explainer", 10), inset(palette_title, "w-pal-title", 18),
        View(id="w-pal", bg="clear", children=[pal_scroll]), inset(details_title, "w-details-title", 12),
        inset(details, "w-details", 12)], id="content", outlet="contentStack")
    scroll = Scroll([content], id="scroll", outlet="scrollView")
    root.add(scroll)
    nav = nav_bar_slot(root, sa)
    gen = primary_button("generate", "Generate design", outlet="generateButton", action="didTapGenerate:",
                         icon="sparkles", subtitle="Uses 1 of your 2 free designs", title_outlet="generateTitleLabel",
                         subtitle_outlet="generateSubtitleLabel", icon_outlet="generateIconView")
    cta_area(root, sa, gen)

    pin(scroll, edges="lrb")
    below(scroll, nav, 0)
    pin(content, to=scroll.content, edges="lr")
    C(content, "top", scroll.content, "top", 8)
    C(scroll.content, "bottom", content, "bottom", 120)
    equal(content, scroll.frame, "width")

    square(thumb, 64)
    pin(summary.children[0])
    size(segmented, h=44)
    pin(seg_row, inset=3)
    C(seg_knob, "top", segmented, "top", 3)
    C(segmented, "bottom", seg_knob, "bottom", 3)
    C(seg_knob, "width", seg_keep, "width")
    C(seg_knob, "leading", segmented, "leading", 3, outlet="segmentKnobLeading")
    for c in (seg_keep, seg_free):
        center(c.children[0])
    square(shield, 18)
    w_pal = content.children[6]
    pin(pal_scroll, inset=(12, 0, 0, 0))
    size(pal_scroll, h=78)
    pin(pal_stack, to=pal_scroll.content)
    equal(pal_stack, pal_scroll.frame, "height")
    for ctrl, col, wrap, swatch, ring, inner, banded in pal_views:
        size(ctrl, w=60)
        pin(col, edges="ltr")
        square(wrap, 56)
        pin(swatch)
        pin(ring)
        if banded:
            pin(inner)
        else:
            center(inner)
            square(inner, 22)
    size(details, h=52)
    pin(details.children[0])
    square(pencil, 18)
    return d


@xib("HomeAI/Redesign/Wizard/PhotoTipsSheetViewController.xib")
def photo_tips_sheet():
    d = Doc("PhotoTipsSheetViewController", owner="PhotoTipsSheetViewController", size=(393, 640))
    root = d.root
    root.bg = "white"
    close = glass_button("close", "xmark", outlet="closeButton", action="didTapClose:", size=36, icon=16,
                         accessibility="Close")
    title = Label("Get the best result", id="title", font=("SemiBold", 24), align="center", outlet="titleLabel")

    def example(id, image, text, symbol, tint):
        img = Image(id=f"{id}-img", image=image, mode="scaleAspectFill", cls="DSImageView",
                    runtime={"cornerRadius": 16})
        ic = Image(id=f"{id}-icon", system=symbol, size=13, weight="semibold", tint=tint)
        lb = Label(text, id=f"{id}-label", font=("Medium", 13), collection="exampleLabels",
                   tag_value=0 if id == "good" else 1)
        row = HStack([ic, lb], id=f"{id}-row", spacing=6, align="center")
        col = VStack([img, row], id=f"{id}-col", spacing=6, align="leading")
        size(img, h=112)
        equal(img, col, "width")
        square(ic, 16)
        return col

    good = example("good", "tips_good", "Wide & bright", "checkmark.circle", "dsLink")
    bad = example("bad", "tips_bad", "Too close / dark", "xmark.circle", "#E5484D")
    examples = HStack([good, bad], id="examples", spacing=12, dist="fillEqually")
    tips = []
    for i, (symbol, text) in enumerate([("sun.max", "Turn on the lights or shoot by day"),
                                        ("viewfinder", "Step back, show the whole room"),
                                        ("hand.raised", "Hold the phone level, at chest height"),
                                        ("eye", "Clutter is fine, we'll handle it")]):
        ic = Image(id=f"tip{i}-icon", system=symbol, size=15, weight="medium", tint="black")
        box = View(id=f"tip{i}-box", cls="DSView", bg="dsSurface", runtime={"cornerRadius": 10}, children=[ic])
        lb = Label(text, id=f"tip{i}-label", font=("Regular", 15), lines=0, collection="tipLabels", tag_value=i)
        row = HStack([box, lb], id=f"tip{i}", spacing=12, align="center", collection="tipRows", tag_value=i)
        square(box, 32)
        center(ic)
        square(ic, 18)
        tips.append(row)
    tips_stack = VStack(tips, id="tips", spacing=12, margins=(4, 4, 4, 4))
    got = primary_button("got-it", "Got it", outlet="gotItButton", action="didTapClose:", title_outlet="gotItLabel")
    col = VStack([title, examples, tips_stack, got], id="col", spacing=14, align="fill")
    root.add(col, close)
    pin(col, edges="lr", inset=20)
    C(col, "top", root, "top", 30)
    pin(close, edges="tr", inset=(16, 0, 0, 16))
    return d


@xib("HomeAI/Redesign/Wizard/CustomStyleSheetViewController.xib")
def custom_style_sheet():
    d = Doc("CustomStyleSheetViewController", owner="CustomStyleSheetViewController", size=(393, 520))
    root = d.root
    root.bg = "white"
    close = glass_button("close", "xmark", outlet="closeButton", action="didTapClose:", size=36, icon=16,
                         accessibility="Close")
    title = Label("Describe your style", id="title", font=("SemiBold", 24), align="center", outlet="titleLabel")
    sub = Label("Materials, colors, mood — in your own words.", id="sub", font=("Regular", 15),
                color="dsTextSecondary", align="center", lines=0, outlet="subtitleLabel")
    text = TextView(id="text", font=("Regular", 16), outlet="textView")
    placeholder = Label("Warm minimal with travertine, linen curtains and soft evening light", id="placeholder",
                        font=("Regular", 16), color="dsTextTertiary", lines=0, outlet="placeholderLabel")
    counter = Label("0/200", id="counter", font=("Regular", 12), color="dsTextTertiary", outlet="counterLabel",
                    hidden=True)
    field = View(id="field", cls="DSView", bg="dsSurface", outlet="fieldView",
                 runtime={"cornerRadius": 20, "borderWidth": 2, "borderColor": "dsLime"},
                 children=[text, placeholder, counter])
    examples = [chip(f"ex{i}", t, icon="sparkles", collection="exampleChips", tag=i, action="didTapExample:")
                for i, t in enumerate(["Cozy cabin", "Parisian flat", "Hotel lobby", "Bright coastal"])]
    ex_rows = VStack([HStack(examples[:2], id="ex-row1", spacing=8),
                      HStack(examples[2:], id="ex-row2", spacing=8)], id="examples", spacing=8, align="leading")
    use = primary_button("use", "Use this style", outlet="useButton", action="didTapUse:", title_outlet="useLabel")
    col = VStack([title, sub, field, ex_rows, use], id="col", spacing=14, align="fill")
    root.add(col, close)
    pin(col, edges="lr", inset=20)
    C(col, "top", root, "top", 30)
    pin(close, edges="tr", inset=(16, 0, 0, 16))
    size(field, h=110)
    pin(text, inset=(8, 12, 8, 12))
    pin(placeholder, edges="lrt", inset=(16, 17, 0, 17))
    pin(counter, edges="rb", inset=(0, 0, 10, 14))
    return d


@xib("HomeAI/Redesign/Wizard/OutOfCreditsSheetViewController.xib")
def out_of_credits_sheet():
    d = Doc("OutOfCreditsSheetViewController", owner="OutOfCreditsSheetViewController", size=(393, 480))
    root = d.root
    root.bg = "white"
    title = Label("You've used your free designs", id="title", font=("SemiBold", 24), align="center", lines=0,
                  outlet="titleLabel")
    sub = Label("Go Pro to keep redesigning. Your photo and settings are saved.", id="sub", font=("Regular", 15),
                color="dsTextSecondary", align="center", lines=0, outlet="subtitleLabel")
    photo = Image(id="photo", mode="scaleAspectFill", cls="DSImageView", runtime={"cornerRadius": 20},
                  outlet="photoImageView")
    arrow_icon = Image(id="arrow-icon", system="arrow.right", size=15, weight="semibold", tint="black")
    arrow = View(id="arrow", cls="DSView", bg="dsSurface", runtime={"pill": True}, children=[arrow_icon])
    lock_icon = Image(id="lock-icon", system="lock", size=17, weight="medium", tint="black")
    lock = View(id="lock", cls="DSView", bg=("#FFFFFF", 0.85), runtime={"pill": True}, children=[lock_icon])
    locked = View(id="locked", cls="DSGradientView", clips=True, outlet="lockedView",
                  runtime={"cornerRadius": 20, "startColor": "#D8C6AE", "endColor": "#8D7B66", "angle": 129},
                  children=[lock])
    preview = HStack([photo, arrow, locked], id="preview", spacing=10, align="center")
    see = primary_button("see-pro", "See Pro plans", outlet="seeProButton", action="didTapSeePro:", icon="crown",
                         title_outlet="seeProLabel")
    not_now = Button("Not now", id="not-now", font=("SemiBold", 15), outlet="notNowButton").on("didTapNotNow:")
    preview_wrap = View(id="preview-wrap", bg="clear", children=[preview])
    col = VStack([title, sub, preview_wrap, see, not_now], id="col", spacing=14, align="fill")
    root.add(col)
    pin(col, edges="lr", inset=20)
    C(col, "top", root, "top", 30)
    size(preview_wrap, h=150)
    center(preview)
    pin(preview, edges="tb")
    size(photo, 120, 150)
    size(locked, 120, 150)
    square(arrow, 36)
    center(arrow_icon)
    square(lock, 44)
    center(lock)
    center(lock_icon)
    size(not_now, h=44)
    return d


@xib("HomeAI/Redesign/Wizard/CameraViewController.xib")
def camera():
    d = Doc("CameraViewController", owner="CameraViewController")
    root = d.root
    root.bg = "black"
    sa = d.safe_area
    preview = View(id="preview", cls="CameraPreviewView", bg="black", clips=True, outlet="previewView", alpha=0)
    grid = View(id="grid", bg="clear", interaction=False, outlet="gridView", alpha=0)
    lines = [View(id=f"grid-{k}", bg=("#FFFFFF", 0.35)) for k in ("v1", "v2", "h1", "h2")]
    grid.add(*lines)
    level = View(id="level", bg="white", outlet="levelView", runtime={"layer.cornerRadius": 1})
    hint_icon = Image(id="hint-icon", system="viewfinder", size=15, weight="medium", tint="dsLime")
    hint_label = Label("Step back to fit the whole room", id="hint-label", font=("Medium", 14), color="white",
                       outlet="hintLabel")
    hint = View(id="hint", cls="DSView", bg=("#000000", 0.45), outlet="hintView", runtime={"pill": True}, alpha=0,
                children=[HStack([hint_icon, hint_label], id="hint-row", spacing=8, align="center",
                                 margins=(0, 16, 0, 16))])
    close = glass_button("close", "xmark", outlet="closeButton", action="didTapClose:", dark=True,
                         accessibility="Close")
    flash = glass_button("flash", "bolt.slash", outlet="flashButton", action="didTapFlash:", dark=True,
                         accessibility="Flash")
    zoom_label = Label("0.5×", id="zoom-label", font=("SemiBold", 13), color="dsLime", align="center",
                       outlet="zoomLabel")
    zoom = Control(id="zoom", cls="DSPressableControl", bg=("#000000", 0.45), outlet="zoomButton",
                   runtime={"pill": True}, children=[zoom_label]).on("didTapZoom:")
    last = Control(id="last", cls="DSPressableControl", clips=True, bg=("#FFFFFF", 0.15), outlet="libraryButton",
                   runtime={"cornerRadius": 12, "borderWidth": 1, "borderColor": ("#FFFFFF", 0.3)},
                   accessibility="Photo library",
                   children=[Image(id="last-img", system="photo.on.rectangle", size=18, tint="white",
                                   outlet="lastPhotoView", mode="center")]).on("didTapLibrary:")
    inner = View(id="shutter-inner", cls="DSView", bg="white", runtime={"pill": True}, interaction=False)
    shutter = Control(id="shutter", cls="DSPressableControl", bg="clear", outlet="shutterButton",
                      runtime={"pill": True, "borderWidth": 4, "borderColor": "white", "hapticOnPress": False},
                      accessibility="Take photo", children=[inner]).on("didTapShutter:")
    flip = glass_button("flip", "arrow.triangle.2.circlepath", outlet="flipButton", action="didTapFlip:",
                        dark=True, size=48, accessibility="Switch camera")
    controls = HStack([last, shutter, flip], id="controls", align="center", dist="equalSpacing",
                      margins=(0, 40, 0, 40))
    flash_overlay = View(id="flash-overlay", bg="white", alpha=0, interaction=False, outlet="flashOverlay")
    root.add(preview, grid, level, hint, close, flash, zoom, controls, flash_overlay)

    pin(preview, edges="lr")
    C(preview, "top", sa, "top", 51)
    C(controls, "top", preview, "bottom", 0)
    pin(grid, to=preview)
    v1, v2, h1, h2 = lines
    for v, m in ((v1, 1 / 3), (v2, 2 / 3)):
        pin(v, edges="tb")
        size(v, w=1)
        C(v, "centerX", grid, "trailing", mult=f"{m:.4f}")
    for h, m in ((h1, 1 / 3), (h2, 2 / 3)):
        pin(h, edges="lr")
        size(h, h=1)
        C(h, "centerY", grid, "bottom", mult=f"{m:.4f}")
    size(level, 120, 2)
    center(level, to=preview)
    pin(hint, edges="t", to=preview, inset=20)
    center(hint, to=preview, y=False)
    size(hint, h=40)
    pin(hint.children[0])
    square(hint_icon, 18)
    pin(close, edges="l", inset=16)
    C(close, "top", sa, "top", -1)
    pin(flash, edges="r", inset=16)
    C(flash, "top", sa, "top", -1)
    center(zoom, to=preview, y=False)
    C(preview, "bottom", zoom, "bottom", 16)
    size(zoom, 52, 32)
    center(zoom_label)
    pin(controls, edges="lr")
    C(sa, "bottom", controls, "bottom", 0)
    size(controls, h=108)
    square(last, 48)
    center(last.children[0])
    square(last.children[0], 48)
    square(shutter, 78)
    square(inner, 64)
    center(inner)
    pin(flash_overlay)
    return d

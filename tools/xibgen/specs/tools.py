from xibgen import *
from dslib import *


def tool_screen(name, title, subtitle, photo_status=False, cta_title="Generate", cta_sub="1 credit · about 30 s"):
    """W1 → T<n> (step 2/2): nav, title, photo summary, then sections added by the caller to `body`."""
    d = Doc(name, owner=name)
    root = d.root
    root.bg = "dsBackground"
    sa = d.safe_area
    titles = title_group(title, subtitle)
    thumb = Image(id="ps-thumb", mode="scaleAspectFill", cls="DSImageView", runtime={"cornerRadius": 14},
                  outlet="photoThumbView")
    ps_title = Label("Your photo", id="ps-title", font=("SemiBold", 15), outlet="photoTitleLabel")
    ps_status = Label("", id="ps-status", font=("Regular", 13), color="dsLink", outlet="photoStatusLabel",
                      hidden=not photo_status)
    change = Button("Change", id="ps-change", font=("Medium", 14), color="dsLink", outlet="changePhotoButton",
                    hug=(750, 750)).on("didTapChangePhoto:")
    summary = View(id="summary", cls="DSView", bg="dsSurface", runtime={"cornerRadius": 20}, outlet="photoSummaryView",
                   children=[HStack([thumb, VStack([ps_title, ps_status], id="ps-texts", spacing=2, hug=(249, 251)),
                                     change], id="ps-row", spacing=12, align="center", margins=(8, 8, 8, 14))])
    body = VStack([titles, summary], id="body", spacing=14, outlet="contentStack")
    scroll = Scroll([body], id="scroll", outlet="scrollView")
    root.add(scroll)
    nav = View(id="nav", cls="WizardNavBar", bg="clear", outlet="navBar")
    root.add(nav)
    pin(nav, edges="lr")
    C(nav, "top", sa, "top", -4)
    size(nav, h=56)
    gen = primary_button("generate", cta_title, outlet="generateButton", action="didTapGenerate:", icon="sparkles",
                         subtitle=cta_sub, title_outlet="generateTitleLabel", subtitle_outlet="generateSubtitleLabel",
                         icon_outlet="generateIconView")
    fade = bottom_fade()
    root.add(fade, gen)
    pin(fade, edges="lrb")
    size(fade, h=140)
    pin(gen, edges="lr", inset=20)
    C(sa, "bottom", gen, "bottom", 0)
    pin(scroll, edges="lrb")
    below(scroll, nav, 0)
    pin(body, to=scroll.content, edges="lr", inset=(0, 20, 0, 20))
    C(body, "top", scroll.content, "top", 8)
    C(scroll.content, "bottom", body, "bottom", 120)
    C(body, "width", scroll.frame, "width", -40)
    pin(summary.children[0])
    square(thumb, 56)
    return d, body


def section(text, id, outlet=None):
    return Label(text, id=id, font=("SemiBold", 17), outlet=outlet)


def toggle_row(id, title, sub, outlet, on=True):
    t = Label(title, id=f"{id}-t", font=("Medium", 15), outlet=f"{outlet}TitleLabel")
    s = Label(sub, id=f"{id}-s", font=("Regular", 12), color="dsTextTertiary", outlet=f"{outlet}SubtitleLabel")
    sw = Switch(id=f"{id}-sw", on=on, onTint="#34C759", outlet=f"{outlet}Switch")
    spacer = View(id=f"{id}-sp", bg="clear", hug=(1, 250))
    return HStack([VStack([t, s], id=f"{id}-texts", spacing=2), spacer, sw], id=id, align="center", spacing=8)


def chip_scroll(id, titles, collection, action, first_selected=True, outlet=None, full_bleed=True):
    chips = [chip(f"{id}{i}", t, selected=(first_selected and i == 0), collection=collection, tag=i, action=action)
             for i, t in enumerate(titles)]
    stack = HStack(chips, id=f"{id}-stack", spacing=8)
    scroll = Scroll([stack], id=f"{id}-scroll", horizontal=True, clips=False, outlet=outlet)
    size(scroll, h=36)
    pin(stack, to=scroll.content)
    equal(stack, scroll.frame, "height")
    return scroll


def segmented(id, titles, outlet_prefix, action, height=40):
    knob = View(id=f"{id}-knob", cls="DSView", bg="dsKnob", outlet=f"{outlet_prefix}Knob",
                runtime={"cornerRadius": (height - 6) / 2, "shadowOpacity": 0.12, "shadowRadius": 3, "shadowOffsetY": 2})
    segs = []
    for i, t in enumerate(titles):
        c = Control(id=f"{id}{i}", cls="DSPressableControl", tag_value=i, collection=f"{outlet_prefix}Controls",
                    runtime={"hapticOnPress": False, "pressedScale": 0.98},
                    children=[Label(t, id=f"{id}{i}-l", font=("Medium", 14), color="dsTextSecondary", align="center",
                                    minScale=0.7, collection=f"{outlet_prefix}Labels", tag_value=i)]).on(action)
        center(c.children[0])
        segs.append(c)
    row = HStack(segs, id=f"{id}-row", dist="fillEqually")
    seg = View(id=id, cls="DSView", bg="dsSegment", runtime={"cornerRadius": height / 2}, outlet=f"{outlet_prefix}View",
               children=[knob, row])
    size(seg, h=height)
    pin(row, inset=3)
    C(knob, "top", seg, "top", 3)
    C(seg, "bottom", knob, "bottom", 3)
    C(knob, "width", segs[0], "width")
    C(knob, "leading", seg, "leading", 3, outlet=f"{outlet_prefix}KnobLeading")
    return seg


def grid_collection(id, outlet, item=(109, 120), horizontal=False, height_outlet=None, height=260):
    cv = Collection(id=id, horizontal=horizontal, spacing=12, item=item, outlet=outlet, clips=False)
    C(cv, "height", const=height, outlet=height_outlet)
    return cv


# ---------------------------------------------------------------- T1 Exterior

FACADES = [("Modern farmhouse", ["#F5F3EE", "#2B2B2B", "#A47551", "#6F7D5C"]),
           ("Scandinavian", ["#E9E4DA", "#3C3C3C", "#C9A27E", "#8E9AA6"]),
           ("Mediterranean", ["#F1E3C8", "#C26A3D", "#5C7A5C", "#2F4F6F"]),
           ("Contemporary", ["#D8D8D8", "#1E1E1E", "#B88A5A", "#7A7A7A"]),
           ("Craftsman", ["#7B5E3B", "#E8DCC3", "#4E5B47", "#2E2A26"]),
           ("Coastal", ["#F7F7F2", "#7FA6B8", "#D9C7A7", "#3E5C76"])]


@xib("HomeAI/Redesign/Tools/ExteriorToolViewController.xib")
def exterior_tool():
    d, body = tool_screen("ExteriorToolViewController", "Exterior style",
                          "The shape of your house stays. We change materials, colors and planting.")
    cards = []
    for i, (name, colors) in enumerate(FACADES):
        dots = []
        for j, c in enumerate(colors):
            dot = View(id=f"fac{i}-d{j}", cls="DSView", bg=c, runtime={"pill": True, "borderWidth": 1.5,
                                                                         "borderColor": "white"})
            square(dot, 16)
            dots.append(dot)
        lab = Label(name, id=f"fac{i}-l", font=("Medium", 14), minScale=0.8, collection="facadeLabels", tag_value=i)
        col = VStack([lab, HStack(dots, id=f"fac{i}-dots", spacing=-4)], id=f"fac{i}-col", spacing=8, align="leading")
        card = Control(id=f"fac{i}", cls="DSPressableControl", bg="dsSurface", tag_value=i, collection="facadeCards",
                       runtime={"cornerRadius": 18}, children=[col]).on("didTapFacade:")
        size(card, h=64)
        pin(col, edges="lt", inset=(12, 14, 0, 0))
        C(card, "trailing", col, "trailing", 8, rel="greaterThanOrEqual")
        cards.append(card)
    grid = VStack([HStack(cards[i:i + 2], id=f"fac-row{i}", spacing=12, dist="fillEqually") for i in (0, 2, 4)],
                  id="facades", spacing=10)
    lights = []
    for i, (key, t) in enumerate([("day", "Day"), ("golden", "Golden hour"), ("dusk", "Dusk")]):
        img = Image(id=f"light-{key}-img", image=f"tools_light_{key}", mode="scaleAspectFill", cls="DSImageView",
                    runtime={"cornerRadius": 16})
        ring = View(id=f"light-{key}-ring", cls="DSView", bg="clear", interaction=False, collection="lightRings",
                    tag_value=i, alpha=0, runtime={"cornerRadius": 16, "borderWidth": 3, "borderColor": "dsLime"})
        check_icon = Image(id=f"light-{key}-chk-i", system="checkmark", size=10, weight="bold", tint="black")
        check = View(id=f"light-{key}-chk", cls="DSView", bg="dsLime", runtime={"pill": True}, collection="lightChecks",
                     tag_value=i, alpha=0, children=[check_icon])
        lab = Label(t, id=f"light-{key}-l", font=("Regular", 13), align="center", collection="lightLabels", tag_value=i)
        ctrl = Control(id=f"light-{key}", cls="DSPressableControl", tag_value=i, collection="lightControls",
                       children=[img, ring, check, lab]).on("didTapLight:")
        pin(img, edges="ltr")
        size(img, h=72)
        pin(ring, to=img)
        pin(check, to=img, edges="tr", inset=(3, 0, 0, 3))
        square(check, 22)
        center(check_icon)
        below(lab, img, 6)
        pin(lab, edges="lrb")
        lights.append(ctrl)
    light_row = HStack(lights, id="lights", spacing=13, dist="fillEqually")
    body.add(section("Facade style", "s-facade", "facadeTitleLabel"), grid, section("Light", "s-light", "lightTitleLabel"),
             light_row, toggle_row("keep", "Keep structure", "Roof, windows and doors stay in place", "keep"))
    return d


# ---------------------------------------------------------------- T2 Garden

@xib("HomeAI/Redesign/Tools/GardenToolViewController.xib")
def garden_tool():
    d, body = tool_screen("GardenToolViewController", "Garden style", "Plants, paths and lighting for your yard.")
    styles = grid_collection("styles", "stylesCollectionView", item=(160, 128), horizontal=True, height=290)
    seasons = chip_scroll("season", ["Spring", "Summer", "Autumn", "Winter"], "seasonChips", "didTapSeason:",
                          first_selected=False)
    body.add(section("Garden style", "s-style", "styleTitleLabel"), styles,
             section("Season", "s-season", "seasonTitleLabel"), seasons,
             toggle_row("keep", "Keep paths & patio", "Hardscape stays, we redo planting", "keep"))
    return d


# ---------------------------------------------------------------- T3 Reference

@xib("HomeAI/Redesign/Tools/ReferenceToolViewController.xib")
def reference_tool():
    d, body = tool_screen("ReferenceToolViewController", "Match a reference",
                          "We'll copy the look of any photo onto your room.")
    body.children[1].hidden = True  # no photo summary here: "My room" slot shows it
    body.children[1].outlet = "photoSummaryView"

    def slot(id, title, outlet_img, outlet_empty, action, removable):
        img = Image(id=f"{id}-img", mode="scaleAspectFill", outlet=outlet_img)
        plus_icon = Image(id=f"{id}-plus", system="plus", size=20, weight="semibold", tint="dsTextTertiary")
        empty_label = Label("Add photo", id=f"{id}-empty-l", font=("Medium", 13), color="dsTextTertiary",
                            align="center")
        empty = View(id=f"{id}-empty", cls="DashedBorderView", bg="dsSurface", outlet=outlet_empty,
                     runtime={"cornerRadius": 22}, children=[VStack([plus_icon, empty_label], id=f"{id}-empty-col",
                                                                   spacing=6, align="center")])
        parts = [img, empty]
        clear = None
        if removable:
            clear = glass_button(f"{id}-clear", "xmark", outlet="clearReferenceButton", action="didTapClearReference:",
                                 size=28, icon=12, accessibility="Remove reference")
            parts.append(clear)
        box = Control(id=f"{id}-box", cls="DSPressableControl", clips=True, bg="dsSurface", runtime={"cornerRadius": 22},
                      children=parts).on(action)
        lab = Label(title, id=f"{id}-l", font=("SemiBold", 14), align="center", collection="slotLabels",
                    tag_value=0 if removable else 1)
        col = VStack([box, lab], id=id, spacing=8, align="fill")
        size(box, h=170)
        pin(img)
        pin(empty)
        center(empty.children[0])
        if clear:
            pin(clear, edges="tr", inset=(8, 0, 0, 8))
        return col

    style_slot = slot("ref", "Style from", "referenceImageView", "referenceEmptyView", "didTapReferenceSlot:", True)
    room_slot = slot("room", "My room", "roomImageView", "roomEmptyView", "didTapChangePhoto:", False)
    arrow_icon = Image(id="arrow-icon", system="arrow.right", size=14, weight="bold", tint="black")
    arrow = View(id="arrow", cls="DSView", bg="dsLime", runtime={"pill": True}, children=[arrow_icon])
    square(arrow, 32)
    center(arrow_icon)
    slots = HStack([style_slot, arrow, room_slot], id="slots", spacing=10, align="center")
    equal(style_slot, room_slot, "width")
    insp = grid_collection("insp", "inspirationCollectionView", item=(76, 100), horizontal=True, height=100)
    copy_titles = ["Colors", "Materials", "Furniture", "Lighting", "Layout"]
    copy_chips = [chip(f"copy{i}", t, selected=i in (0, 1, 3), icon="checkmark", collection="copyChips", tag=i,
                       action="didTapCopyOption:") for i, t in enumerate(copy_titles)]
    copy_rows = VStack([HStack(copy_chips[:3], id="copy-r1", spacing=8), HStack(copy_chips[3:], id="copy-r2", spacing=8)],
                       id="copy", spacing=8, align="leading")
    body.add(slots, section("Or pick from Inspiration", "s-insp", "inspirationTitleLabel"), insp,
             section("What to copy", "s-copy", "copyTitleLabel"), copy_rows)
    return d


# ---------------------------------------------------------------- T4 New walls / T5 New flooring

def material_screen(name, title, subtitle, filters, extra_builder=None):
    d, body = tool_screen(name, title, subtitle)
    chips = chip_scroll("filter", filters, "filterChips", "didTapFilter:")
    grid = grid_collection("materials", "materialsCollectionView", item=(109, 130), height=280,
                           height_outlet="materialsHeightConstraint")
    grid.attrs["scrollEnabled"] = "NO"
    body.add(chips, grid)
    if extra_builder:
        extra_builder(body)
    return d


@xib("HomeAI/Redesign/Tools/WallsToolViewController.xib")
def walls_tool():
    return material_screen("WallsToolViewController", "New walls", "Pick a material. We find the walls automatically.",
                           ["All", "Paint", "Wood", "Stone", "Tile", "Wallpaper"])


@xib("HomeAI/Redesign/Tools/FloorToolViewController.xib")
def floor_tool():
    def extra(body):
        body.add(section("Pattern", "s-pattern", "patternTitleLabel"),
                 segmented("pattern", ["Straight", "Herringbone", "Chevron"], "pattern", "didTapPattern:"),
                 toggle_row("rugs", "Keep rugs", "Rugs stay on top of the new floor", "rugs"))
    return material_screen("FloorToolViewController", "New flooring", "Furniture and rugs stay. Only the floor changes.",
                           ["All", "Wood", "Tile", "Stone", "Carpet"], extra)


@xib("HomeAI/Redesign/Tools/MaterialTileCell.xib")
def material_cell():
    d = Doc("MaterialTileCell", kind="collectionCell", cls="MaterialTileCell", size=(109, 130), reuse="MaterialTileCell")
    img = Image(id="img", mode="scaleAspectFill", cls="DSImageView", bg="dsSurface", runtime={"cornerRadius": 18},
                outlet="thumbImageView")
    ring = View(id="ring", cls="DSView", bg="clear", interaction=False, outlet="ringView", alpha=0,
                runtime={"cornerRadius": 18, "borderWidth": 3, "borderColor": "dsLime"})
    check_icon = Image(id="check-i", system="checkmark", size=10, weight="bold", tint="black")
    check = View(id="check", cls="DSView", bg="dsLime", runtime={"pill": True}, outlet="checkView", alpha=0,
                 children=[check_icon])
    title = Label("Oak", id="title", font=("Regular", 13), align="center", minScale=0.7, outlet="titleLabel")
    d.cell(img, ring, check, title)
    pin(img, edges="ltr")
    C(img, "bottom", title, "top", -6)
    pin(ring, to=img)
    pin(check, to=img, edges="tr", inset=(4, 0, 0, 4))
    square(check, 22)
    center(check_icon)
    pin(title, edges="lrb")
    size(title, h=18)
    return d


# ---------------------------------------------------------------- T6 Furnish

@xib("HomeAI/Redesign/Tools/FurnishToolViewController.xib")
def furnish_tool():
    d, body = tool_screen("FurnishToolViewController", "Furnish empty room",
                          "We add furniture that fits the space and the light.", photo_status=True)
    rooms = chip_scroll("room", ["Living room", "Bedroom", "Dining", "Office", "Kids room", "Study"], "roomChips",
                        "didTapRoom:")
    styles = grid_collection("styles", "stylesCollectionView", item=(72, 94), horizontal=True, height=94)
    density = segmented("density", ["Minimal", "Balanced", "Full"], "density", "didTapDensity:")
    explainer = Label("Balanced: sofa, coffee table, rug, 2–3 decor pieces", id="density-l", font=("Regular", 13),
                      color="dsTextTertiary", lines=0, outlet="densityExplainerLabel")
    body.add(section("Room type", "s-room", "roomTitleLabel"), rooms, section("Style", "s-style", "styleTitleLabel"),
             styles, section("How much furniture", "s-density", "densityTitleLabel"), density, explainer)
    return d


@xib("HomeAI/Redesign/Tools/StyleCircleCell.xib")
def style_circle_cell():
    d = Doc("StyleCircleCell", kind="collectionCell", cls="StyleCircleCell", size=(72, 94), reuse="StyleCircleCell")
    img = Image(id="img", mode="scaleAspectFill", cls="DSImageView", bg="dsSurface", runtime={"cornerRadius": 36},
                outlet="thumbImageView")
    ring = View(id="ring", cls="DSView", bg="clear", interaction=False, outlet="ringView", alpha=0,
                runtime={"cornerRadius": 36, "borderWidth": 3, "borderColor": "dsLime"})
    check_icon = Image(id="check-i", system="checkmark", size=9, weight="bold", tint="black")
    check = View(id="check", cls="DSView", bg="dsLime", runtime={"pill": True}, outlet="checkView", alpha=0,
                 children=[check_icon])
    title = Label("Japandi", id="title", font=("Regular", 12), align="center", minScale=0.7, outlet="titleLabel")
    d.cell(img, ring, check, title)
    pin(img, edges="t")
    center(img, y=False)
    square(img, 72)
    pin(ring, to=img)
    pin(check, to=img, edges="tr")
    square(check, 22)
    center(check_icon)
    below(title, img, 6)
    pin(title, edges="lr")
    return d


# ---------------------------------------------------------------- T7 Floor plan

@xib("HomeAI/Redesign/Tools/FloorPlanToolViewController.xib")
def floor_plan_tool():
    d, body = tool_screen("FloorPlanToolViewController", "Floor plan to 3D",
                          "Upload a plan or a photo of one. We build the rooms in 3D.",
                          cta_title="Build 3D", cta_sub="1 credit · about 60 s")
    body.children[1].hidden = True
    plan_img = Image(id="plan-img", mode="scaleAspectFill", cls="DSImageView", runtime={"cornerRadius": 16},
                     outlet="planImageView")
    badge_icon = Image(id="plan-badge-i", system="checkmark.circle.fill", size=12, weight="semibold", tint="dsLink")
    badge_label = Label("Plan added", id="plan-badge-l", font=("Medium", 12), color="dsLink", outlet="planBadgeLabel")
    badge = View(id="plan-badge", cls="DSView", bg="dsLimeSoft", runtime={"pill": True},
                 children=[HStack([badge_icon, badge_label], id="plan-badge-row", spacing=5, align="center",
                                  margins=(0, 8, 0, 10))])
    tip = Label("Clear 2D plans with labelled rooms work best. Hand sketches are fine too.", id="plan-tip",
                font=("Regular", 13), color="dsTextSecondary", lines=0, outlet="planTipLabel")
    replace = secondary_button("plan-replace", "Replace", outlet="replacePlanButton", action="didTapChangePhoto:",
                               height=36, bg="dsCard", icon="arrow.clockwise", font=("Medium", 14))
    replace.runtime["borderWidth"] = 1
    replace.runtime["borderColor"] = "#E5E5EA"
    right = VStack([badge, tip, replace], id="plan-right", spacing=10, align="leading")
    plan_card = View(id="plan-card", cls="DSView", bg="dsCard", runtime={"cornerRadius": 22, "borderWidth": 1,
                                                                        "borderColor": "#EDEDED"},
                     children=[HStack([plan_img, right], id="plan-row", spacing=14, align="center",
                                      margins=(10, 10, 10, 14))])

    def view_card(i, symbol, title, sub):
        ic = Image(id=f"view{i}-i", system=symbol, size=20, weight="medium", tint="dsTextPrimary")
        t = Label(title, id=f"view{i}-t", font=("SemiBold", 15), collection="viewTitleLabels", tag_value=i)
        s = Label(sub, id=f"view{i}-s", font=("Regular", 12), color="dsTextTertiary", collection="viewSubtitleLabels",
                  tag_value=i)
        col = VStack([ic, View(id=f"view{i}-sp", bg="clear"), t, s], id=f"view{i}-col", spacing=2, align="leading")
        card = Control(id=f"view{i}", cls="DSPressableControl", bg="dsSurface", tag_value=i, collection="viewCards",
                       runtime={"cornerRadius": 20}, children=[col]).on("didTapView:")
        size(card, h=96)
        pin(col, inset=14)
        square(ic, 24)
        return card

    views = HStack([view_card(0, "cube", "Isometric", "3D cut-away"),
                    view_card(1, "square.grid.2x2", "Top view", "Furnished plan")], id="views", spacing=12,
                   dist="fillEqually")
    styles = chip_scroll("pstyle", ["Japandi", "Modern", "Scandi", "Classic", "Loft"], "planStyleChips",
                         "didTapPlanStyle:")
    body.add(plan_card, section("View", "s-view", "viewTitleLabel"), views, section("Style", "s-pstyle", "planStyleTitleLabel"),
             styles)
    pin(plan_card.children[0])
    size(plan_img, 130, 150)
    size(badge, h=26)
    pin(badge.children[0])
    square(badge_icon, 14)
    return d


# ---------------------------------------------------------------- T8 Rearrange

@xib("HomeAI/Redesign/Tools/RearrangeToolViewController.xib")
def rearrange_tool():
    d, body = tool_screen("RearrangeToolViewController", "Rearrange furniture",
                          "Same furniture, new layout. Nothing new is added.", photo_status=True)
    rows = []
    options = [("square.dashed", "Open space", "Big pieces to the walls, more floor"),
               ("sofa", "Cozy", "Seating around the coffee table"),
               ("desktopcomputer", "Work zone", "Desk by the window, reading corner"),
               ("person.2", "Conversation", "Sofas facing each other")]
    for i, (symbol, t, s) in enumerate(options):
        ic = Image(id=f"opt{i}-i", system=symbol, size=20, weight="medium", tint="dsTextPrimary")
        box = View(id=f"opt{i}-box", cls="DSView", bg="dsCard", runtime={"cornerRadius": 12}, children=[ic])
        tl = Label(t, id=f"opt{i}-t", font=("SemiBold", 15), collection="optionTitleLabels", tag_value=i)
        sl = Label(s, id=f"opt{i}-s", font=("Regular", 12), color="dsTextTertiary", collection="optionSubtitleLabels",
                   tag_value=i, minScale=0.8)
        radio_dot = View(id=f"opt{i}-dot", cls="DSView", bg="dsTextPrimary", runtime={"pill": True}, alpha=0,
                         collection="optionRadioDots", tag_value=i)
        radio = View(id=f"opt{i}-radio", cls="DSView", bg="dsCard", runtime={"pill": True, "borderWidth": 1.5,
                                                                            "borderColor": "#C7C7CC"},
                     collection="optionRadios", tag_value=i, children=[radio_dot])
        card = Control(id=f"opt{i}", cls="DSPressableControl", bg="dsSurface", tag_value=i, collection="optionCards",
                       runtime={"cornerRadius": 20},
                       children=[HStack([box, VStack([tl, sl], id=f"opt{i}-texts", spacing=2, hug=(249, 251)), radio],
                                        id=f"opt{i}-row", spacing=14, align="center", margins=(0, 14, 0, 16))]).on(
            "didTapOption:")
        size(card, h=72)
        pin(card.children[0])
        square(box, 48)
        center(ic)
        square(ic, 26)
        square(radio, 22)
        center(radio_dot)
        square(radio_dot, 10)
        rows.append(card)
    body.add(*rows)
    return d

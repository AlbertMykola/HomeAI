from xibgen import *
from dslib import *

DELETE_RED = "#FB2626"
SLOT_BORDER = "#C7C7CC"


def segmented(id, titles, outlet_prefix, action, height=38):
    knob = View(id=f"{id}-knob", cls="DSView", bg="white", outlet=f"{outlet_prefix}Knob",
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


def pill(id, text, bg, color, outlet=None, label_outlet=None, height=24):
    lb = Label(text, id=f"{id}-label", font=("SemiBold", 11), color=color, outlet=label_outlet)
    v = View(id=id, cls="DSView", bg=bg, runtime={"cornerRadius": height / 2}, outlet=outlet,
             children=[HStack([lb], id=f"{id}-row", align="center", margins=(0, 9, 0, 9))])
    size(v, h=height)
    pin(v.children[0])
    return v


@xib("HomeAI/Redesign/Projects/ProjectsViewController.xib")
def projects():
    d = Doc("ProjectsViewController", owner="ProjectsViewController")
    root = d.root
    root.bg = "white"
    sa = d.safe_area

    cv = Collection(id="cv", spacing=13, item=(170, 246), insets=(0, 20, 0, 20), outlet="collectionView",
                    indicators=True)

    # PR3 empty state (Designs / Ideas)
    icon = Image(id="empty-icon", image="clay_interior", mode="scaleAspectFit", outlet="emptyIconView")
    e_title = Label("Your redesigns will live here", id="empty-title", font=("SemiBold", 24), align="center",
                    lines=0, outlet="emptyTitleLabel")
    e_sub = Label("Every design and edit is saved as a version, so you can always go back.", id="empty-sub",
                  font=("Regular", 15), color="dsTextSecondary", align="center", lines=0, lineHeight=1.17,
                  outlet="emptySubtitleLabel")
    e_space = View(id="empty-space", bg="clear")
    size(e_space, 10, 8)
    e_cta = primary_button("empty-cta", "Redesign a room", outlet="emptyPrimaryButton", action="didTapEmptyPrimary:",
                           icon="sparkles", title_outlet="emptyPrimaryLabel")
    size(e_cta, w=260)
    e_ghost = Button("Browse inspiration", id="empty-ghost", font=("SemiBold", 15), color="dsTextPrimary",
                     outlet="emptyGhostButton").on("didTapBrowse:")
    size(e_ghost, 260, 44)
    empty = VStack([icon, e_title, e_sub, e_space, e_cta, e_ghost], id="empty", spacing=12, align="center",
                   outlet="emptyStateView", hidden=True)

    fade = View(id="fade", cls="DSGradientView", interaction=False,
                runtime={"startColor": ("#FFFFFF", 0.0), "midColor": ("#FFFFFF", 0.92), "midLocation": 0.45,
                         "endColor": "white", "angle": 180})

    # header
    header_bg = Blur(id="header-bg", style="systemUltraThinMaterialLight", outlet="headerBackgroundView", alpha=0)
    title = Label("Projects", id="title", font=("SemiBold", 32), outlet="largeTitleLabel", minScale=0.6)
    select_label = Label("Select", id="select-label", font=("Medium", 15), outlet="selectLabel")
    select = Control(id="select", cls="DSPressableControl", bg="dsChip", runtime={"pill": True},
                     outlet="selectButton",
                     children=[HStack([select_label], id="select-row", align="center", margins=(0, 16, 0, 16))]
                     ).on("didTapSelect:")
    seg = segmented("seg", ["Designs", "Ideas"], "segment", "didTapSegment:")
    header = View(id="header", bg="clear", outlet="headerView", children=[title, select, seg])

    # select-mode action bar (replaces the tab bar)
    actions = []
    for i, (symbol, text, color) in enumerate([("square.and.arrow.up", "Share", "dsTextPrimary"),
                                               ("square.3.layers.3d", "Duplicate", "dsTextPrimary"),
                                               ("trash", "Delete", DELETE_RED)]):
        ic = Image(id=f"act{i}-icon", system=symbol, size=19, weight="medium", tint=color)
        lb = Label(text, id=f"act{i}-label", font=("Medium", 11), color=color, align="center",
                   collection="actionLabels", tag_value=i)
        col = VStack([ic, lb], id=f"act{i}-col", spacing=3, align="center")
        ctl = Control(id=f"act{i}", cls="DSPressableControl", collection="actionControls", tag_value=i,
                      children=[col]).on("didTapAction:")
        center(col)
        square(ic, 22)
        actions.append(ctl)
    action_bar = View(id="action-bar", cls="DSView", bg=("#FFFFFF", 0.8), outlet="actionBarView", hidden=True,
                      runtime={"pill": True, "borderWidth": 0.5, "borderColor": "white", "shadowOpacity": 0.1,
                               "shadowRadius": 15, "shadowOffsetY": 8},
                      children=[HStack(actions, id="actions", dist="fillEqually", align="fill")])

    root.add(cv, empty, fade, header_bg, header, action_bar)

    pin(cv)
    pin(header, edges="lr")
    C(header, "top", sa, "top")
    pin(header_bg, edges="ltr")
    C(header_bg, "bottom", header, "bottom")
    pin(title, edges="l", inset=20)
    C(title, "top", header, "top", 8)
    pin(select, edges="r", inset=20)
    center(select, to=title, x=False)
    size(select, h=36)
    pin(select.children[0])
    C(select, "leading", title, "trailing", 12, rel="greaterThanOrEqual")
    pin(seg, edges="lr", inset=20)
    C(seg, "top", header, "top", 64)
    C(header, "bottom", seg, "bottom", 14)

    pin(empty, edges="lr", inset=20)
    C(empty, "top", seg, "bottom", 74)
    square(icon, 132)
    C(e_title, "width", const=320, rel="lessThanOrEqual")
    C(e_sub, "width", const=300, rel="lessThanOrEqual")

    pin(fade, edges="lrb")
    size(fade, h=150)

    pin(action_bar, edges="lr", inset=16)
    C(sa, "bottom", action_bar, "bottom", 0, outlet="actionBarBottomConstraint")
    size(action_bar, h=64)
    pin(action_bar.children[0], inset=(0, 5, 0, 5))
    return d


@xib("HomeAI/Redesign/Projects/ProjectCell.xib")
def project_cell():
    d = Doc("ProjectCell", kind="collectionCell", cls="ProjectCell", size=(170, 246), reuse="ProjectCell")
    img = Image(id="img", mode="scaleAspectFill", cls="DSImageView", bg="dsSurface", outlet="coverImageView",
                runtime={"cornerRadius": 22})
    ring = View(id="ring", cls="DSView", bg="clear", outlet="selectionRingView", hidden=True, interaction=False,
                runtime={"cornerRadius": 22, "borderWidth": 3, "borderColor": "dsLime"})
    version = pill("version", "V3", ("#000000", 0.35), "white", label_outlet="versionLabel")
    check_icon = Image(id="check-icon", system="checkmark", size=12, weight="bold", tint="black",
                       outlet="checkIconView")
    check = View(id="check", cls="DSView", bg=("#FFFFFF", 0.35), outlet="checkView", hidden=True,
                 runtime={"cornerRadius": 13, "borderWidth": 2, "borderColor": "white", "shadowOpacity": 0.2,
                          "shadowRadius": 6, "shadowOffsetY": 2},
                 children=[check_icon])
    title = Label("Japandi living room", id="title", font=("SemiBold", 15), outlet="titleLabel")
    sub = Label("3 versions · Today", id="sub", font=("Regular", 12), color="dsTextTertiary", outlet="subtitleLabel")
    texts = VStack([title, sub], id="texts", spacing=2, align="fill")
    d.cell(img, ring, version, check, texts)
    pin(img, edges="ltr")
    C(img, "height", img, "width", mult="200:170")
    pin(ring, to=img)
    pin(version, to=img, edges="lb", inset=8)
    pin(check, to=img, edges="tr", inset=8)
    square(check, 26)
    center(check_icon)
    square(check_icon, 15)
    below(texts, img, 8)
    pin(texts, edges="lr", inset=4)
    return d


@xib("HomeAI/Redesign/Projects/ProjectDetailViewController.xib")
def project_detail():
    d = Doc("ProjectDetailViewController", owner="ProjectDetailViewController")
    root = d.root
    root.bg = "white"
    sa = d.safe_area

    table = Table(id="table", outlet="tableView")

    # header: compare A/B + "Versions"
    a_img = Image(id="a-img", mode="scaleAspectFill", bg="dsSurface", outlet="aImageView")
    b_img = Image(id="b-img", mode="scaleAspectFill", bg="dsSurface", outlet="bImageView")
    b_clip = View(id="b-clip", bg="clear", clips=True, outlet="bClipView", children=[b_img])
    divider = View(id="divider", bg="white", outlet="dividerView")
    h_icon = Image(id="handle-icon", system="rectangle.split.2x1", size=13, weight="semibold", tint="black")
    handle = View(id="handle", cls="DSView", bg="white", outlet="handleView",
                  runtime={"cornerRadius": 18, "shadowOpacity": 0.25, "shadowRadius": 4, "shadowOffsetY": 2},
                  children=[h_icon])
    a_pill = pill("a-pill", "A · Original", ("#000000", 0.4), "white", label_outlet="aLabel")
    b_pill = pill("b-pill", "B · V3", "dsLime", "black", label_outlet="bLabel")
    compare = View(id="compare", cls="DSView", bg="dsSurface", clips=True, outlet="compareView",
                   runtime={"cornerRadius": 24}, children=[a_img, b_clip, divider, handle, a_pill, b_pill])
    v_title = Label("Versions", id="v-title", font=("SemiBold", 17), outlet="versionsTitleLabel")
    v_hint = Label("Pick two to compare", id="v-hint", font=("Regular", 13), color="dsTextTertiary",
                   outlet="versionsHintLabel")
    v_row = HStack([v_title, View(id="v-spacer", bg="clear", hug=(1, 250)), v_hint], id="v-row", align="center",
                   spacing=8)
    header = View(id="header", bg="white", outlet="headerContainer", children=[compare, v_row])

    fade = View(id="fade", cls="DSGradientView", interaction=False,
                runtime={"startColor": ("#FFFFFF", 0.0), "midColor": "white", "midLocation": 0.35,
                         "endColor": "white", "angle": 180})
    cta = primary_button("cta", "Continue editing", outlet="continueButton", action="didTapContinue:", icon="pencil",
                         title_outlet="continueLabel")

    back = glass_button("back", "chevron.left", action="didTapBack:", accessibility="Back")
    more = glass_button("more", "ellipsis", action="didTapMore:", outlet="moreButton", accessibility="More")
    nav_title = Label("Japandi living room", id="nav-title", font=("SemiBold", 17), align="center",
                      outlet="navTitleLabel", minScale=0.7)
    nav = View(id="nav", bg="white", outlet="navView", children=[back, nav_title, more])

    root.add(table, fade, cta, nav, header)

    pin(nav, edges="lr")
    C(nav, "top", sa, "top")
    size(nav, h=56)
    pin(back, edges="l", inset=16)
    center(back, x=False)
    pin(more, edges="r", inset=16)
    center(more, x=False)
    center(nav_title)
    C(nav_title, "leading", back, "trailing", 12, rel="greaterThanOrEqual")
    C(root, "top", nav, "top", 0, rel="lessThanOrEqual")

    pin(table, edges="lrb")
    below(table, nav, 8)

    # header is moved into tableHeaderView in code; constraints describe its content
    pin(header, edges="lr")
    C(header, "top", sa, "top", 900)
    pin(compare, edges="ltr", inset=(0, 20, 0, 20))
    size(compare, h=250)
    pin(a_img, to=compare)
    pin(b_clip, to=compare, edges="tbr")
    C(b_clip, "width", const=176, outlet="bClipWidthConstraint")
    pin(b_img, to=b_clip, edges="tbr")
    equal(b_img, compare, "width")
    pin(divider, to=compare, edges="tb")
    size(divider, w=2)
    C(divider, "centerX", b_clip, "leading")
    square(handle, 36)
    center(handle, to=divider)
    center(h_icon)
    square(h_icon, 16)
    pin(a_pill, to=compare, edges="lt", inset=10)
    pin(b_pill, to=compare, edges="tr", inset=10)
    below(v_row, compare, 18)
    pin(v_row, edges="lr", inset=20)
    C(header, "bottom", v_row, "bottom", 8)

    pin(fade, edges="lrb")
    size(fade, h=140)
    pin(cta, edges="lr", inset=20)
    C(sa, "bottom", cta, "bottom", 4)
    return d


@xib("HomeAI/Redesign/Projects/ProjectVersionCell.xib")
def project_version_cell():
    d = Doc("ProjectVersionCell", kind="tableCell", cls="ProjectVersionCell", size=(393, 76),
            reuse="ProjectVersionCell")
    thumb = Image(id="thumb", mode="scaleAspectFill", cls="DSImageView", bg="white", outlet="thumbImageView",
                  runtime={"cornerRadius": 12})
    title = Label("V3 · Sage walls", id="title", font=("SemiBold", 15), outlet="titleLabel", minScale=0.8)
    sub = Label("Paint · Today 14:20", id="sub", font=("Regular", 12), color="dsTextTertiary", outlet="subtitleLabel")
    texts = VStack([title, sub], id="texts", spacing=2, align="fill")
    slot_label = Label("B", id="slot-label", font=("Bold", 12), align="center", outlet="slotLabel")
    slot = Control(id="slot", cls="DSPressableControl", bg="clear", outlet="slotControl",
                   runtime={"cornerRadius": 13, "borderWidth": 1.5, "borderColor": SLOT_BORDER},
                   accessibility="Compare", children=[slot_label]).on("didTapSlot:")
    row = HStack([thumb, texts, slot], id="row", spacing=12, align="center", margins=(0, 8, 0, 14))
    box = View(id="box", cls="DSView", bg="dsSurface", outlet="boxView", runtime={"cornerRadius": 18},
               children=[row])
    d.cell(box)
    pin(box, inset=(4, 20, 4, 20))
    size(box, h=68)
    pin(row)
    square(thumb, 52)
    square(slot, 26)
    center(slot_label)
    return d

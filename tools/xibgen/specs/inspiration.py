from xibgen import *
from dslib import *

ROOMS = ["All", "Living", "Bedroom", "Kitchen", "Bathroom", "Dining", "Hallway", "Gaming", "Outdoor"]
SUGGESTIONS = ["Scandinavian", "Japanese", "Minimalist", "Modern", "Mediterranean", "Contemporary", "Bohemian",
               "Industrial", "Classic", "Wabi-sabi"]
SKELETON_COLS = [[230, 170, 210, 200], [170, 240, 180, 210]]
SKELETON = "#ECECEC"


def chip_row(id, titles, collection, action, label_collection=None):
    chips = [chip(f"{id}-{i}", t, selected=(i == 0 and id == "room"), collection=collection, tag=i, action=action,
                  label_collection=label_collection) for i, t in enumerate(titles)]
    stack = HStack(chips, id=f"{id}-stack", spacing=8, margins=(0, 20, 0, 20))
    scroll = Scroll([stack], id=f"{id}-scroll", horizontal=True, outlet=f"{id}ScrollView")
    return scroll, stack, chips


@xib("HomeAI/Redesign/Inspiration/InspirationFeedViewController.xib")
def inspiration():
    d = Doc("InspirationFeedViewController", owner="InspirationFeedViewController")
    root = d.root
    root.bg = "dsBackground"
    sa = d.safe_area

    cv = Collection(id="feed-cv", spacing=12, item=(170, 230), outlet="collectionView", indicators=True)
    empty_title = Label("Nothing found", id="empty-title", font=("SemiBold", 17), align="center",
                        outlet="emptyTitleLabel")
    empty_sub = Label("Try another style or room", id="empty-sub", font=("Regular", 14), color="dsTextSecondary",
                      align="center", lines=0, outlet="emptySubtitleLabel")
    empty = VStack([empty_title, empty_sub], id="empty", spacing=4, align="fill", outlet="emptyStateView",
                   hidden=True)

    # skeleton (I1 · Skeleton): chips + 2 columns, pulsing blocks
    sk_chips = []
    for i, w in enumerate([60, 74, 70, 84, 60]):
        b = View(id=f"sk-chip-{i}", cls="DSView", bg=SKELETON, collection="skeletonBlocks", tag_value=i,
                 runtime={"pill": True})
        size(b, w=w, h=36)
        sk_chips.append(b)
    sk_chip_row = HStack(sk_chips, id="sk-chips", spacing=8)
    sk_cols = []
    for c, heights in enumerate(SKELETON_COLS):
        blocks = []
        for i, h in enumerate(heights):
            b = View(id=f"sk-{c}-{i}", cls="DSView", bg=SKELETON, collection="skeletonBlocks", tag_value=5 + c + i * 2,
                     runtime={"cornerRadius": 20})
            size(b, h=h)
            blocks.append(b)
        sk_cols.append(VStack(blocks, id=f"sk-col-{c}", spacing=12, align="fill"))
    sk_grid = HStack(sk_cols, id="sk-grid", spacing=13, dist="fillEqually", align="top")
    skeleton = View(id="skeleton", bg="dsBackground", outlet="skeletonView", clips=True, children=[sk_chip_row, sk_grid])

    # header
    header_bg = Blur(id="header-bg", style="systemUltraThinMaterial", outlet="headerBackgroundView", alpha=0)
    hairline = View(id="hairline", bg=("#000000", 0.06), outlet="headerHairline", alpha=0)
    big_title = Label("Inspiration", id="big-title", font=("SemiBold", 32), outlet="largeTitleLabel", minScale=0.8)
    small_title = Label("Inspiration", id="small-title", font=("SemiBold", 17), align="center",
                        outlet="compactTitleLabel", alpha=0)
    search = glass_button("search", "magnifyingglass", outlet="searchButton", action="didTapSearch:",
                          accessibility="Search")

    field_icon = Image(id="field-icon", system="magnifyingglass", size=15, weight="medium", tint="dsTextTertiary")
    field = TextField(placeholder="Search styles", font=("Regular", 16), id="search-field", outlet="searchField")
    field_box = View(id="field-box", cls="DSView", bg="dsChip", runtime={"pill": True},
                     children=[HStack([field_icon, field], id="field-row", spacing=8, align="center",
                                      margins=(0, 14, 0, 14))])
    cancel = Button("Cancel", id="cancel", font=("Medium", 16), color="dsTextPrimary", outlet="cancelSearchButton",
                    hug=(751, 750), resist=(751, 750)).on("didTapCancelSearch:")
    search_bar = HStack([field_box, cancel], id="search-bar", spacing=12, align="fill", outlet="searchBarView",
                        hidden=True, alpha=0)

    room_scroll, room_stack, _ = chip_row("room", ROOMS, "roomChips", "didTapRoom:")
    sugg_scroll, sugg_stack, _ = chip_row("suggestion", SUGGESTIONS, "suggestionChips", "didTapSuggestion:")
    sugg_scroll.hidden = True

    header = View(id="header", bg="clear", outlet="headerView",
                  children=[big_title, small_title, search, search_bar, room_scroll, sugg_scroll])

    # offline banner
    off_icon = Image(id="offline-icon", system="wifi.slash", size=14, weight="semibold", tint="white")
    off_label = Label("Offline. Showing saved ideas.", id="offline-label", font=("Medium", 14), color="white",
                      minScale=0.75, outlet="offlineLabel")
    offline = View(id="offline", cls="DSView", bg="#1C1C1E", outlet="offlineBannerView", hidden=True,
                   runtime={"pill": True, "shadowOpacity": 0.15, "shadowRadius": 10, "shadowOffsetY": 4},
                   children=[HStack([off_icon, off_label], id="offline-row", spacing=10, align="center",
                                    margins=(0, 16, 0, 16))])

    root.add(cv, empty, header_bg, hairline, header, skeleton, offline)

    pin(cv)
    center(empty, x=True, y=False)
    C(empty, "top", header, "bottom", 120)
    pin(empty, edges="lr", inset=40)

    pin(header, edges="lr")
    C(header, "top", sa, "top")
    pin(header_bg, edges="ltr")
    C(header_bg, "bottom", header, "bottom")
    pin(hairline, edges="lr")
    C(hairline, "top", header, "bottom")
    size(hairline, h=0.5)

    pin(big_title, edges="l", inset=20)
    pin(search, edges="r", inset=20)
    C(search, "top", header, "top", 8)
    center(big_title, to=search, x=False)
    C(search, "leading", big_title, "trailing", 12, rel="greaterThanOrEqual")
    center(small_title, to=search, x=False)
    center(small_title, y=False)
    pin(search_bar, edges="lr", inset=20)
    center(search_bar, to=search, x=False)
    size(search_bar, h=44)
    pin(field_box.children[0])
    square(field_icon, 18)

    for sc, st in [(room_scroll, room_stack), (sugg_scroll, sugg_stack)]:
        pin(sc, edges="lr")
        C(sc, "top", search, "bottom", 12)
        size(sc, h=36)
        pin(st, to=sc.content)
        equal(st, sc.frame, "height")
    C(header, "bottom", room_scroll, "bottom", 10)

    # skeleton covers chips + grid
    pin(skeleton, edges="lrb")
    C(skeleton, "top", room_scroll, "top")
    pin(sk_chip_row, edges="lt", inset=(0, 20, 0, 0))
    pin(sk_grid, edges="lr", inset=20)
    below(sk_grid, sk_chip_row, 22)

    pin(offline, edges="lr", inset=20)
    C(offline, "top", sa, "top", 6, outlet="offlineTopConstraint")
    size(offline, h=40)
    pin(offline.children[0])
    square(off_icon, 18)
    return d


@xib("HomeAI/Redesign/Inspiration/InspirationCardCell.xib")
def inspiration_card_cell():
    d = Doc("InspirationCardCell", kind="collectionCell", cls="InspirationCardCell", size=(170, 230),
            reuse="InspirationCardCell")
    img = Image(id="photo", mode="scaleAspectFill", bg=SKELETON, cls="DSImageView", outlet="photoImageView",
                runtime={"cornerRadius": 20})
    tag_label = Label("Japandi", id="tag-label", font=("Medium", 12), color="white", outlet="tagLabel")
    tag = View(id="tag", cls="DSView", bg=("#000000", 0.35), runtime={"pill": True}, outlet="tagView",
               children=[HStack([tag_label], id="tag-row", align="center", margins=(0, 10, 0, 10))])
    bookmark = glass_button("bookmark", "bookmark", outlet="bookmarkControl", action="didTapBookmark:", size=30,
                            icon=15, dark=True, accessibility="Save idea")
    d.cell(img, tag, bookmark)
    pin(img)
    pin(tag, edges="lb", inset=8)
    size(tag, h=26)
    pin(tag.children[0])
    C(tag, "trailing", img, "trailing", -8, rel="lessThanOrEqual")
    pin(bookmark, edges="tr", inset=8)
    return d


@xib("HomeAI/Redesign/Inspiration/IdeaDetailViewController.xib")
def inspiration_detail():
    d = Doc("IdeaDetailViewController", owner="IdeaDetailViewController")
    root = d.root
    root.bg = "dsBackground"
    sa = d.safe_area

    hero = Image(id="hero", mode="scaleAspectFill", bg=SKELETON, outlet="heroImageView", clips=True)
    scrim = View(id="scrim", cls="DSGradientView", interaction=False,
                 runtime={"startColor": ("#000000", 0.35), "endColor": ("#000000", 0.0), "angle": 180})
    back = glass_button("back", "chevron.left", outlet="backButton", action="didTapClose:", accessibility="Back")
    nav_save = glass_button("nav-save", "bookmark", outlet="navSaveControl", action="didTapSave:",
                            accessibility="Save idea")
    share = glass_button("share", "square.and.arrow.up", outlet="shareButton", action="didTapShare:",
                         accessibility="Share")
    right = HStack([nav_save, share], id="nav-right", spacing=8)
    nav = View(id="nav", bg="clear", outlet="navView", children=[back, right])

    ai_icon = Image(id="ai-icon", system="sparkles", size=12, weight="semibold", tint="dsLime")
    ai_label = Label("AI redesign · Japandi", id="ai-label", font=("Medium", 12), color="white", outlet="aiTagLabel")
    ai_tag = View(id="ai-tag", cls="DSView", bg=("#000000", 0.35), runtime={"pill": True}, outlet="aiTagView",
                  children=[HStack([ai_icon, ai_label], id="ai-row", spacing=6, align="center", margins=(0, 12, 0, 12))])

    title = Label("Warm Japandi kitchen", id="title", font=("SemiBold", 24), outlet="titleLabel", minScale=0.7)
    sub = Label("Kitchen · Beige palette", id="sub", font=("Regular", 14), color="dsTextTertiary",
                outlet="subtitleLabel")
    title_group = VStack([title, sub], id="title-group", spacing=4, align="fill")

    tag_chips = [chip(f"tag-{i}", t, collection="tagChips", tag=i, action="didTapTag:", height=32)
                 for i, t in enumerate(["Japandi", "Kitchen", "Beige", "Linen"])]
    tags_stack = HStack(tag_chips, id="tags-stack", spacing=8, margins=(0, 20, 0, 20))
    tags_scroll = Scroll([tags_stack], id="tags-scroll", horizontal=True, outlet="tagsScrollView")
    tags_wrap = View(id="tags-wrap", bg="clear", children=[tags_scroll])

    palette_title = Label("Palette", id="palette-title", font=("SemiBold", 15), outlet="paletteTitleLabel")
    swatches = []
    for i, hex in enumerate(["#EFE8DD", "#C9A27E", "#7A6A58", "#2E2B28", "#9AA58A"]):
        s = Control(id=f"swatch-{i}", cls="DSPressableControl", bg=hex, collection="swatchControls", tag_value=i,
                    runtime={"pill": True, "borderWidth": 1, "borderColor": ("#000000", 0.08)}).on("didTapSwatch:")
        square(s, 44)
        swatches.append(s)
    swatch_row = HStack(swatches + [View(id="swatch-spacer", bg="clear", hug=(1, 250))], id="swatch-row", spacing=10)
    palette = VStack([palette_title, swatch_row], id="palette", spacing=10, align="fill", outlet="paletteView")

    save_icon = Image(id="save-icon", system="bookmark", size=19, weight="medium", tint="dsTextPrimary",
                      outlet="saveIconView")
    save = Control(id="save", cls="DSPressableControl", bg="dsChip", outlet="saveControl",
                   runtime={"pill": True, "borderColor": "dsLime"}, accessibility="Save idea",
                   children=[save_icon]).on("didTapSave:")
    square(save, 56)
    center(save_icon)
    square(save_icon, 22)
    try_btn = primary_button("try", "Try on my room", outlet="tryButton", action="didTapTry:", icon="sparkles",
                             title_outlet="tryTitleLabel")
    try_btn.children[0].children[-1].lines = 2
    cta = HStack([save, try_btn], id="cta", spacing=12, align="fill")

    panel_stack = VStack([title_group, tags_wrap, palette, cta], id="panel-stack", spacing=30, align="fill",
                         outlet="panelStack")
    panel = View(id="panel", cls="DSView", bg="dsBackground", outlet="panelView",
                 runtime={"cornerRadius": 34, "layer.maskedCorners": 3}, children=[panel_stack])

    root.add(hero, scrim, nav, ai_tag, panel)

    pin(hero, edges="ltr")
    C(hero, "bottom", panel, "top", 32)
    pin(scrim, edges="ltr")
    size(scrim, h=130)
    pin(nav, edges="lr", inset=16)
    C(nav, "top", sa, "top")
    size(nav, h=56)
    pin(back, edges="l")
    center(back, x=False)
    pin(right, edges="r")
    center(right, x=False)

    pin(ai_tag, edges="l", inset=16)
    C(panel, "top", ai_tag, "bottom", 18)
    size(ai_tag, h=30)
    pin(ai_tag.children[0])
    square(ai_icon, 14)

    pin(panel, edges="lrb")
    C(panel, "top", sa, "top", 300, rel="greaterThanOrEqual")
    pin(panel_stack, edges="lr", inset=20)
    C(panel_stack, "top", panel, "top", 24)
    C(sa, "bottom", panel_stack, "bottom", 0, prio=999)
    C(root, "bottom", panel_stack, "bottom", 16, rel="greaterThanOrEqual")

    pin(tags_scroll, inset=(0, -20, 0, -20))
    size(tags_scroll, h=32)
    pin(tags_stack, to=tags_scroll.content)
    equal(tags_stack, tags_scroll.frame, "height")
    size(cta, h=56)
    return d

from xibgen import *

WHITE85 = ("#FFFFFF", 0.85)


def pill_row(children, margins, spacing):
    return HStack(children, spacing=spacing, align="center", margins=(0, margins[0], 0, margins[1]))


def section_header(text, id, link=None):
    title = Label(text, id=f"{id}-title", font=("SemiBold", 22), kern=-0.11, outlet=f"{id}TitleLabel")
    if not link:
        return title
    btn = Button(link, id=f"{id}-link", font=("Medium", 15), color="dsLink", outlet=f"{id}LinkButton",
                 hug=(750, 750)).on("didTapSeeAll:")
    row = HStack([title, btn], id=f"{id}-row", align="center", spacing=8)
    return row


def wrap(child, id, inset=(0, 20, 0, 20), **kw):
    w = View(id=id, bg="clear", children=[child], **kw)
    w.wrap_inset = inset
    return w


@xib("HomeAI/Redesign/Home/HomeViewController.xib")
def home():
    d = Doc("HomeViewController", owner="HomeViewController")
    root = d.root
    root.bg = "white"

    glow = View(id="glow", cls="DSGradientView", outlet="topGlowView",
                runtime={"startColor": "dsLimeSoft", "endColor": "white", "angle": 180})

    # ---------------- scroll content ----------------
    # 1 free design left banner
    banner_icon = Image(id="banner-icon", system="sparkles", size=17, weight="semibold", tint="dsTextPrimary",
                        outlet="freeBannerIcon")
    banner_text = Label("1 free design left", id="banner-text", font=("Medium", 15), outlet="freeBannerLabel",
                        hug=(249, 251))
    banner_pro = Label("Get Pro", id="banner-pro", font=("SemiBold", 15), color="dsLink", outlet="freeBannerProLabel",
                       hug=(750, 251))
    banner_close = Button(id="banner-close", system="xmark", symbolSize=13, weight="semibold",
                          color="dsTextTertiary", tint="dsTextTertiary",
                          accessibility="Hide").on("didTapCloseFreeBanner:")
    banner_row = HStack([banner_icon, banner_text, banner_pro, banner_close], id="banner-row", spacing=10,
                        align="center", margins=(0, 16, 0, 10))
    banner = Control(id="banner", cls="DSPressableControl", bg="#F4FFE8", outlet="freeBannerControl",
                     runtime={"cornerRadius": 18, "borderWidth": 1, "borderColor": "dsLime"},
                     children=[banner_row]).on("didTapFreeBanner:")
    banner_wrap = wrap(banner, "banner-wrap", inset=(0, 20, 12, 20), outlet="freeBannerContainer", hidden=True)

    # hero
    after = Image(id="hero-after", image="home_hero_after", mode="scaleAspectFill", outlet="heroAfterImageView")
    before = Image(id="hero-before", image="home_hero_before", mode="scaleAspectFill", outlet="heroBeforeImageView")
    before_clip = View(id="before-clip", bg="clear", clips=True, children=[before], outlet="heroBeforeClipView")
    divider = View(id="divider", bg="white", outlet="heroDividerView")
    handle = Image(id="handle", image="ds_compare_handle", outlet="heroHandleView", clips=False,
                   runtime={"layer.shadowOpacity": 0.18, "layer.shadowRadius": 4, "layer.shadowOffset": ("size", (0, 2))})
    scrim = View(id="hero-scrim", cls="DSGradientView", interaction=False,
                 runtime={"startColor": ("#000000", 0.0), "endColor": ("#000000", 0.62), "angle": 180})
    hero_title = Label("Redesign a room", id="hero-title", font=("SemiBold", 28), color="white", kern=-0.28,
                       outlet="heroTitleLabel", minScale=0.7)
    hero_sub = Label("New style in ~30 s. Your layout stays.", id="hero-sub", font=("Regular", 14), color=WHITE85,
                     outlet="heroSubtitleLabel", minScale=0.8)
    hero_t = VStack([hero_title, hero_sub], id="hero-t", spacing=4, align="leading", outlet="heroTextStack")
    upload_icon = Image(id="upload-icon", system="camera", size=17, weight="medium", tint="black")
    upload_label = Label("Upload a photo", id="upload-label", font=("SemiBold", 16), outlet="uploadTitleLabel")
    upload_row = HStack([upload_icon, upload_label], id="upload-row", spacing=8, align="center")
    upload = Control(id="upload", cls="DSPrimaryButton", children=[upload_row], outlet="uploadButton").on("didTapUpload:")
    cost_icon = Image(id="cost-icon", system="sparkles", size=12, weight="semibold", tint="white")
    cost_label = Label("1", id="cost-label", font=("SemiBold", 15), color="white")
    cost = View(id="cost", cls="DSView", bg=("#FFFFFF", 0.25), outlet="costPillView",
                runtime={"pill": True}, hug=(750, 750), resist=(751, 750),
                children=[pill_row([cost_icon, cost_label], (14, 14), 4)])
    action_row = HStack([upload, cost], id="action-row", spacing=10, align="fill")
    hero_text = VStack([hero_t, action_row], id="hero-text", spacing=12, align="fill")
    tag_icon = Image(id="tag-icon", system="sofa", size=11, weight="semibold", tint="black", outlet="heroTagIcon")
    tag_label = Label("Interior", id="tag-label", font=("SemiBold", 12), outlet="heroTagLabel")
    tag = View(id="tag", cls="DSView", bg=("#FFFFFF", 0.8), outlet="heroTagView", runtime={"pill": True},
               children=[pill_row([tag_icon, tag_label], (10, 10), 6)])
    hero_clip = View(id="hero-clip", cls="DSView", bg="dsSurface", clips=True, outlet="heroClipView",
                     runtime={"cornerRadius": 34},
                     children=[after, before_clip, divider, handle, scrim, hero_text, tag])
    hero = View(id="hero", cls="DSView", bg="clear", outlet="heroView",
                runtime={"cornerRadius": 34, "shadowOpacity": 0.12, "shadowRadius": 15, "shadowOffsetY": 10},
                children=[hero_clip])
    hero_wrap = wrap(hero, "hero-wrap")

    # Redesign more — horizontal cards
    cards = []
    for i, (key, title, symbol) in enumerate([("exterior", "Exterior", "house"), ("garden", "Garden", "tree"),
                                               ("reference", "By reference", "photo.on.rectangle")]):
        img = Image(id=f"card-{key}-img", image=f"home_card_{key}", mode="scaleAspectFill")
        sc = View(id=f"card-{key}-scrim", cls="DSGradientView", interaction=False,
                  runtime={"startColor": ("#000000", 0.0), "endColor": ("#000000", 0.55), "angle": 180})
        ic = Image(id=f"card-{key}-icon", system=symbol, size=13, weight="semibold", tint="white")
        lb = Label(title, id=f"card-{key}-label", font=("SemiBold", 14), color="white", collection="moreCardLabels",
                   tag_value=i)
        row = HStack([ic, lb], id=f"card-{key}-row", spacing=6, align="center")
        card = Control(id=f"card-{key}", cls="DSPressableControl", clips=True, bg="dsSurface", tag_value=i,
                       collection="moreCards", runtime={"cornerRadius": 24}, children=[img, sc, row]).on("didTapMoreCard:")
        cards.append(card)
    more_stack = HStack(cards, id="more-stack", spacing=10, margins=(0, 20, 0, 20))
    more_scroll = Scroll([more_stack], id="more-scroll", horizontal=True)
    more_wrap = wrap(more_scroll, "more-wrap", inset=(14, 0, 0, 0))

    # Quick edits
    quick_header = wrap(section_header("Quick edits", "quick"), "quick-header-wrap", inset=(30, 20, 0, 20),
                        outlet="quickHeaderView")
    tools = [("paint", "Paint walls", "clay_paint"), ("floor", "New floor", "clay_flooring"),
             ("replace", "Replace", "clay_replace"), ("remove", "Remove", "clay_remove"),
             ("furnish", "Furnish", "clay_furnish"), ("rearrange", "Rearrange", "clay_rearrange")]
    tiles = []
    for i, (key, title, image) in enumerate(tools):
        ic = Image(id=f"tool-{key}-icon", image=image)
        lb = Label(title, id=f"tool-{key}-label", font=("Medium", 13), align="center", minScale=0.8,
                   collection="toolLabels", tag_value=i)
        col = VStack([ic, lb], id=f"tool-{key}-col", spacing=6, align="center")
        tile = Control(id=f"tool-{key}", cls="DSPressableControl", bg="dsSurface", tag_value=i, collection="toolTiles",
                       runtime={"cornerRadius": 24}, children=[col]).on("didTapTool:")
        tiles.append(tile)
    grid = VStack([HStack(tiles[:3], id="grid-row-1", spacing=13, dist="fillEqually"),
                   HStack(tiles[3:], id="grid-row-2", spacing=13, dist="fillEqually")],
                  id="grid", spacing=13)
    grid_wrap = wrap(grid, "grid-wrap", inset=(12, 20, 0, 20))

    # Plan & ideas
    plan_header = wrap(section_header("Plan & ideas", "plan"), "plan-header-wrap", inset=(30, 20, 0, 20),
                       outlet="planHeaderView")
    plan_cards = []
    for i, (key, title, sub, image, action) in enumerate([
            ("floorplan", "Floor plan → 3D", "Turn a sketch into a room", "clay_floorplan", "didTapFloorPlan:"),
            ("assistant", "Ask AI designer", "Ideas, colors, budget", "clay_assistant", "didTapAssistant:")]):
        bg = View(id=f"plan-{key}-bg", cls="DSGradientView", interaction=False,
                  runtime={"startColor": "dsCardGreenStart", "endColor": "dsCardGreenEnd", "angle": 137})
        ic = Image(id=f"plan-{key}-icon", image=image)
        spacer = View(id=f"plan-{key}-spacer", bg="clear", hug=(250, 1))
        t = Label(title, id=f"plan-{key}-title", font=("SemiBold", 15), minScale=0.8, collection="planTitleLabels",
                  tag_value=i)
        s = Label(sub, id=f"plan-{key}-sub", font=("Regular", 12), color="dsTextSecondary", minScale=0.8,
                  collection="planSubtitleLabels", tag_value=i)
        col = VStack([ic, spacer, t, s], id=f"plan-{key}-col", spacing=4, align="leading")
        card = Control(id=f"plan-{key}", cls="DSPressableControl", clips=True, tag_value=i, collection="planCards",
                       runtime={"cornerRadius": 28}, children=[bg, col]).on(action)
        plan_cards.append(card)
    plan_row = HStack(plan_cards, id="plan-row", spacing=13, dist="fillEqually")
    plan_wrap = wrap(plan_row, "plan-wrap", inset=(12, 20, 0, 20))

    # Recent projects
    recent_header = wrap(section_header("Recent projects", "recent", link="See all"), "recent-header-wrap",
                         inset=(30, 20, 0, 20))
    recent_cv = Collection(id="recent-cv", horizontal=True, spacing=12, item=(150, 214), insets=(0, 20, 0, 20),
                           outlet="recentCollectionView")
    recent_cv_wrap = wrap(recent_cv, "recent-cv-wrap", inset=(12, 0, 0, 0))
    recent = VStack([recent_header, recent_cv_wrap], id="recent", outlet="recentSectionView")

    bottom_pad = View(id="bottom-pad", bg="clear")
    content = VStack([banner_wrap, hero_wrap, more_wrap, quick_header, grid_wrap, plan_header, plan_wrap, recent,
                      bottom_pad], id="content", outlet="contentStack")
    scroll = Scroll([content], id="scroll", outlet="scrollView", indicators=False)

    # ---------------- fixed header ----------------
    header_bg = Blur(id="header-bg", style="systemUltraThinMaterialLight", outlet="headerBackgroundView", alpha=0)
    header_line = View(id="header-line", bg=("#000000", 0.06), outlet="headerHairline", alpha=0)
    logo = Label("Rehomely", id="logo", font=("SemiBold", 26), kern=-0.52, outlet="logoLabel", hug=(251, 251))
    spark = Image(id="credits-icon", system="sparkles", size=13, weight="semibold", tint="black",
                  outlet="creditsIconView")
    credits_label = Label("2 free", id="credits-label", font=("SemiBold", 14), outlet="creditsLabel")
    credits = Control(id="credits", cls="DSPressableControl", bg="dsLimeSoft", outlet="creditsControl",
                      runtime={"pill": True, "borderWidth": 1, "borderColor": "dsLime"},
                      children=[pill_row([spark, credits_label], (11, 13), 6)]).on("didTapCredits:")
    crown = Image(id="pro-crown", system="crown.fill", size=11, weight="semibold", tint="dsLime")
    pro_label = Label("Get Pro", id="pro-label", font=("SemiBold", 13), color="white", outlet="getProLabel")
    get_pro = Control(id="get-pro", cls="DSPressableControl", bg="black", outlet="getProControl",
                      runtime={"pill": True}, children=[pill_row([crown, pro_label], (10, 12), 4)]).on("didTapGetPro:")
    badge_crown = Image(id="badge-crown", system="crown.fill", size=11, weight="semibold", tint="dsLime")
    badge_label = Label("PRO", id="badge-label", font=("Bold", 13), color="white", kern=0.4)
    pro_badge = View(id="pro-badge", cls="DSView", bg="black", outlet="proBadgeView", hidden=True,
                     runtime={"pill": True}, children=[pill_row([badge_crown, badge_label], (10, 12), 4)])
    right = HStack([credits, get_pro, pro_badge], id="header-right", spacing=8, align="fill", hug=(750, 750))
    header_row = HStack([logo, View(id="header-spacer", bg="clear", hug=(1, 250)), right], id="header-row",
                        align="center", spacing=8)
    header = View(id="header", bg="clear", outlet="headerView", children=[header_row])

    # offline banner (overlays header)
    off_icon = Image(id="offline-icon", system="wifi.slash", size=14, weight="semibold", tint="white")
    off_label = Label("No internet. Designs need a connection.", id="offline-label", font=("Medium", 14),
                      color="white", minScale=0.75, outlet="offlineLabel")
    offline = View(id="offline", cls="DSView", bg="#1C1C1E", outlet="offlineBannerView", hidden=True,
                   runtime={"pill": True, "shadowOpacity": 0.15, "shadowRadius": 10, "shadowOffsetY": 4},
                   children=[HStack([off_icon, off_label], id="offline-row", spacing=10, align="center",
                                    margins=(0, 16, 0, 16))])

    root.add(glow, scroll, header_bg, header_line, header, offline)

    # ---------------- constraints ----------------
    sa = d.safe_area
    pin(glow, edges="ltr")
    size(glow, h=320)
    pin(scroll)
    pin(content, to=scroll.content, edges="lrb")
    C(content, "top", scroll.content, "top", 59)
    equal(content, scroll.frame, "width")
    size(bottom_pad, h=28)

    for w in [banner_wrap, hero_wrap, more_wrap, quick_header, grid_wrap, plan_header, plan_wrap, recent_header,
              recent_cv_wrap]:
        pin(w.children[0], inset=w.wrap_inset)

    # banner
    pin(banner_row)
    size(banner, h=48)
    square(banner_icon, 22)
    square(banner_close, 30)

    # hero
    size(hero, h=356)
    pin(hero_clip)
    pin(after)
    pin(before_clip, edges="ltb")
    C(before_clip, "width", const=110, outlet="heroBeforeWidthConstraint")
    pin(before, to=before_clip, edges="ltb")
    equal(before, hero_clip, "width")
    pin(divider, edges="tb")
    size(divider, w=2)
    C(divider, "centerX", before_clip, "trailing")
    square(handle, 32)
    C(handle, "centerX", divider, "centerX")
    C(handle, "centerY", hero_clip, "top", 128)
    pin(scrim, edges="lrb")
    size(scrim, h=200)
    pin(hero_text, edges="lrb", inset=(0, 20, 23, 20))
    size(action_row, h=48)
    square(upload_icon, 20)
    center(upload_row)
    pin(cost.children[0])
    square(cost_icon, 14)
    pin(tag, edges="lt", inset=16)
    size(tag, h=28)
    pin(tag.children[0])
    square(tag_icon, 14)

    # more cards
    size(more_scroll, h=112)
    pin(more_stack, to=more_scroll.content)
    equal(more_stack, more_scroll.frame, "height")
    for card in cards:
        img, sc, row = card.children
        size(card, w=160)
        pin(img)
        pin(sc, edges="lrb")
        size(sc, h=70)
        pin(row, edges="lb", inset=(0, 12, 14, 0))
        C(card, "trailing", row, "trailing", 8, rel="greaterThanOrEqual")
        square(row.children[0], 16)

    # quick grid
    for tile in tiles:
        size(tile, h=118)
        col = tile.children[0]
        center(col)
        C(col, "leading", tile, "leading", 4, rel="greaterThanOrEqual")
        square(col.children[0], 60)

    # plan cards
    for card in plan_cards:
        bg, col = card.children
        size(card, h=158)
        pin(bg)
        pin(col, inset=16)
        square(col.children[0], 64)

    size(recent_cv, h=214)

    # header
    pin(header_bg, edges="ltr")
    C(header_bg, "bottom", header, "bottom")
    pin(header_line, edges="lr")
    C(header_line, "top", header, "bottom")
    size(header_line, h=0.5)
    pin(header, edges="lr")
    C(header, "top", sa, "top")
    size(header, h=52)
    pin(header_row, inset=(0, 20, 0, 20))
    for pillv in (credits, get_pro, pro_badge):
        size(pillv, h=34)
        pin(pillv.children[0])
    square(spark, 16)
    square(crown, 15)
    square(badge_crown, 15)

    pin(offline, edges="lr", inset=20)
    C(offline, "top", sa, "top", 6, outlet="offlineTopConstraint")
    size(offline, h=40)
    pin(offline.children[0])
    square(off_icon, 18)
    return d


@xib("HomeAI/Redesign/Home/HomeProjectCell.xib")
def home_project_cell():
    d = Doc("HomeProjectCell", kind="collectionCell", cls="HomeProjectCell", size=(150, 214), reuse="HomeProjectCell")
    thumb = Image(id="thumb", mode="scaleAspectFill", bg="dsSurface", outlet="thumbImageView",
                  cls="DSImageView", runtime={"cornerRadius": 22})
    title = Label("Living room", id="title", font=("SemiBold", 14), outlet="titleLabel")
    sub = Label("3 versions · Today", id="sub", font=("Regular", 12), color="dsTextTertiary", outlet="subtitleLabel")
    texts = VStack([title, sub], id="texts", spacing=1, align="fill")
    content = d.cell(thumb, texts)
    pin(thumb, edges="ltr")
    size(thumb, h=160)
    below(texts, thumb, 8)
    pin(texts, edges="lr")
    return d

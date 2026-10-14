from xibgen import *
from dslib import *

TOOLS = [("style", "Style", "paintpalette"), ("paint", "Paint", "paintbrush.fill"),
         ("replace", "Replace", "arrow.triangle.2.circlepath"), ("remove", "Remove", "eraser"),
         ("floor", "Floor", "square.grid.3x3"), ("furnish", "Furnish", "sofa"),
         ("layout", "Layout", "arrow.up.and.down.and.arrow.left.and.right")]


@xib("HomeAI/Redesign/Result/ResultViewController.xib")
def result():
    d = Doc("ResultViewController", owner="ResultViewController")
    root = d.root
    root.bg = "black"
    sa = d.safe_area

    # ---------------- photo ----------------
    original = Image(id="original", mode="scaleAspectFill", outlet="originalImageView", alpha=0)
    result_img = Image(id="result", mode="scaleAspectFill", outlet="resultImageView")
    blur = Blur(id="reveal-blur", style="regular", outlet="revealBlurView", alpha=0, interaction=False)
    band = View(id="reveal-band", cls="DSGradientView", outlet="revealBandView", alpha=0, interaction=False,
                runtime={"startColor": ("#A5EE2F", 0.0), "midColor": ("#E9FFC9", 0.85), "endColor": ("#A5EE2F", 0.0),
                         "angle": 180})
    scrim = View(id="top-scrim", cls="DSGradientView", interaction=False,
                 runtime={"startColor": ("#000000", 0.4), "endColor": ("#000000", 0.0), "angle": 180})
    loader_dim = View(id="loader-dim", bg=("#000000", 0.35), outlet="editDimView", alpha=0, interaction=False)
    spinner = Spinner(id="loader-spin", style="medium", outlet="editSpinner")
    loader_label = Label("Applying your change…", id="loader-label", font=("Medium", 14), color="white",
                         outlet="editLoaderLabel")
    loader = View(id="loader", cls="DSView", bg=("#000000", 0.55), outlet="editLoaderView", alpha=0,
                  runtime={"pill": True},
                  children=[HStack([spinner, loader_label], id="loader-row", spacing=10, align="center",
                                   margins=(0, 16, 0, 18))])
    photo = View(id="photo", bg="black", clips=True, outlet="photoView",
                 children=[original, result_img, blur, band, loader_dim, scrim, loader])

    # ---------------- nav ----------------
    back = glass_button("back", "chevron.left", outlet="backButton", action="didTapBack:", dark=True,
                        accessibility="Back")
    download = glass_button("download", "arrow.down.to.line", outlet="downloadButton", action="didTapDownload:",
                            dark=True, accessibility="Save to Photos")
    share = glass_button("share", "square.and.arrow.up", outlet="shareButton", action="didTapShare:", dark=True,
                         accessibility="Share")
    more = Button(id="more", system="ellipsis", symbolSize=17, weight="semibold", color="white", tint="white",
                  bg=("#000000", 0.3), outlet="moreButton", accessibility="More",
                  runtime={"layer.cornerRadius": 22, "layer.borderWidth": 0.5})
    nav_right = HStack([download, share, more], id="nav-right", spacing=8)
    nav = View(id="nav", bg="clear", outlet="navView", children=[back, nav_right])

    # ---------------- overlays on the photo ----------------
    cmp_icon = Image(id="cmp-icon", system="rectangle.split.2x1", size=13, weight="semibold", tint="white")
    cmp_label = Label("Hold to compare", id="cmp-label", font=("Medium", 13), color="white", outlet="compareLabel")
    compare = View(id="compare", cls="DSView", bg=("#000000", 0.35), outlet="compareView", runtime={"pill": True},
                   children=[HStack([cmp_icon, cmp_label], id="cmp-row", spacing=6, align="center",
                                    margins=(0, 12, 0, 12))])
    badge_label = Label("V2", id="badge-label", font=("SemiBold", 12), color="white", outlet="versionBadgeLabel")
    badge = View(id="badge", cls="DSView", bg=("#000000", 0.35), outlet="versionBadgeView", runtime={"pill": True},
                 children=[badge_label])

    # ---------------- editor panel ----------------
    title = Label("Japandi living room", id="title", font=("SemiBold", 19), outlet="titleLabel", minScale=0.7)
    subtitle = Label("Version 2 · Keep structure", id="subtitle", font=("Regular", 13), color="dsTextTertiary",
                     outlet="subtitleLabel")
    texts = VStack([title, subtitle], id="texts", spacing=2, hug=(249, 251))

    def round_button(id, symbol, action, outlet, label):
        ic = Image(id=f"{id}-icon", system=symbol, size=16, weight="medium", tint="dsTextPrimary")
        b = Control(id=id, cls="DSPressableControl", bg="dsSurface", outlet=outlet, accessibility=label,
                    runtime={"pill": True}, children=[ic]).on(action)
        square(b, 40)
        center(ic)
        square(ic, 19)
        return b

    like = round_button("like", "hand.thumbsup", "didTapLike:", "likeButton", "Like")
    dislike = round_button("dislike", "hand.thumbsdown", "didTapDislike:", "dislikeButton", "Dislike")
    header = HStack([texts, like, dislike], id="header", spacing=8, align="center")
    versions = Collection(id="versions", horizontal=True, spacing=12, item=(56, 76), insets=(0, 20, 0, 20),
                          outlet="versionsCollectionView")

    tool_views = []
    for i, (key, t, symbol) in enumerate(TOOLS):
        ic = Image(id=f"tool-{key}-icon", system=symbol, size=18, weight="medium", tint="dsTextPrimary")
        circle = View(id=f"tool-{key}-circle", cls="DSView", bg="dsSurface", runtime={"pill": True}, children=[ic])
        lb = Label(t, id=f"tool-{key}-label", font=("Medium", 11), align="center", minScale=0.7,
                   collection="toolLabels", tag_value=i)
        col = VStack([circle, lb], id=f"tool-{key}-col", spacing=5, align="center")
        ctrl = Control(id=f"tool-{key}", cls="DSPressableControl", tag_value=i, collection="toolControls",
                       accessibility=t, children=[col]).on("didTapTool:")
        size(ctrl, w=56)
        pin(col, edges="ltr")
        C(ctrl, "bottom", col, "bottom")
        square(circle, 52)
        center(ic)
        square(ic, 22)
        tool_views.append(ctrl)
    tools_stack = HStack(tool_views, id="tools-stack", spacing=6, margins=(0, 20, 0, 20))
    tools = Scroll([tools_stack], id="tools", horizontal=True, outlet="toolsScrollView")

    ask_icon = Image(id="ask-icon", system="sparkles", size=15, weight="medium", tint="#5DAA12", outlet="askIconView")
    ask_label = Label("Ask for a change…", id="ask-label", font=("Regular", 15), color="dsTextTertiary",
                      outlet="askPlaceholderLabel")
    ask_tap = Control(id="ask-tap", cls="DSPressableControl", bg="clear", outlet="askControl",
                      runtime={"pressedScale": 0.98, "hapticOnPress": False},
                      children=[HStack([ask_icon, ask_label], id="ask-row", spacing=10, align="center")]).on("didTapAsk:")
    mic_icon = Image(id="mic-icon", system="mic", size=15, weight="medium", tint="dsTextPrimary")
    mic = Control(id="mic", cls="DSPressableControl", bg="dsCard", outlet="micButton", accessibility="Speak a change",
                  runtime={"pill": True}, children=[mic_icon]).on("didTapMic:")
    ask_bar = View(id="ask-bar", cls="DSView", bg="dsSurface", outlet="askBarView", runtime={"pill": True},
                   children=[ask_tap, mic])

    def inset(v, id):
        w = View(id=id, bg="clear", children=[v])
        pin(v, inset=(0, 20, 0, 20))
        return w

    panel_stack = VStack([inset(header, "w-header"), versions, tools, inset(ask_bar, "w-ask")], id="panel-stack",
                         spacing=14, outlet="panelStack")
    panel = View(id="panel", cls="DSView", bg="dsBackground", outlet="panelView",
                 runtime={"cornerRadius": 34, "layer.maskedCorners": 3}, children=[panel_stack])

    # ---------------- R6 · ask (typing) ----------------
    ask_title = Label("Ask for a change", id="ask-title", font=("SemiBold", 15), outlet="askTitleLabel")
    ask_cost = Label("1 credit · 2 left", id="ask-cost", font=("Regular", 12), color="dsTextTertiary",
                     outlet="askCostLabel", hug=(750, 251))
    ask_head = HStack([ask_title, View(id="ask-head-sp", bg="clear", hug=(1, 250)), ask_cost], id="ask-head",
                      align="center")
    suggestions = [chip(f"sug{i}", t, icon="sparkles", collection="suggestionChips", tag=i,
                        action="didTapSuggestion:")
                   for i, t in enumerate(["Warmer light", "Add plants", "Darker floor", "Bigger rug", "Add art"])]
    sug_stack = HStack(suggestions, id="sug-stack", spacing=8, margins=(0, 20, 0, 20))
    sug_scroll = Scroll([sug_stack], id="sug-scroll", horizontal=True, outlet="suggestionScrollView")
    ask_text = TextView(id="ask-text", font=("Regular", 16), outlet="askTextView")
    ask_ph = Label("Describe the change…", id="ask-ph", font=("Regular", 16), color="dsTextTertiary",
                   outlet="askTextPlaceholder")
    ask_field = View(id="ask-field", cls="DSView", bg="dsSurface", outlet="askFieldView",
                     runtime={"cornerRadius": 22, "borderWidth": 1.5, "borderColor": "dsLime"},
                     children=[ask_text, ask_ph])
    send_icon = Image(id="send-icon", system="arrow.up", size=17, weight="bold", tint="black")
    send = Control(id="send", cls="DSPrimaryButton", outlet="sendButton", accessibility="Send",
                   children=[send_icon]).on("didTapSend:")
    ask_row = HStack([ask_field, send], id="ask-row2", spacing=10, align="bottom")
    ask_panel = View(id="ask-panel", cls="DSView", bg="dsBackground", outlet="askPanelView", hidden=True,
                     runtime={"cornerRadius": 28, "layer.maskedCorners": 3, "shadowOpacity": 0.1, "shadowRadius": 20},
                     children=[VStack([inset(ask_head, "w-ask-head"), sug_scroll, inset(ask_row, "w-ask-row")],
                                      id="ask-stack", spacing=12)])

    # ---------------- R6 · voice ----------------
    dot = View(id="rec-dot", cls="DSView", bg="#FF3B30", runtime={"pill": True})
    listening = Label("Listening…", id="listening", font=("Medium", 14), color="dsTextSecondary",
                      outlet="listeningLabel")
    listen_row = HStack([dot, listening], id="listen-row", spacing=6, align="center")
    wave = View(id="wave", bg="clear", outlet="waveView")
    transcript = Label("", id="transcript", font=("SemiBold", 18), align="center", lines=3,
                       outlet="transcriptLabel")
    v_cancel = glass_button("v-cancel", "xmark", outlet="voiceCancelButton", action="didTapVoiceCancel:", size=48,
                            accessibility="Cancel")
    v_cancel.bg = "dsSurface"
    v_done_pulse = View(id="v-pulse", cls="DSView", bg=("#A5EE2F", 0.25), runtime={"pill": True},
                        outlet="voicePulseView", interaction=False)
    v_done_icon = Image(id="v-done-icon", system="checkmark", size=20, weight="bold", tint="black")
    v_done = Control(id="v-done", cls="DSPrimaryButton", outlet="voiceDoneButton", accessibility="Done",
                     children=[v_done_icon]).on("didTapVoiceDone:")
    v_done_wrap = View(id="v-done-wrap", bg="clear", children=[v_done_pulse, v_done])
    v_text = glass_button("v-text", "textformat", outlet="voiceTextButton", action="didTapVoiceKeyboard:", size=48,
                          accessibility="Type instead")
    v_text.bg = "dsSurface"
    v_controls = HStack([v_cancel, v_done_wrap, v_text], id="v-controls", dist="equalSpacing", align="center",
                        margins=(0, 20, 0, 20))
    voice_panel = View(id="voice-panel", cls="DSView", bg="dsBackground", outlet="voicePanelView", hidden=True,
                       runtime={"cornerRadius": 34, "layer.maskedCorners": 3},
                       children=[VStack([listen_row, wave, transcript, v_controls], id="voice-stack", spacing=16,
                                        align="center")])

    root.add(photo, nav, compare, badge, panel, ask_panel, voice_panel)

    # ---------------- constraints ----------------
    pin(photo, edges="ltr")
    C(photo, "bottom", panel, "top", 72)
    for v in (original, result_img, loader_dim):
        pin(v)
    pin(blur)
    pin(band, edges="lr")
    size(band, h=120)
    C(band, "top", photo, "top", -120, outlet="revealBandTopConstraint")
    pin(scrim, edges="ltr")
    size(scrim, h=140)
    center(loader, to=photo, y=False)
    C(loader, "centerY", photo, "centerY", -36)
    size(loader, h=44)
    pin(loader.children[0])

    pin(nav, edges="lr", inset=(0, 16, 0, 16))
    C(nav, "top", sa, "top", -4)
    size(nav, h=56)
    pin(back, edges="l")
    center(back, x=False)
    pin(nav_right, edges="r")
    center(nav_right, x=False)
    square(more, 44)

    pin(compare, edges="l", inset=16)
    C(panel, "top", compare, "bottom", 16)
    size(compare, h=36)
    pin(compare.children[0])
    square(cmp_icon, 16)
    pin(badge, edges="r", inset=16)
    C(badge, "centerY", compare, "centerY")
    size(badge, h=28)
    pin(badge_label, edges="lr", inset=(0, 10, 0, 10))
    center(badge_label, x=False)

    pin(panel, edges="lrb")
    pin(panel_stack, edges="lr")
    C(panel_stack, "top", panel, "top", 18)
    C(sa, "bottom", panel_stack, "bottom", 6)
    size(versions, h=76)
    size(tools, h=74)
    pin(tools_stack, to=tools.content)
    equal(tools_stack, tools.frame, "height")
    size(ask_bar, h=50)
    pin(ask_tap, edges="ltb", inset=(0, 16, 0, 0))
    C(mic, "leading", ask_tap, "trailing", 8)
    pin(mic, edges="r", inset=6)
    center(mic, x=False)
    square(mic, 38)
    center(mic_icon)
    square(mic_icon, 18)
    pin(ask_tap.children[0], edges="lr")
    center(ask_tap.children[0], x=False)
    square(ask_icon, 18)

    # ask panel sits on the keyboard
    pin(ask_panel, edges="lr")
    C(ask_panel, "bottom", root, "bottom", 0, outlet="askPanelBottomConstraint")
    ask_stack = ask_panel.children[0]
    pin(ask_stack, edges="lr")
    C(ask_stack, "top", ask_panel, "top", 18)
    C(ask_panel, "bottom", ask_stack, "bottom", 14)
    size(sug_scroll, h=36)
    pin(sug_stack, to=sug_scroll.content)
    equal(sug_stack, sug_scroll.frame, "height")
    C(ask_field, "height", const=52, rel="greaterThanOrEqual")
    C(ask_field, "height", const=112, rel="lessThanOrEqual")
    C(ask_field, "height", const=52, outlet="askFieldHeightConstraint", prio=750)
    pin(ask_text, inset=(6, 12, 6, 12))
    pin(ask_ph, edges="lr", inset=(0, 17, 0, 17))
    C(ask_ph, "top", ask_field, "top", 15)
    size(send, 48, 48)
    center(send_icon)
    square(send_icon, 20)

    pin(voice_panel, edges="lrb")
    vstack = voice_panel.children[0]
    pin(vstack, edges="lr", inset=(0, 20, 0, 20))
    C(vstack, "top", voice_panel, "top", 24)
    C(sa, "bottom", vstack, "bottom", 12)
    square(dot, 8)
    size(wave, 200, 44)
    equal(v_controls, vstack, "width")
    square(v_done_wrap, 96)
    center(v_done, to=v_done_wrap)
    square(v_done, 72)
    pin(v_done_pulse)
    center(v_done_icon)
    square(v_done_icon, 24)
    return d


@xib("HomeAI/Redesign/Result/ResultVersionCell.xib")
def version_cell():
    d = Doc("ResultVersionCell", kind="collectionCell", cls="ResultVersionCell", size=(56, 76), reuse="ResultVersionCell")
    thumb = Image(id="thumb", mode="scaleAspectFill", cls="DSImageView", bg="dsSurface", runtime={"cornerRadius": 16},
                  outlet="thumbImageView")
    ring = View(id="ring", cls="DSView", bg="clear", interaction=False, outlet="ringView",
                runtime={"cornerRadius": 16, "borderWidth": 2.5, "borderColor": "dsTextPrimary"})
    again_icon = Image(id="again-icon", system="arrow.clockwise", size=17, weight="medium", tint="dsTextPrimary",
                       outlet="againIconView", hidden=True)
    label = Label("V1", id="label", font=("Regular", 11), color="dsTextTertiary", align="center", outlet="titleLabel")
    d.cell(thumb, ring, again_icon, label)
    pin(thumb, edges="ltr")
    size(thumb, h=56)
    pin(ring, to=thumb)
    center(again_icon, to=thumb)
    square(again_icon, 22)
    below(label, thumb, 4)
    pin(label, edges="lr")
    return d


@xib("HomeAI/Redesign/Result/CompareViewController.xib")
def compare():
    d = Doc("CompareViewController", owner="CompareViewController")
    root = d.root
    root.bg = "black"
    sa = d.safe_area
    after = Image(id="after", mode="scaleAspectFit", outlet="afterImageView")
    before = Image(id="before", mode="scaleAspectFit", outlet="beforeImageView")
    before_clip = View(id="before-clip", bg="clear", clips=True, outlet="beforeClipView", children=[before])
    divider = View(id="divider", bg="white", outlet="dividerView")
    handle = Image(id="handle", image="ds_compare_handle", outlet="handleView", clips=False)
    stage = View(id="stage", bg="black", clips=True, outlet="stageView", children=[after, before_clip, divider, handle])
    close = glass_button("close", "xmark", outlet="closeButton", action="didTapClose:", dark=True, accessibility="Close")
    fit = glass_button("fit", "viewfinder", outlet="fitButton", action="didTapFit:", dark=True,
                       accessibility="Reset zoom")
    seg_knob = View(id="seg-knob", cls="DSView", bg="dsKnob", outlet="segmentKnob", runtime={"pill": True})
    segs = []
    for i, t in enumerate(["Original", "Split", "Result"]):
        c = Control(id=f"seg{i}", cls="DSPressableControl", tag_value=i, collection="segmentControls",
                    runtime={"hapticOnPress": False, "pressedScale": 0.97},
                    children=[Label(t, id=f"seg{i}-label", font=("Medium", 14), color="dsTextSecondary", align="center",
                                    collection="segmentLabels", tag_value=i)]).on("didTapSegment:")
        center(c.children[0])
        segs.append(c)
    seg_row = HStack(segs, id="seg-row", dist="fillEqually")
    segmented = View(id="segmented", cls="DSView", bg="dsGlass", runtime={"pill": True}, outlet="segmentedView",
                     children=[seg_knob, seg_row])
    root.add(stage, close, fit, segmented)
    pin(stage, edges="lr")
    C(stage, "top", sa, "top", 0)
    C(segmented, "top", stage, "bottom", 12)
    pin(after)
    pin(before_clip, edges="ltb")
    C(before_clip, "width", stage, "width", mult="0.5", outlet="beforeWidthConstraint")
    pin(before, to=before_clip, edges="ltb")
    equal(before, stage, "width")
    pin(divider, edges="tb")
    size(divider, w=2)
    C(divider, "centerX", before_clip, "trailing")
    square(handle, 32)
    center(handle, to=divider)
    pin(close, edges="l", inset=16)
    C(close, "top", sa, "top", 4)
    pin(fit, edges="r", inset=16)
    C(fit, "top", sa, "top", 4)
    pin(segmented, edges="lr", inset=46)
    size(segmented, h=40)
    C(sa, "bottom", segmented, "bottom", 8)
    pin(seg_row, inset=3)
    C(seg_knob, "top", segmented, "top", 3)
    C(segmented, "bottom", seg_knob, "bottom", 3)
    C(seg_knob, "width", segs[0], "width")
    C(seg_knob, "leading", segmented, "leading", 3, outlet="segmentKnobLeading")
    return d


def sheet_title(text, id="title", outlet="titleLabel"):
    return Label(text, id=id, font=("SemiBold", 24), align="center", lines=0, outlet=outlet)


def sheet_sub(text, id="sub", outlet="subtitleLabel"):
    return Label(text, id=id, font=("Regular", 15), color="dsTextSecondary", align="center", lines=0, outlet=outlet)


@xib("HomeAI/Redesign/Result/ChangeStyleSheetViewController.xib")
def change_style_sheet():
    d = Doc("ChangeStyleSheetViewController", owner="ChangeStyleSheetViewController", size=(393, 640))
    root = d.root
    root.bg = "dsBackground"
    close = glass_button("close", "xmark", outlet="closeButton", action="didTapClose:", size=36, icon=16,
                         accessibility="Close")
    grid = Collection(id="grid", spacing=12, item=(104, 128), outlet="collectionView")
    see_all = Button("See all styles", id="see-all", font=("Medium", 14), color="dsLink", outlet="seeAllButton").on(
        "didTapSeeAll:")
    seg_knob = View(id="seg-knob", cls="DSView", bg="dsKnob", outlet="strengthKnob",
                    runtime={"cornerRadius": 16, "shadowOpacity": 0.12, "shadowRadius": 3, "shadowOffsetY": 2})
    segs = []
    for i, t in enumerate(["Subtle", "Balanced", "Bold"]):
        c = Control(id=f"str{i}", cls="DSPressableControl", tag_value=i, collection="strengthControls",
                    runtime={"hapticOnPress": False, "pressedScale": 0.98},
                    children=[Label(t, id=f"str{i}-label", font=("Medium", 14), color="dsTextSecondary", align="center",
                                    collection="strengthLabels", tag_value=i)]).on("didTapStrength:")
        center(c.children[0])
        segs.append(c)
    seg_row = HStack(segs, id="str-row", dist="fillEqually")
    strength = View(id="strength", cls="DSView", bg="dsSegment", runtime={"cornerRadius": 19}, outlet="strengthView",
                    children=[seg_knob, seg_row])
    keep_t = Label("Keep room structure", id="keep-t", font=("Medium", 15), outlet="keepTitleLabel")
    keep_s = Label("Walls, windows and layout stay", id="keep-s", font=("Regular", 12), color="dsTextTertiary",
                   outlet="keepSubtitleLabel")
    keep_switch = Switch(id="keep-switch", on=True, onTint="#34C759", outlet="keepSwitch")
    keep_row = HStack([VStack([keep_t, keep_s], id="keep-texts", spacing=2), View(id="keep-sp", bg="clear", hug=(1, 250)),
                       keep_switch], id="keep-row", align="center", spacing=8)
    restyle = primary_button("restyle", "Restyle · 1 credit", outlet="restyleButton", action="didTapRestyle:",
                             icon="wand.and.stars", title_outlet="restyleLabel")
    col = VStack([sheet_title("Change style"), sheet_sub("Same room, new look"), grid, see_all, strength, keep_row,
                  restyle], id="col", spacing=14, align="fill")
    root.add(col, close)
    pin(col, edges="lr", inset=20)
    C(col, "top", root, "top", 30)
    pin(close, edges="tr", inset=(16, 0, 0, 16))
    size(grid, h=270)
    size(see_all, h=24)
    size(strength, h=38)
    pin(seg_row, inset=3)
    C(seg_knob, "top", strength, "top", 3)
    C(strength, "bottom", seg_knob, "bottom", 3)
    C(seg_knob, "width", segs[0], "width")
    C(seg_knob, "leading", strength, "leading", 3, outlet="strengthKnobLeading")
    return d


@xib("HomeAI/Redesign/Result/ChangeStyleCell.xib")
def change_style_cell():
    d = Doc("ChangeStyleCell", kind="collectionCell", cls="ChangeStyleCell", size=(104, 128), reuse="ChangeStyleCell")
    img = Image(id="img", mode="scaleAspectFill", cls="DSImageView", bg="dsSurface", runtime={"cornerRadius": 18},
                outlet="thumbImageView")
    ring = View(id="ring", cls="DSView", bg="clear", interaction=False, outlet="ringView", alpha=0,
                runtime={"cornerRadius": 18, "borderWidth": 3, "borderColor": "dsLime"})
    check_icon = Image(id="check-icon", system="checkmark", size=11, weight="bold", tint="black")
    check = View(id="check", cls="DSView", bg="dsLime", runtime={"pill": True}, outlet="checkView", alpha=0,
                 children=[check_icon])
    cur_label = Label("Current", id="cur-label", font=("Medium", 11), color="white")
    current = View(id="current", cls="DSView", bg=("#000000", 0.55), runtime={"pill": True}, outlet="currentTag",
                   hidden=True, children=[cur_label])
    title = Label("Modern", id="title", font=("Regular", 13), align="center", minScale=0.75, outlet="titleLabel")
    d.cell(img, ring, check, current, title)
    pin(img, edges="ltr")
    C(img, "height", img, "width")
    pin(ring, to=img)
    pin(check, edges="tr", to=img, inset=(3, 0, 0, 3))
    square(check, 24)
    center(check_icon)
    pin(current, to=img, edges="lb", inset=(0, 6, 6, 0))
    size(current, h=22)
    pin(cur_label, edges="lr", inset=(0, 8, 0, 8))
    center(cur_label, x=False)
    below(title, img, 6)
    pin(title, edges="lr")
    return d


@xib("HomeAI/Redesign/Result/ShareSheetViewController.xib")
def share_sheet():
    d = Doc("ShareSheetViewController", owner="ShareSheetViewController", size=(393, 700))
    root = d.root
    root.bg = "dsBackground"
    close = glass_button("close", "xmark", outlet="closeButton", action="didTapClose:", size=36, icon=16,
                         accessibility="Close")
    before = Image(id="before", mode="scaleAspectFill", outlet="beforeImageView")
    after = Image(id="after", mode="scaleAspectFill", outlet="afterImageView")
    single = Image(id="single", mode="scaleAspectFill", outlet="singleImageView", hidden=True)
    preview = View(id="preview", cls="DSView", bg="black", clips=True, runtime={"cornerRadius": 22},
                   outlet="previewView",
                   children=[HStack([before, after], id="ba", spacing=2, dist="fillEqually"), single])
    seg_knob = View(id="seg-knob", cls="DSView", bg="dsKnob", outlet="formatKnob",
                    runtime={"cornerRadius": 16, "shadowOpacity": 0.12, "shadowRadius": 3, "shadowOffsetY": 2})
    segs = []
    for i, t in enumerate(["Before / After", "Result", "Story 9:16"]):
        c = Control(id=f"fmt{i}", cls="DSPressableControl", tag_value=i, collection="formatControls",
                    runtime={"hapticOnPress": False, "pressedScale": 0.98},
                    children=[Label(t, id=f"fmt{i}-label", font=("Medium", 14), color="dsTextSecondary", align="center",
                                    minScale=0.7, collection="formatLabels", tag_value=i)]).on("didTapFormat:")
        center(c.children[0])
        C(c.children[0], "leading", c, "leading", 4, rel="greaterThanOrEqual")
        segs.append(c)
    seg_row = HStack(segs, id="fmt-row", dist="fillEqually")
    formats = View(id="formats", cls="DSView", bg="dsSegment", runtime={"cornerRadius": 19}, outlet="formatView",
                   children=[seg_knob, seg_row])

    def option_row(id, icon, title, sub, accessory):
        ic = Image(id=f"{id}-icon", system=icon, size=15, weight="medium", tint="dsTextPrimary")
        box = View(id=f"{id}-box", cls="DSView", bg="dsCard", runtime={"cornerRadius": 9}, children=[ic])
        t = Label(title, id=f"{id}-t", font=("Medium", 16))
        s = Label(sub, id=f"{id}-s", font=("Regular", 13), color="dsTextTertiary")
        row = HStack([box, VStack([t, s], id=f"{id}-texts", spacing=2), View(id=f"{id}-sp", bg="clear", hug=(1, 250)),
                      accessory], id=id, spacing=14, align="center", margins=(0, 16, 0, 16))
        square(box, 32)
        center(ic)
        square(ic, 18)
        size(row, h=56)
        return row

    mark_switch = Switch(id="mark-switch", on=True, onTint="#34C759", outlet="watermarkSwitch")
    crown = Image(id="pro-crown", system="crown.fill", size=12, weight="semibold", tint="black")
    pro_badge = View(id="pro-badge", cls="DSView", bg="dsLime", runtime={"pill": True}, outlet="hdProBadge",
                     children=[HStack([crown, Label("PRO", id="pro-l", font=("Bold", 13), color="black")], id="pro-row", spacing=4,
                                      align="center", margins=(0, 10, 0, 12))])
    hd_switch = Switch(id="hd-switch", on=False, onTint="#34C759", outlet="hdSwitch", hidden=True)
    hd_access = HStack([pro_badge, hd_switch], id="hd-access", spacing=0, align="center")
    row1 = option_row("mark", "sparkles", "Made with Rehomely", "Small mark in the corner", mark_switch)
    row2 = option_row("hd", "photo.on.rectangle", "HD export · 4K", "Free: 1080 px", hd_access)
    divider = View(id="divider", bg="dsDivider")
    options = View(id="options", cls="DSView", bg="dsSurface", runtime={"cornerRadius": 18},
                   children=[VStack([row1, divider, row2], id="opt-stack")])
    actions = []
    for i, (key, t, symbol) in enumerate([("save", "Save", "arrow.down.to.line"), ("copy", "Copy", "doc.on.doc"),
                                          ("messages", "Messages", "message"), ("more", "More", "ellipsis")]):
        ic = Image(id=f"act-{key}-icon", system=symbol, size=18, weight="medium", tint="dsTextPrimary")
        circle = View(id=f"act-{key}-circle", cls="DSView", bg="dsChip", runtime={"pill": True}, children=[ic])
        lb = Label(t, id=f"act-{key}-l", font=("Regular", 12), color="dsTextSecondary", align="center",
                   collection="actionLabels", tag_value=i)
        col = VStack([circle, lb], id=f"act-{key}-col", spacing=6, align="center")
        ctrl = Control(id=f"act-{key}", cls="DSPressableControl", tag_value=i, collection="actionControls",
                       accessibility=t, children=[col]).on("didTapQuickAction:")
        size(ctrl, w=72)
        pin(col, edges="ltr")
        C(ctrl, "bottom", col, "bottom")
        square(circle, 56)
        center(ic)
        square(ic, 22)
        actions.append(ctrl)
    actions_row = HStack(actions, id="actions", dist="equalSpacing")
    share_btn = primary_button("share-btn", "Share", outlet="shareButton", action="didTapShare:",
                               icon="square.and.arrow.up", title_outlet="shareLabel")
    col = VStack([sheet_title("Share your redesign"), preview, formats, options, actions_row, share_btn], id="col",
                 spacing=16, align="fill")
    root.add(col, close)
    pin(col, edges="lr", inset=20)
    C(col, "top", root, "top", 30)
    pin(close, edges="tr", inset=(16, 0, 0, 16))
    size(preview, h=210)
    pin(preview.children[0])
    pin(single)
    size(formats, h=38)
    pin(seg_row, inset=3)
    C(seg_knob, "top", formats, "top", 3)
    C(formats, "bottom", seg_knob, "bottom", 3)
    C(seg_knob, "width", segs[0], "width")
    C(seg_knob, "leading", formats, "leading", 3, outlet="formatKnobLeading")
    pin(options.children[0])
    size(divider, h=1)
    size(pro_badge, h=30)
    pin(pro_badge.children[0])
    square(crown, 15)
    return d


@xib("HomeAI/Redesign/Result/DislikeSheetViewController.xib")
def dislike_sheet():
    d = Doc("DislikeSheetViewController", owner="DislikeSheetViewController", size=(393, 560))
    root = d.root
    root.bg = "dsBackground"
    close = glass_button("close", "xmark", outlet="closeButton", action="didTapClose:", size=36, icon=16,
                         accessibility="Close")
    reasons = ["Changed my room layout", "Doesn't look realistic", "Wrong style", "Weird objects or artifacts",
               "Ignored my request", "Other"]
    chips = [chip(f"r{i}", t, collection="reasonChips", tag=i, action="didTapReason:") for i, t in enumerate(reasons)]
    rows = VStack([HStack(chips[0:2], id="rr1", spacing=8), HStack(chips[2:4], id="rr2", spacing=8),
                   HStack(chips[4:6], id="rr3", spacing=8)], id="reasons", spacing=8, align="leading",
                  outlet="reasonsStack")
    field = TextField(placeholder="Tell us more (optional)", font=("Regular", 15), id="more-field", outlet="detailsField")
    field_box = View(id="field-box", cls="DSView", bg="dsSurface", runtime={"cornerRadius": 18}, children=[field])
    gift = Image(id="gift", system="gift", size=15, weight="medium", tint="dsLink")
    note_label = Label("We'll regenerate this one for free", id="note-label", font=("Medium", 14), color="dsLink",
                       lines=0, outlet="freeRetryLabel")
    note = View(id="note", cls="DSView", bg="dsLimeSoft", runtime={"cornerRadius": 16}, outlet="freeRetryView",
                children=[HStack([gift, note_label], id="note-row", spacing=10, align="center", margins=(12, 14, 12, 14))])
    send = primary_button("send", "Send & try again", outlet="sendRetryButton", action="didTapSendRetry:",
                          icon="arrow.clockwise", title_outlet="sendRetryLabel")
    just = Button("Just send feedback", id="just", font=("SemiBold", 15), outlet="justSendButton").on("didTapJustSend:")
    col = VStack([sheet_title("What went wrong?"), sheet_sub("Your answer trains the next version"), rows, field_box,
                  note, send, just], id="col", spacing=14, align="fill")
    root.add(col, close)
    pin(col, edges="lr", inset=20)
    C(col, "top", root, "top", 30)
    pin(close, edges="tr", inset=(16, 0, 0, 16))
    size(field_box, h=52)
    pin(field, inset=(0, 16, 0, 16))
    pin(note.children[0])
    square(gift, 18)
    size(just, h=44)
    return d

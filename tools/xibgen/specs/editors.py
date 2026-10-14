from xibgen import *
from dslib import *


def editor_shell(name, title, make_right_buttons):
    """Photo canvas on top, glass nav, hint pill and a white bottom panel (returned for filling)."""
    d = Doc(name, owner=name)
    right_buttons = make_right_buttons()
    root = d.root
    root.bg = "black"
    sa = d.safe_area
    canvas = View(id="canvas", cls="MaskCanvasView", bg="black", outlet="canvasView")
    original = Image(id="original", mode="scaleAspectFill", outlet="originalOverlayView", alpha=0, interaction=False)
    scrim = View(id="scrim", cls="DSGradientView", interaction=False,
                 runtime={"startColor": ("#000000", 0.4), "endColor": ("#000000", 0.0), "angle": 180})
    close = glass_button("close", "xmark", outlet="closeButton", action="didTapClose:", dark=True, accessibility="Close")
    nav_title = Label(title, id="nav-title", font=("SemiBold", 17), color="white", align="center", outlet="navTitleLabel")
    right = HStack(right_buttons, id="nav-right", spacing=8)
    hint_icon = Image(id="hint-icon", system="hand.raised", size=13, weight="medium", tint="white", outlet="hintIconView")
    hint_label = Label("Tap any dot to pick an object", id="hint-label", font=("Medium", 13), color="white",
                       outlet="hintLabel", minScale=0.8)
    hint = View(id="hint", cls="DSView", bg=("#000000", 0.45), outlet="hintView", runtime={"pill": True}, alpha=0,
                interaction=False,
                children=[HStack([hint_icon, hint_label], id="hint-row", spacing=8, align="center", margins=(0, 14, 0, 14))])
    panel_stack = VStack([], id="panel-stack", spacing=16, outlet="panelStack")
    panel = View(id="panel", cls="DSView", bg="dsBackground", outlet="panelView",
                 runtime={"cornerRadius": 34, "layer.maskedCorners": 3, "shadowOpacity": 0.12, "shadowRadius": 15,
                          "shadowOffsetY": -6},
                 children=[panel_stack])
    root.add(canvas, original, scrim, close, nav_title, right, hint, panel)
    pin(canvas, edges="ltr")
    C(canvas, "bottom", panel, "top", 34)
    pin(original, to=canvas)
    pin(scrim, edges="ltr")
    size(scrim, h=140)
    pin(close, edges="l", inset=16)
    C(close, "top", sa, "top", -2)
    center(nav_title, to=close, x=False)
    center(nav_title, y=False)
    pin(right, edges="r", inset=16)
    center(right, to=close, x=False)
    center(hint, y=False)
    C(panel, "top", hint, "bottom", 14)
    size(hint, h=36)
    pin(hint.children[0])
    square(hint_icon, 16)
    pin(panel, edges="lrb")
    pin(panel_stack, edges="lr", inset=(0, 20, 0, 20))
    C(panel_stack, "top", panel, "top", 18)
    C(sa, "bottom", panel_stack, "bottom", 6)
    return d, root, panel_stack


def panel_header(title, sub, extra=None):
    t = Label(title, id="p-title", font=("SemiBold", 20), outlet="panelTitleLabel")
    s = Label(sub, id="p-sub", font=("Regular", 13), color="dsTextTertiary", outlet="panelSubtitleLabel", minScale=0.8)
    texts = VStack([t, s], id="p-texts", spacing=2, hug=(249, 251))
    return HStack([texts] + ([extra] if extra else []), id="p-header", align="center", spacing=8)


def segmented(id, titles, outlet_prefix, action, height=34, width=None):
    knob = View(id=f"{id}-knob", cls="DSView", bg="dsCard", outlet=f"{outlet_prefix}Knob",
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
    size(seg, w=width, h=height)
    pin(row, inset=3)
    C(knob, "top", seg, "top", 3)
    C(seg, "bottom", knob, "bottom", 3)
    C(knob, "width", segs[0], "width")
    C(knob, "leading", seg, "leading", 3, outlet=f"{outlet_prefix}KnobLeading")
    return seg


def h_chips(id, titles, collection, action, icon=None):
    chips = [chip(f"{id}{i}", t, selected=(i == 0 and icon is None), icon=icon, collection=collection, tag=i,
                  action=action, height=34) for i, t in enumerate(titles)]
    stack = HStack(chips, id=f"{id}-stack", spacing=8)
    scroll = Scroll([stack], id=f"{id}-scroll", horizontal=True, clips=False)
    size(scroll, h=34)
    pin(stack, to=scroll.content)
    equal(stack, scroll.frame, "height")
    return scroll


@xib("HomeAI/Redesign/Editors/PaintEditorViewController.xib")
def paint_editor():
    d, root, stack = editor_shell("PaintEditorViewController", "", lambda: [
        glass_button("compare", "rectangle.split.2x1", outlet="compareButton", dark=True,
                     accessibility="Hold to see the original")])
    mode = segmented("mode", ["Auto", "Brush"], "mode", "didTapMode:", width=136)
    header = panel_header("Paint walls", "AI finds your walls", mode)
    palettes = h_chips("pal", ["Trending", "Neutrals", "Greens", "Warm", "Blues", "Darks"], "paletteChips",
                       "didTapPalette:")
    swatches = []
    for i in range(10):
        inner = View(id=f"sw{i}-c", cls="DSView", bg="#A9B59A", collection="swatchColorViews", tag_value=i,
                     runtime={"pill": True, "borderWidth": 1, "borderColor": ("#000000", 0.1)})
        ring = Control(id=f"sw{i}", cls="DSPressableControl", tag_value=i, collection="swatchControls",
                       runtime={"pill": True, "borderWidth": 0, "borderColor": "black"}, children=[inner]).on("didTapSwatch:")
        square(ring, 52)
        center(inner)
        square(inner, 42)
        swatches.append(ring)
    sw_stack = HStack(swatches, id="sw-stack", spacing=8)
    sw_scroll = Scroll([sw_stack], id="sw-scroll", horizontal=True, clips=False)
    size(sw_scroll, h=52)
    pin(sw_stack, to=sw_scroll.content)
    equal(sw_stack, sw_scroll.frame, "height")
    size_row = brush_size_row()
    size_row.hidden = True
    size_row.outlet = "brushSizeRow"
    apply_btn = primary_button("apply", "Apply · 1 credit", outlet="applyButton", action="didTapApply:",
                               icon="checkmark", title_outlet="applyLabel")
    stack.add(header, palettes, sw_scroll, size_row, apply_btn)
    return d


def brush_size_row():
    lab = Label("Size", id="size-label", font=("Medium", 15), outlet="sizeTitleLabel")
    small = View(id="size-small", cls="DSView", bg="dsTextTertiary", runtime={"pill": True})
    big = View(id="size-big", cls="DSView", bg="dsTextTertiary", runtime={"pill": True})
    slider = Slider(id="size-slider", value=28, minv=12, maxv=48, outlet="sizeSlider").on("didChangeSize:", "valueChanged")
    row = HStack([lab, small, slider, big], id="size-row", spacing=12, align="center")
    square(small, 8)
    square(big, 20)
    return row


@xib("HomeAI/Redesign/Editors/ReplaceEditorViewController.xib")
def replace_editor():
    d, root, stack = editor_shell("ReplaceEditorViewController", "Replace", lambda: [
        glass_button("compare", "rectangle.split.2x1", outlet="compareButton", dark=True,
                     accessibility="Hold to see the original")])
    header = panel_header("Replace", "Tap an object on the photo")
    suggestions = h_chips("sug", ["Travertine block", "Round marble", "Oak low table", "Nesting set", "Glass & brass"],
                          "suggestionChips", "didTapSuggestion:", icon="sparkles")
    suggestions.outlet = "suggestionScrollView"
    spark = Image(id="prompt-icon", system="sparkles", size=15, weight="medium", tint="#5DAA12")
    field = TextField(placeholder="Describe the new object", font=("Regular", 15), id="prompt-field",
                      outlet="promptField")
    mic_icon = Image(id="p-mic-icon", system="mic", size=15, weight="medium", tint="dsTextPrimary")
    mic = Control(id="p-mic", cls="DSPressableControl", bg="dsCard", outlet="micButton", accessibility="Speak",
                  runtime={"pill": True, "shadowOpacity": 0.08, "shadowRadius": 2, "shadowOffsetY": 1},
                  children=[mic_icon]).on("didTapMic:")
    prompt = View(id="prompt", cls="DSView", bg="dsSurface", runtime={"pill": True}, outlet="promptView",
                  children=[HStack([spark, field, mic], id="prompt-row", spacing=10, align="center",
                                   margins=(0, 16, 0, 6))])
    keep_t = Label("Keep size & position", id="keep-t", font=("Medium", 15), outlet="keepTitleLabel")
    keep_s = Label("Matches perspective, light and shadows", id="keep-s", font=("Regular", 12), color="dsTextTertiary",
                   outlet="keepSubtitleLabel")
    keep = Switch(id="keep", on=True, onTint="#34C759", outlet="keepSwitch")
    keep_row = HStack([VStack([keep_t, keep_s], id="keep-texts", spacing=2), View(id="keep-sp", bg="clear", hug=(1, 250)),
                       keep], id="keep-row", align="center", spacing=8)
    brush_link = Button("Can't find it? Paint over the object", id="brush-link", font=("Medium", 13), color="dsLink",
                        outlet="brushFallbackButton", hidden=True).on("didTapBrushFallback:")
    apply_btn = primary_button("apply", "Replace · 1 credit", outlet="applyButton", action="didTapApply:",
                               icon="arrow.triangle.2.circlepath", title_outlet="applyLabel")
    stack.add(header, suggestions, prompt, keep_row, brush_link, apply_btn)
    size(prompt, h=52)
    pin(prompt.children[0])
    square(spark, 18)
    square(mic, 40)
    center(mic_icon)
    square(mic_icon, 18)
    return d


@xib("HomeAI/Redesign/Editors/RemoveEditorViewController.xib")
def remove_editor():
    d, root, stack = editor_shell("RemoveEditorViewController", "Remove", lambda: [
        glass_button("undo", "arrow.uturn.backward", outlet="undoButton", action="didTapUndo:", dark=True,
                     accessibility="Undo"),
        glass_button("redo", "arrow.uturn.forward", outlet="redoButton", action="didTapRedo:", dark=True,
                     accessibility="Redo")])
    header = panel_header("Remove", "Brush over anything you want gone")
    mode = segmented("mode", ["Brush", "Lasso", "Tap object"], "mode", "didTapMode:", height=40)
    size_row = brush_size_row()
    size_row.outlet = "brushSizeRow"
    clear = secondary_button("clear", "Clear", outlet="clearButton", action="didTapClear:", height=56)
    apply_btn = primary_button("apply", "Remove · 1 credit", outlet="applyButton", action="didTapApply:", icon="eraser",
                               title_outlet="applyLabel")
    actions = HStack([clear, apply_btn], id="actions", spacing=12)
    size(clear, w=114)
    stack.add(header, mode, size_row, actions)
    return d

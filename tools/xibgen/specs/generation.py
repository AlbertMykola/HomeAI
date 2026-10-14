from xibgen import *
from dslib import *


@xib("HomeAI/Redesign/Generation/GenerationViewController.xib")
def generation():
    d = Doc("GenerationViewController", owner="GenerationViewController")
    root = d.root
    root.bg = "dsBackground"
    sa = d.safe_area

    # ---------------- nav ----------------
    collapse = glass_button("collapse", "chevron.down", outlet="collapseButton", action="didTapCollapse:",
                            accessibility="Minimize")
    nav_title = Label("Creating your design", id="nav-title", font=("SemiBold", 17), align="center",
                      outlet="navTitleLabel")

    # ---------------- photo card ----------------
    photo = Image(id="photo", mode="scaleAspectFill", outlet="photoImageView")
    tint = View(id="tint", bg=("#000000", 0.18), interaction=False)
    scanned = View(id="scanned", bg=("#A5EE2F", 0.10), interaction=False, outlet="scannedAreaView")
    scan = View(id="scan", cls="DSGradientView", interaction=False, outlet="scanLineView",
                runtime={"startColor": ("#A5EE2F", 0.0), "midColor": ("#A5EE2F", 0.55), "endColor": "#E9FFC9",
                         "midLocation": 0.85, "angle": 180})
    edge = View(id="edge", bg="#E9FFC9", interaction=False, outlet="scanEdgeView", clips=False,
                runtime={"layer.shadowOpacity": 0.9, "layer.shadowRadius": 6,
                         "layer.shadowOffset": ("size", (0, 0))})
    points = View(id="points", bg="clear", interaction=False, outlet="pointsView")
    clip = View(id="photo-clip", cls="DSView", clips=True, bg="dsSurface", runtime={"cornerRadius": 34},
                outlet="photoClipView", children=[photo, tint, scanned, scan, edge, points])
    card = View(id="photo-card", cls="DSView", bg="clear", outlet="photoCardView",
                runtime={"cornerRadius": 34, "shadowOpacity": 0.12, "shadowRadius": 15, "shadowOffsetY": 10},
                children=[clip])

    # ---------------- progress ----------------
    percent = Label("12%", id="percent", font=("SemiBold", 40), kern=-0.8, outlet="percentLabel")
    eta = Label("~30 s left", id="eta", font=("Regular", 15), color="dsTextSecondary", outlet="etaLabel",
                hug=(750, 251))
    percent_row = HStack([percent, View(id="pr-spacer", bg="clear", hug=(1, 250)), eta], id="percent-row",
                         align="lastBaseline", spacing=8)
    track = View(id="track", cls="DSView", bg="dsChip", clips=True, runtime={"cornerRadius": 4}, outlet="trackView")
    fill = View(id="fill", cls="DSGradientView", outlet="fillView",
                runtime={"cornerRadius": 4, "startColor": "#B8F655", "endColor": "#8FDB1C", "angle": 90})
    track.add(fill)
    progress = VStack([percent_row, track], id="progress", spacing=10, outlet="progressStack")

    # ---------------- steps ----------------
    rows = []
    for i, title in enumerate(["Analyzing your room", "Keeping walls & windows", "Applying style", "Final touches"]):
        ring = View(id=f"s{i}-ring", cls="DSView", bg="clear", collection="stepRings", tag_value=i,
                    runtime={"pill": True, "borderWidth": 2, "borderColor": "#D1D1D6"})
        check = Image(id=f"s{i}-check", system="checkmark", size=10, weight="bold", tint="dsLime")
        done = View(id=f"s{i}-done", cls="DSView", bg="dsInk", collection="stepDoneViews", tag_value=i, alpha=0,
                    runtime={"pill": True}, children=[check])
        spin = View(id=f"s{i}-spin", bg="clear", collection="stepSpinnerViews", tag_value=i, alpha=0)
        ind = View(id=f"s{i}-ind", bg="clear", children=[ring, done, spin])
        lab = Label(title, id=f"s{i}-label", font=("Regular", 15), color="dsTextTertiary", collection="stepLabels",
                    tag_value=i)
        row = HStack([ind, lab], id=f"s{i}", spacing=10, align="center", collection="stepRows", tag_value=i)
        square(ind, 22)
        pin(ring, inset=1)
        pin(done)
        pin(spin)
        center(check)
        square(check, 13)
        rows.append(row)
    steps = VStack(rows, id="steps", spacing=10, outlet="stepsStack")

    # ---------------- notify ----------------
    bell = Image(id="bell", system="bell", size=16, weight="medium", tint="dsTextPrimary", outlet="notifyIconView")
    notify_label = Label("Notify me when it's ready", id="notify-label", font=("Medium", 15), outlet="notifyLabel",
                         hug=(249, 251))
    chev = Image(id="notify-chev", system="chevron.right", size=13, weight="semibold", tint="dsTextTertiary",
                 outlet="notifyAccessoryView")
    notify = Control(id="notify", cls="DSPressableControl", bg="dsSurface", outlet="notifyControl",
                     runtime={"cornerRadius": 20},
                     children=[HStack([bell, notify_label, chev], id="notify-row", spacing=10, align="center",
                                      margins=(0, 16, 0, 16))]).on("didTapNotify:")

    # ---------------- failure overlay (G3 / G4) ----------------
    f_back = glass_button("f-back", "chevron.left", outlet="failureBackButton", action="didTapFailureBack:",
                          accessibility="Back")
    f_photo = Image(id="f-photo", mode="scaleAspectFill", outlet="failurePhotoView", cls="DSImageView",
                    runtime={"cornerRadius": 28})
    f_tint = View(id="f-tint", cls="DSView", bg=("#FFFFFF", 0.55), runtime={"cornerRadius": 28}, interaction=False)
    f_icon_img = Image(id="f-icon-img", system="arrow.clockwise", size=24, weight="semibold", tint="dsLime",
                       outlet="failureIconImageView")
    f_icon = View(id="f-icon", cls="DSView", bg="dsInk", outlet="failureIconView",
                  runtime={"pill": True, "shadowOpacity": 0.2, "shadowRadius": 10, "shadowOffsetY": 8},
                  children=[f_icon_img])
    f_title = Label("Something went wrong", id="f-title", font=("SemiBold", 26), kern=-0.13, align="center", lines=0,
                    outlet="failureTitleLabel")
    f_body = Label("Our servers hiccuped. Your credit is back — try again, it usually works.", id="f-body",
                   font=("Regular", 15), color="dsTextSecondary", align="center", lines=0, lineHeight=1.2,
                   outlet="failureBodyLabel")
    f_code = Label("Error 502 · ID 7F3A", id="f-code", font=("Regular", 12), color="dsTextTertiary", align="center",
                   outlet="failureCodeLabel")
    f_primary = primary_button("f-primary", "Try again", outlet="failurePrimaryButton", action="didTapFailurePrimary:",
                               icon="arrow.clockwise", title_outlet="failurePrimaryLabel",
                               icon_outlet="failurePrimaryIcon")
    f_secondary = Button("Change photo", id="f-secondary", font=("SemiBold", 15), outlet="failureSecondaryButton").on(
        "didTapFailureSecondary:")
    texts = VStack([f_title, f_body], id="f-texts", spacing=10, align="fill", outlet="failureTextStack")
    actions = VStack([f_primary, f_secondary], id="f-actions", spacing=10, align="fill", outlet="failureActionsStack")
    failure = View(id="failure", bg="dsBackground", outlet="failureView", hidden=True,
                   children=[f_back, f_photo, f_tint, f_icon, texts, f_code, actions])

    root.add(collapse, nav_title, card, progress, steps, notify, failure)

    # constraints
    pin(collapse, edges="l", inset=16)
    C(collapse, "top", sa, "top", 2)
    center(nav_title, to=collapse, x=False)
    center(nav_title, y=False)
    pin(card, edges="lr", inset=20)
    below(card, collapse, 6)
    C(card, "height", const=420, prio=750)
    C(card, "height", root, "height", mult="0.49", rel="lessThanOrEqual")
    pin(clip)
    pin(photo)
    pin(tint)
    pin(scanned, edges="ltr")
    C(scanned, "height", const=0, outlet="scannedHeightConstraint")
    pin(scan, edges="lr")
    size(scan, h=70)
    C(scan, "bottom", scanned, "bottom", 0)
    pin(edge, edges="lr")
    size(edge, h=2)
    C(edge, "bottom", scanned, "bottom", 0)
    pin(points)
    pin(progress, edges="lr", inset=20)
    below(progress, card, 20)
    size(track, h=8)
    pin(fill, edges="ltb")
    C(fill, "width", const=0, outlet="fillWidthConstraint")
    pin(steps, edges="lr", inset=20)
    below(steps, progress, 16)
    pin(notify, edges="lr", inset=20)
    size(notify, h=56)
    C(sa, "bottom", notify, "bottom", 0)
    C(notify, "top", steps, "bottom", 12, rel="greaterThanOrEqual")
    pin(notify.children[0])
    square(bell, 20)
    square(chev, 18)

    pin(failure)
    pin(f_back, edges="l", inset=16)
    C(f_back, "top", sa, "top", 2)
    size(f_photo, 200, 250)
    center(f_photo, y=False)
    C(f_photo, "top", sa, "top", 81)
    pin(f_tint, to=f_photo)
    square(f_icon, 64)
    center(f_icon, y=False)
    C(f_icon, "centerY", f_photo, "bottom", 0)
    center(f_icon_img)
    square(f_icon_img, 30)
    pin(texts, edges="lr", inset=20)
    below(texts, f_icon, 28)
    pin(f_code, edges="lr", inset=20)
    C(actions, "top", f_code, "bottom", 24, rel="greaterThanOrEqual")
    C(f_code, "top", texts, "bottom", 16, rel="greaterThanOrEqual")
    pin(actions, edges="lr", inset=20)
    C(sa, "bottom", actions, "bottom", 0)
    C(actions, "top", f_code, "bottom", 66, prio=250)
    size(f_secondary, h=44)
    return d


@xib("HomeAI/Redesign/Generation/NotifySheetViewController.xib")
def notify_sheet():
    d = Doc("NotifySheetViewController", owner="NotifySheetViewController", size=(393, 400))
    root = d.root
    root.bg = "dsBackground"
    title = Label("Get one ping when it's ready?", id="title", font=("SemiBold", 24), align="center", lines=0,
                  outlet="titleLabel")
    sub = Label("We'll send a single notification for this design. No spam, ever.", id="sub", font=("Regular", 15),
                color="dsTextSecondary", align="center", lines=0, outlet="subtitleLabel")
    app_icon_img = Image(id="app-icon-img", system="house.lodge", size=16, weight="semibold", tint="black")
    app_icon = View(id="app-icon", cls="DSGradientView", runtime={"cornerRadius": 9, "startColor": "#B8F655",
                                                                    "endColor": "#8FDB1C", "angle": 180},
                    children=[app_icon_img])
    app_name = Label("Rehomely", id="app-name", font=("system", 14, "semibold"))
    now = Label("now", id="now", font=("system", 13), color="dsTextTertiary", outlet="nowLabel", hug=(750, 251))
    msg = Label("Your living room is ready ✨", id="msg", font=("system", 14), outlet="messageLabel")
    texts = VStack([HStack([app_name, now], id="name-row", spacing=6), msg], id="n-texts", spacing=2)
    thumb = Image(id="thumb", mode="scaleAspectFill", cls="DSImageView", runtime={"cornerRadius": 8},
                  outlet="thumbImageView")
    preview = View(id="preview", cls="DSView", bg="dsChip", runtime={"cornerRadius": 22}, outlet="previewView",
                   children=[HStack([app_icon, texts, thumb], id="preview-row", spacing=10, align="center",
                                    margins=(12, 12, 12, 12))])
    turn_on = primary_button("turn-on", "Turn on notifications", outlet="turnOnButton", action="didTapTurnOn:",
                             icon="bell", title_outlet="turnOnLabel", icon_outlet="bellIconView")
    not_now = Button("Not now", id="not-now", font=("SemiBold", 15), outlet="notNowButton").on("didTapNotNow:")
    col = VStack([title, sub, preview, turn_on, not_now], id="col", spacing=14, align="fill")
    root.add(col)
    pin(col, edges="lr", inset=20)
    C(col, "top", root, "top", 30)
    pin(preview.children[0])
    square(app_icon, 38)
    center(app_icon_img)
    square(app_icon_img, 20)
    square(thumb, 38)
    size(not_now, h=44)
    return d

from xibgen import *
from dslib import *

QUESTIONS = [("paintpalette", "What color goes with a grey sofa?"),
             ("ruler", "How to make a small room feel bigger?"),
             ("lightbulb", "Ideas for a cozy bedroom"),
             ("sofa", "Which rug size for my living room?")]
CARET = "#8FDB1C"
BORDER = "dsDivider"
ERROR = "#E5484D"


def title_block(prefix, avatar_outlet=None):
    """Title · AI designer: clay avatar 30 + name + green dot · Online."""
    avatar = Image(id=f"{prefix}-avatar", image="clay_assistant", mode="scaleAspectFit", outlet=avatar_outlet)
    name = Label("AI designer", id=f"{prefix}-name", font=("SemiBold", 16), outlet="navTitleLabel")
    dot = View(id=f"{prefix}-dot", cls="DSView", bg="#34C759", runtime={"cornerRadius": 3})
    online = Label("Online", id=f"{prefix}-online", font=("Regular", 11), color="dsTextTertiary",
                   outlet="statusLabel")
    status = HStack([dot, online], id=f"{prefix}-status", spacing=4, align="center")
    texts = VStack([name, status], id=f"{prefix}-texts", spacing=0, align="leading")
    row = HStack([avatar, texts], id=f"{prefix}-row", spacing=8, align="center")
    square(avatar, 30)
    square(dot, 6)
    return row


@xib("HomeAI/Redesign/Assistant/AssistantViewController.xib")
def assistant():
    d = Doc("AssistantViewController", owner="AssistantViewController")
    root = d.root
    root.bg = "dsBackground"
    sa = d.safe_area

    table = Table(id="table", outlet="tableView")

    # A1 start: greeting + quick questions
    avatar = Image(id="hero-avatar", image="clay_assistant", mode="scaleAspectFit", outlet="heroAvatarView")
    hi = Label("Hi! I'm your AI designer", id="hi", font=("SemiBold", 26), align="center", lines=0,
               outlet="greetingTitleLabel")
    hi_sub = Label("Send a photo of your room or ask anything about colors, layout and furniture.", id="hi-sub",
                   font=("Regular", 15), color="dsTextSecondary", align="center", lines=0, lineHeight=1.17,
                   outlet="greetingSubtitleLabel")
    greeting = VStack([avatar, hi, hi_sub], id="greeting", spacing=10, align="center")
    try_label = Label("Try asking", id="try", font=("Medium", 13), color="dsTextTertiary", outlet="tryAskingLabel")
    rows = []
    for i, (symbol, text) in enumerate(QUESTIONS):
        ic = Image(id=f"q{i}-icon", system=symbol, size=16, weight="medium", tint="dsLink")
        lb = Label(text, id=f"q{i}-label", font=("Regular", 15), lines=2, collection="questionLabels", tag_value=i)
        arrow = Image(id=f"q{i}-arrow", system="arrow.right", size=13, weight="medium", tint="dsTextTertiary")
        row = HStack([ic, lb, arrow], id=f"q{i}-row", spacing=12, align="center", margins=(0, 14, 0, 16))
        card = Control(id=f"q{i}", cls="DSPressableControl", bg="dsSurface", collection="questionControls",
                       tag_value=i, runtime={"cornerRadius": 18}, children=[row]).on("didTapQuestion:")
        size(card, h=56)
        pin(row)
        square(ic, 20)
        square(arrow, 16)
        rows.append(card)
    questions = VStack([try_label] + rows, id="questions", spacing=10, align="fill")
    start_col = VStack([greeting, questions], id="start-col", spacing=64, align="fill")
    start = Scroll([start_col], id="start", outlet="startScrollView")

    fade = View(id="top-fade", cls="DSGradientView", interaction=False,
                runtime={"startColor": "dsBackground", "midColor": "dsBackground", "midLocation": 0.75,
                         "endColor": "dsBackgroundClear", "angle": 180})

    # nav
    back = glass_button("back", "chevron.left", action="didTapBack:", accessibility="Back")
    history = glass_button("history", "clock.arrow.circlepath", action="didTapHistory:",
                           accessibility="History")
    title = title_block("nav")
    nav = View(id="nav", bg="clear", outlet="navView", children=[back, title, history])

    # attachment preview (56 pt with ✕)
    thumb = Image(id="att-thumb", mode="scaleAspectFill", cls="DSImageView", outlet="attachmentImageView",
                  runtime={"cornerRadius": 14})
    remove = glass_button("att-remove", "xmark", action="didTapRemoveAttachment:", size=22, icon=10, dark=True,
                          accessibility="Remove photo")
    attachment = View(id="attachment", bg="clear", outlet="attachmentView", hidden=True, children=[thumb, remove])

    # composer
    attach_icon = Image(id="attach-icon", system="photo.on.rectangle", size=17, weight="medium", tint="dsTextPrimary")
    attach = Control(id="attach", cls="DSPressableControl", bg="dsChip", runtime={"pill": True},
                     accessibility="Add a photo", children=[attach_icon]).on("didTapAttach:")
    field = TextField(placeholder="Ask about your space…", font=("Regular", 15), id="field", outlet="messageField")
    mic_icon = Image(id="mic-icon", system="mic", size=15, weight="medium", tint="dsTextPrimary", outlet="micIconView")
    mic = Control(id="mic", cls="DSPressableControl", bg="dsCard", runtime={"pill": True}, outlet="micButton",
                  accessibility="Ask by voice", children=[mic_icon]).on("didTapMic:")
    send_icon = Image(id="send-icon", system="arrow.up", size=15, weight="bold", tint="black")
    send = Control(id="send", cls="DSPrimaryButton", outlet="sendButton", hidden=True, accessibility="Send",
                   children=[send_icon]).on("didTapSend:")
    field_box = View(id="field-box", cls="DSView", bg="dsSurface", runtime={"pill": True}, outlet="fieldBox",
                     children=[HStack([field, mic, send], id="field-row", spacing=8, align="center",
                                      margins=(0, 16, 0, 6))])
    composer = HStack([attach, field_box], id="composer", spacing=10, align="center", outlet="composerView")

    root.add(table, start, fade, nav, attachment, composer)

    pin(nav, edges="lr")
    C(nav, "top", sa, "top")
    size(nav, h=56)
    pin(back, edges="l", inset=16)
    center(back, x=False)
    pin(history, edges="r", inset=16)
    center(history, x=False)
    center(title)

    pin(fade, edges="ltr")
    size(fade, h=140)

    pin(table, edges="lr")
    pin(table, edges="t")
    C(table, "bottom", composer, "top", -4)

    pin(start, edges="lr")
    C(start, "top", nav, "bottom")
    C(start, "bottom", composer, "top", -8)
    pin(start_col, to=start.content, edges="lrb", inset=(0, 20, 16, 20))
    C(start_col, "top", start.content, "top", 40)
    equal(start_col, start.frame, "width", const=-40)
    square(avatar, 104)
    C(hi_sub, "width", const=320, rel="lessThanOrEqual")

    pin(composer, edges="lr", inset=20)
    size(composer, h=48)
    C(sa, "bottom", composer, "bottom", 4, outlet="composerBottomConstraint")
    square(attach, 44)
    center(attach_icon)
    square(attach_icon, 20)
    size(field_box, h=48)
    pin(field_box.children[0])
    for b, ic in [(mic, mic_icon), (send, send_icon)]:
        square(b, 36)
        center(ic)
        square(ic, 17)

    pin(attachment, edges="l", inset=20)
    C(composer, "top", attachment, "bottom", 10)
    size(attachment, 64, 64)
    pin(thumb, edges="lb")
    size(thumb, 56, 56)
    pin(remove, edges="tr")
    return d


@xib("HomeAI/Redesign/Assistant/AssistantUserCell.xib")
def assistant_user_cell():
    d = Doc("AssistantUserCell", kind="tableCell", cls="AssistantUserCell", size=(393, 220), reuse="AssistantUserCell")
    photo = Image(id="photo", mode="scaleAspectFill", cls="DSImageView", bg="dsSurface", outlet="photoImageView",
                  runtime={"cornerRadius": 20})
    text = Label("How can I make this living room feel warmer?", id="text", font=("Regular", 15), lines=0,
                 lineHeight=1.15, outlet="messageLabel")
    bubble = View(id="bubble", cls="DSGradientView", outlet="bubbleView",
                  runtime={"startColor": "dsLimeTop", "endColor": "dsLimeBottom", "angle": 180, "cornerRadius": 22},
                  clips=True, children=[text])
    err_icon = Image(id="err-icon", system="exclamationmark.circle.fill", size=13, weight="semibold", tint=ERROR)
    err_label = Label("Couldn't send · Retry", id="err-label", font=("Medium", 13), color=ERROR, outlet="errorLabel")
    error = Control(id="error", cls="DSPressableControl", outlet="errorControl", hidden=True,
                    children=[HStack([err_icon, err_label], id="err-row", spacing=6, align="center")]).on("didTapRetry:")
    col = VStack([photo, bubble, error], id="col", spacing=6, align="trailing")
    content = d.cell(col)
    pin(col, edges="tr", inset=(0, 0, 0, 20))
    C(content, "bottom", col, "bottom", 16)
    C(col, "leading", content, "leading", 60, rel="greaterThanOrEqual")
    size(photo, 190, 136)
    pin(text, inset=(12, 16, 12, 16))
    C(text, "width", const=250, rel="lessThanOrEqual")
    pin(error.children[0])
    square(err_icon, 16)
    return d


@xib("HomeAI/Redesign/Assistant/AssistantReplyCell.xib")
def assistant_reply_cell():
    d = Doc("AssistantReplyCell", kind="tableCell", cls="AssistantReplyCell", size=(393, 420),
            reuse="AssistantReplyCell")
    avatar = Image(id="avatar", image="clay_assistant", mode="scaleAspectFit")
    dots = []
    for i in range(3):
        dot = View(id=f"dot{i}", cls="DSView", bg="dsTextTertiary", collection="typingDots", tag_value=i,
                   runtime={"cornerRadius": 4})
        square(dot, 8)
        dots.append(dot)
    typing = View(id="typing", cls="DSView", bg="dsChip", outlet="typingView", runtime={"cornerRadius": 22},
                  children=[HStack(dots, id="dots", spacing=5, align="center")])
    answer = Label("Three quick wins for this room:", id="answer", font=("Regular", 15), lines=0, outlet="answerLabel")
    caret = View(id="caret", cls="DSView", bg=CARET, outlet="caretView", runtime={"cornerRadius": 2})
    size(caret, 8, 16)
    col = VStack([typing, answer, caret], id="col", spacing=8, align="leading")
    top = HStack([avatar, col], id="top", spacing=8, align="top")
    ideas = Collection(id="ideas", horizontal=True, spacing=12, item=(236, 218), insets=(0, 58, 0, 20),
                       outlet="ideasCollectionView")
    content = d.cell(top, ideas)
    pin(top, edges="lt", inset=(0, 20, 0, 0))
    C(content, "trailing", top, "trailing", 20, rel="greaterThanOrEqual")
    square(avatar, 30)
    pin(typing.children[0], inset=(14, 16, 14, 16))
    pin(ideas, edges="lr")
    below(ideas, top, 16)
    C(ideas, "height", const=218, outlet="ideasHeightConstraint")
    C(content, "bottom", ideas, "bottom", 16)
    return d


@xib("HomeAI/Redesign/Assistant/AssistantIdeaCell.xib")
def assistant_idea_cell():
    d = Doc("AssistantIdeaCell", kind="collectionCell", cls="AssistantIdeaCell", size=(236, 218),
            reuse="AssistantIdeaCell")
    preview = Image(id="preview", mode="scaleAspectFill", bg="dsSurface", outlet="previewImageView")
    title = Label("Warm wood + linen", id="title", font=("SemiBold", 15), outlet="titleLabel", minScale=0.8)
    sub = Label("Japandi · keeps your layout", id="sub", font=("Regular", 12), color="dsTextTertiary",
                outlet="subtitleLabel", minScale=0.8)
    texts = VStack([title, sub], id="texts", spacing=2, align="fill")
    icon = Image(id="apply-icon", system="sparkles", size=15, weight="semibold", tint="black")
    label = Label("Apply to my photo", id="apply-label", font=("SemiBold", 14), color="black", outlet="applyTitleLabel")
    apply_row = HStack([icon, label], id="apply-row", spacing=8, align="center")
    apply = Control(id="apply", cls="DSPrimaryButton", children=[apply_row]).on("didTapApply:")
    card = View(id="card", cls="DSView", bg="dsCard", clips=True,
                runtime={"cornerRadius": 22, "borderWidth": 1, "borderColor": BORDER},
                children=[preview, texts, apply])
    d.cell(card)
    pin(card)
    pin(preview, edges="ltr")
    size(preview, h=112)
    below(texts, preview, 10)
    pin(texts, edges="lr", inset=12)
    below(apply, texts, 10)
    pin(apply, edges="lr", inset=12)
    size(apply, h=40)
    center(apply_row)
    square(icon, 18)
    return d


@xib("HomeAI/Redesign/Assistant/AssistantAttachSheetViewController.xib")
def assistant_attach_sheet():
    d = Doc("AssistantAttachSheetViewController", owner="AssistantAttachSheetViewController", size=(393, 380))
    root = d.root
    root.bg = "dsBackground"
    close = glass_button("close", "xmark", action="didTapClose:", size=36, icon=16, accessibility="Close")
    title = Label("Add a photo", id="title", font=("SemiBold", 24), align="center", outlet="titleLabel")
    sub = Label("Show me the room you want to change", id="sub", font=("Regular", 15), color="dsTextSecondary",
                align="center", lines=0, outlet="subtitleLabel")
    items = []
    options = [("camera", "Take a photo", None), ("photo.on.rectangle", "Choose from library", None),
               ("folder", "From my projects", "Use a room you already redesigned")]
    for i, (symbol, text, hint) in enumerate(options):
        ic = Image(id=f"opt{i}-icon", system=symbol, size=15, weight="medium", tint="dsTextPrimary")
        box = View(id=f"opt{i}-box", cls="DSView", bg="dsCard", runtime={"cornerRadius": 9}, children=[ic])
        lb = Label(text, id=f"opt{i}-label", font=("Medium", 16), collection="optionLabels", tag_value=i)
        parts = [lb]
        if hint:
            parts.append(Label(hint, id=f"opt{i}-hint", font=("Regular", 13), color="dsTextTertiary",
                               outlet="projectsHintLabel"))
        texts = VStack(parts, id=f"opt{i}-texts", spacing=2, align="fill")
        chev = Image(id=f"opt{i}-chev", system="chevron.right", size=13, weight="semibold", tint="dsTextTertiary")
        row = HStack([box, texts, chev], id=f"opt{i}-row", spacing=14, align="center", margins=(0, 16, 0, 16))
        ctl = Control(id=f"opt{i}", cls="DSPressableControl", bg="clear", collection="optionRows", tag_value=i,
                      runtime={"pressedScale": 0.98}, children=[row]).on("didTapOption:")
        size(ctl, h=56)
        pin(row)
        square(box, 32)
        center(ic)
        square(ic, 18)
        square(chev, 18)
        items.append(ctl)
        if i < len(options) - 1:
            div = View(id=f"div{i}", bg=BORDER)
            size(div, h=1)
            items.append(div)
    group = View(id="group", cls="DSView", bg="dsSurface", runtime={"cornerRadius": 18}, clips=True,
                 children=[VStack(items, id="group-stack", align="fill")])
    col = VStack([title, sub, group], id="col", spacing=14, align="fill")
    root.add(col, close)
    pin(col, edges="lr", inset=20)
    C(col, "top", root, "top", 28)
    pin(group.children[0])
    pin(close, edges="tr", inset=16)
    return d


@xib("HomeAI/Redesign/Assistant/AssistantHistoryViewController.xib")
def assistant_history():
    d = Doc("AssistantHistoryViewController", owner="AssistantHistoryViewController", size=(393, 640))
    root = d.root
    root.bg = "dsBackground"
    title = Label("History", id="title", font=("SemiBold", 24), outlet="titleLabel")
    new_chat = secondary_button("new", "New chat", action="didTapNewChat:", height=36, bg="dsLimeSoft", icon="plus",
                                font=("SemiBold", 14))
    header = HStack([title, View(id="spacer", bg="clear", hug=(1, 250)), new_chat], id="header", align="center")
    table = Table(id="table", outlet="tableView")
    empty = Label("No conversations yet", id="empty", font=("Regular", 15), color="dsTextTertiary", align="center",
                  outlet="emptyLabel", hidden=True)
    root.add(header, table, empty)
    pin(header, edges="lr", inset=20)
    C(header, "top", root, "top", 28)
    C(new_chat.children[0], "leading", new_chat, "leading", 14, rel="greaterThanOrEqual")
    pin(table, edges="lrb")
    below(table, header, 12)
    center(empty)
    return d


@xib("HomeAI/Redesign/Assistant/AssistantHistoryCell.xib")
def assistant_history_cell():
    d = Doc("AssistantHistoryCell", kind="tableCell", cls="AssistantHistoryCell", size=(393, 76),
            reuse="AssistantHistoryCell")
    thumb = Image(id="thumb", mode="scaleAspectFill", cls="DSImageView", bg="dsCard", outlet="thumbImageView",
                  runtime={"cornerRadius": 10})
    title = Label("How can I make this room warmer?", id="title", font=("Medium", 15), outlet="titleLabel")
    sub = Label("Today", id="sub", font=("Regular", 13), color="dsTextTertiary", outlet="subtitleLabel")
    texts = VStack([title, sub], id="texts", spacing=2, align="fill")
    chev = Image(id="chev", system="chevron.right", size=13, weight="semibold", tint="dsTextTertiary")
    row = HStack([thumb, texts, chev], id="row", spacing=12, align="center", margins=(0, 12, 0, 14))
    box = View(id="box", cls="DSView", bg="dsSurface", runtime={"cornerRadius": 18}, children=[row])
    content = d.cell(box)
    pin(box, inset=(4, 20, 4, 20))
    pin(row)
    square(thumb, 44)
    square(chev, 16)
    size(box, h=64)
    return d


@xib("HomeAI/Redesign/Assistant/AssistantProjectPickerViewController.xib")
def assistant_project_picker():
    d = Doc("AssistantProjectPickerViewController", owner="AssistantProjectPickerViewController", size=(393, 700))
    root = d.root
    root.bg = "dsBackground"
    title = Label("From my projects", id="title", font=("SemiBold", 24), align="center", outlet="titleLabel")
    close = glass_button("close", "xmark", action="didTapClose:", size=36, icon=16, accessibility="Close")
    cv = Collection(id="cv", spacing=13, item=(170, 214), insets=(8, 20, 24, 20), outlet="collectionView")
    empty = Label("No projects yet", id="empty", font=("Regular", 15), color="dsTextTertiary", align="center",
                  outlet="emptyLabel", hidden=True)
    root.add(title, cv, close, empty)
    pin(title, edges="lr", inset=60)
    C(title, "top", root, "top", 28)
    pin(close, edges="tr", inset=16)
    pin(cv, edges="lrb")
    below(cv, title, 12)
    center(empty)
    return d

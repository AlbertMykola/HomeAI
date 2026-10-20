from xibgen import *
from dslib import *


@xib("HomeAI/Redesign/States/DSAlertViewController.xib")
def ds_alert():
    """A/12 Generic error / Discard edits: dim + card (r28), title, message, two pill buttons."""
    d = Doc("DSAlertViewController", owner="DSAlertViewController")
    root = d.root
    root.bg = "clear"
    dim = View(id="dim", bg=("#000000", 0.3), outlet="dimView")
    title = Label("Something went wrong", id="title", font=("SemiBold", 17), align="center", lines=0,
                  outlet="titleLabel")
    message = Label("We couldn't load this. Check your connection and try again.", id="message",
                    font=("Regular", 15), color="dsTextSecondary", align="center", lines=0, lineHeight=1.12,
                    outlet="messageLabel")
    texts = VStack([title, message], id="texts", spacing=6, align="fill")
    buttons = []
    for i in range(2):
        lb = Label("Cancel", id=f"btn{i}-label", font=("SemiBold", 16), align="center", collection="buttonLabels",
                   tag_value=i, lines=0, resist=(750, 1000))
        b = Control(id=f"btn{i}", cls="DSPressableControl", bg="dsChip", collection="buttons", tag_value=i,
                    runtime={"pill": True}, children=[lb]).on("didTapButton:")
        C(b, "height", const=48, rel="greaterThanOrEqual")
        center(lb)
        C(lb, "top", b, "top", 8, rel="greaterThanOrEqual")
        C(lb, "leading", b, "leading", 10, rel="greaterThanOrEqual")
        buttons.append(b)
    row = HStack(buttons, id="buttons", spacing=10, dist="fillEqually")
    col = VStack([texts, row], id="col", spacing=18, align="fill")
    card = View(id="card", cls="DSView", bg="dsBackground", outlet="cardView",
                runtime={"cornerRadius": 28, "shadowOpacity": 0.18, "shadowRadius": 24, "shadowOffsetY": 10},
                children=[col])
    root.add(dim, card)
    pin(dim)
    center(card)
    pin(card, edges="lr", inset=46)
    pin(col, inset=(22, 18, 18, 18))
    return d


@xib("HomeAI/Redesign/States/StateScreenViewController.xib")
def state_screen():
    """A/12 full-screen states: Content blocked · Offline · Camera access off · Force update."""
    d = Doc("StateScreenViewController", owner="StateScreenViewController")
    root = d.root
    root.bg = "dsBackground"
    sa = d.safe_area

    back = glass_button("back", "chevron.left", outlet="backButton", action="didTapBack:", accessibility="Back")

    photo = Image(id="photo", mode="scaleAspectFill", cls="DSImageView", bg="dsSurface", outlet="photoImageView",
                  runtime={"cornerRadius": 28})
    tint = View(id="tint", cls="DSView", bg=("#FFFFFF", 0.55), interaction=False, runtime={"cornerRadius": 28})
    photo_wrap = View(id="photo-wrap", bg="clear", outlet="photoContainer", hidden=True, children=[photo, tint])

    icon = Image(id="icon", system="wifi.slash", size=30, weight="medium", tint="dsTextPrimary", outlet="iconImageView")
    icon_box = View(id="icon-box", cls="DSView", bg="dsSurface", outlet="iconBoxView", runtime={"pill": True},
                    children=[icon])
    icon_wrap = View(id="icon-wrap", bg="clear", children=[icon_box])

    title = Label("You're offline", id="title", font=("SemiBold", 26), align="center", lines=0, kern=-0.13,
                  outlet="titleLabel")
    body = Label("Designs are created in the cloud.", id="body", font=("Regular", 15), color="dsTextSecondary",
                 align="center", lines=0, lineHeight=1.2, outlet="bodyLabel")
    caption = Label("Your projects are saved on this iPhone.", id="caption", font=("Regular", 12),
                    color="dsTextTertiary", align="center", lines=0, outlet="captionLabel")

    news_title = Label("What's new", id="news-title", font=("SemiBold", 14), outlet="newsTitleLabel")
    news_body = Label("• Paint with real colors", id="news-body", font=("Regular", 14), color="dsTextSecondary",
                      lines=0, lineHeight=1.2, outlet="newsBodyLabel")
    news = View(id="news", cls="DSView", bg="dsSurface", runtime={"cornerRadius": 20}, outlet="newsCardView",
                hidden=True, children=[VStack([news_title, news_body], id="news-col", spacing=6, align="fill")])

    news_wrap = View(id="news-wrap", bg="clear", children=[news])
    content = VStack([icon_wrap, title, body, caption, news_wrap], id="content", spacing=10, align="fill",
                     outlet="contentStack")

    primary = primary_button("primary", "Try again", outlet="primaryButton", action="didTapPrimary:",
                             icon="arrow.clockwise", title_outlet="primaryLabel", icon_outlet="primaryIconView")
    spinner = Spinner(id="primary-spin", style="medium", outlet="primarySpinner", animating=False, hidden=True)
    primary.add(spinner)
    secondary_label = Label("Content rules", id="secondary-label", font=("SemiBold", 15), align="center",
                            outlet="secondaryLabel")
    secondary = Control(id="secondary", cls="DSPressableControl", bg="clear", outlet="secondaryButton",
                        runtime={"pill": True}, children=[secondary_label]).on("didTapSecondary:")
    size(secondary, h=48)
    center(secondary_label)
    actions = VStack([primary, secondary], id="actions", spacing=10, align="fill", outlet="actionsStack")

    root.add(photo_wrap, content, actions, back)

    pin(back, edges="l", inset=16)
    C(back, "top", sa, "top", 6)

    pin(photo_wrap, edges="lr")
    C(photo_wrap, "top", sa, "top", 86)
    size(photo_wrap, h=250)
    pin(photo, to=photo_wrap, edges="tb")
    center(photo, to=photo_wrap, y=False)
    size(photo, w=200)
    pin(tint, to=photo)

    center(content, y=False)
    pin(content, edges="lr", inset=20)
    C(content, "centerY", root, "centerY", -60, prio=250, id="content-center")
    C(content, "top", photo_wrap, "bottom", -32, outlet="contentBelowPhotoConstraint", prio=999)
    pin(icon_box, to=icon_wrap, edges="tb")
    center(icon_box, to=icon_wrap, y=False)
    C(icon_box, "width", const=120, outlet="iconSizeConstraint")
    C(icon_box, "height", icon_box, "width")
    center(icon)
    square(icon, 40)
    pin(news.children[0], inset=(14, 16, 14, 16))
    pin(news, to=news_wrap, edges="tb", inset=(6, 0, 0, 0))
    center(news, to=news_wrap, y=False)
    C(news, "width", const=313, prio=750)
    C(news, "leading", news_wrap, "leading", 0, rel="greaterThanOrEqual")

    pin(actions, edges="lr", inset=20)
    C(sa, "bottom", actions, "bottom", 4)
    center(spinner)
    return d

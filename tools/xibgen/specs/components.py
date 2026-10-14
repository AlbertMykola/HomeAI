from xibgen import *

TABS = [("create", "Create", "plus.square"), ("inspiration", "Inspiration", "square.grid.2x2"),
        ("projects", "Projects", "folder"), ("profile", "Profile", "person")]


@xib("HomeAI/Redesign/Components/DSTabBarView.xib")
def tab_bar():
    d = Doc("DSTabBarView", owner="DSTabBarView", size=(361, 64))
    root = d.root
    root.bg = "clear"
    card = View(id="card", cls="DSView", bg="clear", outlet="cardView",
                runtime={"cornerRadius": 32, "shadowOpacity": 0.1, "shadowRadius": 15, "shadowOffsetY": 8})
    blur = Blur(id="blur", style="systemUltraThinMaterialLight",
                runtime={"layer.cornerRadius": 32})
    tint = View(id="tint", cls="DSView", bg="dsTabBar",
                runtime={"cornerRadius": 32, "borderWidth": 0.5, "borderColor": "dsGlassBorder"})
    items = []
    for index, (key, title, symbol) in enumerate(TABS):
        hl = View(id=f"{key}-hl", cls="DSView", bg="dsLimeTint", collection="highlightViews", tag_value=index,
                  runtime={"cornerRadius": 27}, alpha=0)
        icon = Image(id=f"{key}-icon", system=symbol, size=20, weight="medium", tint="dsTextSecondary",
                     collection="iconViews", tag_value=index)
        label = Label(title, id=f"{key}-label", font=("Medium", 10), color="dsTextSecondary",
                      align="center", collection="titleLabels", tag_value=index)
        col = VStack([icon, label], id=f"{key}-stack", spacing=2, align="center")
        item = Control(id=f"{key}-item", cls="DSPressableControl", children=[hl, col], collection="itemControls",
                       tag_value=len(items), runtime={"hapticOnPress": False, "pressedScale": 0.94},
                       accessibility=title).on("didTapItem:")
        items.append(item)
    row = HStack(items, id="row", dist="fillEqually", spacing=0)
    card.add(blur, tint, row)
    root.add(card)
    pin(card)
    pin(blur)
    pin(tint)
    pin(row, inset=(5, 5, 5, 5))
    for item in items:
        hl = item.children[0]
        col = item.children[1]
        pin(hl)
        center(col)
        square(col.children[0], 24)
    return d


@xib("HomeAI/Redesign/Components/DSToastView.xib")
def toast():
    """A/12 Toasts & banners: dark glass 48 pt, radius 24 (light variant on photo screens is set in code)."""
    d = Doc("DSToastView", owner="DSToastView", size=(353, 48))
    root = d.root
    root.bg = "clear"
    icon = Image(id="icon", system="checkmark.circle", size=16, weight="semibold", tint="dsLime",
                 outlet="iconView")
    label = Label("Saved to Photos", id="label", font=("Medium", 15), color="white", lines=2, outlet="messageLabel")
    action = Label("Open", id="action", font=("SemiBold", 15), color="dsLime", outlet="actionLabel", hidden=True,
                   hug=(751, 251), resist=(751, 750))
    row = HStack([icon, label, action], id="row", spacing=10, align="center", margins=(12, 18, 12, 20))
    card = View(id="card", cls="DSView", bg=("#232325", 0.96), outlet="cardView", children=[row],
                runtime={"cornerRadius": 24, "shadowOpacity": 0.22, "shadowRadius": 16, "shadowOffsetY": 8})
    root.add(card)
    pin(card, edges="tb")
    center(card, y=False)
    C(card, "leading", root, "leading", 0, rel="greaterThanOrEqual")
    pin(row)
    square(icon, 20)
    C(card, "height", const=48, rel="greaterThanOrEqual")
    return d

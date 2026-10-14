"""
xibgen — tiny Python DSL that writes Interface Builder .xib files.

Used to scaffold the redesign screens: every screen's layout lives in a real
.xib (editable in Interface Builder afterwards); this script only saves us from
typing the XML by hand. Specs live in tools/xibgen/specs/*.py.

    python3 tools/xibgen/build.py            # regenerate every spec
    python3 tools/xibgen/build.py home       # regenerate specs/home.py only
"""
import itertools
import os
import re
from xml.sax.saxutils import quoteattr, escape

_ids = itertools.count(1)

# ---------------------------------------------------------------------------
# Fonts / colors
# ---------------------------------------------------------------------------

GEOLOGICA = {"Thin", "ExtraLight", "Light", "Regular", "Medium", "SemiBold", "Bold", "ExtraBold", "Black"}

# Mirrors HomeAI/Assets.xcassets/RedesignColors — values only matter for the IB canvas.
NAMED_COLORS = {}


def register_colors(path):
    import json
    for d in os.listdir(path):
        if not d.endswith(".colorset"):
            continue
        c = json.load(open(os.path.join(path, d, "Contents.json")))["colors"][0]["color"]["components"]

        def comp(v):
            v = str(v)
            return int(v, 16) / 255 if v.startswith("0x") else (float(v) / 255 if float(v) > 1 else float(v))
        NAMED_COLORS[d[:-9]] = (comp(c["red"]), comp(c["green"]), comp(c["blue"]), float(c["alpha"]))


def color_xml(key, value):
    """value: 'name' (asset), '#RRGGBB', '#RRGGBBAA', ('#RRGGBB', alpha), 'clear', 'white', 'black'."""
    if value is None:
        return ""
    if isinstance(value, tuple):
        hex_, alpha = value
    elif value == "clear":
        return f'<color key="{key}" white="0.0" alpha="0.0" colorSpace="custom" customColorSpace="genericGamma22GrayColorSpace"/>'
    elif value == "white":
        return f'<color key="{key}" white="1" alpha="1" colorSpace="custom" customColorSpace="genericGamma22GrayColorSpace"/>'
    elif value == "black":
        return f'<color key="{key}" white="0.0" alpha="1" colorSpace="custom" customColorSpace="genericGamma22GrayColorSpace"/>'
    elif value.startswith("#"):
        hex_, alpha = value, 1.0
        if len(value) == 9:
            hex_, alpha = value[:7], int(value[7:9], 16) / 255
    else:
        Doc.current.named_colors.add(value)
        return f'<color key="{key}" name="{value}"/>'
    h = hex_.lstrip("#")
    r, g, b = (int(h[i:i + 2], 16) / 255 for i in (0, 2, 4))
    return (f'<color key="{key}" red="{r:.4f}" green="{g:.4f}" blue="{b:.4f}" alpha="{alpha:.3f}" '
            f'colorSpace="custom" customColorSpace="sRGB"/>')


def _runtime_attr(key, value):
    if isinstance(value, bool):
        return f'<userDefinedRuntimeAttribute type="boolean" keyPath="{key}" value="{"YES" if value else "NO"}"/>'
    if isinstance(value, (int, float)):
        return (f'<userDefinedRuntimeAttribute type="number" keyPath="{key}">'
                f'<real key="value" value="{value}"/></userDefinedRuntimeAttribute>')
    if isinstance(value, str) and value.startswith("str:"):
        return f'<userDefinedRuntimeAttribute type="string" keyPath="{key}" value={quoteattr(value[4:])}/>'
    if isinstance(value, tuple) and len(value) == 2 and value[0] == "size":
        w, h = value[1]
        return (f'<userDefinedRuntimeAttribute type="size" keyPath="{key}">'
                f'<size key="value" width="{w}" height="{h}"/></userDefinedRuntimeAttribute>')
    if isinstance(value, tuple) and len(value) == 2 and value[0] == "point":
        x, y = value[1]
        return (f'<userDefinedRuntimeAttribute type="point" keyPath="{key}">'
                f'<point key="value" x="{x}" y="{y}"/></userDefinedRuntimeAttribute>')
    # colors
    return f'<userDefinedRuntimeAttribute type="color" keyPath="{key}">{color_xml("value", value)}</userDefinedRuntimeAttribute>'


# ---------------------------------------------------------------------------
# Elements
# ---------------------------------------------------------------------------

class Guide:
    def __init__(self, owner, key):
        self.owner = owner
        self.key = key
        self.id = f"{owner.id}-{key}"


class El:
    tag = "view"

    def __init__(self, id=None, children=(), cls=None, bg=None, outlet=None, collection=None, label=None,
                 hidden=False, alpha=None, clips=None, interaction=None, mode=None, tint=None,
                 hug=None, resist=None, attrs=None, runtime=None, tag_value=None, accessibility=None, **props):
        self.id = id or f"g{next(_ids)}"
        self.children = list(children)
        self.parent = None
        for c in self.children:
            c.parent = self
        self.cls = cls
        self.bg = bg
        self.outlet = outlet
        self.collection = collection
        self.label = label or (outlet if outlet else None)
        self.hidden = hidden
        self.alpha = alpha
        self.clips = clips
        self.interaction = interaction
        self.mode = mode
        self.tint = tint
        self.hug = hug          # (h, v)
        self.resist = resist    # (h, v)
        self.attrs = dict(attrs or {})
        self.runtime = dict(runtime or {})
        self.runtime.update(props)
        self.tag_value = tag_value
        self.accessibility = accessibility
        self.actions = []
        self.extra_xml = []
        self.constraints_here = []

    # layout helpers -------------------------------------------------------
    def add(self, *children):
        for c in children:
            c.parent = self
            self.children.append(c)
        return self

    def on(self, selector, event="touchUpInside"):
        self.actions.append((selector, event))
        return self

    def guide(self, key):
        return Guide(self, key)

    # xml ----------------------------------------------------------------
    def base_attrs(self):
        a = {}
        a["contentMode"] = self.mode or "scaleToFill"
        if self.hug:
            a["horizontalHuggingPriority"] = str(self.hug[0])
            a["verticalHuggingPriority"] = str(self.hug[1])
        if self.resist:
            a["horizontalCompressionResistancePriority"] = str(self.resist[0])
            a["verticalCompressionResistancePriority"] = str(self.resist[1])
        if self.hidden:
            a["hidden"] = "YES"
        if self.alpha is not None:
            a["alpha"] = str(self.alpha)
        if self.clips is not None:
            a["clipsSubviews"] = "YES" if self.clips else "NO"
        if self.interaction is not None:
            a["userInteractionEnabled"] = "YES" if self.interaction else "NO"
        if self.tag_value is not None:
            a["tag"] = str(self.tag_value)
        if self.parent is not None and not getattr(self, "managed", False):
            a["translatesAutoresizingMaskIntoConstraints"] = "NO"
        a["id"] = self.id
        if self.cls:
            a["customClass"] = self.cls
            a["customModule"] = "HomeAI"
            a["customModuleProvider"] = "target"
        if self.label:
            a["userLabel"] = self.label
        a.update(self.attrs)
        return a

    def inner_xml(self):
        return ""

    def subviews_key(self):
        return "subviews"

    def to_xml(self, indent, key=None):
        a = self.base_attrs()
        if key:
            a = {"key": key, **a}
        pad = " " * indent
        out = [pad + f"<{self.tag} " + " ".join(f"{k}={quoteattr(v)}" for k, v in a.items()) + ">"]
        if self.parent is None and self.tag not in ("collectionViewCell", "tableViewCell"):
            out.append(pad + '    <autoresizingMask key="autoresizingMask" widthSizable="YES" heightSizable="YES"/>')
        out += self.children_xml(indent)
        inner = self.inner_xml()
        if inner:
            out.append(pad + "    " + inner)
        if self.bg is not None:
            out.append(pad + "    " + color_xml("backgroundColor", self.bg))
        if self.tint is not None:
            out.append(pad + "    " + color_xml("tintColor", self.tint))
        for x in self.extra_xml:
            out.append(pad + "    " + x)
        if self.constraints_here:
            out.append(pad + "    <constraints>")
            for c in self.constraints_here:
                out.append(pad + "        " + c.to_xml(self))
            out.append(pad + "    </constraints>")
        if self.accessibility:
            out.append(pad + f'    <accessibility key="accessibilityConfiguration" label={quoteattr(self.accessibility)}/>')
        if self.runtime:
            out.append(pad + "    <userDefinedRuntimeAttributes>")
            for k, v in self.runtime.items():
                out.append(pad + "        " + _runtime_attr(k, v))
            out.append(pad + "    </userDefinedRuntimeAttributes>")
        conns = self.connections_xml()
        if conns:
            out.append(pad + "    <connections>")
            out += [pad + "        " + c for c in conns]
            out.append(pad + "    </connections>")
        out.append(pad + f"</{self.tag}>")
        return out

    def children_xml(self, indent):
        if not self.children:
            return []
        pad = " " * indent
        out = [pad + f"    <{self.subviews_key()}>"]
        for c in self.children:
            out += c.to_xml(indent + 8)
        out.append(pad + f"    </{self.subviews_key()}>")
        return out

    def connections_xml(self):
        res = []
        for sel, ev in self.actions:
            res.append(f'<action selector="{sel}" destination="-1" eventType="{ev}" id="{self.id}-a{len(res)}"/>')
        return res

    def walk(self):
        yield self
        for c in self.children:
            yield from c.walk()


class View(El):
    tag = "view"


class Control(El):
    """A DSPressableControl laid out as a plain <view>.

    ibtool (Xcode 27) crashes compiling a <control>/<button> that has subviews when the deployment target
    is below iOS 17, so tappable cards are declared as views with a UIControl subclass and their action is
    the `actionName` runtime attribute (sent through the responder chain, like a First Responder action)."""
    tag = "view"

    def on(self, selector, event="touchUpInside"):
        assert event == "touchUpInside"
        self.runtime["actionName"] = "str:" + selector
        return self


class Label(El):
    tag = "label"

    def __init__(self, text="", font=("Regular", 15), color="dsTextPrimary", align="natural", lines=1,
                 minScale=None, kern=None, lineHeight=None, **kw):
        kw.setdefault("interaction", False)
        if kern is not None:
            kw.setdefault("cls", "DSLabel")
            kw.setdefault("runtime", {})["letterSpacing"] = kern
        if lineHeight is not None:
            kw.setdefault("cls", "DSLabel")
            kw.setdefault("runtime", {})["lineHeightMultiple"] = lineHeight
        super().__init__(**kw)
        self.text, self.font, self.color, self.align, self.lines, self.minScale = text, font, color, align, lines, minScale

    def base_attrs(self):
        a = super().base_attrs()
        a.update({"opaque": "NO", "text": self.text, "textAlignment": self.align,
                  "lineBreakMode": "tailTruncation" if self.lines == 1 else "wordWrap",
                  "numberOfLines": str(self.lines), "baselineAdjustment": "alignBaselines"})
        if self.minScale:
            a["adjustsFontSizeToFit"] = "YES"
            a["minimumScaleFactor"] = str(self.minScale)
        else:
            a["adjustsFontSizeToFit"] = "NO"
        if not self.hug:
            a.setdefault("horizontalHuggingPriority", "251")
            a.setdefault("verticalHuggingPriority", "251")
        return a

    def inner_xml(self):
        return font_xml(self.font) + color_xml("textColor", self.color) + \
            ('<nil key="highlightedColor"/>')


def font_xml(font, key="fontDescription"):
    if font[0] == "system":
        weight = font[2] if len(font) > 2 else "regular"
        return f'<fontDescription key="{key}" type="system" weight="{weight}" pointSize="{font[1]}"/>'
    weight, size = font
    assert weight in GEOLOGICA, weight
    Doc.current.fonts.add(weight)
    return f'<fontDescription key="{key}" name="Geologica-{weight}" family="Geologica" pointSize="{size}"/>'


class Image(El):
    tag = "imageView"

    def __init__(self, image=None, system=None, size=None, weight=None, scale=None, **kw):
        kw.setdefault("interaction", False)
        kw.setdefault("clips", True)
        kw.setdefault("mode", "scaleAspectFit")
        super().__init__(**kw)
        self.image, self.system, self.size, self.weight, self.scale = image, system, size, weight, scale

    def base_attrs(self):
        a = super().base_attrs()
        if self.image:
            a["image"] = self.image
            Doc.current.images.add(self.image)
        if self.system:
            a["image"] = self.system
            a["catalog"] = "system"
            Doc.current.symbols.add(self.system)
        if not self.hug:
            a.setdefault("horizontalHuggingPriority", "251")
            a.setdefault("verticalHuggingPriority", "251")
        return a

    def inner_xml(self):
        if self.system and self.size:
            w = f' weight="{self.weight}"' if self.weight else ""
            s = f' scale="{self.scale}"' if self.scale else ""
            return (f'<preferredSymbolConfiguration key="preferredSymbolConfiguration" configurationType="pointSize" '
                    f'pointSize="{self.size}"{s}{w}/>')
        return ""


class Button(El):
    """Plain UIButton (custom type). Prefer Control + children for designed buttons."""
    tag = "button"

    def __init__(self, title="", font=("SemiBold", 15), color="dsTextPrimary", image=None, system=None,
                 symbolSize=None, weight=None, **kw):
        super().__init__(**kw)
        self.title, self.font, self.color, self.image, self.system = title, font, color, image, system
        self.symbolSize, self.weight = symbolSize, weight

    def base_attrs(self):
        a = super().base_attrs()
        a.update({"opaque": "NO", "contentHorizontalAlignment": "center", "contentVerticalAlignment": "center",
                  "buttonType": "system", "lineBreakMode": "middleTruncation"})
        return a

    def inner_xml(self):
        x = font_xml(self.font, "fontDescription")
        x += '<inset key="imageEdgeInsets" minX="0.0" minY="0.0" maxX="2.2250738585072014e-308" maxY="0.0"/>'
        img = ""
        if self.image:
            Doc.current.images.add(self.image)
            img = f' image="{self.image}"'
        if self.system:
            Doc.current.symbols.add(self.system)
            img = f' image="{self.system}" catalog="system"'
        title = f" title={quoteattr(self.title)}" if self.title else ""
        x += f'<state key="normal"{title}{img}>{color_xml("titleColor", self.color)}'
        if self.system and self.symbolSize:
            w = f' weight="{self.weight}"' if self.weight else ""
            x += (f'<preferredSymbolConfiguration key="preferredSymbolConfiguration" configurationType="pointSize" '
                  f'pointSize="{self.symbolSize}"{w}/>')
        x += "</state>"
        return x


class Stack(El):
    tag = "stackView"

    def __init__(self, children=(), axis="horizontal", spacing=0, align="fill", dist="fill", margins=None, **kw):
        super().__init__(children=children, **kw)
        self.axis, self.spacing, self.align, self.dist, self.margins = axis, spacing, align, dist, margins

    def base_attrs(self):
        a = super().base_attrs()
        a["opaque"] = "NO"
        if self.axis == "vertical":
            a["axis"] = "vertical"
        if self.align != "fill":
            a["alignment"] = self.align
        if self.dist != "fill":
            a["distribution"] = self.dist
        a["spacing"] = str(self.spacing)
        if self.margins:
            a["layoutMarginsFollowReadableWidth"] = "NO"
            a["layoutMarginsRelativeArrangement"] = "YES"
        return a

    def subviews_key(self):
        return "subviews"

    def inner_xml(self):
        if self.margins:
            t, l, b, r = self.margins
            return f'<edgeInsets key="layoutMargins" top="{t}" left="{l}" bottom="{b}" right="{r}"/>'
        return ""


def HStack(children=(), **kw):
    return Stack(children, axis="horizontal", **kw)


def VStack(children=(), **kw):
    return Stack(children, axis="vertical", **kw)


class Scroll(El):
    tag = "scrollView"

    def __init__(self, children=(), horizontal=False, indicators=False, bounce=True, paging=False, **kw):
        kw.setdefault("clips", True)
        super().__init__(children=children, **kw)
        self.horizontal, self.indicators, self.bounce, self.paging = horizontal, indicators, bounce, paging
        self.content = Guide(self, "contentLayoutGuide")
        self.frame = Guide(self, "frameLayoutGuide")

    def base_attrs(self):
        a = super().base_attrs()
        a["showsHorizontalScrollIndicator"] = "NO"
        a["showsVerticalScrollIndicator"] = "YES" if self.indicators else "NO"
        if not self.bounce:
            a["bounces"] = "NO"
        if self.horizontal:
            a["alwaysBounceHorizontal"] = "YES"
        else:
            a["alwaysBounceVertical"] = "YES"
        if self.paging:
            a["pagingEnabled"] = "YES"
        return a

    def inner_xml(self):
        return (f'<viewLayoutGuide key="contentLayoutGuide" id="{self.content.id}"/>'
                f'<viewLayoutGuide key="frameLayoutGuide" id="{self.frame.id}"/>')


class Collection(El):
    tag = "collectionView"

    def __init__(self, horizontal=False, spacing=10, item=(50, 50), insets=(0, 0, 0, 0), indicators=False, **kw):
        kw.setdefault("clips", True)
        kw.setdefault("bg", "clear")
        super().__init__(**kw)
        self.horizontal, self.spacing, self.item, self.insets, self.indicators = horizontal, spacing, item, insets, indicators

    def base_attrs(self):
        a = super().base_attrs()
        a.update({"multipleTouchEnabled": "YES", "showsHorizontalScrollIndicator": "NO",
                  "showsVerticalScrollIndicator": "YES" if self.indicators else "NO",
                  "dataMode": "none"})
        return a

    def inner_xml(self):
        t, l, b, r = self.insets
        return (f'<collectionViewFlowLayout key="collectionViewLayout" '
                f'{"scrollDirection=" + chr(34) + "horizontal" + chr(34) + " " if self.horizontal else ""}'
                f'minimumLineSpacing="{self.spacing}" minimumInteritemSpacing="{self.spacing}" id="{self.id}-layout">'
                f'<size key="itemSize" width="{self.item[0]}" height="{self.item[1]}"/>'
                f'<size key="headerReferenceSize" width="0.0" height="0.0"/>'
                f'<size key="footerReferenceSize" width="0.0" height="0.0"/>'
                f'<inset key="sectionInset" minX="{l}" minY="{t}" maxX="{r}" maxY="{b}"/>'
                f'</collectionViewFlowLayout>')


class Table(El):
    tag = "tableView"

    def __init__(self, style="plain", separator="none", **kw):
        kw.setdefault("clips", True)
        kw.setdefault("bg", "clear")
        super().__init__(**kw)
        self.style, self.separator = style, separator

    def base_attrs(self):
        a = super().base_attrs()
        a.update({"alwaysBounceVertical": "YES", "style": self.style, "separatorStyle": self.separator,
                  "rowHeight": "-1", "estimatedRowHeight": "-1", "sectionHeaderHeight": "-1",
                  "estimatedSectionHeaderHeight": "-1", "sectionFooterHeight": "-1",
                  "estimatedSectionFooterHeight": "-1", "showsVerticalScrollIndicator": "NO"})
        return a


class TextField(El):
    tag = "textField"

    def __init__(self, placeholder="", font=("Regular", 16), color="dsTextPrimary", **kw):
        super().__init__(**kw)
        self.placeholder, self.font, self.color = placeholder, font, color

    def base_attrs(self):
        a = super().base_attrs()
        a.update({"opaque": "NO", "contentHorizontalAlignment": "left", "contentVerticalAlignment": "center",
                  "placeholder": self.placeholder, "minimumFontSize": "12"})
        return a

    def inner_xml(self):
        return color_xml("textColor", self.color) + font_xml(self.font) + \
            '<textInputTraits key="textInputTraits" autocapitalizationType="sentences" returnKeyType="done"/>'


class TextView(El):
    tag = "textView"

    def __init__(self, text="", font=("Regular", 16), color="dsTextPrimary", **kw):
        kw.setdefault("clips", True)
        kw.setdefault("bg", "clear")
        super().__init__(**kw)
        self.text, self.font, self.color = text, font, color

    def base_attrs(self):
        a = super().base_attrs()
        a.update({"multipleTouchEnabled": "YES", "scrollEnabled": "NO", "textAlignment": "natural",
                  "text": self.text})
        return a

    def inner_xml(self):
        return color_xml("textColor", self.color) + font_xml(self.font) + \
            '<textInputTraits key="textInputTraits" autocapitalizationType="sentences"/>'


class Switch(El):
    tag = "switch"

    def __init__(self, on=True, onTint="dsLime", **kw):
        super().__init__(**kw)
        self.on_, self.onTint = on, onTint

    def base_attrs(self):
        a = super().base_attrs()
        a.update({"opaque": "NO", "contentHorizontalAlignment": "center", "contentVerticalAlignment": "center",
                  "on": "YES" if self.on_ else "NO"})
        return a

    def inner_xml(self):
        return color_xml("onTintColor", self.onTint)


class Spinner(El):
    tag = "activityIndicatorView"

    def __init__(self, style="medium", animating=True, **kw):
        kw.setdefault("interaction", False)
        super().__init__(**kw)
        self.style, self.animating = style, animating

    def base_attrs(self):
        a = super().base_attrs()
        a.update({"opaque": "NO", "hidesWhenStopped": "YES", "style": self.style})
        if self.animating:
            a["animating"] = "YES"
        return a


class Blur(El):
    tag = "visualEffectView"

    def __init__(self, style="systemUltraThinMaterialLight", **kw):
        kw.setdefault("clips", True)
        super().__init__(**kw)
        self.style = style
        self.content_view = View(id=f"{self.id}-cv", children=[])
        self.content_view.managed = True
        self.content_view.parent = self

    def to_xml(self, indent, key=None):
        a = self.base_attrs()
        pad = " " * indent
        out = [pad + "<visualEffectView " + " ".join(f"{k}={quoteattr(v)}" for k, v in a.items()) + ">"]
        cv = self.content_view
        cv.children = self.children
        for c in cv.children:
            c.parent = cv
        cvx = cv.to_xml(indent + 4, key="contentView")
        cvx.insert(1, pad + '        <autoresizingMask key="autoresizingMask" widthSizable="YES" heightSizable="YES"/>')
        out += cvx
        out.append(pad + f'    <blurEffect style="{self.style}"/>')
        if self.constraints_here:
            out.append(pad + "    <constraints>")
            for c in self.constraints_here:
                out.append(pad + "        " + c.to_xml(self))
            out.append(pad + "    </constraints>")
        if self.runtime:
            out.append(pad + "    <userDefinedRuntimeAttributes>")
            for k, v in self.runtime.items():
                out.append(pad + "        " + _runtime_attr(k, v))
            out.append(pad + "    </userDefinedRuntimeAttributes>")
        out.append(pad + "</visualEffectView>")
        return out

    def walk(self):
        yield self
        yield self.content_view
        for c in self.children:
            yield from c.walk()


class PageControl(El):
    tag = "pageControl"

    def __init__(self, pages=3, current="dsTextPrimary", other="#00000033", **kw):
        super().__init__(**kw)
        self.pages, self.current, self.other = pages, current, other

    def base_attrs(self):
        a = super().base_attrs()
        a.update({"opaque": "NO", "contentHorizontalAlignment": "center", "contentVerticalAlignment": "center",
                  "numberOfPages": str(self.pages)})
        return a

    def inner_xml(self):
        return color_xml("pageIndicatorTintColor", self.other) + color_xml("currentPageIndicatorTintColor", self.current)


class Slider(El):
    tag = "slider"

    def __init__(self, value=0.5, minv=0, maxv=1, tint="dsLime", **kw):
        super().__init__(**kw)
        self.value, self.minv, self.maxv, self.mtint = value, minv, maxv, tint

    def base_attrs(self):
        a = super().base_attrs()
        a.update({"opaque": "NO", "contentHorizontalAlignment": "center", "contentVerticalAlignment": "center",
                  "value": str(self.value), "minValue": str(self.minv), "maxValue": str(self.maxv)})
        return a

    def inner_xml(self):
        return color_xml("minimumTrackTintColor", self.mtint)


# ---------------------------------------------------------------------------
# Constraints
# ---------------------------------------------------------------------------

class C:
    def __init__(self, a, attr, b=None, attr2=None, const=0, mult=None, rel="equal", prio=None, outlet=None, id=None):
        self.a, self.attr, self.b, self.attr2 = a, attr, b, attr2 or (attr if b is not None else None)
        self.const, self.mult, self.rel, self.prio, self.outlet = const, mult, rel, prio, outlet
        self.id = id or f"c{next(_ids)}"
        Doc.current.constraints.append(self)

    def to_xml(self, container):
        a = {}
        if not (self.b is None and container is self.a):
            a["firstItem"] = self.a.id
        a["firstAttribute"] = self.attr
        if self.rel != "equal":
            a["relation"] = self.rel
        if self.b is not None:
            a["secondItem"] = self.b.id
            a["secondAttribute"] = self.attr2
        if self.mult is not None:
            a["multiplier"] = str(self.mult)
        if self.const:
            a["constant"] = str(self.const)
        if self.prio is not None:
            a["priority"] = str(self.prio)
        a["id"] = self.id
        return "<constraint " + " ".join(f'{k}="{v}"' for k, v in a.items()) + "/>"


def _owner(x):
    return x.owner if isinstance(x, Guide) else x


def _ancestors(v):
    res = []
    while v is not None:
        res.append(v)
        v = v.parent
    return res


def _place(c):
    if c.b is None:
        c.a.constraints_here.append(c)
        return
    a, b = _owner(c.a), _owner(c.b)
    anc_a = _ancestors(a)
    anc_b = set(map(id, _ancestors(b)))
    for v in anc_a:
        if id(v) in anc_b:
            # guides & content views of blur live on the blur itself
            if isinstance(v, View) and isinstance(v.parent, Blur) and v is v.parent.content_view:
                pass
            v.constraints_here.append(c)
            return
    raise ValueError(f"no common ancestor for {c.a.id} / {c.b.id}")


# Shorthands ----------------------------------------------------------------

def sv(v):
    return v.parent


def pin(v, to=None, edges="ltrb", inset=0, l=None, t=None, r=None, b=None, prio=None):
    """Pin edges to `to` (default: superview). edges: any of l,t,r,b. inset: int or (t,l,b,r)."""
    to = to or v.parent
    if isinstance(inset, (tuple, list)):
        it, il, ib, ir = inset
    else:
        it = il = ib = ir = inset
    il = il if l is None else l
    it = it if t is None else t
    ir = ir if r is None else r
    ib = ib if b is None else b
    res = []
    if "l" in edges:
        res.append(C(v, "leading", to, "leading", il, prio=prio))
    if "t" in edges:
        res.append(C(v, "top", to, "top", it, prio=prio))
    if "r" in edges:
        res.append(C(to, "trailing", v, "trailing", ir, prio=prio))
    if "b" in edges:
        res.append(C(to, "bottom", v, "bottom", ib, prio=prio))
    return res


def size(v, w=None, h=None, prio=None):
    if w is not None:
        C(v, "width", const=w, prio=prio)
    if h is not None:
        C(v, "height", const=h, prio=prio)


def square(v, s):
    size(v, s, s)


def aspect(v, ratio, prio=None):
    """width / height."""
    C(v, "width", v, "height", mult=f"{ratio}", prio=prio)


def center(v, to=None, x=True, y=True, dx=0, dy=0):
    to = to or v.parent
    if x:
        C(v, "centerX", to, "centerX", dx)
    if y:
        C(v, "centerY", to, "centerY", dy)


def below(v, other, gap=0, rel="equal", outlet=None):
    return C(v, "top", other, "bottom", gap, rel=rel, outlet=outlet)


def equal(v, other, attr, const=0, mult=None):
    C(v, attr, other, attr, const, mult=mult)


def safe(root):
    return Doc.current.safe_area


# ---------------------------------------------------------------------------
# Document
# ---------------------------------------------------------------------------

class Doc:
    current = None

    def __init__(self, name, owner=None, kind="view", cls=None, size=(393, 852), reuse=None):
        """kind: 'view' (File's Owner = owner, root plain view),
                 'collectionCell' / 'tableCell' (root cell with class `cls`, outlets on the cell)"""
        Doc.current = self
        self.name, self.owner, self.kind, self.cls, self.size, self.reuse = name, owner, kind, cls, size, reuse
        self.fonts, self.images, self.symbols, self.named_colors = set(), set(), set(), set()
        self.constraints = []
        self.top_objects = []
        if kind == "view":
            self.root = View(id="root", cls=cls, label="Root")
            self.safe_area = Guide(self.root, "safeArea")
        else:
            self.root = None
            self.safe_area = None

    def cell(self, *children, bg="clear"):
        tag = "collectionViewCell" if self.kind == "collectionCell" else "tableViewCell"
        cell = El(id="cell", cls=self.cls, label=self.cls)
        cell.tag = tag
        content = View(id="cell-content", children=children, bg=bg, label="Content")
        if self.kind == "tableCell":
            content.tag = "tableViewCellContentView"
        content.parent = cell
        cell.content = content
        self.root = cell
        self.safe_area = None
        return content

    def write(self, path):
        for c in self.constraints:
            _place(c)
        root = self.root
        outlets_owner, outlets_root = [], []
        nodes = root.content.walk() if hasattr(root, "content") else root.walk()
        for v in nodes:
            if v.outlet:
                (outlets_owner if self.kind == "view" else outlets_root).append(
                    f'<outlet property="{v.outlet}" destination="{v.id}" id="{v.id}-o"/>')
            if v.collection:
                (outlets_owner if self.kind == "view" else outlets_root).append(
                    f'<outletCollection property="{v.collection}" destination="{v.id}" collectionClass="NSMutableArray" id="{v.id}-oc"/>')
        for c in self.constraints:
            if c.outlet:
                (outlets_owner if self.kind == "view" else outlets_root).append(
                    f'<outlet property="{c.outlet}" destination="{c.id}" id="{c.id}-o"/>')

        L = ['<?xml version="1.0" encoding="UTF-8"?>',
             '<document type="com.apple.InterfaceBuilder3.CocoaTouch.XIB" version="3.0" toolsVersion="24127" '
             'targetRuntime="iOS.CocoaTouch" propertyAccessControl="none" useAutolayout="YES" '
             'useTraitCollections="YES" useSafeAreas="YES" colorMatched="YES">',
             '    <device id="retina6_12" orientation="portrait" appearance="light"/>',
             '    <dependencies>',
             '        <deployment identifier="iOS"/>',
             '        <plugIn identifier="com.apple.InterfaceBuilder.IBCocoaTouchPlugin" version="24063"/>',
             '        <capability name="Image references" minToolsVersion="12.0"/>',
             '        <capability name="Named colors" minToolsVersion="9.0"/>',
             '        <capability name="Safe area layout guides" minToolsVersion="9.0"/>',
             '        <capability name="System colors in document resources" minToolsVersion="11.0"/>',
             '        <capability name="documents saved in the Xcode 8 format" minToolsVersion="8.0"/>',
             '    </dependencies>']
        body = []
        if self.kind == "view":
            body.append('        <placeholder placeholderIdentifier="IBFilesOwner" id="-1" userLabel="File\'s Owner"'
                        + (f' customClass="{self.owner}" customModule="HomeAI" customModuleProvider="target"' if self.owner else "")
                        + ">")
            conns = list(outlets_owner)
            if self.owner and self.owner.endswith("ViewController"):
                conns.insert(0, '<outlet property="view" destination="root" id="root-view-o"/>')
            elif self.owner:
                conns.insert(0, '<outlet property="contentView" destination="root" id="root-view-o"/>')
            if conns:
                body.append("            <connections>")
                body += ["                " + c for c in conns]
                body.append("            </connections>")
            body.append("        </placeholder>")
        else:
            body.append('        <placeholder placeholderIdentifier="IBFilesOwner" id="-1" userLabel="File\'s Owner"/>')
        body.append('        <placeholder placeholderIdentifier="IBFirstResponder" id="-2" customClass="UIResponder"/>')

        if self.kind == "view":
            if self.safe_area:
                root.extra_xml.insert(0, f'<viewLayoutGuide key="safeArea" id="{self.safe_area.id}"/>')
            xml = root.to_xml(8)
            w, h = self.size
            xml.insert(1, f'            <rect key="frame" x="0.0" y="0.0" width="{w}" height="{h}"/>')
            body += xml
        else:
            body += self._cell_xml(outlets_root)
        for t in self.top_objects:
            body += t.to_xml(8)
        body.append('        </objects>')
        body.insert(0, '    <objects>')

        head_fonts = []
        if self.fonts:
            head_fonts.append('    <customFonts key="customFonts">')
            for f in sorted(self.fonts):
                head_fonts.append(f'        <array key="Geologica-{f}.ttf">')
                head_fonts.append(f'            <string>Geologica-{f}</string>')
                head_fonts.append('        </array>')
            head_fonts.append('    </customFonts>')
        res = ['    <resources>']
        for i in sorted(self.images):
            res.append(f'        <image name="{i}" width="64" height="64"/>')
        for i in sorted(self.symbols):
            res.append(f'        <image name="{i}" catalog="system" width="128" height="128"/>')
        for n in sorted(self.named_colors):
            r, g, b, a = NAMED_COLORS.get(n, (0.5, 0.5, 0.5, 1))
            res.append(f'        <namedColor name="{n}">')
            res.append(f'            <color red="{r:.4f}" green="{g:.4f}" blue="{b:.4f}" alpha="{a:.3f}" colorSpace="custom" customColorSpace="sRGB"/>')
            res.append('        </namedColor>')
        res.append('    </resources>')
        out = L + head_fonts + body + (res if len(res) > 2 else []) + ['</document>']
        text = "\n".join(out) + "\n"
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, "w") as f:
            f.write(text)

    def _cell_xml(self, outlets):
        cell = self.root
        w, h = self.size
        content = cell.content
        tag = cell.tag
        a = {"opaque": "NO", "clipsSubviews": "YES", "multipleTouchEnabled": "YES", "contentMode": "center",
             "id": "cell", "customClass": self.cls, "customModule": "HomeAI", "customModuleProvider": "target"}
        if self.reuse:
            a["reuseIdentifier"] = self.reuse
        pad = " " * 8
        out = [pad + f"<{tag} " + " ".join(f"{k}={quoteattr(v)}" for k, v in a.items()) + ">"]
        out.append(pad + f'    <rect key="frame" x="0.0" y="0.0" width="{w}" height="{h}"/>')
        out.append(pad + '    <autoresizingMask key="autoresizingMask" flexibleMaxX="YES" flexibleMaxY="YES"/>')
        content.parent = None
        cx = content.to_xml(12, key="contentView")
        content.parent = cell
        # contentView keeps autoresizing (no translates=NO)
        cx = [l.replace(' translatesAutoresizingMaskIntoConstraints="NO"', '', 1) if i == 0 else l
              for i, l in enumerate(cx)]
        cx.insert(1, f'                <rect key="frame" x="0.0" y="0.0" width="{w}" height="{h}"/>')
        out += cx
        if cell.constraints_here:
            out.append(pad + "    <constraints>")
            for c in cell.constraints_here:
                out.append(pad + "        " + c.to_xml(cell))
            out.append(pad + "    </constraints>")
        if outlets:
            out.append(pad + "    <connections>")
            out += [pad + "        " + o for o in outlets]
            out.append(pad + "    </connections>")
        out.append(pad + f"</{tag}>")
        return out

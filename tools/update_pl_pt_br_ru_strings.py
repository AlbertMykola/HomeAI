#!/usr/bin/env python3
"""
Rebuild pl / pt-BR / ru Localizable.strings from nl template order.
Preserves existing translations; fills gaps via Google Translate (EN source).
"""
from __future__ import annotations

import hashlib
import time
from pathlib import Path
from typing import Dict, Optional, Tuple

from deep_translator import GoogleTranslator

ROOT = Path("/Users/mykolaalbert/Desktop/HomeAI")
RES = ROOT / "HomeAI" / "Resources"
TEMPLATE = RES / "nl.lproj" / "Localizable.strings"

LOCALES = {
    "pl": RES / "pl.lproj" / "Localizable.strings",
    "pt-BR": RES / "pt-BR.lproj" / "Localizable.strings",
    "ru": RES / "ru.lproj" / "Localizable.strings",
}

MANUAL_OVERRIDES: Dict[str, Dict[str, str]] = {
    "ru": {
        "daily_limit_reached_message": "Вы использовали дневной лимит: %d генераций изображений. Пожалуйста, попробуйте снова завтра.",
        "Cyberpunk": "Киберпанк",
        "assistant_chat_greeting_interior_designer": (
            "Здравствуйте! Я Моника. Расскажите о комнате — о её размере, что вас беспокоит "
            "и какое настроение вы хотите, и я предложу планировку, палитру и несколько быстрых улучшений."
        ),
        "assistant_chat_greeting_budget_estimator": (
            "Здравствуйте, я Оливия. Опишите запланированный ремонт (комнаты, масштаб, уровень отделки), "
            "и я дам ориентир по бюджету и подскажу, где можно сэкономить."
        ),
        "assistant_chat_greeting_exterior_expert": (
            "Здравствуйте! Я Джейкоб. Расскажите о вашем доме — о стиле, проблемных зонах и желаемой атмосфере — "
            "и я предложу внешние изменения, которые действительно дадут заметный результат."
        ),
        "assistant_chat_greeting_material_guide": (
            "Здравствуйте, я Мартин. Расскажите, для какой поверхности вы подбираете материалы "
            "и как вы её будете использовать, и я сокращу выбор до нескольких удачных вариантов."
        ),
        "assistant_suggest_exterior_1": "Какие цвета фасада подойдут моему дому?",
        "assistant_suggest_exterior_2": "Как сделать экстерьер моего дома дороже и статуснее?",
    },
    "pl": {
        "Cyberpunk": "Cyberpunk",
        "assistant_chat_greeting_exterior_expert": (
            "Hej! Jestem Jakub. Opowiedz mi o swoim domu — o stylu, problematycznych miejscach i o klimacie, "
            "jakiego szukasz — a zaproponuję zmiany na zewnątrz, które naprawdę zrobią różnicę."
        ),
    },
    "pt-BR": {
        "Cyberpunk": "Cyberpunk",
        "assistant_chat_greeting_budget_estimator": (
            "Olá, eu sou Olivia. Descreva a reforma que você está planejando (ambientes, escopo e nível de acabamento) "
            "e eu te passo um orçamento aproximado e onde economizar."
        ),
        "assistant_chat_greeting_exterior_expert": (
            "Ei! Sou o Jacob. Conte-me sobre a sua casa — estilo, pontos problemáticos e o clima que você quer — "
            "que eu sugiro mudanças externas que realmente fazem diferença."
        ),
        "assistant_chat_greeting_material_guide": (
            "Olá, eu sou Martin. Diga para qual superfície você está escolhendo materiais e como vai usá‑los, "
            "e eu reduzo para algumas opções inteligentes."
        ),
    },
}


def unescape(s: str) -> str:
    out: list[str] = []
    i = 0
    while i < len(s):
        if s[i] == "\\" and i + 1 < len(s):
            n = s[i + 1]
            if n == "n":
                out.append("\n")
                i += 2
                continue
            if n == "t":
                out.append("\t")
                i += 2
                continue
            if n == "r":
                out.append("\r")
                i += 2
                continue
            if n == '"':
                out.append('"')
                i += 2
                continue
            if n == "\\":
                out.append("\\")
                i += 2
                continue
            if n == "u" and i + 5 < len(s):
                hx = s[i + 2 : i + 6]
                if len(hx) == 4 and all(c in "0123456789abcdefABCDEF" for c in hx):
                    out.append(chr(int(hx, 16)))
                    i += 6
                    continue
        out.append(s[i])
        i += 1
    return "".join(out)


def escape_value(s: str) -> str:
    return (
        s.replace("\\", "\\\\")
        .replace('"', '\\"')
        .replace("\n", "\\n")
        .replace("\r", "\\r")
        .replace("\t", "\\t")
    )


def read_quoted(line: str, start: int) -> Tuple[str, int]:
    if start >= len(line) or line[start] != '"':
        raise ValueError("expected opening quote")
    i = start + 1
    buf: list[str] = []
    while i < len(line):
        ch = line[i]
        if ch == "\\":
            if i + 1 < len(line):
                buf.append(line[i : i + 2])
                i += 2
                continue
        if ch == '"':
            return "".join(buf), i + 1
        buf.append(ch)
        i += 1
    raise ValueError("unterminated string")


def parse_line(line: str) -> Optional[Tuple[str, str]]:
    stripped = line.strip()
    if not stripped or stripped.startswith("//"):
        return None
    if not stripped.endswith(";"):
        return None
    body = stripped[:-1].strip()
    key_lit, pos = read_quoted(body, 0)
    rest = body[pos:].lstrip()
    if not rest.startswith("="):
        return None
    rest = rest[1:].lstrip()
    val_lit, pos2 = read_quoted(rest, 0)
    trailing = rest[pos2:]
    if trailing.strip():
        return None
    key = unescape(key_lit)
    val = unescape(val_lit)
    return key, val


def parse_strings_file(path: Path) -> Dict[str, str]:
    text = path.read_text(encoding="utf-8")
    pairs: Dict[str, str] = {}
    for line in text.splitlines():
        parsed = parse_line(line)
        if not parsed:
            continue
        k, v = parsed
        pairs[k] = v
    return pairs


def needs_translation(locale_code: str, key: str, old: Optional[str], en_val: Optional[str]) -> bool:
    if old is None or old.strip() == "":
        return True
    if en_val is None:
        # key such as Cyberpunk: keep existing non-placeholder translation
        if old != key:
            return False
        return True
    if old != en_val:
        return False
    # old still matches English source
    if key == en_val:
        if len(key) <= 24 and (" " not in key) and ("\n" not in key):
            return False
        return True
    return True


class Translator:
    def __init__(self, target: str) -> None:
        self._gt = GoogleTranslator(source="en", target=target)
        self._cache: Dict[str, str] = {}

    def translate(self, text: str) -> str:
        if not text:
            return text
        h = hashlib.sha256(text.encode("utf-8")).hexdigest()
        if h in self._cache:
            return self._cache[h]
        # Retry on transient failures
        for attempt in range(4):
            try:
                out = self._gt.translate(text)
                self._cache[h] = out
                time.sleep(0.05)
                return out
            except Exception:
                time.sleep(1.2 * (attempt + 1))
        raise RuntimeError(f"translate failed after retries for: {text[:80]!r}")


def build_translators() -> Dict[str, Translator]:
    return {
        "pl": Translator("pl"),
        "pt-BR": Translator("pt"),
        "ru": Translator("ru"),
    }


def resolve_value(
    locale: str,
    key: str,
    en_map: Dict[str, str],
    old_map: Dict[str, str],
    tr: Translator,
) -> str:
    if key in MANUAL_OVERRIDES.get(locale, {}):
        return MANUAL_OVERRIDES[locale][key]

    en_val = en_map.get(key)
    old = old_map.get(key)

    if key == "":
        return old if old is not None else ""
    if key == " ":
        return old if old is not None else " "

    if not needs_translation(locale, key, old, en_val):
        return old if old is not None else (en_val or key)

    src = en_val if en_val is not None else key
    return tr.translate(src)


def render_line(key: str, val: str) -> str:
    return f'"{escape_value(key)}" = "{escape_value(val)}";\n'


def rebuild_locale(locale: str, en_map: Dict[str, str], old_map: Dict[str, str], tr: Translator) -> str:
    lines = TEMPLATE.read_text(encoding="utf-8").splitlines(keepends=True)
    out: list[str] = []
    memo: Dict[str, str] = {}

    for line in lines:
        parsed = parse_line(line)
        if not parsed:
            out.append(line if line.endswith("\n") else line + "\n")
            continue
        key, _nl_val = parsed
        if key not in memo:
            memo[key] = resolve_value(locale, key, en_map, old_map, tr)
        out.append(render_line(key, memo[key]))
    return "".join(out)


def nonempty_en_keys(en_map: Dict[str, str]) -> list[str]:
    return sorted(k for k, v in en_map.items() if v.strip() != "")


def verify(en_map: Dict[str, str], out_path: Path) -> list[str]:
    tgt = parse_strings_file(out_path)
    missing: list[str] = []
    for k in nonempty_en_keys(en_map):
        if k not in tgt or tgt[k].strip() == "":
            missing.append(k)
    return missing


def main() -> None:
    if not TEMPLATE.exists():
        raise SystemExit(f"Missing template: {TEMPLATE}")

    en_map = parse_strings_file(RES / "en.lproj" / "Localizable.strings")
    en_nonempty = nonempty_en_keys(en_map)
    print(f"EN non-empty keys: {len(en_nonempty)}")

    translators = build_translators()

    for locale, out_path in LOCALES.items():
        old_map = parse_strings_file(out_path)
        print(f"\n== {locale} ==")
        body = rebuild_locale(locale, en_map, old_map, translators[locale])
        out_path.write_text(body, encoding="utf-8")
        miss = verify(en_map, out_path)
        print(f"Wrote {out_path} ({len(body)} bytes)")
        print(f"Missing vs EN non-empty: {len(miss)}")
        if miss:
            print("First missing:", miss[:10])

    # Extra checks
    for locale, out_path in LOCALES.items():
        data = out_path.read_text(encoding="utf-8")
        if '"Cyberpunk"' not in data:
            print(f"WARNING: Cyberpunk missing in {locale}")
        if "\\\\n" in data and "Full 2D floor plan" in data:
            # doubled backslash before n in values (heuristic)
            pass


if __name__ == "__main__":
    main()

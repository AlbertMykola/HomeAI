"""Regenerates redesign XIBs from specs/*.py and checks each with ibtool."""
import importlib.util
import os
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(os.path.dirname(HERE))
sys.path.insert(0, HERE)
import xibgen  # noqa: E402

xibgen.register_colors(os.path.join(REPO, "HomeAI/Assets.xcassets/RedesignColors"))

REGISTRY = []


def xib(path):
    """Decorator for spec functions: @xib("HomeAI/Redesign/Home/HomeViewController.xib")."""
    def deco(fn):
        REGISTRY.append((path, fn))
        return fn
    return deco


xibgen.xib = xib


def swift_outlets(cls):
    """@IBOutlet names of `cls` (searched across HomeAI/**/*.swift), or None if the class isn't found."""
    import re
    pat = re.compile(r"(?:final\s+)?class\s+" + re.escape(cls) + r"\b")
    for dirpath, _, files in os.walk(os.path.join(REPO, "HomeAI")):
        for f in files:
            if not f.endswith(".swift"):
                continue
            text = open(os.path.join(dirpath, f)).read()
            if not pat.search(text):
                continue
            names = set(re.findall(r"@IBOutlet[^\n]*?var\s+(\w+)", text))
            names |= {"view", "contentView"}
            return names
    return None


def check_outlets(doc, full):
    import re
    cls = doc.owner if doc.kind == "view" else doc.cls
    if not cls:
        return []
    known = swift_outlets(cls)
    if known is None:
        return [f"class {cls} not found in Swift sources"]
    xml = open(full).read()
    used = set(re.findall(r'<outlet(?:Collection)? property="(\w+)"', xml))
    return [f"outlet '{o}' missing in {cls}" for o in sorted(used - known)]


def main(only):
    specs = sorted(f[:-3] for f in os.listdir(os.path.join(HERE, "specs")) if f.endswith(".py"))
    for name in specs:
        if only and name not in only:
            continue
        spec = importlib.util.spec_from_file_location(f"spec_{name}", os.path.join(HERE, "specs", name + ".py"))
        mod = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(mod)
    failed = False
    for path, fn in REGISTRY:
        doc = fn()
        full = os.path.join(REPO, path)
        doc.write(full)
        r = subprocess.run(["ibtool", "--errors", "--warnings", "--output-format", "human-readable-text",
                            "--minimum-deployment-target", "15.6", "--module", "HomeAI", "--compile", "/tmp/xibgen_check.nib", full], capture_output=True, text=True)
        msgs = [l for l in r.stdout.splitlines() if ("error" in l or "warning" in l) and "Unsupported" not in l]
        problems = check_outlets(doc, full)
        msgs += problems
        status = "ok" if r.returncode == 0 and not problems and not any("error" in m for m in msgs) else "FAIL"
        failed |= status == "FAIL"
        print(f"[{status}] {path}")
        for m in msgs:
            print("    " + m)
    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    main(set(sys.argv[1:]))

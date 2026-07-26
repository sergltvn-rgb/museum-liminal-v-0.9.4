#!/usr/bin/env python3
"""Cross-check localization/game.csv against every key the code actually uses.

Three classes of defect are fatal, because each one is visible to the player:
  * a key the code asks for that the catalogue does not answer -> raw KEY on screen;
  * a catalogue row whose format specifiers do not match the arguments at a call
    site -> "String formatting error" at runtime. On Godot 4.7 the validated `%`
    (both operands statically typed, which is the usual shape) logs that error and
    yields the format string unchanged, so the player reads a literal "%s" or a
    bare key; where an operand is an untyped Variant the unvalidated path aborts
    the enclosing function at that statement instead;
  * a row that is missing a translation for one of the shipped locales.

Run from the project root:  python tools/check_localization.py
Exit code is non-zero when anything fatal is found, so CI can gate on it.
"""

from __future__ import annotations

import csv
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CSV_PATH = ROOT / "localization" / "game.csv"
CODE_DIRS = [ROOT / "game", ROOT / "scenes"]

# UPPER_SNAKE literals that look like keys but are not: input actions, node and
# group names, and UI text that happens to be uppercase. Mirrored by
# NON_KEY_LITERALS in game/test_map_verification.gd — adding a name in one place
# means adding it in the other.
NOT_KEYS = {"WASD", "START", "LMB", "RMB", "ESC"}

# Test scripts are skipped outright. They name production constants as strings to
# resolve them through get_script_constant_map() (EXHIBITS, CAMS, KILL_PLANE_Y,
# ANOMALY_SCALE_SPAN, SCALE_MIN/MAX) and never render text to a player, so every
# such constant would otherwise have to be excused by name here and in the
# in-engine sweep. Mirrors NON_UI_SOURCE_PREFIX in test_map_verification.gd.
NON_UI_SOURCE_PREFIX = "test_"

# Godot's own %-format specifiers. "%%" is a literal percent and takes no argument.
SPEC_RE = re.compile(r"%(?:%|[-+ #0]*\*?\d*(?:\.\d+)?[sdfxXoceEgGvb])")
KEY_LITERAL_RE = re.compile(r'"([A-Z][A-Z0-9_]{3,})"')


def specifiers(text: str) -> list[str]:
    """Format specifiers in `text`, excluding the literal "%%" escape."""
    return [s for s in SPEC_RE.findall(text) if s != "%%"]


def load_catalogue() -> tuple[list[str], dict[str, dict[str, str]]]:
    with CSV_PATH.open(encoding="utf-8", newline="") as handle:
        rows = list(csv.reader(handle))
    if not rows:
        sys.exit(f"{CSV_PATH} is empty")
    header, *body = rows
    locales = [column.strip() for column in header[1:]]
    catalogue: dict[str, dict[str, str]] = {}
    for line_no, row in enumerate(body, start=2):
        if not row or not row[0].strip():
            continue
        key = row[0].strip()
        if key in catalogue:
            print(f"  duplicate key {key} (game.csv line {line_no})")
        catalogue[key] = dict(zip(locales, row[1:]))
    return locales, catalogue


def source_files() -> list[Path]:
    files: list[Path] = []
    for directory in CODE_DIRS:
        if not directory.is_dir():
            continue
        files.extend(sorted(directory.rglob("*.gd")))
        files.extend(sorted(directory.rglob("*.tscn")))
    return [f for f in files if not f.name.startswith(NON_UI_SOURCE_PREFIX)]


def used_keys() -> dict[str, list[str]]:
    """Every key literal in the codebase, mapped to the sites that mention it."""
    sites: dict[str, list[str]] = {}
    for path in source_files():
        rel = path.relative_to(ROOT).as_posix()
        for line_no, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
            for key in KEY_LITERAL_RE.findall(line):
                if key in NOT_KEYS:
                    continue
                sites.setdefault(key, []).append(f"{rel}:{line_no}")
    return sites


def _count_bracketed(rest: str) -> int:
    """Elements of the bracketed list starting at `rest`, by top-level commas."""
    if rest.startswith("[]"):
        return 0
    depth = 0
    args = 1
    for char in rest:
        if char in "([{":
            depth += 1
        elif char in ")]}":
            depth -= 1
            if depth == 0:
                break
        elif char == "," and depth == 1:
            args += 1
    return args


def count_format_args(line: str, key: str) -> int | None:
    """Arguments fed to the translation of `key` on this line.

    Two shapes are recognised, because the codebase uses both:
      tr("KEY") % x  /  tr("KEY") % [a, b]     — the raw operator
      Loc.fmt("KEY", [a, b])  /  Loc.fmt("KEY") — the format-safe helper

    Returns None when the line merely mentions the key without formatting it —
    a dictionary field, a constant, or an argument to some other translation.
    That is the common case and needs no checking.

    The match must be anchored immediately after the key literal. A line may hold
    two translations, only one of which is formatted, as in
    `tr("A") if cond else tr("B") % arg` — attributing that `%` to A would invent
    a mismatch that does not exist.
    """
    anchor = line.find(key)
    if anchor == -1:
        return None
    tail = line[anchor + len(key):]

    percent = re.match(r'"?\)\s*%\s*', tail)
    if percent is not None:
        rest = tail[percent.end():].strip()
        return _count_bracketed(rest) if rest.startswith("[") else 1

    # Loc.fmt("KEY", [ ... ]) — the argument list is always a literal array.
    helper = re.match(r'"\s*,\s*(?=\[)', tail)
    if helper is not None:
        return _count_bracketed(tail[helper.end():].strip())

    # Loc.fmt("KEY") with no argument list at all formats nothing.
    if re.match(r'"\s*\)', tail) and "Loc.fmt" in line[:anchor]:
        return 0
    return None


def main() -> int:
    locales, catalogue = load_catalogue()
    sites = used_keys()
    fatal = 0

    missing = sorted(set(sites) - set(catalogue))
    if missing:
        fatal += len(missing)
        print(f"\nMISSING FROM CATALOGUE ({len(missing)}):")
        for key in missing:
            print(f"  {key}  <- {sites[key][0]}")

    unused = sorted(set(catalogue) - set(sites))
    if unused:
        print(f"\nIN CATALOGUE BUT NEVER USED ({len(unused)}):")
        for key in unused:
            print(f"  {key}")

    blank = [
        f"{key}[{locale}]"
        for key, row in sorted(catalogue.items())
        for locale in locales
        if not row.get(locale, "").strip()
    ]
    if blank:
        fatal += len(blank)
        print(f"\nEMPTY TRANSLATIONS ({len(blank)}):")
        for entry in blank:
            print(f"  {entry}")

    # Every locale must agree on the specifier list, or switching language turns a
    # working screen into a crash.
    skew = []
    for key, row in sorted(catalogue.items()):
        shapes = {locale: specifiers(row.get(locale, "")) for locale in locales}
        if len({tuple(v) for v in shapes.values()}) > 1:
            skew.append((key, shapes))
    if skew:
        fatal += len(skew)
        print(f"\nSPECIFIERS DIFFER BETWEEN LOCALES ({len(skew)}):")
        for key, shapes in skew:
            print(f"  {key}: {shapes}")

    # The core check: catalogue specifiers versus arguments at each call site.
    mismatches = []
    formatted_keys: set[str] = set()
    for path in source_files():
        rel = path.relative_to(ROOT).as_posix()
        for line_no, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
            for key in KEY_LITERAL_RE.findall(line):
                if key in NOT_KEYS or key not in catalogue:
                    continue
                args = count_format_args(line, key)
                if args is None:
                    continue
                formatted_keys.add(key)
                for locale in locales:
                    expected = len(specifiers(catalogue[key].get(locale, "")))
                    if expected != args:
                        mismatches.append(
                            f"  {rel}:{line_no}  {key}[{locale}] wants {expected} "
                            f"specifier(s), call site passes {args}\n      {line.strip()}"
                        )
    if mismatches:
        fatal += len(mismatches)
        print(f"\nFORMAT ARGUMENT MISMATCHES ({len(mismatches)}):")
        for entry in mismatches:
            print(entry)

    # A key carrying specifiers that no call site ever formats renders a literal
    # "%s" on screen. It also means the scanner above never inspected that key, so
    # letting it pass would quietly restore the blind spot this check exists to
    # close.
    unformatted = sorted(
        key
        for key, row in catalogue.items()
        if key in sites
        and specifiers(row.get(locales[0], ""))
        and key not in formatted_keys
    )
    if unformatted:
        fatal += len(unformatted)
        print(f"\nKEYS WITH SPECIFIERS THAT NO CALL SITE FORMATS ({len(unformatted)}):")
        for key in unformatted:
            print(f"  {key}  <- {sites[key][0]}")

    print(
        f"\n{len(catalogue)} keys in catalogue, {len(sites)} used in code, "
        f"locales: {', '.join(locales)}"
    )
    if fatal:
        print(f"FAILED — {fatal} fatal problem(s)")
        return 1
    print("OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())

#!/usr/bin/env python3
"""Generates the Arabic presentation-form table used by the PDF importer.

A PDF stores glyphs, not text. An Arabic-script letter is written as the
presentation form that joins with its neighbours (U+FB50–U+FEFF), so reading a
Persian CV back out of a file requires mapping each form onto the base letters
it stands for. That mapping is data, not logic, and this script is where the
data comes from.

The rule
--------
A code point is included when its Unicode **compatibility decomposition**
(NFKC) consists only of Arabic-script characters and contains no space:

  * every letter form — isolated, final, initial, medial — folds to its base
    letter, in whatever script variant the decomposition names (a Farsi yeh
    form folds to U+06CC, the letter a Persian keyboard produces);
  * the lam-alef ligatures fold to two letters, because that is what they
    spell: "کالا" contains one, and dropping it would corrupt the word;
  * forms whose decomposition is a word (the Allah ligature, the Quranic
    abbreviations) are excluded, as are the diacritic stacks whose
    decomposition begins with a space.

The decomposition is read from the interpreter's own Unicode database rather
than from a list typed by hand, so this file cannot drift from Unicode and
cannot quietly lose a range: an earlier hand-set ceiling of U+FBB1 dropped the
Farsi-yeh forms at U+FBFC–U+FBFF, and the result was a CI failure that pointed
at a presentation form in the extracted text.

Usage:
    python3 tools/generate_arabic_table.py            # rewrite the Dart file
    python3 tools/generate_arabic_table.py --check    # fail if it is stale
"""

from __future__ import annotations

import argparse
import sys
import unicodedata
from pathlib import Path

TARGET = Path(__file__).resolve().parent.parent / "lib/data/import/arabic_presentation_forms.dart"

HEADER = '''// GENERATED FILE — do not edit by hand.
//
// Produced by `python3 tools/generate_arabic_table.py`, which explains the rule
// it applies. Regenerate it rather than editing it: the table is derived from
// Unicode's own compatibility decompositions, and a hand-edited row is a bug
// waiting for a user whose name contains the letter it dropped.

/// Presentation forms that stand for Arabic-script letters, as
/// `(first code point, how many in the run, the base letters)`.
///
/// Run-length encoded because the forms arrive in contiguous blocks — the four
/// shapes of one letter sit next to each other — which turns eight hundred
/// entries into a few hundred rows and keeps the file reviewable.
const List<(int, int, String)> arabicFormRuns = <(int, int, String)>[
'''

FOOTER = '''];

/// The same table, keyed by code point.
///
/// Built once on first use: a PDF import is not latency-sensitive, and a
/// literal map of every form would be a thousand lines of generated code
/// rather than a table someone can read.
final Map<int, String> arabicPresentationForms = <int, String>{
  for (final (int first, int count, String base) in arabicFormRuns)
    for (int code = first; code < first + count; code++) code: base,
};
'''


def forms() -> dict[int, str]:
    """Every code point in the Arabic presentation-form blocks that means letters."""
    table: dict[int, str] = {}
    for code in range(0xFB50, 0xFF00):
        decomposed = unicodedata.normalize("NFKC", chr(code))
        if not decomposed or len(decomposed) > 6:
            continue
        if any(character == " " for character in decomposed):
            continue
        if not all(0x0600 <= ord(character) <= 0x06FF for character in decomposed):
            continue
        table[code] = decomposed
    return table


def runs(table: dict[int, str]) -> list[tuple[int, int, str]]:
    """Collapses the table into contiguous runs that share a base form."""
    out: list[tuple[int, int, str]] = []
    start = previous = None
    value = None
    for code, base in sorted(table.items()):
        if start is not None and code == previous + 1 and base == value:
            previous = code
            continue
        if start is not None:
            out.append((start, previous - start + 1, value))
        start = previous = code
        value = base
    if start is not None:
        out.append((start, previous - start + 1, value))
    return out


def render() -> str:
    rows = "\n".join(
        "    (0x%04X, %d, '%s')," % (first, count, base.replace("'", r"\'"))
        for first, count, base in runs(forms())
    )
    return HEADER + rows + "\n" + FOOTER


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--check",
        action="store_true",
        help="exit non-zero if the generated file differs from what would be written",
    )
    arguments = parser.parse_args()

    generated = render()
    if arguments.check:
        if not TARGET.exists() or TARGET.read_text(encoding="utf-8") != generated:
            print(f"{TARGET} is out of date; run tools/generate_arabic_table.py")
            return 1
        print(f"{TARGET} is up to date")
        return 0

    TARGET.parent.mkdir(parents=True, exist_ok=True)
    TARGET.write_text(generated, encoding="utf-8")
    table = forms()
    print(
        f"wrote {TARGET}: {len(table)} code points in "
        f"{len(runs(table))} runs ({len(generated)} bytes)"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())

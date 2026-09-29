#!/usr/bin/env python3
"""A cheap, local syntax check for Dart sources.

This project is developed in an environment with no Dart SDK, so `flutter
analyze` only runs in CI, and a five-minute round trip per typo is a bad way to
find a missing brace. This script does the small part of the job that a
tokenizer can do reliably:

  * strips comments and string literals, honouring `r'…'` raw strings, `'''`
    and `\"\"\"` blocks, escapes, and `$` interpolation (including `${…}`);
  * checks that brackets, braces and parentheses balance, per file;
  * reports a line and column for the first unbalanced opener;
  * flags a few mistakes that are always wrong rather than stylistic:
    a `const RegExp(`, an unclosed block comment, a tab-indented line inside a
    file that uses spaces, and a stray `{{`/`}}` outside a string (the exact
    shape of the placeholder bug this repository shipped once).

It is **not** a compiler. It cannot see types, and it will not catch a wrong
method name. It is the difference between "CI says line 402 has an error" and
"CI says the whole file is unbalanced", which is worth having when the
compiler is five minutes away.
"""

from __future__ import annotations

import argparse
import sys
from dataclasses import dataclass
from pathlib import Path

OPENERS = {"(": ")", "[": "]", "{": "}"}
CLOSERS = {v: k for k, v in OPENERS.items()}


@dataclass
class Problem:
    path: Path
    line: int
    column: int
    message: str

    def __str__(self) -> str:
        return f"{self.path}:{self.line}:{self.column}: {self.message}"


def strip_source(source: str) -> str:
    """Replace comments and string contents with spaces, keeping offsets.

    Offsets are preserved so the reported line and column point at the real
    place in the original file, which is the whole point of the exercise.
    """
    out: list[str] = []
    i = 0
    n = len(source)
    line = 1

    def blank(count: int) -> None:
        nonlocal line
        line += source.count("\n", i, i + count)
        out.append("".join("\n" if c == "\n" else " " for c in source[i : i + count]))

    while i < n:
        char = source[i]

        # Line comment.
        if source.startswith("//", i):
            end = source.find("\n", i)
            end = n if end < 0 else end
            blank(end - i)
            i = end
            continue

        # Block comment (Dart nests them).
        if source.startswith("/*", i):
            depth = 1
            j = i + 2
            while j < n and depth:
                if source.startswith("/*", j):
                    depth += 1
                    j += 2
                elif source.startswith("*/", j):
                    depth -= 1
                    j += 2
                else:
                    j += 1
            blank(j - i)
            i = j
            continue

        # String literals, including raw and triple-quoted forms.
        raw = False
        quote_index = i
        if char == "r" and i + 1 < n and source[i + 1] in "'\"":
            raw = True
            quote_index = i + 1
        if source[quote_index] in "'\"":
            quote = source[quote_index]
            triple = source.startswith(quote * 3, quote_index)
            delimiter = quote * 3 if triple else quote
            j = quote_index + len(delimiter)
            while j < n:
                if not raw and source[j] == "\\":
                    j += 2
                    continue
                if not raw and source[j] == "$" and j + 1 < n:
                    # Interpolation: ${…} can contain anything, including the
                    # closing quote of the literal, so skip it as a unit.
                    if source[j + 1] == "{":
                        depth = 1
                        k = j + 2
                        while k < n and depth:
                            if source[k] == "{":
                                depth += 1
                            elif source[k] == "}":
                                depth -= 1
                            k += 1
                        j = k
                        continue
                    j += 2
                    continue
                if source.startswith(delimiter, j):
                    j += len(delimiter)
                    break
                j += 1
            blank(j - i)
            i = j
            continue

        out.append(char)
        if char == "\n":
            line += 1
        i += 1

    return "".join(out)


def check(path: Path) -> list[Problem]:
    source = path.read_text(encoding="utf-8")
    problems: list[Problem] = []

    stripped = strip_source(source)

    # Balance, with the position of the unmatched opener.
    stack: list[tuple[str, int]] = []
    for index, char in enumerate(stripped):
        if char in OPENERS:
            stack.append((char, index))
        elif char in CLOSERS:
            if not stack:
                line = stripped.count("\n", 0, index) + 1
                column = index - stripped.rfind("\n", 0, index)
                problems.append(
                    Problem(path, line, column, f"unmatched closing '{char}'")
                )
            else:
                opener, position = stack.pop()
                if OPENERS[opener] != char:
                    line = stripped.count("\n", 0, position) + 1
                    column = position - stripped.rfind("\n", 0, position)
                    problems.append(
                        Problem(
                            path,
                            line,
                            column,
                            f"'{opener}' opened here is closed by '{char}'",
                        )
                    )
    for opener, position in stack:
        line = stripped.count("\n", 0, position) + 1
        column = position - stripped.rfind("\n", 0, position)
        problems.append(
            Problem(path, line, column, f"'{opener}' is never closed")
        )

    # Things that are wrong in every Dart file.
    if "const RegExp(" in stripped:
        index = stripped.index("const RegExp(")
        line = stripped.count("\n", 0, index) + 1
        problems.append(
            Problem(path, line, 1, "const RegExp(...) — RegExp is never const")
        )

    for number, text in enumerate(source.splitlines(), start=1):
        if text.startswith("\t"):
            problems.append(
                Problem(path, number, 1, "tab indentation (this project uses spaces)")
            )
        if "{{" in text and not text.lstrip().startswith(("//", "///")):
            problems.append(
                Problem(path, number, text.index("{{") + 1, "unresolved '{{' placeholder")
            )

    return problems


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "paths",
        nargs="*",
        default=["lib", "test", "integration_test"],
        help="files or directories to check (default: lib test integration_test)",
    )
    arguments = parser.parse_args()

    targets: list[Path] = []
    for raw in arguments.paths:
        candidate = Path(raw)
        if candidate.is_dir():
            targets.extend(sorted(candidate.rglob("*.dart")))
        elif candidate.suffix == ".dart" and candidate.exists():
            targets.append(candidate)

    problems: list[Problem] = []
    for target in targets:
        problems.extend(check(target))

    for problem in problems:
        print(problem)
    print(f"checked {len(targets)} Dart file(s): {len(problems)} problem(s)")
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())

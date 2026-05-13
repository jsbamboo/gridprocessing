#!/usr/bin/env python3
"""Convert a simple LaTeX technical note to Markdown.

Usage:
  python3 _tool.tex_to_md.py INPUT.tex [OUTPUT.md] [--bbl REFERENCES.bbl]

If OUTPUT is omitted, the script writes INPUT_stem_confluence.md.
If --bbl is omitted, the script uses INPUT_stem.bbl when it exists.
"""

import argparse
import re
from pathlib import Path
from typing import Optional, Tuple


def protect_url_percents(text: str) -> str:
    def repl(match: re.Match) -> str:
        return match.group(0).replace("%", "@@PERCENT@@")

    text = re.sub(r"\\url\{[^{}]*\}", repl, text)
    text = re.sub(r"<https?://[^>]*>", repl, text)
    return text


def unprotect_url_percents(text: str) -> str:
    return text.replace("@@PERCENT@@", "%")


def slugify(text: str) -> str:
    text = re.sub(r"<[^>]+>", "", text)
    text = re.sub(r"[*_`]", "", text)
    text = re.sub(r"[^\w\s-]", "", text.lower())
    text = re.sub(r"[\s_]+", "-", text).strip("-")
    return text or "section"


def strip_comments(line: str) -> str:
    line = protect_url_percents(line)
    out = []
    escaped = False
    for ch in line:
        if ch == "%" and not escaped:
            break
        out.append(ch)
        escaped = ch == "\\" and not escaped
        if ch != "\\":
            escaped = False
    return unprotect_url_percents("".join(out))


def braced_arg(s: str, start: int) -> Optional[Tuple[str, int]]:
    if start < 0 or start >= len(s) or s[start] != "{":
        return None
    depth = 0
    out = []
    i = start
    while i < len(s):
        ch = s[i]
        if ch == "{" and (i == 0 or s[i - 1] != "\\"):
            depth += 1
            if depth > 1:
                out.append(ch)
        elif ch == "}" and (i == 0 or s[i - 1] != "\\"):
            depth -= 1
            if depth == 0:
                return "".join(out), i + 1
            out.append(ch)
        else:
            out.append(ch)
        i += 1
    return None


def replace_single_arg_commands(text: str, commands: dict) -> str:
    changed = True
    while changed:
        changed = False
        for cmd, (prefix, suffix) in commands.items():
            needle = "\\" + cmd + "{"
            i = text.find(needle)
            while i != -1:
                parsed = braced_arg(text, i + len(cmd) + 1)
                if not parsed:
                    break
                content, end = parsed
                replacement = prefix + clean_inline(content) + suffix
                text = text[:i] + replacement + text[end:]
                changed = True
                i = text.find(needle, i + len(replacement))
    return text


def clean_inline(text: str) -> str:
    text = re.sub(r"\\lstinline(.)(.*?)\1", lambda m: f"`{m.group(2)}`", text)
    text = re.sub(r"\\verb(.)(.*?)\1", lambda m: f"`{m.group(2)}`", text)
    text = re.sub(r"\\url\{([^{}]+)\}", lambda m: "<" + m.group(1).replace(r"\_", "_") + ">", text)
    text = re.sub(
        r"\\doi\{([^{}]+)\}",
        lambda m: "https://doi.org/" + m.group(1).replace("https://doi.org/", ""),
        text,
    )
    text = re.sub(
        r"\\citep(?:\[[^\]]*\])?(?:\[[^\]]*\])?\{([^{}]+)\}",
        lambda m: "[" + ", ".join(x.strip() for x in m.group(1).split(",")) + "]",
        text,
    )
    text = re.sub(
        r"\\citet\{([^{}]+)\}",
        lambda m: "[" + ", ".join(x.strip() for x in m.group(1).split(",")) + "]",
        text,
    )
    text = replace_single_arg_commands(
        text,
        {
            "textbf": ("**", "**"),
            "emph": ("*", "*"),
            "textit": ("*", "*"),
            "sout": ("~~", "~~"),
            "underline": ("_", "_"),
        },
    )
    replacements = {
        r"\&": "&",
        r"\_": "_",
        r"\%": "%",
        r"\$": "$",
        r"\#": "#",
        r"\{": "{",
        r"\}": "}",
        r"\textbullet": "-",
        r"\rightarrow": "->",
        r"\leftarrow": "<-",
        r"\times": "x",
        r"\cdot": ".",
        "~": " ",
        "``": '"',
        "''": '"',
        "\u2010": "-",
        "\u2011": "-",
        "\u2012": "-",
        "\u2013": "-",
        "\u2014": "-",
    }
    for src, dst in replacements.items():
        text = text.replace(src, dst)
    text = text.replace("$", "")
    text = re.sub(r"\\[a-zA-Z]+\*?(?:\[[^\]]*\])?", "", text)
    text = re.sub(r"\s+", " ", text)
    return text.strip()


def convert_table(match: re.Match) -> str:
    block = match.group(0)
    caption = ""
    cap = re.search(r"\\caption\{([^{}]+)\}", block)
    if cap:
        caption = clean_inline(cap.group(1))
    tab = re.search(r"\\begin\{tabular\}\{[^{}]*\}(.*?)\\end\{tabular\}", block, re.S)
    if not tab:
        return ""
    rows = []
    for raw in tab.group(1).splitlines():
        raw = strip_comments(raw).strip()
        if not raw or raw.startswith("\\"):
            continue
        raw = raw.rstrip("\\").strip()
        if "&" not in raw:
            continue
        cells = [clean_inline(c.strip()) for c in raw.split("&")]
        rows.append(cells)
    if not rows:
        return ""
    width = max(len(r) for r in rows)
    rows = [r + [""] * (width - len(r)) for r in rows]
    out = []
    if caption:
        out.extend([f"**Table: {caption}**", ""])
    out.append("| " + " | ".join(rows[0]) + " |")
    out.append("| " + " | ".join(["---"] * width) + " |")
    for row in rows[1:]:
        out.append("| " + " | ".join(row) + " |")
    return "\n".join(out) + "\n"


def convert_figure(match: re.Match) -> str:
    block = match.group(0)
    img = re.search(r"\\includegraphics(?:\[[^\]]*\])?\{([^{}]+)\}", block)
    cap = re.search(r"\\caption\{([^{}]+)\}", block)
    if not img:
        return ""
    path = img.group(1)
    caption = clean_inline(cap.group(1)) if cap else Path(path).name
    return f"\n![{caption}]({path})\n\n*Figure: {caption}*\n"


def convert_bibliography(bbl_path: Optional[Path]) -> str:
    if not bbl_path or not bbl_path.exists():
        return ""
    text = bbl_path.read_text()
    items = re.split(r"\\bibitem(?:\[[^\]]*\])?\{([^{}]+)\}", text)
    refs = []
    for i in range(1, len(items), 2):
        key = items[i]
        body = items[i + 1]
        body = re.sub(r"\\end\{thebibliography\}", "", body)
        body = clean_inline(body)
        body = re.sub(r"\s+", " ", body).strip()
        if body:
            refs.append(f"- **[{key}]** {body}")
    if not refs:
        return ""
    return "\n## References\n\n" + "\n".join(refs) + "\n"


def render_toc(toc: list[tuple[int, str, str]]) -> str:
    if not toc:
        return ""
    lines = ["## Contents", ""]
    for level, anchor, text in toc:
        indent = "  " if level == 3 else ""
        lines.append(f"{indent}- [{text}](#{anchor})")
    return "\n".join(lines) + "\n\n"


def extract_title(src: str, fallback: str) -> str:
    title_pos = src.find(r"\title")
    if title_pos == -1:
        return fallback
    parsed = braced_arg(src, src.find("{", title_pos))
    if not parsed:
        return fallback
    return clean_inline(parsed[0]).strip("*") or fallback


def body_from_document(src: str) -> str:
    if r"\begin{document}" in src:
        body = src.split(r"\begin{document}", 1)[1]
    else:
        body = src
    body = body.split(r"\bibliographystyle", 1)[0]
    body = body.split(r"\bibliography", 1)[0]
    body = re.sub(r".*?\\maketitle", "", body, flags=re.S)
    return body


def convert_tex(tex_path: Path, out_path: Path, bbl_path: Optional[Path], include_toc: bool = True) -> None:
    src = tex_path.read_text()
    title = extract_title(src, tex_path.stem.replace("_", " "))
    body = body_from_document(src)
    body = re.sub(r"\\begin\{table\*?\}.*?\\end\{table\*?\}", convert_table, body, flags=re.S)
    body = re.sub(r"\\begin\{figure\*?\}.*?\\end\{figure\*?\}", convert_figure, body, flags=re.S)

    code_blocks = []

    def hold_code(match: re.Match) -> str:
        idx = len(code_blocks)
        code_blocks.append(match.group(1).strip("\n"))
        return f"\n@@CODE_BLOCK_{idx}@@\n"

    body = re.sub(
        r"\\begin\{lstlisting\}(?:\[[^\]]*\])?(.*?)\\end\{lstlisting\}",
        hold_code,
        body,
        flags=re.S,
    )

    lines = []
    toc = []
    used_anchors = set()
    for raw in body.splitlines():
        line = strip_comments(raw).strip()
        if not line:
            if lines and lines[-1] != "":
                lines.append("")
            continue
        if line.startswith(r"\copyrightstatement"):
            parsed = braced_arg(line, len(r"\copyrightstatement"))
            if parsed:
                lines.extend(["**Copyright statement:** " + clean_inline(parsed[0]), ""])
            continue
        if line == r"\introduction":
            lines.extend(["## Introduction", ""])
            toc.append((2, "introduction", "Introduction"))
            used_anchors.add("introduction")
            continue
        if line in {r"\newpage", r"\tableofcontents", r"\nolinenumbers"}:
            continue
        if line.startswith(r"\vspace") or line.startswith(r"\belowtable"):
            continue
        for level, cmd in [(4, "subsubsection"), (3, "subsection"), (2, "section")]:
            prefix = "\\" + cmd
            if line.startswith(prefix):
                parsed = braced_arg(line, len(prefix))
                if parsed:
                    heading = clean_inline(parsed[0])
                    lines.extend(["#" * level + " " + heading, ""])
                    if 2 <= level <= 3:
                        base_anchor = slugify(heading)
                        anchor = base_anchor
                        suffix = 2
                        while anchor in used_anchors:
                            anchor = f"{base_anchor}-{suffix}"
                            suffix += 1
                        used_anchors.add(anchor)
                        toc.append((level, anchor, re.sub(r"[*_`]", "", heading)))
                    break
        else:
            if line.startswith(r"\begin{itemize}") or line.startswith(r"\begin{enumerate}"):
                continue
            if line.startswith(r"\end{itemize}") or line.startswith(r"\end{enumerate}"):
                lines.append("")
                continue
            if line.startswith(r"\item"):
                line = "- " + line[len(r"\item"):].strip()
            line = re.sub(r"\\begin\{[^{}]+\}(?:\[[^\]]*\])?", "", line)
            line = re.sub(r"\\end\{[^{}]+\}", "", line)
            cleaned = clean_inline(line)
            if cleaned:
                lines.append(cleaned)

    references_md = convert_bibliography(bbl_path)
    if references_md:
        toc.append((2, "references", "References"))

    md = "# " + title + "\n\n"
    md += f"_Converted from `{tex_path.name}` for LLNL Confluence-compatible Markdown._\n\n"
    if include_toc:
        md += render_toc(toc)
    md += "\n".join(lines)
    for idx, code in enumerate(code_blocks):
        md = md.replace(f"@@CODE_BLOCK_{idx}@@", "```bash\n" + code + "\n```")
    md += references_md
    md = re.sub(r"\n{3,}", "\n\n", md).rstrip() + "\n"
    out_path.write_text(md)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("input", type=Path, help="Input .tex file")
    parser.add_argument("output", type=Path, nargs="?", help="Output .md file")
    parser.add_argument("--bbl", type=Path, help="Optional .bbl file for references")
    parser.add_argument("--no-toc", action="store_true", help="Do not include a clickable outline")
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    tex_path = args.input
    out_path = args.output or tex_path.with_name(tex_path.stem + "_confluence.md")
    bbl_path = args.bbl
    if bbl_path is None:
        candidate = tex_path.with_suffix(".bbl")
        bbl_path = candidate if candidate.exists() else None
    convert_tex(tex_path, out_path, bbl_path, include_toc=not args.no_toc)
    print(out_path)


if __name__ == "__main__":
    main()

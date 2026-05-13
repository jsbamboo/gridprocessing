#!/usr/bin/env python3
"""Convert a practical Markdown technical note to standalone HTML.

This lightweight converter is intentionally scoped to the Markdown produced by
_tool.tex_to_md.py: headings, paragraphs, fenced code blocks, pipe tables,
bullet lists, images, inline code, emphasis, bold text, and autolinks.

Usage:
  python3 _tool.md_to_html.py INPUT.md [OUTPUT.html] [--title TITLE] [--max-width 1200px]
"""

import argparse
import html
import re
from pathlib import Path


def slugify(text: str) -> str:
    text = re.sub(r"<[^>]+>", "", text)
    text = re.sub(r"[^\w\s-]", "", text.lower())
    text = re.sub(r"[\s_]+", "-", text).strip("-")
    return text or "section"


def inline_md(text: str) -> str:
    placeholders = []

    def hold(value: str) -> str:
        placeholders.append(value)
        return f"@@INLINE{len(placeholders) - 1}@@"

    text = html.escape(text)
    text = re.sub(r"!\[([^\]]*)\]\(([^)]+)\)", lambda m: hold(
        f'<img src="{html.escape(m.group(2), quote=True)}" alt="{html.escape(m.group(1), quote=True)}">'
    ), text)
    text = re.sub(r"`([^`]+)`", lambda m: hold(f"<code>{m.group(1)}</code>"), text)
    text = re.sub(r"&lt;(https?://[^&]+)&gt;", lambda m: hold(
        f'<a href="{html.escape(m.group(1), quote=True)}">{m.group(1)}</a>'
    ), text)
    text = re.sub(r"\[([^\]]+)\]\(([^)]+)\)", lambda m: hold(
        f'<a href="{html.escape(m.group(2), quote=True)}">{m.group(1)}</a>'
    ), text)
    text = re.sub(r"\*\*([^*]+)\*\*", r"<strong>\1</strong>", text)
    text = re.sub(r"(?<!\*)\*([^*\n]+)\*(?!\*)", r"<em>\1</em>", text)
    text = re.sub(r"(?<!\w)_([^_\n]+)_(?!\w)", r"<em>\1</em>", text)

    for idx, value in enumerate(placeholders):
        text = text.replace(f"@@INLINE{idx}@@", value)
    return text


def is_table_start(lines: list[str], idx: int) -> bool:
    if idx + 1 >= len(lines):
        return False
    return lines[idx].lstrip().startswith("|") and re.match(r"^\s*\|?\s*:?-{3,}:?\s*(\|\s*:?-{3,}:?\s*)+\|?\s*$", lines[idx + 1])


def split_table_row(line: str) -> list[str]:
    line = line.strip()
    if line.startswith("|"):
        line = line[1:]
    if line.endswith("|"):
        line = line[:-1]
    return [cell.strip() for cell in line.split("|")]


def render_table(lines: list[str], idx: int) -> tuple[str, int]:
    headers = split_table_row(lines[idx])
    idx += 2
    rows = []
    while idx < len(lines) and lines[idx].lstrip().startswith("|"):
        rows.append(split_table_row(lines[idx]))
        idx += 1

    out = ["<table>", "<thead><tr>"]
    out.extend(f"<th>{inline_md(cell)}</th>" for cell in headers)
    out.append("</tr></thead>")
    out.append("<tbody>")
    for row in rows:
        out.append("<tr>")
        out.extend(f"<td>{inline_md(cell)}</td>" for cell in row)
        out.append("</tr>")
    out.extend(["</tbody>", "</table>"])
    return "\n".join(out), idx


def render_markdown(markdown: str) -> tuple[str, str, list[tuple[int, str, str]]]:
    lines = markdown.splitlines()
    out = []
    title = ""
    paragraph = []
    in_code = False
    code_lang = ""
    code_lines = []
    in_list = False
    used_ids = set()
    toc = []
    idx = 0

    def flush_paragraph() -> None:
        nonlocal paragraph
        if paragraph:
            out.append("<p>" + inline_md(" ".join(paragraph)) + "</p>")
            paragraph = []

    def close_list() -> None:
        nonlocal in_list
        if in_list:
            out.append("</ul>")
            in_list = False

    while idx < len(lines):
        line = lines[idx]
        stripped = line.strip()

        if in_code:
            if stripped.startswith("```"):
                code = html.escape("\n".join(code_lines))
                cls = f' class="language-{html.escape(code_lang, quote=True)}"' if code_lang else ""
                out.append(f"<pre><code{cls}>{code}</code></pre>")
                in_code = False
                code_lang = ""
                code_lines = []
            else:
                code_lines.append(line)
            idx += 1
            continue

        if stripped.startswith("```"):
            flush_paragraph()
            close_list()
            in_code = True
            code_lang = stripped[3:].strip()
            idx += 1
            continue

        if not stripped:
            flush_paragraph()
            close_list()
            idx += 1
            continue

        if is_table_start(lines, idx):
            flush_paragraph()
            close_list()
            table_html, idx = render_table(lines, idx)
            out.append(table_html)
            continue

        heading = re.match(r"^(#{1,6})\s+(.+)$", stripped)
        if heading:
            flush_paragraph()
            close_list()
            level = len(heading.group(1))
            text = heading.group(2).strip()
            if not title and level == 1:
                title = re.sub(r"[*_`]", "", text)
            base_id = slugify(text)
            section_id = base_id
            suffix = 2
            while section_id in used_ids:
                section_id = f"{base_id}-{suffix}"
                suffix += 1
            used_ids.add(section_id)
            if 2 <= level <= 3:
                toc.append((level, section_id, re.sub(r"[*_`]", "", text)))
            out.append(f'<h{level} id="{section_id}">{inline_md(text)}</h{level}>')
            idx += 1
            continue

        if stripped.startswith("- "):
            flush_paragraph()
            if not in_list:
                out.append("<ul>")
                in_list = True
            out.append(f"<li>{inline_md(stripped[2:].strip())}</li>")
            idx += 1
            continue

        if re.match(r"^\d+\.\s+", stripped):
            flush_paragraph()
            close_list()
            item = re.sub(r"^\d+\.\s+", "", stripped)
            out.append(f"<p>{inline_md(item)}</p>")
            idx += 1
            continue

        close_list()
        paragraph.append(stripped)
        idx += 1

    if in_code:
        code = html.escape("\n".join(code_lines))
        out.append(f"<pre><code>{code}</code></pre>")
    flush_paragraph()
    close_list()
    return "\n".join(out), title or "Markdown Document", toc


def render_toc(toc: list[tuple[int, str, str]]) -> str:
    if not toc:
        return ""
    out = ['<nav class="toc" aria-label="Table of contents">', "<h2>Contents</h2>", "<ul>"]
    for level, section_id, text in toc:
        cls = "toc-h3" if level == 3 else "toc-h2"
        out.append(f'<li class="{cls}"><a href="#{html.escape(section_id, quote=True)}">{inline_md(text)}</a></li>')
    out.extend(["</ul>", "</nav>"])
    return "\n".join(out)


def page_template(title: str, body: str, max_width: str, toc_html: str) -> str:
    safe_title = html.escape(title)
    safe_width = html.escape(max_width, quote=True)
    return f"""<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>{safe_title}</title>
  <style>
    :root {{
      color-scheme: light;
      --text: #17202a;
      --muted: #5f6b7a;
      --border: #d8dee8;
      --code-bg: #f6f8fa;
      --link: #0645ad;
    }}
    body {{
      margin: 0;
      background: #ffffff;
      color: var(--text);
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Helvetica, Arial, sans-serif;
      font-size: 16px;
      line-height: 1.58;
    }}
    main {{
      max-width: {safe_width};
      margin: 0 auto;
      padding: 32px 40px 64px;
    }}
    h1, h2, h3, h4, h5, h6 {{
      line-height: 1.25;
      margin: 1.5em 0 0.55em;
      color: #111827;
    }}
    h1 {{
      font-size: 2rem;
      margin-top: 0;
      padding-bottom: 0.35em;
      border-bottom: 1px solid var(--border);
    }}
    h2 {{
      font-size: 1.45rem;
      border-bottom: 1px solid var(--border);
      padding-bottom: 0.2em;
    }}
    h3 {{ font-size: 1.18rem; }}
    p {{ margin: 0.8em 0; }}
    a {{ color: var(--link); }}
    code {{
      background: var(--code-bg);
      border-radius: 4px;
      padding: 0.12em 0.32em;
      font-family: ui-monospace, SFMono-Regular, Menlo, Consolas, "Liberation Mono", monospace;
      font-size: 0.92em;
    }}
    pre {{
      overflow-x: auto;
      background: var(--code-bg);
      border: 1px solid var(--border);
      border-radius: 6px;
      padding: 14px 16px;
      line-height: 1.45;
    }}
    pre code {{
      background: transparent;
      border: 0;
      padding: 0;
      font-size: 0.88rem;
    }}
    table {{
      width: 100%;
      border-collapse: collapse;
      margin: 1em 0 1.4em;
      font-size: 0.95rem;
    }}
    th, td {{
      border: 1px solid var(--border);
      padding: 8px 10px;
      vertical-align: top;
    }}
    th {{
      background: #f1f4f8;
      text-align: left;
      font-weight: 650;
    }}
    ul {{
      padding-left: 1.45rem;
      margin: 0.55em 0 1em;
    }}
    .toc {{
      border: 1px solid var(--border);
      border-radius: 6px;
      background: #fbfcfe;
      padding: 14px 18px;
      margin: 1.2em 0 2em;
    }}
    .toc h2 {{
      border: 0;
      padding: 0;
      margin: 0 0 0.5em;
      font-size: 1.05rem;
    }}
    .toc ul {{
      list-style: none;
      padding-left: 0;
      margin: 0;
    }}
    .toc li {{
      break-inside: avoid;
      margin: 0.25em 0;
    }}
    .toc .toc-h3 {{
      padding-left: 1.1em;
      font-size: 0.94rem;
    }}
    img {{
      max-width: 100%;
      height: auto;
      display: block;
      margin: 1.1em 0;
    }}
    @media (max-width: 760px) {{
      main {{
        padding: 22px 18px 44px;
      }}
      body {{
        font-size: 15px;
      }}
    }}
  </style>
</head>
<body>
  <main>
{toc_html}
{body}
  </main>
</body>
</html>
"""


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("input", type=Path, help="Input Markdown file")
    parser.add_argument("output", type=Path, nargs="?", help="Output HTML file")
    parser.add_argument("--title", help="Override HTML title")
    parser.add_argument("--max-width", default="1200px", help="CSS max-width for the page body")
    parser.add_argument("--no-toc", action="store_true", help="Do not include a clickable table of contents")
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    md_path = args.input
    out_path = args.output or md_path.with_suffix(".html")
    body, detected_title, toc = render_markdown(md_path.read_text())
    toc_html = "" if args.no_toc else render_toc(toc)
    html_text = page_template(args.title or detected_title, body, args.max_width, toc_html)
    out_path.write_text(html_text)
    print(out_path)


if __name__ == "__main__":
    main()

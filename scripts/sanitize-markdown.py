#!/usr/bin/env python3
"""
Converts GitHub-flavored markdown (with HTML tables, details/summary, ins tags)
into Azure DevOps-compatible markdown for PR comments.

Uses a proper HTML parser (not regex) for table conversion to handle nested
tables, rowspan/colspan headers, and inline HTML within cells.

Adapted from the Bitbucket pipe's sanitize-markdown.py — Azure DevOps has
the same rendering constraints (no <details>, limited HTML table support).
"""

import re
import sys
from html.parser import HTMLParser


class Node:
    def __init__(self, tag, attrs=None):
        self.tag = tag
        self.attrs = attrs or {}
        self.children = []

    def find_all(self, tag):
        result = []
        for child in self.children:
            if isinstance(child, Node):
                if child.tag == tag:
                    result.append(child)
                result.extend(child.find_all(tag))
        return result

    def get_text_md(self):
        parts = []
        for child in self.children:
            if isinstance(child, str):
                parts.append(child)
            elif isinstance(child, Node):
                t = child.tag
                if t == 'br':
                    parts.append(' ')
                elif t == 'sup':
                    inner = child.get_text_md().strip()
                    if inner:
                        parts.append(f'({inner})')
                elif t == 'a':
                    href = child.attrs.get('href', '')
                    text = child.get_text_md().strip()
                    parts.append(f'[{text}]({href})' if href and text else text or '')
                elif t == 'ins':
                    inner = child.get_text_md().strip()
                    parts.append(f'**{inner}**' if inner else '')
                elif t in ('b', 'strong'):
                    inner = child.get_text_md().strip()
                    parts.append(f'**{inner}**' if inner else '')
                elif t in ('i', 'em'):
                    inner = child.get_text_md().strip()
                    parts.append(f'*{inner}*' if inner else '')
                elif t == 'code':
                    inner = child.get_text_md().strip()
                    parts.append(f'`{inner}`' if inner else '')
                elif t == 'table':
                    pass
                elif t in ('details', 'summary'):
                    parts.append(child.get_text_md())
                else:
                    parts.append(child.get_text_md())
        return ''.join(parts)


class DOMBuilder(HTMLParser):
    VOID = {'br', 'hr', 'img', 'input', 'meta', 'link', 'col'}

    def __init__(self):
        super().__init__()
        self.root = Node('root')
        self._stack = [self.root]

    def handle_starttag(self, tag, attrs):
        node = Node(tag, dict(attrs))
        self._stack[-1].children.append(node)
        if tag not in self.VOID:
            self._stack.append(node)

    def handle_endtag(self, tag):
        for i in range(len(self._stack) - 1, 0, -1):
            if self._stack[i].tag == tag:
                self._stack = self._stack[:i]
                return

    def handle_data(self, data):
        if data:
            self._stack[-1].children.append(data)

    def handle_entityref(self, name):
        self._stack[-1].children.append(
            {'nbsp': ' ', 'amp': '&', 'lt': '<', 'gt': '>', 'quot': '"'}.get(name, f'&{name};')
        )

    def handle_charref(self, name):
        try:
            c = chr(int(name[1:], 16) if name.startswith('x') else int(name))
            self._stack[-1].children.append(c)
        except (ValueError, OverflowError):
            self._stack[-1].children.append(f'&#{name};')


def parse_html(html):
    b = DOMBuilder()
    b.feed(html)
    return b.root


def table_to_markdown(table_node):
    header_rows, data_rows = [], []
    for child in table_node.children:
        if not isinstance(child, Node):
            continue
        if child.tag == 'thead':
            header_rows.extend(
                tr for tr in child.children if isinstance(tr, Node) and tr.tag == 'tr'
            )
        elif child.tag == 'tbody':
            data_rows.extend(
                tr for tr in child.children if isinstance(tr, Node) and tr.tag == 'tr'
            )
        elif child.tag == 'tr':
            cells = [c for c in child.children if isinstance(c, Node) and c.tag in ('th', 'td')]
            if cells and all(c.tag == 'th' for c in cells):
                header_rows.append(child)
            else:
                data_rows.append(child)

    col_count = 0
    for row in header_rows + data_rows:
        n = sum(
            int(c.attrs.get('colspan', 1))
            for c in row.children
            if isinstance(c, Node) and c.tag in ('th', 'td')
        )
        col_count = max(col_count, n)
    if col_count == 0:
        return ''

    if header_rows:
        grid = [[None] * col_count for _ in range(len(header_rows))]
        for ri, row in enumerate(header_rows):
            ci = 0
            for cell in row.children:
                if not isinstance(cell, Node) or cell.tag not in ('th', 'td'):
                    continue
                cs = int(cell.attrs.get('colspan', 1))
                rs = int(cell.attrs.get('rowspan', 1))
                text = re.sub(r'\s+', ' ', cell.get_text_md()).strip()
                while ci < col_count and grid[ri][ci] is not None:
                    ci += 1
                if ci >= col_count:
                    break
                for r in range(ri, min(ri + rs, len(header_rows))):
                    for c in range(ci, min(ci + cs, col_count)):
                        grid[r][c] = text
                ci += cs
        merged = []
        for c in range(col_count):
            vals = list(
                dict.fromkeys(
                    grid[r][c] for r in range(len(header_rows)) if grid[r][c] is not None
                )
            )
            merged.append(vals[-1] if vals else '')
    else:
        merged = [''] * col_count

    lines = [
        '| ' + ' | '.join(h.replace('|', '\\|') for h in merged) + ' |',
        '|' + '|'.join(['---'] * col_count) + '|',
    ]
    nested = []

    for row in data_rows:
        cells = [c for c in row.children if isinstance(c, Node) and c.tag in ('td', 'th')]
        if not cells:
            continue
        if len(cells) == 1 and int(cells[0].attrs.get('colspan', 1)) > 1:
            for t in cells[0].find_all('table'):
                nested.append(table_to_markdown(t))
            continue
        texts = [
            re.sub(r'\s+', ' ', c.get_text_md()).strip().replace('|', '\\|')
            for c in cells
        ]
        while len(texts) < col_count:
            texts.append('')
        lines.append('| ' + ' | '.join(texts) + ' |')

    result = '\n'.join(lines)
    if nested:
        result += '\n\n' + '\n\n'.join(n for n in nested if n)
    return result


def find_top_level_tables(text):
    spans = []
    i = 0
    while i < len(text):
        m = re.search(r'<table[^>]*>', text[i:], re.IGNORECASE)
        if not m:
            break
        start = i + m.start()
        depth, j = 1, i + m.end()
        while j < len(text):
            o = re.search(r'<table[^>]*>', text[j:], re.IGNORECASE)
            c = re.search(r'</table\s*>', text[j:], re.IGNORECASE)
            if c is None:
                break
            if o and o.start() < c.start():
                depth += 1
                j += o.end()
            else:
                depth -= 1
                if depth == 0:
                    spans.append((start, j + c.end()))
                    i = j + c.end()
                    break
                j += c.end()
        else:
            break
        if depth != 0:
            i = start + 1
    return spans


def sanitize(text):
    text = re.sub(r'<ins>(.*?)</ins>', r'**\1**', text, flags=re.DOTALL)

    for start, end in reversed(find_top_level_tables(text)):
        dom = parse_html(text[start:end])
        tables = dom.find_all('table')
        if tables:
            text = text[:start] + '\n' + table_to_markdown(tables[0]) + '\n' + text[end:]

    text = re.sub(r'<details>\s*<summary>.*?</summary>', '', text, flags=re.DOTALL)
    text = re.sub(r'</details>', '', text, flags=re.IGNORECASE)
    text = re.sub(r'<details[^>]*>', '', text, flags=re.IGNORECASE)

    out = []
    for line in text.split('\n'):
        if line.strip().startswith('|') and not re.match(r'^\s*\|[-:| ]+\|\s*$', line):
            line = re.sub(r'<br\s*/?>', ' ', line)
            line = re.sub(r'<sup>(.*?)</sup>', r'(\1)', line)
            line = re.sub(
                r'<a[^>]*href="([^"]*)"[^>]*>(.*?)</a>', r'[\2](\1)', line, flags=re.DOTALL
            )
            line = line.replace('&nbsp;', ' ')
        out.append(line)
    text = '\n'.join(out)

    text = re.sub(r'<br\s*/?>', '\n', text)
    text = re.sub(r'<sup>(.*?)</sup>', r'(\1)', text)
    text = re.sub(r'<a[^>]*href="([^"]*)"[^>]*>(.*?)</a>', r'[\2](\1)', text, flags=re.DOTALL)
    text = text.replace('&nbsp;', ' ')
    text = re.sub(r'<!---?\s.*?-?-->', '', text, flags=re.DOTALL)
    text = re.sub(r'\n{4,}', '\n\n\n', text)

    return text


if __name__ == '__main__':
    if len(sys.argv) != 3:
        print(f"Usage: {sys.argv[0]} <input.md> <output.md>", file=sys.stderr)
        sys.exit(1)
    with open(sys.argv[1]) as f:
        content = f.read()
    result = sanitize(content)
    with open(sys.argv[2], 'w') as f:
        f.write(result)

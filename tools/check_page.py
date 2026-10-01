#!/usr/bin/env python3
"""Compare the shortened product page with its backup.

Usage: python3 tools/check_page.py [old.html] [new.html]

Reports, per language:
  - visible word counts (English = all body text not marked lang="sv";
    Swedish = all body text not marked lang="en"),
  - every number in the old page that is missing from the new page,
  - long dashes in the new page,
  - whether the ids and the contact block are unchanged.
"""
import re
import sys
from html.parser import HTMLParser

SKIP = {"script", "style", "head"}
VOID = {"meta", "link", "br", "img", "input", "hr", "wbr"}


class Text(HTMLParser):
    """Collect visible body text for one language."""

    def __init__(self, lang):
        super().__init__(convert_charrefs=True)
        self.lang = lang
        self.stack = []  # (tag, hidden)
        self.chunks = []

    def hidden(self):
        return any(h for _, h in self.stack)

    def handle_starttag(self, tag, attrs):
        if tag in VOID:
            return
        a = dict(attrs)
        hide = tag in SKIP or (a.get("lang") not in (None, self.lang) and tag != "html")
        self.stack.append((tag, hide))
        if tag in ("p", "div", "td", "th", "tr", "li", "dt", "dd", "h1", "h2", "h3", "section", "span"):
            self.chunks.append(" ")

    def handle_endtag(self, tag):
        if tag in VOID:
            return
        for i in range(len(self.stack) - 1, -1, -1):
            if self.stack[i][0] == tag:
                del self.stack[i:]
                break
        self.chunks.append(" ")

    def handle_data(self, data):
        if not self.hidden():
            self.chunks.append(data)

    def text(self):
        return re.sub(r"\s+", " ", "".join(self.chunks).replace(" ", " ")).strip()


def visible(html, lang):
    p = Text(lang)
    p.feed(html)
    return p.text()


def words(text):
    return [w for w in text.split() if re.search(r"[0-9A-Za-zÅÄÖåäö]", w)]


def numbers(text, lang):
    """Every number as a normalised token, plus every range and date as written."""
    found = set()
    for d in re.findall(r"\d{4}-\d{2}-\d{2}", text):
        found.add(d)
    text = re.sub(r"\d{4}-\d{2}-\d{2}", " ", text)
    if lang == "sv":
        pat = r"\d{1,3}(?:[  ]\d{3})+(?:,\d+)?|\d+(?:,\d+)?"
    else:
        pat = r"\d{1,3}(?:,\d{3})+(?:\.\d+)?|\d+(?:\.\d+)?"
    num = re.compile(pat)
    for m in num.finditer(text):
        t = m.group(0)
        if lang == "sv":
            t = re.sub(r"[  ]", "", t).replace(",", ".")
        else:
            t = t.replace(",", "")
        found.add(t)
    if lang == "sv":
        # Figures shared by both languages are written English-style (1,621).
        for m in re.finditer(r"\b\d{1,3}(?:,\d{3})+\b", text):
            found.add(m.group(0).replace(",", ""))
    # Ranges such as 5–8, 106,000–113,000 or "2 to 3" stay ranges.
    rng = re.compile(r"(%s)\s*(?:–|-|to|till)\s*(%s)" % (pat, pat))
    for m in rng.finditer(text):
        a, b = m.group(1), m.group(2)
        if lang == "sv":
            a, b = (re.sub(r"[  ]", "", x).replace(",", ".") for x in (a, b))
        else:
            a, b = (x.replace(",", "") for x in (a, b))
        found.add("range %s–%s" % (a, b))
    return found


def ids(html):
    return sorted(set(re.findall(r'\bid="([^"]+)"', html)))


def contact(html):
    m = re.search(r'<div class="contact">.*?</div>', html, re.S)
    return m.group(0) if m else None


def main():
    old_path = sys.argv[1] if len(sys.argv) > 1 else "index.backup.html"
    new_path = sys.argv[2] if len(sys.argv) > 2 else "index.html"
    old = open(old_path, encoding="utf-8").read()
    new = open(new_path, encoding="utf-8").read()
    ok = True
    for lang in ("en", "sv"):
        o, n = visible(old, lang), visible(new, lang)
        print("[%s] words: %d before, %d after (%.0f%%)" % (
            lang, len(words(o)), len(words(n)), 100.0 * len(words(n)) / len(words(o))))
        missing = sorted(numbers(o, lang) - numbers(n, lang))
        print("[%s] missing numbers: %s" % (lang, missing if missing else "none"))
        ok &= not missing
    dashes = [i + 1 for i, line in enumerate(new.splitlines()) if "—" in line or "&mdash;" in line]
    print("long dashes in new file: %s" % (dashes if dashes else "none"))
    ok &= not dashes
    same_ids = ids(old) == ids(new)
    print("ids unchanged: %s %s" % (same_ids, ids(new)))
    ok &= same_ids
    same_contact = contact(old) == contact(new)
    print("contact block unchanged: %s" % same_contact)
    ok &= same_contact
    print("ALL CHECKS PASS" if ok else "CHECKS FAILED")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())

#!/usr/bin/env python3
# 使い方: parse_instruction.py "<指示文>"  →  1行に "色 トレイ" を出す(例: red left)
# 例: "赤いブロックを左のトレイへ" / "赤は左、青は右"
import sys, re

COLORS = {"red": ["赤", "red"], "blue": ["青", "blue"], "green": ["緑", "green"]}
TRAYS = {"left": ["左", "left"], "right": ["右", "right"]}

def find(clause, table):
    hits = [k for k, words in table.items() if any(w in clause.lower() for w in words)]
    return hits

text = " ".join(sys.argv[1:])
clauses = [c.strip() for c in re.split(r"[、,，。;\n]| and |そして|その後", text) if c.strip()]
pairs = []
for c in clauses:
    cs, ts = find(c, COLORS), find(c, TRAYS)
    if len(cs) == 1 and len(ts) == 1:
        pairs.append((cs[0], ts[0]))
    else:
        print("解釈できない句: %r (色=%s, トレイ=%s)" % (c, cs, ts), file=sys.stderr)
        sys.exit(1)
if not pairs:
    print("指示が空です", file=sys.stderr); sys.exit(1)
if len({t for _, t in pairs}) < len(pairs) or len({c for c, _ in pairs}) < len(pairs):
    print("同じ色、または同じトレイが複数回指定されています(未対応)", file=sys.stderr); sys.exit(1)
for c, t in pairs:
    print(c, t)

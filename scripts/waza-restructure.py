#!/usr/bin/env python3
"""TASK-033: restructure SKILL.md files for waza.

Reads each skill from git HEAD (so it can be re-run), then
  1. rewrites the frontmatter to spec fields (name, description, metadata),
  2. moves bulky reference sections verbatim into references/<slug>.md and lists them under "## References",
  3. replaces absolute tool paths with bare command names and sibling-skill links with plain names,
  4. proves that no line was lost: lines(new SKILL.md body + references) == lines(normalised original body).
Usage: python3 scripts/waza-restructure.py [skills-dir]
"""
import re, subprocess, sys, pathlib, collections

SK = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else "skills")

MOVE = [  # heading regexes, matched against the heading text without its number
    r"Example", r"Reference implementation", r"Acceptance [Cc]riteria", r"Output [Ff]ile [Ss]chema", r"Output [Ss]chema",
    r"Exact API", r"Sensitive Field Stripping", r"Expected output tree", r"Run report format", r"Per-Run Workflow",
    r"Terraform Resources", r"Provider template", r"What `check.sh` verifies", r"What NOT to Capture",
    r"Coding (&|and)? ?(Naming )?[Ss]tandards", r"UUID prohibition", r"Idempotency", r"Re-run",
]
EXTRA_MOVE = {  # per-skill additional sections, added only where the budget needs them
    "discovery-admin-config": [r"Human vs machine auth detection", r"Harness expectation", r"Related skills", r"Sensitive field strip"],
    "discovery-identity-teams": [r"Harness expectations", r"Empty-set handling", r"Related skills"],
    "discovery-secrets-engines": [r"Built-in mount skip list", r"Sensitive field strip table", r"Zero TTL handling", r"Related skills"],
    "discovery-orchestrator": [r"Prerequisites"],
    "vault-codifier-conventions": [r"Tool selection", r"Naming", r"Namespace targeting and imports", r"State layers"],
    "codification-namespaces": [r"Governance"],
    "discovery-policies": [r"Deduplication"],
}
# '###' subsections under a kept '## Process' section that are moved out (matched on the heading text)
MOVE_TABLE = {"discovery-secrets-engines": "engine-dispatch-table"}   # first table of a kept section -> references/<name>.md
MOVE_SUB = [r"Exact curl commands", r"Detailed Steps", r"Reference implementation"]

DNU = {
    "discovery": "writing Terraform (use the matching codification-* skill), or any write to Vault",
    "codification": "reading Vault (use the matching discovery-* skill), or applying the generated Terraform",
    "validation": "a production cluster (harness only), or changing the generated output",
    "vault-codifier": "running discovery or generating a resource (use the discovery-* and codification-* skills)",
    "vault-exporter": "a production cluster without review, or anything but creating the read-only exporter",
}


def git_show(path):
    return subprocess.run(["git", "show", f"HEAD:{path}"], capture_output=True, text=True, check=True).stdout


def norm(s):
    s = re.sub(r"\]\(scripts/\)", "](scripts/run.sh)", s)   # waza rejects links to a directory; run.sh is the entry point
    s = re.sub(r"/opt/homebrew/bin/", "", s)
    s = re.sub(r"\[(`[^`]+`)\]\(\.\./[a-z-]+/SKILL\.md\)", r"\1", s)
    s = re.sub(r"\[([^\]]+)\]\(\.\./[a-z-]+/SKILL\.md\)", r"\1", s)
    return s


def parse_front(text):
    m = re.match(r"---\n(.*?)\n---\n(.*)", text, re.S)
    fm, body = m.group(1), m.group(2)
    d, key, lst = {}, None, None
    for line in fm.split("\n"):
        if re.match(r"^[a-z_]+:", line):
            key, _, v = line.partition(":"); v = v.strip()
            if v in (">", "|"): d[key] = []; lst = "text"
            elif v == "": d[key] = []; lst = "list"
            else: d[key] = v.strip('"'); lst = None
        elif key and line.strip():
            if lst == "text": d[key].append(line.strip())
            else: d[key].append(line.strip().lstrip("- ").strip().strip('"'))
    if isinstance(d.get("description"), list): d["description"] = " ".join(d["description"])
    return d, body


def split_sections(body):
    """Split on '## ' headings that are outside fenced code blocks."""
    parts, cur, fence = [], [], False
    for line in body.split("\n"):
        if line.lstrip().startswith("```"): fence = not fence
        if not fence and line.startswith("## ") and cur:
            parts.append("\n".join(cur) + "\n"); cur = []
        cur.append(line)
    parts.append("\n".join(cur))
    return parts


def slug(h):
    return re.sub(r"-+", "-", re.sub(r"[^a-z0-9]+", "-", h.lower())).strip("-")


def run(skill):
    name = skill.name
    rel = f"skills/{name}/SKILL.md"
    orig = git_show(rel)
    fm, body = parse_front(orig)
    body = norm(body)
    parts = split_sections(body)
    keep, moved = [parts[0]], []
    pats = MOVE + EXTRA_MOVE.get(name, [])
    for p in parts[1:]:
        h = re.match(r"## (.*)", p).group(1)
        h0 = re.sub(r"^\d+\.?\s*", "", h).strip()
        if any(re.match(pat, h0) for pat in pats):
            moved.append((h0, p))
        else:
            keep.append(p)
    keep2 = []
    for p in keep:
        out, cur, fence, sub = [], [], False, None
        blocks = []   # (heading or None, text)
        buf = []; head = None
        for line in p.split("\n"):
            if line.lstrip().startswith("```"): fence = not fence
            if not fence and re.match(r"### ", line):
                blocks.append((head, "\n".join(buf))); buf = []; head = line[4:].strip()
            buf.append(line)
        blocks.append((head, "\n".join(buf)))
        kept = []
        for h, t in blocks:
            if h and any(re.match(pat, h) for pat in MOVE_SUB):
                moved.append((h, "## " + h + "\n" + "\n".join(t.split("\n")[1:]) + ("\n" if not t.endswith("\n") else "")))
            else:
                kept.append(t)
        keep2.append("\n".join(kept))
    keep = keep2
    if name in MOVE_TABLE:
        out = []
        for p in keep:
            lines_ = p.split("\n"); idx = [i for i, l in enumerate(lines_) if l.startswith("|")]
            if idx and not any(m[0] == MOVE_TABLE[name] for m in moved) and p.startswith("## Process"):
                a, b = idx[0], idx[-1]
                tbl = "\n".join(lines_[a:b + 1])
                moved.append((MOVE_TABLE[name], "## Engine dispatch table\n\n" + tbl + "\n"))
                lines_[a:b + 1] = [f"> Table moved verbatim: see [{MOVE_TABLE[name]}](references/{MOVE_TABLE[name]}.md)."]
            out.append("\n".join(lines_))
        keep = out
    # references
    refdir = skill / "references"
    if refdir.exists():
        for f in refdir.glob("*.md"): f.unlink()
    used, refs = set(), []
    for h0, p in moved:
        s = slug(h0) or "section"; base = s; i = 2
        while s in used: s = f"{base}-{i}"; i += 1
        used.add(s); refdir.mkdir(exist_ok=True)
        text = re.sub(r"\]\((scripts|references)/", r"](../\1/", p.rstrip("\n") + "\n")
        (refdir / f"{s}.md").write_text(text)
        refs.append((h0, s))
    newbody = "".join(keep).rstrip("\n") + "\n"
    if refs:
        newbody += "\n## References\n\nLoad these when you need the detail; each is moved verbatim from this file.\n\n"
        newbody += "".join(f"- [{h}](references/{s}.md)\n" for h, s in refs)
    # frontmatter
    trig = fm.get("triggers", [])
    kind = next(k for k in DNU if name.startswith(k))
    desc = fm["description"].rstrip()
    desc = re.sub(r"\s+", " ", desc)
    use = "; ".join([t for t in trig if not re.match(r"TASK-\d+$", t)][:2])
    desc = re.sub(r"\s*TASK-\d+[^.]*(\([^)]*\))?[^.]*\.", "", desc)  # ids live in metadata
    PROC = {"discovery": "Run after exporter setup, then codify.",
            "codification": "Run after discovery, then validate.",
            "validation": "Run after codification, then read the report."}
    if kind in PROC and not desc.startswith("Use when"):
        desc = "Use when you need to " + desc[0].lower() + desc[1:]
        if not desc.endswith("."): desc += "."
        desc += " " + PROC[kind]
    desc = f"{desc} USE FOR: {use}. DO NOT USE FOR: {DNU[kind]}."
    meta = []
    for k in ("task", "capability", "role"):
        if k in fm: meta.append(f'  {k}: "{fm[k]}"')
    if fm.get("depends_on"): meta.append('  depends_on: "' + ", ".join(fm["depends_on"]) + '"')
    meta.append('  version: "1.0"')
    import textwrap
    folded = "\n".join("  " + l for l in textwrap.wrap(desc, 112))
    front = f"---\nname: {name}\ndescription: >\n{folded}\nmetadata:\n" + "\n".join(meta) + "\n---\n"
    (skill / "SKILL.md").write_text(front + newbody)
    # lossless proof
    def lines(s): return collections.Counter(re.sub(r"\]\(\.\./(scripts|references)/", r"](\1/", re.sub(r"^#{2,3} ", "## ", l)) for l in s.split("\n") if l.strip() and not l.startswith("> Table moved verbatim") and l != "## Engine dispatch table")
    after = lines(newbody.split("\n## References\n")[0] if refs else newbody)
    for f in refdir.glob("*.md") if refdir.exists() else []: after += lines(f.read_text())
    before = lines(body)
    lost = before - after; gained = after - before
    return name, len(moved), sum(lost.values()), sum(gained.values())


if __name__ == "__main__":
    bad = 0
    for sk in sorted(SK.iterdir()):
        if not (sk / "SKILL.md").exists(): continue
        n, mv, lost, gained = run(sk)
        flag = "" if lost == 0 and gained == 0 else "   <-- CHECK"
        if flag: bad = 1
        print(f"{n:32s} moved {mv:2d} sections; lines lost {lost}, gained {gained}{flag}")
    sys.exit(bad)

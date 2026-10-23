"""Generate E-SUGID documentation diagrams (white paper, black borders skin)."""
import html
import math
import os
import sys

OUT = sys.argv[1] if len(sys.argv) > 1 else r"E:\programs\esugid\docs\diagrams"

PAPER = "#ffffff"
INK = "#000000"
MUTED = "#333333"
SOFT = "#555555"
SANS = "'Geist', system-ui, sans-serif"
MONO = "'Geist Mono', ui-monospace, monospace"
SERIF = "'Instrument Serif', 'Noto Serif', serif"
FN, FS, FA, FT = 14, 11, 10, 9  # node name, sublabel, arrow label, tag

FONT_LINK = ('<link href="https://fonts.googleapis.com/css2?family=Instrument+Serif:ital@0;1'
             '&family=Geist:wght@400;500;600&family=Geist+Mono:wght@400;500;600'
             '&family=Noto+Serif:ital@0;1&display=swap" rel="stylesheet">')


def esc(s):
    return html.escape(str(s), quote=True)


def r4(v):
    return int(math.ceil(v / 4.0) * 4)


def tw(s, size, mono=False):
    return len(s) * size * (0.62 if mono else 0.60)


def text(x, y, s, size=FN, weight=None, fam=SANS, fill=INK, anchor="middle", ls=None):
    attrs = [f'x="{x}"', f'y="{y}"', f'fill="{fill}"', f'font-size="{size}"',
             f'font-family="{fam}"', f'text-anchor="{anchor}"']
    if weight:
        attrs.append(f'font-weight="{weight}"')
    if ls:
        attrs.append(f'letter-spacing="{ls}"')
    return f'<text {" ".join(attrs)}>{esc(s)}</text>'


def tag(x, y, label):
    w = r4(tw(label, FT, True) + 12)
    return (f'<rect x="{x}" y="{y}" width="{w}" height="16" rx="2" fill="none" stroke="{INK}" stroke-width="0.8"/>'
            + text(x + w / 2, y + 11.5, label, FT, 500, MONO, INK, ls="0.08em"))


def box(x, y, w, h, name, sub=None, tg=None, kind="normal", rx=6):
    """kind: normal | focal | external."""
    sw = {"normal": 1.2, "focal": 2.6, "external": 1.2}[kind]
    dash = ' stroke-dasharray="5,4"' if kind == "external" else ""
    out = [f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="{rx}" fill="{PAPER}"/>',
           f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="{rx}" fill="{PAPER}" stroke="{INK}" stroke-width="{sw}"{dash}/>']
    top = y
    if tg:
        out.append(tag(x + 10, y + 10, tg))
        top = y + 26
    names = name.split("\n")
    lh = FN + 4
    block = len(names) * lh + (FS + 6 if sub else 0)
    base = top + (y + h - top - block) / 2 + FN - 2
    cx = x + w / 2
    for i, n in enumerate(names):
        out.append(text(cx, round(base + i * lh, 1), n, FN, 600))
    if sub:
        out.append(text(cx, round(base + (len(names) - 1) * lh + FS + 6, 1), sub, FS, None, MONO, SOFT))
    return "\n".join(out)


def ortho(pts, r=8):
    def sgn(v):
        return (v > 0) - (v < 0)
    d = f"M{pts[0][0]},{pts[0][1]}"
    n = len(pts)
    for i in range(1, n - 1):
        (x0, y0), (x1, y1), (x2, y2) = pts[i - 1], pts[i], pts[i + 1]
        lin = abs(x1 - x0) + abs(y1 - y0)
        lout = abs(x2 - x1) + abs(y2 - y1)
        rr = min(r, lin if i == 1 else lin / 2, lout if i == n - 2 else lout / 2)
        ux, uy = sgn(x1 - x0), sgn(y1 - y0)
        vx, vy = sgn(x2 - x1), sgn(y2 - y1)
        d += f" L{x1 - ux * rr},{y1 - uy * rr} Q{x1},{y1} {x1 + vx * rr},{y1 + vy * rr}"
    d += f" L{pts[-1][0]},{pts[-1][1]}"
    return d


def arrow(pts, dashed=False, marker="arrow", width=1.3, color=MUTED):
    dash = ' stroke-dasharray="5,4"' if dashed else ""
    mk = f' marker-end="url(#{marker})"' if marker else ""
    return f'<path d="{ortho(pts)}" fill="none" stroke="{color}" stroke-width="{width}"{dash}{mk}/>'


def label(cx, cy, s):
    lines = s.split("\n")
    w = r4(max(len(l) for l in lines) * FA * 0.62 + 12)
    lh = FA + 4
    h = r4(len(lines) * lh + 4)
    out = [f'<rect x="{cx - w / 2}" y="{cy - h / 2}" width="{w}" height="{h}" rx="2" fill="{PAPER}"/>']
    first = cy - len(lines) * lh / 2 + FA - 1
    for i, l in enumerate(lines):
        out.append(text(cx, round(first + i * lh, 1), l, FA, 500, MONO, SOFT, ls="0.06em"))
    return "\n".join(out), w, h


def lab_h(cx, y, s, side="above", gap=6):
    """Label for a horizontal segment at y."""
    _, w, h = label(0, 0, s)
    cy = y - gap - h / 2 if side == "above" else y + gap + h / 2
    return label(cx, cy, s)[0]


def lab_v(x, cy, s, side="right", gap=8):
    """Label beside a vertical segment at x."""
    _, w, h = label(0, 0, s)
    cx = x + gap + w / 2 if side == "right" else x - gap - w / 2
    return label(cx, cy, s)[0]


MARKERS = f"""
<marker id="arrow" markerWidth="10" markerHeight="8" refX="9" refY="4" orient="auto"><polygon points="0 0, 10 4, 0 8" fill="{MUTED}"/></marker>
<marker id="gen" markerWidth="14" markerHeight="12" refX="13" refY="6" orient="auto" markerUnits="userSpaceOnUse"><polygon points="1 1, 13 6, 1 11" fill="{PAPER}" stroke="{INK}" stroke-width="1.2"/></marker>"""


def legend(y, W, items):
    """items: list of (kind, text). kinds: solid, dashed, line, box, focal, external, gen, oval, diamond, dot."""
    out = [f'<line x1="32" y1="{y - 12}" x2="{W - 32}" y2="{y - 12}" stroke="{INK}" stroke-opacity="0.15" stroke-width="0.8"/>',
           text(32, y + 12, "LEGEND", FT, 500, MONO, SOFT, anchor="start", ls="0.14em")]
    x = 112
    for kind, t in items:
        if kind in ("solid", "dashed", "line", "gen"):
            mk = {"solid": "arrow", "dashed": "arrow", "line": None, "gen": "gen"}[kind]
            dash = ' stroke-dasharray="5,4"' if kind == "dashed" else ""
            mka = f' marker-end="url(#{mk})"' if mk else ""
            out.append(f'<line x1="{x}" y1="{y + 8}" x2="{x + 36}" y2="{y + 8}" stroke="{MUTED}" stroke-width="1.3"{dash}{mka}/>')
        elif kind in ("box", "focal", "external"):
            sw = 2.6 if kind == "focal" else 1.2
            dash = ' stroke-dasharray="5,4"' if kind == "external" else ""
            out.append(f'<rect x="{x}" y="{y}" width="36" height="16" rx="3" fill="{PAPER}" stroke="{INK}" stroke-width="{sw}"{dash}/>')
        elif kind == "oval":
            out.append(f'<rect x="{x}" y="{y}" width="36" height="16" rx="8" fill="{PAPER}" stroke="{INK}" stroke-width="1.2"/>')
        elif kind == "diamond":
            out.append(f'<polygon points="{x + 18},{y - 2} {x + 36},{y + 8} {x + 18},{y + 18} {x},{y + 8}" fill="{PAPER}" stroke="{INK}" stroke-width="1.2"/>')
        elif kind == "dot":
            out.append(f'<circle cx="{x + 18}" cy="{y + 8}" r="5" fill="{INK}"/>')
        elif kind == "ellipse":
            out.append(f'<ellipse cx="{x + 18}" cy="{y + 8}" rx="18" ry="9" fill="{PAPER}" stroke="{INK}" stroke-width="1.2"/>')
        elif kind == "store":
            out.append(f'<path d="M{x + 36},{y} H{x} V{y + 16} H{x + 36}" fill="none" stroke="{INK}" stroke-width="1.2"/>'
                       f'<line x1="{x + 10}" y1="{y}" x2="{x + 10}" y2="{y + 16}" stroke="{INK}" stroke-width="1.2"/>')
        out.append(text(x + 46, y + 12, t, FA + 1, None, SANS, MUTED, anchor="start"))
        x += 46 + int(tw(t, FA + 1)) + 36
    return "\n".join(out)


def page(slug, eyebrow, title, desc, W, H, body):
    return f"""<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>{esc(title)}</title>
  {FONT_LINK}
  <style>
    *, *::before, *::after {{ box-sizing: border-box; margin: 0; padding: 0; }}
    :root {{
      --color-paper:  {PAPER};
      --color-ink:    {INK};
      --color-muted:  {MUTED};
      --font-sans:    {SANS};
      --font-serif:   {SERIF};
      --font-mono:    {MONO};
    }}
    body {{
      font-family: var(--font-sans);
      background: var(--color-paper);
      color: var(--color-ink);
      min-height: 100vh;
      display: flex;
      align-items: center;
      justify-content: center;
      padding: 3rem 2rem;
    }}
    .frame {{ max-width: {W}px; width: 100%; }}
    .diagram-container {{ width: 100%; overflow-x: auto; }}
    .eyebrow {{
      font-family: var(--font-mono);
      font-size: 0.7rem;
      font-weight: 500;
      letter-spacing: 0.18em;
      text-transform: uppercase;
      color: var(--color-muted);
      margin-bottom: 0.5rem;
    }}
    h1 {{
      font-family: var(--font-serif);
      font-size: clamp(1.5rem, 2.4vw + 0.75rem, 2.2rem);
      font-weight: 400;
      letter-spacing: -0.02em;
      line-height: 1.15;
      color: var(--color-ink);
      margin-bottom: 1.5rem;
    }}
    svg {{ width: 100%; min-width: {W}px; display: block; }}
    @media print {{
      .diagram-container {{ overflow-x: visible; }}
      svg {{ min-width: 0; }}
    }}
  </style>
</head>
<body>
  <div class="frame">
    <p class="eyebrow">{esc(eyebrow)}</p>
    <h1>{esc(title)}</h1>
    <div class="diagram-container">
      <svg viewBox="0 0 {W} {H}" xmlns="http://www.w3.org/2000/svg" role="img" aria-labelledby="{slug}-title {slug}-desc">
        <title id="{slug}-title">{esc(title)}</title>
        <desc id="{slug}-desc">{esc(desc)}</desc>
        <defs>{MARKERS}
        </defs>
        <rect width="100%" height="100%" fill="{PAPER}"/>
{body}
      </svg>
    </div>
  </div>
</body>
</html>
"""


def write(slug, content):
    os.makedirs(OUT, exist_ok=True)
    path = os.path.join(OUT, slug + ".html")
    with open(path, "w", encoding="utf-8") as f:
        f.write(content)
    print(path)


# ---------------------------------------------------------------- 1. Architecture
def architecture():
    W, H = 1200, 700
    b = []
    # zone (drawn first)
    b.append(f'<rect x="40" y="256" width="1120" height="136" rx="8" fill="none" stroke="{INK}" stroke-width="1" stroke-dasharray="6,4"/>')
    zl = "FIREBASE PROJECT · e-sugid"
    zw = r4(len(zl) * FT * 0.76 + 16)
    b.append(f'<rect x="184" y="249" width="{zw}" height="14" fill="{PAPER}"/>')
    b.append(text(184 + zw / 2, 260, zl, FT, 500, MONO, SOFT, ls="0.14em"))
    # arrows
    b.append(arrow([(508, 152), (508, 196), (152, 196), (152, 296)]))
    b.append(lab_h(330, 196, "SIGN IN"))
    b.append(arrow([(548, 152), (548, 236), (376, 236), (376, 296)]))
    b.append(lab_h(462, 236, "REAL-TIME DATA"))
    b.append(arrow([(600, 152), (600, 296)]))
    b.append(lab_v(600, 216, "CALLABLE APIS"))
    b.append(arrow([(720, 100), (1048, 100), (1048, 296)]))
    b.append(lab_h(900, 100, "UPLOAD FILES"))
    b.append(arrow([(824, 296), (824, 128), (720, 128)]))
    b.append(lab_v(824, 208, "PUSH ALERTS"))
    b.append(arrow([(480, 116), (344, 116)]))
    b.append(lab_h(412, 116, "MAP · WEATHER"))
    b.append(arrow([(512, 320), (464, 320)]))
    b.append(arrow([(464, 344), (512, 344)], dashed=True))
    b.append(arrow([(688, 332), (736, 332)]))
    b.append(arrow([(252, 512), (252, 440), (152, 440), (152, 368)]))
    b.append(arrow([(376, 512), (376, 368)]))
    b.append(arrow([(452, 512), (452, 448), (568, 448), (568, 368)]))
    b.append(lab_v(376, 488, "MANAGE RECORDS", "left"))
    b.append(arrow([(632, 368), (632, 512)]))
    b.append(arrow([(664, 368), (664, 456), (856, 456), (856, 512)]))
    # nodes
    b.append(box(136, 80, 208, 72, "Map & Weather APIs", "Google Maps · Open-Meteo", "EXTERNAL", "external"))
    b.append(box(480, 80, 240, 72, "Resident Mobile App", "Flutter · Android", "CLIENT"))
    b.append(box(64, 296, 176, 72, "Authentication", "email · Google · OTP", "FIREBASE"))
    b.append(box(288, 296, 176, 72, "Cloud Firestore", "NoSQL · security rules", "DATABASE"))
    b.append(box(512, 296, 176, 72, "Cloud Functions", "APIs · triggers · cron", "BACKEND", "focal"))
    b.append(box(736, 296, 176, 72, "Cloud Messaging", "FCM topics · devices", "FIREBASE"))
    b.append(box(960, 296, 176, 72, "Cloud Storage", "photos · documents", "FIREBASE"))
    b.append(box(232, 512, 240, 72, "Staff Admin Console", "web · Firebase Hosting", "CLIENT"))
    b.append(box(544, 512, 176, 72, "Gemini API", "E-SUGID Assistant", "EXTERNAL", "external"))
    b.append(box(768, 512, 176, 72, "Brevo Email API", "OTP · invitations", "EXTERNAL", "external"))
    b.append(legend(644, W, [("solid", "Request / data flow"), ("dashed", "Event trigger"),
                             ("focal", "Core backend"), ("box", "E-SUGID component"),
                             ("external", "Third-party service")]))
    write("01-system-architecture", page(
        "system-architecture", "System Architecture · E-SUGID", "E-SUGID System Architecture",
        "The resident mobile app and staff admin console use Firebase Authentication, Firestore, Storage and Cloud "
        "Functions, which also drive push messaging and call the Gemini and Brevo services.",
        W, H, "\n".join(b)))


# ---------------------------------------------------------------- 2. Use case
def actor(cx, cy, name):
    s = f"stroke=\"{INK}\" stroke-width=\"1.6\" fill=\"none\""
    return "\n".join([
        f'<circle cx="{cx}" cy="{cy - 30}" r="10" fill="{PAPER}" stroke="{INK}" stroke-width="1.6"/>',
        f'<line x1="{cx}" y1="{cy - 20}" x2="{cx}" y2="{cy + 8}" {s}/>',
        f'<line x1="{cx - 18}" y1="{cy - 10}" x2="{cx + 18}" y2="{cy - 10}" {s}/>',
        f'<path d="M{cx - 14},{cy + 30} L{cx},{cy + 8} L{cx + 14},{cy + 30}" {s}/>',
        text(cx, cy + 48, name, 13, 600),
    ])


def usecase(cx, cy, name, focal=False):
    sw = 2.6 if focal else 1.2
    return (f'<ellipse cx="{cx}" cy="{cy}" rx="140" ry="24" fill="{PAPER}" stroke="{INK}" stroke-width="{sw}"/>'
            + text(cx, cy + 4.5, name, 13, 500))


def use_case():
    W, H = 1360, 780
    b = []
    b.append(f'<rect x="220" y="96" width="760" height="592" rx="8" fill="none" stroke="{INK}" stroke-width="1.4"/>')
    b.append(text(600, 124, "E-SUGID Community Services System", 15, 600))
    res = ["Register & verify residency", "View announcements & alerts", "Submit & track a concern",
           "Report an emergency", "Request documents & helpdesk", "Join Bayanihan, jobs & marketplace",
           "Ask the E-SUGID Assistant"]
    staff = ["Publish announcements", "Handle assigned concerns", "Respond to emergency reports",
             "Verify resident accounts", "Request staff accounts"]
    it = ["Approve staff accounts", "Manage departments & orgs", "Set access policies & audit"]
    ry = [168 + 80 * i for i in range(7)]
    sy = [168 + 64 * i for i in range(5)]
    iy = [520, 584, 648]
    # resident associations (left)
    ports = [372 + 12 * i for i in range(7)]
    vx = {0: 140, 1: 156, 2: 172, 4: 172, 5: 156, 6: 140}
    for i in range(7):
        if i == 3:
            b.append(arrow([(108, ports[i]), (260, ry[i])], marker=None))
        else:
            b.append(arrow([(108, ports[i]), (vx[i], ports[i]), (vx[i], ry[i]), (260, ry[i])], marker=None))
    # staff associations (right)
    sp = [272 + 12 * i for i in range(5)]
    svx = {0: 1012, 1: 996, 3: 996, 4: 1012}
    for i in range(5):
        if i == 2:
            b.append(arrow([(1072, sp[i]), (940, sy[i])], marker=None))
        else:
            b.append(arrow([(1072, sp[i]), (svx[i], sp[i]), (svx[i], sy[i]), (940, sy[i])], marker=None))
    ip = [572, 584, 596]
    for i in range(3):
        if i == 1:
            b.append(arrow([(1072, ip[i]), (940, iy[i])], marker=None))
        else:
            b.append(arrow([(1072, ip[i]), (1012, ip[i]), (1012, iy[i]), (940, iy[i])], marker=None))
    # generalisations
    b.append(arrow([(1100, 542), (1100, 356)], marker="gen", color=INK))
    b.append(arrow([(1232, 176), (1164, 176), (1164, 274), (1130, 274)], marker="gen", color=INK))
    b.append(arrow([(1232, 296), (1130, 296)], marker="gen", color=INK))
    b.append(arrow([(1232, 416), (1164, 416), (1164, 318), (1130, 318)], marker="gen", color=INK))
    for i, n in enumerate(res):
        b.append(usecase(400, ry[i], n, focal=(i == 2)))
    for i, n in enumerate(staff):
        b.append(usecase(800, sy[i], n))
    for i, n in enumerate(it):
        b.append(usecase(800, iy[i], n))
    b.append(actor(80, 408, "Resident"))
    b.append(actor(1100, 296, "Staff"))
    b.append(actor(1100, 584, "LGU IT Admin"))
    b.append(actor(1260, 176, "Barangay Official"))
    b.append(actor(1260, 296, "Organization Staff"))
    b.append(actor(1260, 416, "LGU Department"))
    b.append(legend(728, W, [("line", "Association"), ("gen", "Generalization (is a kind of)"),
                             ("ellipse", "Use case"), ("focal", "Core use case")]))
    write("02-use-case-diagram", page(
        "use-case", "Use Case Diagram · E-SUGID", "E-SUGID Use Case Diagram",
        "Residents register, receive announcements, submit concerns, report emergencies and request services; "
        "barangay, organization and department staff handle publishing, concerns, emergencies and verification; "
        "the LGU IT administrator approves staff and manages structure and policies.",
        W, H, "\n".join(b)))


# ---------------------------------------------------------------- 3. Flowchart
def oval(cx, y, w, name):
    return (f'<rect x="{cx - w / 2}" y="{y}" width="{w}" height="40" rx="20" fill="{PAPER}" stroke="{INK}" stroke-width="1.4"/>'
            + text(cx, y + 25, name, FN, 600))


def diamond(cx, cy, name, hw=96, hh=44):
    return (f'<polygon points="{cx},{cy - hh} {cx + hw},{cy} {cx},{cy + hh} {cx - hw},{cy}" fill="{PAPER}" stroke="{INK}" stroke-width="1.4"/>'
            + text(cx, cy + 5, name, 13, 600))


def flowchart():
    W, H = 900, 1400
    b = []
    M, R = 320, 680
    # arrows
    b.append(arrow([(M, 104), (M, 136)]))
    b.append(arrow([(M, 188), (M, 224)]))
    b.append(arrow([(416, 268), (580, 268)]))
    b.append(lab_h(498, 268, "NO"))
    b.append(arrow([(R, 292), (R, 324)]))
    b.append(arrow([(580, 348), (324, 348)]))
    b.append(arrow([(M, 312), (M, 392)]))
    b.append(lab_v(M, 330, "YES"))
    b.append(arrow([(424, 436), (580, 436)]))
    b.append(lab_h(498, 436, "NO"))
    b.append(arrow([(R, 460), (R, 492)]))
    b.append(arrow([(M, 480), (M, 528)]))
    b.append(lab_v(M, 504, "YES"))
    b.append(arrow([(416, 572), (580, 572)]))
    b.append(lab_h(498, 572, "STAFF"))
    b.append(arrow([(M, 616), (M, 656)]))
    b.append(lab_v(M, 636, "RESIDENT"))
    for y0, y1 in [(708, 740), (792, 824), (876, 908), (960, 992), (1044, 1080), (1168, 1204), (1256, 1288)]:
        b.append(arrow([(M, y0), (M, y1)]))
    b.append(lab_v(M, 1186, "YES"))
    b.append(arrow([(R, 596), (R, 1018), (440, 1018)]))
    b.append(arrow([(224, 1124), (160, 1124), (160, 1018), (200, 1018)]))
    b.append(lab_h(192, 1124, "NO"))
    b.append(lab_v(160, 1071, "KEEP WORKING", "left"))
    # nodes
    b.append(oval(M, 64, 200, "Start"))
    b.append(box(200, 136, 240, 52, "Launch E-SUGID", "app or admin console"))
    b.append(diamond(M, 268, "Signed in?"))
    b.append(box(580, 244, 200, 48, "Log in or register", "email · Google"))
    b.append(box(580, 324, 200, 48, "Verify email OTP", "6-digit code"))
    b.append(f'<circle cx="{M}" cy="348" r="5" fill="{INK}"/>')
    b.append(diamond(M, 436, "Account approved?", 104))
    b.append(box(580, 412, 200, 48, "Show pending status", "await review"))
    b.append(oval(R, 492, 160, "End"))
    b.append(diamond(M, 572, "User role?"))
    b.append(box(580, 548, 200, 48, "Open staff console", "dashboard · queues"))
    b.append(box(200, 656, 240, 52, "Choose a service", "concern · SOS · document"))
    b.append(box(200, 740, 240, 52, "Submit report", "details · photo · location"))
    b.append(box(200, 824, 240, 52, "Validate & route", "Cloud Functions", kind="focal"))
    b.append(box(200, 908, 240, 52, "Notify assigned office", "push · in-app"))
    b.append(box(200, 992, 240, 52, "Review & update status", "assigned staff"))
    b.append(diamond(M, 1124, "Resolved?"))
    b.append(box(200, 1204, 240, 52, "Notify resident of result", "status · public update"))
    b.append(oval(M, 1288, 200, "End"))
    b.append(legend(1352, W, [("oval", "Start / end"), ("box", "Process"), ("diamond", "Decision"),
                              ("dot", "Merge"), ("focal", "Core step")]))
    write("03-system-flowchart", page(
        "flowchart", "System Flowchart · E-SUGID", "E-SUGID System Flowchart",
        "Users sign in or register with email OTP, unapproved accounts wait for review, residents submit a "
        "service report that Cloud Functions validate and route, and staff update it until it is resolved and "
        "the resident is notified.",
        W, H, "\n".join(b)))


# ---------------------------------------------------------------- 4a. DFD context
def dfd_context():
    W, H = 1120, 660
    b = []
    # flows
    b.append(arrow([(224, 264), (440, 264)]))
    b.append(lab_h(332, 264, "PROFILE · CONCERNS\nSOS · REQUESTS"))
    b.append(arrow([(440, 304), (224, 304)]))
    b.append(lab_h(332, 304, "ANNOUNCEMENTS\nALERTS · STATUS", "below"))
    b.append(arrow([(680, 264), (896, 264)]))
    b.append(lab_h(788, 264, "ASSIGNED CASES\nNOTIFICATIONS"))
    b.append(arrow([(896, 304), (680, 304)]))
    b.append(lab_h(788, 304, "POSTS · UPDATES\nREVIEWS", "below"))
    b.append(arrow([(540, 480), (540, 360)]))
    b.append(lab_v(540, 420, "ACCOUNTS · ROLES\nPOLICIES", "left"))
    b.append(arrow([(580, 360), (580, 480)]))
    b.append(lab_v(580, 420, "REPORTS\nAUDIT LOGS"))
    b.append(arrow([(540, 200), (540, 112)]))
    b.append(lab_v(540, 156, "OTP EMAIL · PUSH\nAI QUESTIONS", "left"))
    b.append(arrow([(580, 112), (580, 200)]))
    b.append(lab_v(580, 156, "AI ANSWERS\nDELIVERY STATUS"))
    # process 0
    b.append(f'<rect x="440" y="200" width="240" height="160" rx="16" fill="{PAPER}" stroke="{INK}" stroke-width="2.6"/>')
    b.append(f'<line x1="440" y1="236" x2="680" y2="236" stroke="{INK}" stroke-width="1.2"/>')
    b.append(text(560, 223, "0", 13, 600, MONO))
    b.append(text(560, 280, "E-SUGID", 17, 600))
    b.append(text(560, 302, "Community Services", FN, 600))
    b.append(text(560, 320, "System", FN, 600))
    # entities
    b.append(box(64, 240, 160, 88, "Resident", "mobile app user"))
    b.append(box(896, 240, 160, 88, "Office Staff", "barangay · org · dept"))
    b.append(box(480, 480, 160, 80, "LGU IT Admin", "admin console"))
    b.append(box(480, 32, 160, 80, "External Services", "Brevo · Gemini · FCM", kind="external"))
    b.append(legend(616, W, [("focal", "Process (the system)"), ("box", "External entity"),
                             ("external", "Third-party service"), ("solid", "Data flow")]))
    write("04a-data-flow-context", page(
        "dfd-context", "Data Flow Diagram · Level 0", "E-SUGID Context Data Flow Diagram",
        "Residents send profiles, concerns, emergency reports and requests to E-SUGID and receive announcements, "
        "alerts and status updates; office staff receive cases and send updates; the LGU IT admin manages accounts "
        "and policies; external services handle email, AI answers and push delivery.",
        W, H, "\n".join(b)))


# ---------------------------------------------------------------- 4b. Activity diagram
def activity():
    W, H = 1040, 960
    b = []
    lanes = [(40, "RESIDENT"), (360, "E-SUGID SYSTEM"), (680, "ASSIGNED OFFICE STAFF")]
    for x, n in lanes:
        b.append(f'<rect x="{x}" y="64" width="320" height="804" fill="none" stroke="{INK}" stroke-width="1.2"/>')
        b.append(f'<line x1="{x}" y1="100" x2="{x + 320}" y2="100" stroke="{INK}" stroke-width="1.2"/>')
        b.append(text(x + 160, 87, n, 11, 600, MONO, INK, ls="0.14em"))
    act = dict(rx=14)
    b.append(arrow([(200, 146), (200, 172)]))
    b.append(arrow([(200, 224), (200, 256)]))
    b.append(arrow([(310, 282), (410, 282)]))
    b.append(arrow([(520, 308), (520, 340)]))
    b.append(arrow([(520, 392), (520, 424)]))
    b.append(arrow([(630, 450), (730, 450)]))
    b.append(arrow([(840, 476), (840, 520)]))
    b.append(arrow([(752, 560), (310, 560)]))
    b.append(lab_h(716, 560, "YES"))
    b.append(arrow([(200, 534), (200, 504), (800, 504), (800, 476)]))
    b.append(lab_h(270, 504, "RESPONSE", "below"))
    b.append(arrow([(840, 600), (840, 636)]))
    b.append(lab_v(840, 618, "NO"))
    b.append(arrow([(840, 688), (840, 720)]))
    b.append(arrow([(730, 746), (630, 746)]))
    b.append(arrow([(410, 746), (310, 746)]))
    b.append(arrow([(200, 772), (200, 814)]))
    b.append(f'<circle cx="200" cy="136" r="10" fill="{INK}"/>')
    b.append(box(90, 172, 220, 52, "Fill out concern form", "category · details · photo", **act))
    b.append(box(90, 256, 220, 52, "Submit concern", "with location", **act))
    b.append(box(410, 256, 220, 52, "Validate & de-duplicate", "Cloud Functions", **act))
    b.append(box(410, 340, 220, 52, "Route concern", "barangay · dept · org", kind="focal", **act))
    b.append(box(410, 424, 220, 52, "Notify assigned staff", "push · in-app", **act))
    b.append(box(730, 424, 220, 52, "Review concern", "admin console", **act))
    b.append(diamond(840, 560, "Need more info?", 88, 40))
    b.append(box(90, 534, 220, 52, "Provide information", "reply · new photo", **act))
    b.append(box(730, 636, 220, 52, "Act on the concern", "field work · coordination", **act))
    b.append(box(730, 720, 220, 52, "Mark as resolved", "public update · note", **act))
    b.append(box(410, 720, 220, 52, "Notify resident", "push · in-app", **act))
    b.append(box(90, 720, 220, 52, "View the resolution", "feedback · resubmit", **act))
    b.append(f'<circle cx="200" cy="828" r="13" fill="{PAPER}" stroke="{INK}" stroke-width="1.6"/>')
    b.append(f'<circle cx="200" cy="828" r="8" fill="{INK}"/>')
    b.append(legend(904, W, [("dot", "Start"), ("box", "Action"), ("diamond", "Decision"),
                             ("focal", "Core action"), ("solid", "Control flow")]))
    write("04b-activity-diagram", page(
        "activity", "Activity Diagram · Concern handling", "E-SUGID Concern Handling Activity Diagram",
        "A resident submits a concern, the system validates, de-duplicates and routes it to the responsible office, "
        "staff review it and may request more information, then resolve it and the resident is notified.",
        W, H, "\n".join(b)))


# ---------------------------------------------------------------- 5. ER diagram
def entity(x, y, w, name, fields, focal=False):
    h = r4(40 + len(fields) * 18 + 8)
    sw = 2.6 if focal else 1.2
    out = [f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="6" fill="{PAPER}"/>',
           f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="6" fill="{PAPER}" stroke="{INK}" stroke-width="{sw}"/>',
           f'<line x1="{x}" y1="{y + 36}" x2="{x + w}" y2="{y + 36}" stroke="{INK}" stroke-width="1"/>',
           text(x + w / 2, y + 23, name, FN, 600)]
    for i, f in enumerate(fields):
        fy = y + 56 + i * 18
        if f.startswith("#"):
            out.append(text(x + 14, fy, "PK", FT, 600, MONO, INK, anchor="start"))
            out.append(text(x + 40, fy, f[1:].strip(), FS, 600, MONO, INK, anchor="start"))
        elif f.startswith(">"):
            out.append(text(x + 14, fy, "FK", FT, 600, MONO, SOFT, anchor="start"))
            out.append(text(x + 40, fy, f[1:].strip(), FS, None, MONO, INK, anchor="start"))
        else:
            out.append(text(x + 40, fy, f, FS, None, MONO, SOFT, anchor="start"))
    return "\n".join(out), h


def card(x, y, s, horizontal_side="above"):
    w = 16
    return (f'<rect x="{x - w / 2}" y="{y - 8}" width="{w}" height="16" rx="2" fill="{PAPER}"/>'
            + text(x, y + 4, s, FA + 1, 600, MONO, INK))


def er():
    W, H = 1120, 1120
    b = []
    ents = [
        (80, 72, "barangay_profiles", ["# id", "name", "barangay", "logoUrl", "updatedAt"]),
        (440, 72, "lgu_departments", ["# id", "name", "publicName", "status", "updatedAt"]),
        (800, 72, "organizations", ["# id", "name", "organizationType", "status", "updatedAt"]),
        (440, 272, "users", ["# uid", "email", "name", "role", "positionTitle", "accountStatus",
                             "verificationStatus", "> barangayId", "> departmentId", "> organizationId",
                             "contactNumber", "address", "birthDate"]),
        (80, 272, "posts", ["# id", "title", "content", "category", "> authorId", "publisherEntityType",
                            "visibility", "targetBarangays", "status", "publishAt", "expiresAt"]),
        (80, 552, "alerts", ["# id", "title", "message", "severity", "alertType", "> createdBy",
                             "targetBarangays", "status", "publishedAt", "expiresAt"]),
        (80, 812, "audit_logs", ["# id", "> actorId", "action", "entityType", "entityId", "barangayId",
                                 "createdAt"]),
        (800, 272, "submissions (concerns)", ["# id", "title", "description", "category", "status",
                                              "visibility", "> residentId", "> organizationId",
                                              "> recipientBarangayId", "recipientType", "routingStatus",
                                              "location", "attachmentUrl", "submittedAt"]),
        (800, 604, "emergency_reports", ["# id", "> reporterId", "emergencyType", "description", "location",
                                         "barangay", "routedAgency", "status", "imageUrl", "createdAt"]),
        (800, 864, "document_requests", ["# id", "> userId", "type", "status", "paymentStatus", "note",
                                         "createdAt"]),
        (440, 616, "notifications", ["# id", "> userId", "type", "title", "message", "referenceId", "read",
                                     "createdAt"]),
    ]
    boxes, geo = [], {}
    for x, y, n, f in ents:
        svg, h = entity(x, y, 240, n, f, focal=(n == "users"))
        boxes.append(svg)
        geo[n] = (x, y, h)
    for n, (x, y, h) in geo.items():
        print(f"  {n}: y {y}..{y + h}", file=sys.stderr)
    ux, uy, uh = geo["users"]
    # relationships
    rel = []
    rel.append(arrow([(200, 212), (200, 240), (500, 240), (500, 272)], marker=None))
    rel.append(arrow([(560, 212), (560, 272)], marker=None))
    rel.append(arrow([(880, 212), (880, 240), (620, 240), (620, 272)], marker=None))
    rel.append(arrow([(960, 212), (960, 272)], marker=None))
    py = 272 + geo["posts"][2] / 2
    ay = 552 + geo["alerts"][2] / 2
    ly = 812 + geo["audit_logs"][2] / 2
    sy = 272 + geo["submissions (concerns)"][2] / 2
    ey = 604 + geo["emergency_reports"][2] / 2
    dy = 864 + geo["document_requests"][2] / 2
    rel.append(arrow([(440, py), (320, py)], marker=None))
    rel.append(arrow([(440, 460), (368, 460), (368, ay), (320, ay)], marker=None))
    rel.append(arrow([(440, 500), (400, 500), (400, ly), (320, ly)], marker=None))
    rel.append(arrow([(680, sy), (800, sy)], marker=None))
    rel.append(arrow([(680, 476), (752, 476), (752, ey), (800, ey)], marker=None))
    rel.append(arrow([(680, 516), (720, 516), (720, dy), (800, dy)], marker=None))
    rel.append(arrow([(560, uy + uh), (560, 616)], marker=None))
    # cardinalities
    c = []
    c += [card(212, 226, "1"), card(512, 258, "N")]
    c += [card(572, 226, "1"), card(572, 258, "N")]
    c += [card(868, 226, "1"), card(632, 258, "N")]
    c += [card(972, 226, "1"), card(972, 258, "N")]
    c += [card(428, py - 14, "1"), card(332, py - 14, "N")]
    c += [card(428, 446, "1"), card(332, ay - 14, "N")]
    c += [card(428, 514, "1"), card(332, ly - 14, "N")]
    c += [card(692, sy - 14, "1"), card(788, sy - 14, "N")]
    c += [card(692, 462, "1"), card(788, ey - 14, "N")]
    c += [card(692, 530, "1"), card(788, dy - 14, "N")]
    c += [card(572, uy + uh + 14, "1"), card(572, 602, "N")]
    b += rel + c + boxes
    b.append(legend(1076, W, [("focal", "Central entity"), ("line", "Relationship (1 to N)")]))
    b.append(text(560, 1088, "PK primary key · FK foreign key (document ID reference) · Cloud Firestore collections",
                  FA + 1, None, SANS, MUTED, anchor="start"))
    write("05-entity-relationship-diagram", page(
        "er", "Entity-Relationship Diagram · Database Design", "E-SUGID Entity-Relationship Diagram",
        "The users collection links to barangays, departments and organizations and owns posts, alerts, concerns, "
        "emergency reports, document requests, notifications and audit logs; organizations are assigned concerns.",
        W, H, "\n".join(b)))


if __name__ == "__main__":
    architecture()
    use_case()
    flowchart()
    dfd_context()
    activity()
    er()

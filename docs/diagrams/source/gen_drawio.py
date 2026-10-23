"""Generate editable draw.io versions of the E-SUGID documentation diagrams.

Same layouts as gen_diagrams.py, rebuilt with native draw.io shapes (UML actors,
cylinders, swimlanes, ER tables with crow's-foot notation).
"""
import html
import math
import os
import sys

OUT = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(__file__), "..", "drawio")

BOX = "rounded=1;arcSize=8;whiteSpace=wrap;html=1;fillColor=#FFFFFF;strokeColor=#000000;fontColor=#000000;fontSize=13;"
FOCAL = BOX + "strokeWidth=3;"
EXT = BOX + "dashed=1;dashPattern=6 4;"
EDGE = ("edgeStyle=orthogonalEdgeStyle;rounded=1;html=1;strokeColor=#333333;strokeWidth=1.3;"
        "endArrow=block;endFill=1;endSize=7;")
LINE = "edgeStyle=orthogonalEdgeStyle;rounded=1;html=1;strokeColor=#333333;strokeWidth=1.3;endArrow=none;"
LABEL = ("text;html=1;align=center;verticalAlign=middle;fillColor=#FFFFFF;strokeColor=none;fontSize=10;"
         "fontColor=#444444;fontFamily=Courier New;fontStyle=1;spacing=0;")


def esc(s):
    return html.escape(s, quote=True)


def r4(v):
    return int(math.ceil(v / 4.0) * 4)


def rich(name, sub=None, tag=None):
    parts = []
    if tag:
        parts.append(f'<font style="font-size:9px" color="#555555">{tag}</font>')
    parts.append(f"<b>{name}</b>")
    if sub:
        parts.append(f'<font style="font-size:11px" color="#555555">{sub}</font>')
    return "<br>".join(parts)


class Doc:
    def __init__(self):
        self.cells = []
        self.geo = {}
        self.n = 0

    def nid(self, p="c"):
        self.n += 1
        return f"{p}{self.n}"

    def v(self, x, y, w, h, value, style, id=None, parent="1"):
        id = id or self.nid()
        self.geo[id] = (x, y, w, h)
        self.cells.append(
            f'<mxCell id="{id}" value="{esc(value)}" style="{style}" vertex="1" parent="{parent}">'
            f'<mxGeometry x="{x}" y="{y}" width="{w}" height="{h}" as="geometry"/></mxCell>')
        return id

    def e(self, pts, src=None, tgt=None, style=EDGE, extra=""):
        st = style + extra
        attrs = ""
        if src:
            x, y, w, h = self.geo[src]
            st += f"exitX={min(max((pts[0][0] - x) / w, 0), 1):.4f};exitY={min(max((pts[0][1] - y) / h, 0), 1):.4f};exitDx=0;exitDy=0;"
            attrs += f' source="{src}"'
        if tgt:
            x, y, w, h = self.geo[tgt]
            st += f"entryX={min(max((pts[-1][0] - x) / w, 0), 1):.4f};entryY={min(max((pts[-1][1] - y) / h, 0), 1):.4f};entryDx=0;entryDy=0;"
            attrs += f' target="{tgt}"'
        inner = "".join(f'<mxPoint x="{px}" y="{py}"/>' for px, py in pts[1:-1])
        geo = f'<mxGeometry relative="1" as="geometry">'
        if not src:
            geo += f'<mxPoint x="{pts[0][0]}" y="{pts[0][1]}" as="sourcePoint"/>'
        if not tgt:
            geo += f'<mxPoint x="{pts[-1][0]}" y="{pts[-1][1]}" as="targetPoint"/>'
        if inner:
            geo += f'<Array as="points">{inner}</Array>'
        geo += "</mxGeometry>"
        self.cells.append(f'<mxCell id="{self.nid("e")}" style="{st}" edge="1" parent="1"{attrs}>{geo}</mxCell>')

    def label(self, cx, cy, s):
        lines = s.split("\n")
        w = r4(max(len(l) for l in lines) * 6.6 + 12)
        h = r4(len(lines) * 14 + 4)
        self.v(cx - w / 2, cy - h / 2, w, h, "<br>".join(esc(l) for l in lines), LABEL)
        return w, h

    def lab_h(self, cx, y, s, side="above"):
        h = r4(len(s.split("\n")) * 14 + 4)
        self.label(cx, y - 6 - h / 2 if side == "above" else y + 6 + h / 2, s)

    def lab_v(self, x, cy, s, side="right"):
        lines = s.split("\n")
        w = r4(max(len(l) for l in lines) * 6.6 + 12)
        self.label(x + 8 + w / 2 if side == "right" else x - 8 - w / 2, cy, s)

    def text(self, x, y, w, h, s, size=13, bold=True, align="center", color="#000000"):
        st = (f"text;html=1;align={align};verticalAlign=middle;fontSize={size};fontColor={color};"
              f"fontStyle={1 if bold else 0};strokeColor=none;fillColor=none;")
        return self.v(x, y, w, h, s, st)

    def legend(self, y, W, items):
        self.cells.append(
            f'<mxCell id="{self.nid("l")}" style="endArrow=none;html=1;strokeColor=#BBBBBB;" edge="1" parent="1">'
            f'<mxGeometry relative="1" as="geometry"><mxPoint x="32" y="{y - 12}" as="sourcePoint"/>'
            f'<mxPoint x="{W - 32}" y="{y - 12}" as="targetPoint"/></mxGeometry></mxCell>')
        self.text(32, y, 72, 16, "LEGEND", 10, True, "left", "#555555")
        x = 112
        shapes = {
            "box": BOX, "focal": FOCAL, "external": EXT,
            "oval": BOX + "arcSize=50;",
            "diamond": "rhombus;html=1;fillColor=#FFFFFF;strokeColor=#000000;",
            "dot": "ellipse;html=1;fillColor=#000000;strokeColor=#000000;",
            "ellipse": "ellipse;html=1;fillColor=#FFFFFF;strokeColor=#000000;",
        }
        for kind, t in items:
            if kind in shapes:
                w, h = (12, 12) if kind == "dot" else (36, 18)
                self.v(x + (12 if kind == "dot" else 0), y + (3 if kind == "dot" else -1), w, h, "", shapes[kind])
            else:
                st = {"solid": EDGE, "dashed": EDGE + "dashed=1;", "line": LINE,
                      "gen": LINE + "endArrow=block;endFill=0;endSize=12;",
                      "crow": LINE + "startArrow=ERmandOne;endArrow=ERmany;startSize=10;endSize=10;"}[kind]
                self.e([(x, y + 8), (x + 40, y + 8)], style=st)
            tw_ = int(len(t) * 6.4) + 8
            self.text(x + 46, y, tw_, 16, t, 11, False, "left", "#333333")
            x += 46 + tw_ + 32

    def save(self, slug, title, W, H):
        model = (f'<mxGraphModel dx="{W}" dy="{H}" grid="1" gridSize="4" guides="1" page="1" '
                 f'pageWidth="{W}" pageHeight="{H}" background="#FFFFFF" math="0" shadow="0">'
                 f'<root><mxCell id="0"/><mxCell id="1" parent="0"/>{"".join(self.cells)}</root></mxGraphModel>')
        os.makedirs(OUT, exist_ok=True)
        path = os.path.join(OUT, slug + ".drawio")
        with open(path, "w", encoding="utf-8") as f:
            f.write(f'<mxfile host="drawio-mcp"><diagram id="{slug}" name="{esc(title)}">{model}</diagram></mxfile>')
        print(os.path.abspath(path))


# ---------------------------------------------------------------- 1. Architecture
def architecture():
    d = Doc()
    d.v(40, 256, 1120, 136, "", "rounded=1;arcSize=6;html=1;fillColor=none;strokeColor=#000000;dashed=1;dashPattern=6 4;")
    d.label(184 + 92, 256, "FIREBASE PROJECT · e-sugid")
    cyl = "shape=cylinder3;boundedLbl=1;backgroundOutline=1;size=10;whiteSpace=wrap;html=1;fillColor=#FFFFFF;strokeColor=#000000;fontSize=13;"
    maps = d.v(136, 80, 208, 72, rich("Map &amp; Weather APIs", "Google Maps · Open-Meteo", "EXTERNAL"), EXT)
    mob = d.v(480, 80, 240, 72, rich("Resident Mobile App", "Flutter · Android", "CLIENT"), BOX)
    auth = d.v(64, 296, 176, 72, rich("Authentication", "email · Google · OTP", "FIREBASE"), BOX)
    fs = d.v(288, 296, 176, 72, rich("Cloud Firestore", "NoSQL · security rules"), cyl)
    fn = d.v(512, 296, 176, 72, rich("Cloud Functions", "APIs · triggers · cron", "BACKEND"), FOCAL)
    fcm = d.v(736, 296, 176, 72, rich("Cloud Messaging", "FCM topics · devices", "FIREBASE"), BOX)
    st = d.v(960, 296, 176, 72, rich("Cloud Storage", "photos · documents"), cyl)
    adm = d.v(232, 512, 240, 72, rich("Staff Admin Console", "web · Firebase Hosting", "CLIENT"), BOX)
    gem = d.v(544, 512, 176, 72, rich("Gemini API", "E-SUGID Assistant", "EXTERNAL"), EXT)
    bre = d.v(768, 512, 176, 72, rich("Brevo Email API", "OTP · invitations", "EXTERNAL"), EXT)
    d.e([(508, 152), (508, 196), (152, 196), (152, 296)], mob, auth)
    d.lab_h(330, 196, "SIGN IN")
    d.e([(548, 152), (548, 236), (376, 236), (376, 296)], mob, fs)
    d.lab_h(462, 236, "REAL-TIME DATA")
    d.e([(600, 152), (600, 296)], mob, fn)
    d.lab_v(600, 216, "CALLABLE APIS")
    d.e([(720, 100), (1048, 100), (1048, 296)], mob, st)
    d.lab_h(900, 100, "UPLOAD FILES")
    d.e([(824, 296), (824, 128), (720, 128)], fcm, mob)
    d.lab_v(824, 208, "PUSH ALERTS")
    d.e([(480, 116), (344, 116)], mob, maps)
    d.lab_h(412, 116, "MAP · WEATHER")
    d.e([(512, 320), (464, 320)], fn, fs)
    d.e([(464, 344), (512, 344)], fs, fn, extra="dashed=1;")
    d.e([(688, 332), (736, 332)], fn, fcm)
    d.e([(252, 512), (252, 440), (152, 440), (152, 368)], adm, auth)
    d.e([(376, 512), (376, 368)], adm, fs)
    d.e([(452, 512), (452, 448), (568, 448), (568, 368)], adm, fn)
    d.lab_v(376, 488, "MANAGE RECORDS", "left")
    d.e([(632, 368), (632, 512)], fn, gem)
    d.e([(664, 368), (664, 456), (856, 456), (856, 512)], fn, bre)
    d.legend(644, 1200, [("solid", "Request / data flow"), ("dashed", "Event trigger"), ("focal", "Core backend"),
                         ("box", "E-SUGID component"), ("external", "Third-party service")])
    d.save("01-system-architecture", "System Architecture", 1200, 700)


# ---------------------------------------------------------------- 2. Use case
def use_case():
    d = Doc()
    d.v(220, 96, 760, 592, "E-SUGID Community Services System",
        "rounded=1;arcSize=2;html=1;fillColor=none;strokeColor=#000000;strokeWidth=1.4;verticalAlign=top;fontStyle=1;fontSize=15;spacingTop=12;")
    uc = "ellipse;whiteSpace=wrap;html=1;fillColor=#FFFFFF;strokeColor=#000000;fontSize=13;"
    act = ("shape=umlActor;verticalLabelPosition=bottom;verticalAlign=top;html=1;outlineConnect=0;"
           "fillColor=#FFFFFF;strokeColor=#000000;strokeWidth=1.6;fontStyle=1;fontSize=13;")
    res = ["Register &amp; verify residency", "View announcements &amp; alerts", "Submit &amp; track a concern",
           "Report an emergency", "Request documents &amp; helpdesk", "Join Bayanihan, jobs &amp; marketplace",
           "Ask the E-SUGID Assistant"]
    staff = ["Publish announcements", "Handle assigned concerns", "Respond to emergency reports",
             "Verify resident accounts", "Request staff accounts"]
    it = ["Approve staff accounts", "Manage departments &amp; orgs", "Set access policies &amp; audit"]
    ry = [168 + 80 * i for i in range(7)]
    sy = [168 + 64 * i for i in range(5)]
    iy = [520, 584, 648]
    a_res = d.v(62, 368, 36, 80, "Resident", act)
    a_st = d.v(1082, 256, 36, 80, "Staff", act)
    a_it = d.v(1082, 544, 36, 80, "LGU IT Admin", act)
    a_b = d.v(1242, 136, 36, 80, "Barangay Official", act)
    a_o = d.v(1242, 256, 36, 80, "Organization Staff", act)
    a_d = d.v(1242, 376, 36, 80, "LGU Department", act)
    ucs_r = [d.v(260, y - 24, 280, 48, n, uc + ("strokeWidth=3;" if i == 2 else "")) for i, (n, y) in enumerate(zip(res, ry))]
    ucs_s = [d.v(660, y - 24, 280, 48, n, uc) for n, y in zip(staff, sy)]
    ucs_i = [d.v(660, y - 24, 280, 48, n, uc) for n, y in zip(it, iy)]
    ports = [372 + 12 * i for i in range(7)]
    vx = {0: 140, 1: 156, 2: 172, 4: 172, 5: 156, 6: 140}
    for i in range(7):
        pts = [(98, ports[i]), (260, ry[i])] if i == 3 else [(98, ports[i]), (vx[i], ports[i]), (vx[i], ry[i]), (260, ry[i])]
        d.e(pts, a_res, ucs_r[i], LINE)
    sp = [272 + 12 * i for i in range(5)]
    svx = {0: 1012, 1: 996, 3: 996, 4: 1012}
    for i in range(5):
        pts = [(1082, sp[i]), (940, sy[i])] if i == 2 else [(1082, sp[i]), (svx[i], sp[i]), (svx[i], sy[i]), (940, sy[i])]
        d.e(pts, a_st, ucs_s[i], LINE)
    ip = [572, 584, 596]
    for i in range(3):
        pts = [(1082, ip[i]), (940, iy[i])] if i == 1 else [(1082, ip[i]), (1012, ip[i]), (1012, iy[i]), (940, iy[i])]
        d.e(pts, a_it, ucs_i[i], LINE)
    gen = LINE + "endArrow=block;endFill=0;endSize=12;strokeColor=#000000;"
    d.e([(1100, 544), (1100, 360)], a_it, None, gen)
    d.e([(1242, 176), (1164, 176), (1164, 274), (1118, 274)], a_b, a_st, gen)
    d.e([(1242, 296), (1118, 296)], a_o, a_st, gen)
    d.e([(1242, 416), (1164, 416), (1164, 318), (1118, 318)], a_d, a_st, gen)
    d.legend(728, 1360, [("line", "Association"), ("gen", "Generalization (is a kind of)"),
                         ("ellipse", "Use case"), ("focal", "Core use case")])
    d.save("02-use-case-diagram", "Use Case Diagram", 1360, 780)


# ---------------------------------------------------------------- 3. Flowchart
def flowchart():
    d = Doc()
    M, R = 320, 680
    oval = BOX + "arcSize=50;fontStyle=1;"
    dia = "rhombus;whiteSpace=wrap;html=1;fillColor=#FFFFFF;strokeColor=#000000;fontStyle=1;fontSize=13;strokeWidth=1.4;"
    n = {}
    n["start"] = d.v(M - 100, 64, 200, 40, "Start", oval)
    n["p1"] = d.v(200, 136, 240, 52, rich("Launch E-SUGID", "app or admin console"), BOX)
    n["d1"] = d.v(M - 96, 224, 192, 88, "Signed in?", dia)
    n["r1"] = d.v(580, 244, 200, 48, rich("Log in or register", "email · Google"), BOX)
    n["r2"] = d.v(580, 324, 200, 48, rich("Verify email OTP", "6-digit code"), BOX)
    n["dot"] = d.v(M - 5, 343, 10, 10, "", "ellipse;html=1;fillColor=#000000;strokeColor=#000000;")
    n["d2"] = d.v(M - 104, 392, 208, 88, "Account approved?", dia)
    n["r3"] = d.v(580, 412, 200, 48, rich("Show pending status", "await review"), BOX)
    n["end1"] = d.v(R - 80, 492, 160, 40, "End", oval)
    n["d3"] = d.v(M - 96, 528, 192, 88, "User role?", dia)
    n["r4"] = d.v(580, 548, 200, 48, rich("Open staff console", "dashboard · queues"), BOX)
    steps = [("a1", 656, "Choose a service", "concern · SOS · document"),
             ("a2", 740, "Submit report", "details · photo · location"),
             ("a3", 824, "Validate &amp; route", "Cloud Functions"),
             ("a4", 908, "Notify assigned office", "push · in-app"),
             ("a5", 992, "Review &amp; update status", "assigned staff")]
    for k, y, nm, sb in steps:
        n[k] = d.v(200, y, 240, 52, rich(nm, sb), FOCAL if k == "a3" else BOX)
    n["d4"] = d.v(M - 96, 1080, 192, 88, "Resolved?", dia)
    n["a6"] = d.v(200, 1204, 240, 52, rich("Notify resident of result", "status · public update"), BOX)
    n["end2"] = d.v(M - 100, 1288, 200, 40, "End", oval)
    E = d.e
    E([(M, 104), (M, 136)], n["start"], n["p1"])
    E([(M, 188), (M, 224)], n["p1"], n["d1"])
    E([(416, 268), (580, 268)], n["d1"], n["r1"]); d.lab_h(498, 268, "NO")
    E([(R, 292), (R, 324)], n["r1"], n["r2"])
    E([(580, 348), (325, 348)], n["r2"], n["dot"])
    E([(M, 312), (M, 343)], n["d1"], n["dot"], extra="endArrow=none;"); d.lab_v(M, 328, "YES")
    E([(M, 353), (M, 392)], n["dot"], n["d2"])
    E([(424, 436), (580, 436)], n["d2"], n["r3"]); d.lab_h(498, 436, "NO")
    E([(R, 460), (R, 492)], n["r3"], n["end1"])
    E([(M, 480), (M, 528)], n["d2"], n["d3"]); d.lab_v(M, 504, "YES")
    E([(416, 572), (580, 572)], n["d3"], n["r4"]); d.lab_h(498, 572, "STAFF")
    E([(M, 616), (M, 656)], n["d3"], n["a1"]); d.lab_v(M, 636, "RESIDENT")
    chain = ["a1", "a2", "a3", "a4", "a5"]
    for a, b in zip(chain, chain[1:]):
        E([(M, d.geo[n[a]][1] + 52), (M, d.geo[n[b]][1])], n[a], n[b])
    E([(M, 1044), (M, 1080)], n["a5"], n["d4"])
    E([(M, 1168), (M, 1204)], n["d4"], n["a6"]); d.lab_v(M, 1186, "YES")
    E([(M, 1256), (M, 1288)], n["a6"], n["end2"])
    E([(R, 596), (R, 1018), (440, 1018)], n["r4"], n["a5"])
    E([(224, 1124), (160, 1124), (160, 1018), (200, 1018)], n["d4"], n["a5"])
    d.lab_h(192, 1124, "NO")
    d.lab_v(160, 1071, "KEEP WORKING", "left")
    d.legend(1352, 900, [("oval", "Start / end"), ("box", "Process"), ("diamond", "Decision"),
                         ("dot", "Merge"), ("focal", "Core step")])
    d.save("03-system-flowchart", "System Flowchart", 900, 1400)


# ---------------------------------------------------------------- 4a. DFD context
def dfd_context():
    d = Doc()
    proc = ("swimlane;rounded=1;arcSize=10;startSize=36;html=1;fillColor=#FFFFFF;swimlaneFillColor=#FFFFFF;"
            "strokeColor=#000000;strokeWidth=3;fontStyle=1;fontSize=13;fontFamily=Courier New;")
    p = d.v(440, 200, 240, 160, "0", proc)
    d.cells.append(
        f'<mxCell id="ptxt" value="{esc("<b><font style=\"font-size:17px\">E-SUGID</font></b><br><b>Community Services<br>System</b>")}" '
        f'style="text;html=1;align=center;verticalAlign=middle;fontSize=14;strokeColor=none;fillColor=none;" vertex="1" parent="{p}">'
        f'<mxGeometry x="0" y="36" width="240" height="124" as="geometry"/></mxCell>')
    res = d.v(64, 240, 160, 88, rich("Resident", "mobile app user"), BOX)
    stf = d.v(896, 240, 160, 88, rich("Office Staff", "barangay · org · dept"), BOX)
    adm = d.v(480, 480, 160, 80, rich("LGU IT Admin", "admin console"), BOX)
    ext = d.v(480, 32, 160, 80, rich("External Services", "Brevo · Gemini · FCM"), EXT)
    d.e([(224, 264), (440, 264)], res, p); d.lab_h(332, 264, "PROFILE · CONCERNS\nSOS · REQUESTS")
    d.e([(440, 304), (224, 304)], p, res); d.lab_h(332, 304, "ANNOUNCEMENTS\nALERTS · STATUS", "below")
    d.e([(680, 264), (896, 264)], p, stf); d.lab_h(788, 264, "ASSIGNED CASES\nNOTIFICATIONS")
    d.e([(896, 304), (680, 304)], stf, p); d.lab_h(788, 304, "POSTS · UPDATES\nREVIEWS", "below")
    d.e([(540, 480), (540, 360)], adm, p); d.lab_v(540, 420, "ACCOUNTS · ROLES\nPOLICIES", "left")
    d.e([(580, 360), (580, 480)], p, adm); d.lab_v(580, 420, "REPORTS\nAUDIT LOGS")
    d.e([(540, 200), (540, 112)], p, ext); d.lab_v(540, 156, "OTP EMAIL · PUSH\nAI QUESTIONS", "left")
    d.e([(580, 112), (580, 200)], ext, p); d.lab_v(580, 156, "AI ANSWERS\nDELIVERY STATUS")
    d.legend(616, 1120, [("focal", "Process (the system)"), ("box", "External entity"),
                         ("external", "Third-party service"), ("solid", "Data flow")])
    d.save("04a-data-flow-context", "Data Flow Diagram - Level 0", 1120, 660)


# ---------------------------------------------------------------- 4b. Activity diagram
def activity():
    d = Doc()
    lane = ("swimlane;startSize=36;html=1;fillColor=#FFFFFF;swimlaneFillColor=#FFFFFF;strokeColor=#000000;"
            "strokeWidth=1.2;fontStyle=1;fontSize=12;fontFamily=Courier New;")
    for x, nm in [(40, "RESIDENT"), (360, "E-SUGID SYSTEM"), (680, "ASSIGNED OFFICE STAFF")]:
        d.v(x, 64, 320, 804, nm, lane)
    act = BOX.replace("arcSize=8", "arcSize=28")
    dot = "ellipse;html=1;fillColor=#000000;strokeColor=#000000;"
    s = d.v(190, 126, 20, 20, "", dot)
    r1 = d.v(90, 172, 220, 52, rich("Fill out concern form", "category · details · photo"), act)
    r2 = d.v(90, 256, 220, 52, rich("Submit concern", "with location"), act)
    s1 = d.v(410, 256, 220, 52, rich("Validate &amp; de-duplicate", "Cloud Functions"), act)
    s2 = d.v(410, 340, 220, 52, rich("Route concern", "barangay · dept · org"), act + "strokeWidth=3;")
    s3 = d.v(410, 424, 220, 52, rich("Notify assigned staff", "push · in-app"), act)
    t1 = d.v(730, 424, 220, 52, rich("Review concern", "admin console"), act)
    dm = d.v(752, 520, 176, 80, "Need more info?",
             "rhombus;whiteSpace=wrap;html=1;fillColor=#FFFFFF;strokeColor=#000000;fontStyle=1;fontSize=13;")
    r3 = d.v(90, 534, 220, 52, rich("Provide information", "reply · new photo"), act)
    t2 = d.v(730, 636, 220, 52, rich("Act on the concern", "field work · coordination"), act)
    t3 = d.v(730, 720, 220, 52, rich("Mark as resolved", "public update · note"), act)
    s4 = d.v(410, 720, 220, 52, rich("Notify resident", "push · in-app"), act)
    r4 = d.v(90, 720, 220, 52, rich("View the resolution", "feedback · resubmit"), act)
    end = d.v(187, 815, 26, 26, "", "ellipse;html=1;fillColor=#FFFFFF;strokeColor=#000000;strokeWidth=1.6;")
    d.v(192, 820, 16, 16, "", dot)
    E = d.e
    E([(200, 146), (200, 172)], s, r1)
    E([(200, 224), (200, 256)], r1, r2)
    E([(310, 282), (410, 282)], r2, s1)
    E([(520, 308), (520, 340)], s1, s2)
    E([(520, 392), (520, 424)], s2, s3)
    E([(630, 450), (730, 450)], s3, t1)
    E([(840, 476), (840, 520)], t1, dm)
    E([(752, 560), (310, 560)], dm, r3); d.lab_h(716, 560, "YES")
    E([(200, 534), (200, 504), (800, 504), (800, 476)], r3, t1); d.lab_h(270, 504, "RESPONSE", "below")
    E([(840, 600), (840, 636)], dm, t2); d.lab_v(840, 618, "NO")
    E([(840, 688), (840, 720)], t2, t3)
    E([(730, 746), (630, 746)], t3, s4)
    E([(410, 746), (310, 746)], s4, r4)
    E([(200, 772), (200, 815)], r4, end)
    d.legend(904, 1040, [("dot", "Start"), ("box", "Action"), ("diamond", "Decision"),
                         ("focal", "Core action"), ("solid", "Control flow")])
    d.save("04b-activity-diagram", "Activity Diagram - Concern handling", 1040, 960)


# ---------------------------------------------------------------- 5. ER diagram
def er():
    d = Doc()
    ents = [
        ("barangay_profiles", 80, 72, ["# id", "name", "barangay", "logoUrl", "updatedAt"]),
        ("lgu_departments", 440, 72, ["# id", "name", "publicName", "status", "updatedAt"]),
        ("organizations", 800, 72, ["# id", "name", "organizationType", "status", "updatedAt"]),
        ("users", 440, 272, ["# uid", "email", "name", "role", "positionTitle", "accountStatus",
                             "verificationStatus", "> barangayId", "> departmentId", "> organizationId",
                             "contactNumber", "address", "birthDate"]),
        ("posts", 80, 272, ["# id", "title", "content", "category", "> authorId", "publisherEntityType",
                            "visibility", "targetBarangays", "status", "publishAt", "expiresAt"]),
        ("alerts", 80, 552, ["# id", "title", "message", "severity", "alertType", "> createdBy",
                             "targetBarangays", "status", "publishedAt", "expiresAt"]),
        ("audit_logs", 80, 812, ["# id", "> actorId", "action", "entityType", "entityId", "barangayId", "createdAt"]),
        ("submissions (concerns)", 800, 272, ["# id", "title", "description", "category", "status", "visibility",
                                              "> residentId", "> organizationId", "> recipientBarangayId",
                                              "recipientType", "routingStatus", "location", "attachmentUrl",
                                              "submittedAt"]),
        ("emergency_reports", 800, 604, ["# id", "> reporterId", "emergencyType", "description", "location",
                                         "barangay", "routedAgency", "status", "imageUrl", "createdAt"]),
        ("document_requests", 800, 864, ["# id", "> userId", "type", "status", "paymentStatus", "note", "createdAt"]),
        ("notifications", 440, 616, ["# id", "> userId", "type", "title", "message", "referenceId", "read",
                                     "createdAt"]),
    ]
    ids = {}
    for name, x, y, fields in ents:
        h = r4(40 + len(fields) * 18 + 8)
        sw = 3 if name == "users" else 1.2
        eid = d.v(x, y, 240, h, name,
                  f"swimlane;fontStyle=1;horizontal=1;startSize=36;collapsible=0;"
                  f"html=1;rounded=1;arcSize=4;"
                  f"fillColor=#FFFFFF;swimlaneFillColor=#FFFFFF;strokeColor=#000000;strokeWidth={sw};fontSize=14;")
        ids[name] = eid
        for i, f in enumerate(fields):
            if f.startswith("#"):
                val = f"<b>PK&nbsp;&nbsp;{esc(f[1:].strip())}</b>"
            elif f.startswith(">"):
                val = f'<font color="#555555">FK</font>&nbsp;&nbsp;{esc(f[1:].strip())}'
            else:
                val = f'<font color="#555555">&nbsp;&nbsp;&nbsp;&nbsp;{esc(f)}</font>'
            d.cells.append(
                f'<mxCell id="{eid}f{i}" value="{esc(val)}" style="text;html=1;strokeColor=none;fillColor=none;align=left;'
                f'verticalAlign=middle;spacingLeft=12;fontSize=11;fontFamily=Courier New;" vertex="1" parent="{eid}">'
                f'<mxGeometry y="{40 + 18 * i}" width="240" height="18" as="geometry"/></mxCell>')
    g = {k: d.geo[v] for k, v in ids.items()}
    crow = LINE + "startArrow=ERmandOne;endArrow=ERmany;startSize=10;endSize=10;"
    u = ids["users"]
    E = d.e
    E([(200, 212), (200, 240), (500, 240), (500, 272)], ids["barangay_profiles"], u, crow)
    E([(560, 212), (560, 272)], ids["lgu_departments"], u, crow)
    E([(880, 212), (880, 240), (620, 240), (620, 272)], ids["organizations"], u, crow)
    E([(960, 212), (960, 272)], ids["organizations"], ids["submissions (concerns)"], crow)
    mid = lambda n: g[n][1] + g[n][3] / 2
    E([(440, mid("posts")), (320, mid("posts"))], u, ids["posts"], crow)
    E([(440, 460), (368, 460), (368, mid("alerts")), (320, mid("alerts"))], u, ids["alerts"], crow)
    E([(440, 500), (400, 500), (400, mid("audit_logs")), (320, mid("audit_logs"))], u, ids["audit_logs"], crow)
    sub = "submissions (concerns)"
    E([(680, mid(sub)), (800, mid(sub))], u, ids[sub], crow)
    E([(680, 476), (752, 476), (752, mid("emergency_reports")), (800, mid("emergency_reports"))], u,
      ids["emergency_reports"], crow)
    E([(680, 516), (720, 516), (720, mid("document_requests")), (800, mid("document_requests"))], u,
      ids["document_requests"], crow)
    E([(560, g["users"][1] + g["users"][3]), (560, 616)], u, ids["notifications"], crow)
    d.legend(1076, 1120, [("focal", "Central entity"), ("crow", "One to many (crow's foot)")])
    d.text(560, 1076, 528, 16, "PK primary key · FK foreign key (document ID) · Cloud Firestore collections",
           11, False, "left", "#333333")
    d.save("05-entity-relationship-diagram", "Entity-Relationship Diagram", 1120, 1120)


if __name__ == "__main__":
    architecture()
    use_case()
    flowchart()
    dfd_context()
    activity()
    er()

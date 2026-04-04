#!/usr/bin/env python3
"""Generate StitchSmart Architecture Diagram PDF"""

from reportlab.lib.pagesizes import A3, landscape
from reportlab.lib import colors
from reportlab.lib.units import mm
from reportlab.pdfgen import canvas
from reportlab.lib.colors import HexColor, Color

OUTPUT = "StitchSmart_Architecture.pdf"
PAGE_W, PAGE_H = landscape(A3)

# ── Palette ────────────────────────────────────────────────────────────────
C_BG        = HexColor("#F8F9FA")
C_TITLE_BG  = HexColor("#1A1A2E")
C_PRIMARY   = HexColor("#7B3FF2")
C_OWNER     = HexColor("#FF6B35")
C_TAILOR    = HexColor("#4CAF50")
C_CUSTOMER  = HexColor("#2196F3")
C_DELIVERY  = HexColor("#00BCD4")
C_FIREBASE  = HexColor("#FF9800")
C_MODEL     = HexColor("#9C27B0")
C_FLOW      = HexColor("#E91E63")
C_WHITE     = colors.white
C_DARK      = HexColor("#1A1A2E")
C_GREY      = HexColor("#78909C")
C_LIGHT_BG  = HexColor("#ECEFF1")
C_BORDER    = HexColor("#CFD8DC")

def draw_rounded_rect(c, x, y, w, h, r=4*mm, fill=None, stroke=None, stroke_width=1):
    p = c.beginPath()
    p.moveTo(x + r, y)
    p.lineTo(x + w - r, y)
    p.arcTo(x + w - r, y, x + w, y + r, 270, 90)
    p.lineTo(x + w, y + h - r)
    p.arcTo(x + w - r, y + h - r, x + w, y + h, 0, 90)
    p.lineTo(x + r, y + h)
    p.arcTo(x, y + h - r, x + r, y + h, 90, 90)
    p.lineTo(x, y + r)
    p.arcTo(x, y, x + r, y + r, 180, 90)
    p.close()
    if fill:
        c.setFillColor(fill)
    if stroke:
        c.setStrokeColor(stroke)
        c.setLineWidth(stroke_width)
    if fill and stroke:
        c.drawPath(p, fill=1, stroke=1)
    elif fill:
        c.drawPath(p, fill=1, stroke=0)
    else:
        c.drawPath(p, fill=0, stroke=1)

def mix(col, ratio):
    """Mix a HexColor with white at the given ratio (0=original, 1=white)."""
    r = col.red + (1 - col.red) * ratio
    g = col.green + (1 - col.green) * ratio
    b = col.blue + (1 - col.blue) * ratio
    return Color(r, g, b)

def center_text(c, text, x, y, w, font, size, color):
    c.setFont(font, size)
    c.setFillColor(color)
    tw = c.stringWidth(text, font, size)
    c.drawString(x + (w - tw) / 2, y, text)

def draw_arrow(c, x1, y1, x2, y2, color=None, dash=None):
    if color:
        c.setStrokeColor(color)
    c.setLineWidth(1.2)
    if dash:
        c.setDash(dash)
    else:
        c.setDash([])
    c.line(x1, y1, x2, y2)
    # Arrowhead
    import math
    dx, dy = x2 - x1, y2 - y1
    length = math.sqrt(dx*dx + dy*dy)
    if length == 0:
        return
    ux, uy = dx/length, dy/length
    size = 5
    ax1 = x2 - size*ux + size*0.5*uy
    ay1 = y2 - size*uy - size*0.5*ux
    ax2 = x2 - size*ux - size*0.5*uy
    ay2 = y2 - size*uy + size*0.5*ux
    if color:
        c.setFillColor(color)
    c.setStrokeColor(color if color else colors.black)
    p = c.beginPath()
    p.moveTo(x2, y2)
    p.lineTo(ax1, ay1)
    p.lineTo(ax2, ay2)
    p.close()
    c.drawPath(p, fill=1, stroke=0)
    c.setDash([])

def pill(c, x, y, w, h, text, font, size, bg, fg):
    draw_rounded_rect(c, x, y, w, h, r=h/2, fill=bg, stroke=None)
    center_text(c, text, x, y + h*0.28, w, font, size, fg)

# ── Screen-group box ───────────────────────────────────────────────────────
def screen_box(c, x, y, w, h, title, screens, header_color, text_color=C_WHITE):
    draw_rounded_rect(c, x, y, w, h, r=5*mm, fill=C_WHITE, stroke=header_color, stroke_width=1.5)
    # Header strip
    draw_rounded_rect(c, x, y + h - 11*mm, w, 11*mm, r=4*mm, fill=header_color)
    # Fix bottom corners of header
    c.setFillColor(header_color)
    c.rect(x, y + h - 11*mm, w, 5*mm, fill=1, stroke=0)
    center_text(c, title, x, y + h - 8*mm, w, "Helvetica-Bold", 9, text_color)
    # Screens
    line_h = 7.5*mm
    for i, scr in enumerate(screens):
        sy = y + h - 14*mm - (i+1)*line_h
        draw_rounded_rect(c, x+4*mm, sy, w-8*mm, 6*mm, r=1.5*mm,
                          fill=mix(header_color, 0.85),
                          stroke=mix(header_color, 0.5), stroke_width=0.5)
        c.setFont("Helvetica", 7)
        c.setFillColor(C_DARK)
        c.drawString(x + 7*mm, sy + 1.8*mm, scr)

# ── Firebase collection box ────────────────────────────────────────────────
def firestore_box(c, x, y, w, h, collection, fields):
    draw_rounded_rect(c, x, y, w, h, r=3*mm, fill=HexColor("#FFF8E1"), stroke=C_FIREBASE, stroke_width=1)
    c.setFont("Helvetica-Bold", 7.5)
    c.setFillColor(C_FIREBASE)
    c.drawString(x+3*mm, y+h-5.5*mm, collection)
    c.setFont("Helvetica", 6.5)
    c.setFillColor(C_GREY)
    for i, f in enumerate(fields):
        c.drawString(x+3*mm, y+h-10*mm - i*5.5*mm, f"• {f}")

# ── Model box ──────────────────────────────────────────────────────────────
def model_box(c, x, y, w, h, name, fields):
    draw_rounded_rect(c, x, y, w, h, r=3*mm, fill=HexColor("#F3E5F5"), stroke=C_MODEL, stroke_width=1)
    c.setFont("Helvetica-Bold", 7.5)
    c.setFillColor(C_MODEL)
    c.drawString(x+3*mm, y+h-5.5*mm, name)
    c.setFont("Courier", 6)
    c.setFillColor(C_DARK)
    for i, f in enumerate(fields):
        c.drawString(x+3*mm, y+h-10*mm - i*5*mm, f)

# ══════════════════════════════════════════════════════════════════════════
def build():
    c = canvas.Canvas(OUTPUT, pagesize=landscape(A3))
    W, H = PAGE_W, PAGE_H

    # ── Background ────────────────────────────────────────────────────────
    c.setFillColor(C_BG)
    c.rect(0, 0, W, H, fill=1, stroke=0)

    # ── Title bar ─────────────────────────────────────────────────────────
    c.setFillColor(C_TITLE_BG)
    c.rect(0, H - 22*mm, W, 22*mm, fill=1, stroke=0)
    c.setFont("Helvetica-Bold", 18)
    c.setFillColor(C_WHITE)
    c.drawString(14*mm, H - 14*mm, "StitchSmart — Application Architecture")
    c.setFont("Helvetica", 9)
    c.setFillColor(HexColor("#90CAF9"))
    c.drawString(14*mm, H - 19*mm, "Flutter · Firebase · Google Sign-In · Claude AI · GoRouter")
    # Legend pills
    legend = [("Owner", C_OWNER), ("Tailor", C_TAILOR), ("Customer", C_CUSTOMER), ("Delivery", C_DELIVERY)]
    lx = W - 5*mm
    for label, col in reversed(legend):
        lw = c.stringWidth(label, "Helvetica-Bold", 8) + 10*mm
        lx -= lw + 3*mm
        pill(c, lx, H - 15*mm, lw, 7*mm, label, "Helvetica-Bold", 8, col, C_WHITE)

    TOP = H - 26*mm
    MARGIN = 10*mm

    # ═══════════════════════ LAYER LABELS ═════════════════════════════════
    def layer_label(text, y):
        c.setFont("Helvetica-Bold", 7)
        c.setFillColor(C_GREY)
        c.drawString(MARGIN, y, text)
        c.setStrokeColor(C_BORDER)
        c.setLineWidth(0.5)
        c.line(MARGIN + c.stringWidth(text, "Helvetica-Bold", 7) + 3*mm, y + 2, W - MARGIN, y + 2)

    # ── Layer Y positions ─────────────────────────────────────────────────
    Y_AUTH    = TOP - 32*mm
    Y_ROUTER  = TOP - 55*mm
    Y_SCREENS = TOP - 130*mm
    Y_STATE   = TOP - 155*mm
    Y_MODELS  = TOP - 195*mm
    Y_FIRE    = TOP - 232*mm

    layer_label("AUTHENTICATION & ROLE DETECTION", TOP - 3*mm)
    layer_label("NAVIGATION  (GoRouter)", TOP - 26*mm)
    layer_label("SCREENS BY ROLE", TOP - 48*mm)
    layer_label("APP STATE  (ChangeNotifier Singleton)", TOP - 122*mm)
    layer_label("DOMAIN MODELS", TOP - 162*mm)
    layer_label("FIREBASE COLLECTIONS  (Firestore)", TOP - 199*mm)

    # ═══════════════════════ AUTH ROW ═════════════════════════════════════
    auth_boxes = [
        ("Google Sign-In", HexColor("#4285F4"), "OAuth 2.0\ngoogle_sign_in"),
        ("Firebase Auth", HexColor("#FF9800"), "Email / Google\nfirebase_auth"),
        ("Role Detection", C_PRIMARY, "config/admin\nownerEmails / tailorEmails\ndeliveryEmails"),
        ("Splash Screen", C_DARK, "Auto-redirect\nbased on role"),
    ]
    bw = (W - 2*MARGIN - 9*mm) / 4
    for i, (title, col, sub) in enumerate(auth_boxes):
        bx = MARGIN + i*(bw + 3*mm)
        draw_rounded_rect(c, bx, Y_AUTH, bw, 20*mm, r=3*mm, fill=mix(col, 0.9), stroke=col, stroke_width=1.5)
        c.setFont("Helvetica-Bold", 8.5)
        c.setFillColor(col)
        c.drawString(bx+3*mm, Y_AUTH+14*mm, title)
        c.setFont("Helvetica", 6.5)
        c.setFillColor(C_GREY)
        for j, line in enumerate(sub.split("\n")):
            c.drawString(bx+3*mm, Y_AUTH+9*mm - j*5*mm, line)
        if i < 3:
            draw_arrow(c, bx+bw, Y_AUTH+10*mm, bx+bw+3*mm, Y_AUTH+10*mm, C_GREY)

    # ═══════════════════════ ROUTER ROW ═══════════════════════════════════
    routes = [
        ("/", "Splash", C_DARK),
        ("/login", "Login", C_GREY),
        ("/home", "Home", C_CUSTOMER),
        ("/owner", "Owner\nDashboard", C_OWNER),
        ("/tailor", "Tailor\nDashboard", C_TAILOR),
        ("/delivery", "Delivery\nDashboard", C_DELIVERY),
        ("/orders", "My Orders", C_CUSTOMER),
        ("/designer", "Designer", C_CUSTOMER),
        ("/measurements", "Measurements", C_CUSTOMER),
        ("/catalog", "Catalog", C_CUSTOMER),
    ]
    rw = (W - 2*MARGIN - 9*mm*(len(routes)-1)) / len(routes)
    for i, (path, label, col) in enumerate(routes):
        rx = MARGIN + i*(rw + 3*mm)
        draw_rounded_rect(c, rx, Y_ROUTER, rw, 18*mm, r=2.5*mm, fill=mix(col, 0.88), stroke=col, stroke_width=1)
        c.setFont("Courier-Bold", 6)
        c.setFillColor(col)
        c.drawString(rx+2*mm, Y_ROUTER+13*mm, path)
        c.setFont("Helvetica", 6.5)
        c.setFillColor(C_DARK)
        for j, line in enumerate(label.split("\n")):
            c.drawString(rx+2*mm, Y_ROUTER+8.5*mm - j*5*mm, line)

    # ═══════════════════════ SCREEN GROUPS ════════════════════════════════
    group_w = (W - 2*MARGIN - 3*3*mm) / 4
    groups = [
        ("CUSTOMER", C_CUSTOMER, [
            "home_screen.dart",
            "measurement_dashboard_screen.dart",
            "camera_measurement_screen.dart",
            "measurement_result_screen.dart",
            "dress_catalog_screen.dart",
            "dress_detail_screen.dart",
            "dress_designer_screen.dart",
            "orders_screen.dart",
        ]),
        ("TAILOR", C_TAILOR, [
            "tailor_dashboard_screen.dart",
            "  · My Orders tab",
            "  · Rate Card tab",
            "  pending → inProgress",
            "  → readyForPickup",
        ]),
        ("OWNER", C_OWNER, [
            "owner_dashboard_screen.dart",
            "  · Stats cards",
            "  · Tailors management",
            "  · Delivery partners",
            "  · Delivery settings",
            "rates_management_screen.dart",
            "  · Claude AI key config",
        ]),
        ("DELIVERY", C_DELIVERY, [
            "delivery_dashboard_screen.dart",
            "  · Subscription status",
            "  · Available orders",
            "  · My deliveries",
            "  · Earnings tracker",
            "  readyForPickup →",
            "  → outForDelivery →",
            "  → delivered",
        ]),
    ]
    for i, (role, col, screens) in enumerate(groups):
        gx = MARGIN + i*(group_w + 3*mm)
        gh = 66*mm
        gy = Y_SCREENS
        screen_box(c, gx, gy, group_w, gh, role + " SCREENS", screens, col)

    # ═══════════════════════ APP STATE ════════════════════════════════════
    state_y = Y_STATE
    state_h = 30*mm
    draw_rounded_rect(c, MARGIN, state_y, W-2*MARGIN, state_h, r=4*mm,
                      fill=mix(C_PRIMARY, 0.93),
                      stroke=C_PRIMARY, stroke_width=1.5)
    c.setFont("Helvetica-Bold", 9)
    c.setFillColor(C_PRIMARY)
    c.drawString(MARGIN+4*mm, state_y+state_h-7*mm, "AppState  (lib/core/app_state.dart)  —  ChangeNotifier Singleton")

    state_sections = [
        ("Auth", ["isLoggedIn", "signOut()", "displayName", "initials"]),
        ("Profile & Role", ["loadUserProfile(uid)", "saveUserProfile()", "getRoleFromConfig(email)", "setProfile(profile)"]),
        ("Rates", ["loadRates()", "updateRate()", "deleteRate()", "_seedDefaultRates()"]),
        ("Delivery", ["enrollDeliveryPartner(email)", "removeDeliveryPartner(email)", "saveDeliverySettings()", "getDeliverySettings()"]),
        ("Orders", ["updateOrderStatus(id, status)"]),
        ("AI", ["saveClaudeApiKey(key)", "getClaudeApiKey()"]),
    ]
    sw = (W - 2*MARGIN - 5*3*mm) / 6
    for i, (sec_title, items) in enumerate(state_sections):
        sx = MARGIN + i*(sw + 3*mm)
        sy = state_y + 3*mm
        sh = state_h - 11*mm
        draw_rounded_rect(c, sx, sy, sw, sh, r=2*mm,
                          fill=C_WHITE, stroke=mix(C_PRIMARY, 0.6), stroke_width=0.7)
        c.setFont("Helvetica-Bold", 6.5)
        c.setFillColor(C_PRIMARY)
        c.drawString(sx+2*mm, sy+sh-5*mm, sec_title)
        c.setFont("Courier", 5.5)
        c.setFillColor(C_DARK)
        for j, item in enumerate(items):
            c.drawString(sx+2*mm, sy+sh-10*mm - j*4.5*mm, item)

    # ═══════════════════════ MODELS ═══════════════════════════════════════
    models = [
        ("DressOrder", [
            "id: String",
            "dressType: String",
            "tailorName: String",
            "customerId: String?",
            "status: OrderStatus",
            "paymentStatus: PaymentStatus",
            "orderDate: DateTime",
            "deliveryDate: DateTime?",
            "price: double",
            "fabricDescription: String?",
            "deliveryAddress: String?",
            "deliveryPartnerId: String?",
            "deliveryFee: double",
        ]),
        ("OrderStatus (enum)", [
            "pending",
            "inProgress",
            "readyForPickup",
            "outForDelivery  ← NEW",
            "delivered",
            "cancelled",
            "",
            ".label → String",
            ".color → Color",
        ]),
        ("PaymentStatus (enum)", [
            "unpaid",
            "advancePaid",
            "fullyPaid",
            "",
            ".label → String",
            ".color → Color",
        ]),
        ("UserProfile", [
            "name: String",
            "gender: Gender",
            "age: int",
            "role: UserRole",
            "email: String?",
            "photoUrl: String?",
        ]),
        ("UserRole (enum)", [
            "customer",
            "tailor",
            "owner",
            "delivery  ← NEW",
        ]),
        ("StitchingRate", [
            "dressType: String",
            "basePrice: double",
            "notes: String?",
        ]),
        ("BodyMeasurements", [
            "shoulder: double",
            "chest: double",
            "waist: double",
            "hip: double",
            "height: double",
        ]),
    ]
    mw = (W - 2*MARGIN - 6*3*mm) / 7
    for i, (name, fields) in enumerate(models):
        mx = MARGIN + i*(mw + 3*mm)
        mh = 30*mm
        model_box(c, mx, Y_MODELS, mw, mh, name, fields)

    # ═══════════════════════ FIRESTORE ════════════════════════════════════
    fire_cols = [
        ("users/{uid}", ["name", "email", "role", "photoUrl", "age", "setupComplete"]),
        ("orders/{orderId}", ["dressType", "tailorName", "customerId", "status", "paymentStatus", "orderDate", "deliveryDate", "price", "deliveryAddress", "deliveryPartnerId", "deliveryFee"]),
        ("config/admin", ["ownerEmails: []", "tailorEmails: []", "deliveryEmails: []"]),
        ("config/delivery", ["feePerOrder: double", "subscriptionFee: double"]),
        ("config/api", ["claudeKey: String"]),
        ("rates/{dressType}", ["dressType", "basePrice", "notes"]),
        ("subscriptions/{email}", ["email", "active: bool", "subscribedAt", "subscribedUntil", "totalDeliveries"]),
    ]
    fw = (W - 2*MARGIN - 6*3*mm) / 7
    for i, (coll, fields) in enumerate(fire_cols):
        fx = MARGIN + i*(fw + 3*mm)
        fh = 28*mm
        firestore_box(c, fx, Y_FIRE, fw, fh, coll, fields)

    # ═══════════════════════ ORDER STATUS FLOW ════════════════════════════
    flow_y = 6*mm
    flow_statuses = [
        ("pending", C_GREY, "Customer\nplaces order"),
        ("inProgress", HexColor("#2196F3"), "Tailor starts\nstitching"),
        ("readyForPickup", HexColor("#9C27B0"), "Tailor marks\nready"),
        ("outForDelivery", HexColor("#00BCD4"), "Delivery partner\naccepts"),
        ("delivered", HexColor("#4CAF50"), "Delivered to\ncustomer"),
    ]
    fw2 = 36*mm
    total_w = len(flow_statuses)*fw2 + (len(flow_statuses)-1)*8*mm
    start_x = (W - total_w) / 2
    c.setFont("Helvetica-Bold", 7)
    c.setFillColor(C_DARK)
    tw = c.stringWidth("ORDER STATUS FLOW", "Helvetica-Bold", 7)
    c.drawString(start_x, flow_y + 13*mm, "ORDER STATUS FLOW →")
    for i, (status, col, actor) in enumerate(flow_statuses):
        fx2 = start_x + i*(fw2 + 8*mm)
        draw_rounded_rect(c, fx2, flow_y, fw2, 11*mm, r=2*mm, fill=mix(col, 0.85), stroke=col, stroke_width=1.2)
        c.setFont("Helvetica-Bold", 7)
        c.setFillColor(col)
        center_text(c, status, fx2, flow_y+7*mm, fw2, "Helvetica-Bold", 7, col)
        c.setFont("Helvetica", 5.5)
        c.setFillColor(C_GREY)
        for j, line in enumerate(actor.split("\n")):
            center_text(c, line, fx2, flow_y+3.5*mm - j*4*mm, fw2, "Helvetica", 5.5, C_GREY)
        if i < len(flow_statuses)-1:
            ax = fx2 + fw2 + 0.5*mm
            draw_arrow(c, ax, flow_y+5.5*mm, ax+7*mm, flow_y+5.5*mm, col)

    # ── Footer ─────────────────────────────────────────────────────────────
    c.setFont("Helvetica", 7)
    c.setFillColor(C_GREY)
    c.drawString(MARGIN, 2.5*mm, "StitchSmart · Flutter + Firebase Architecture · Generated 2026")
    c.drawRightString(W - MARGIN, 2.5*mm, "Roles: Customer | Tailor | Owner | Delivery Partner")

    c.save()
    print(f"✓ Saved: {OUTPUT}")

build()

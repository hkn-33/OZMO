# PRODUCT.md — OZMO

> Binding product context for design decisions. Read before any UI work.

## What it is
OZMO is the operating system for restaurant and hotel chains ("sieci lokali"). It replaces
the daily patchwork of Excel, WhatsApp and paper checklists with one system: tasks &
checklists, team chats, work schedules, stock levels, daily reports and cost control —
per branch and across the whole network.

## Register
**Product** (design SERVES the work). This is a tool people use on shift, every day, fast.
Not a marketing surface — except the public landing page (`/`, anon), which is **brand**
register and is the one place identity leads.

## Platform
Web, **mobile-first**, installable PWA. Used on phones behind the bar and on a manager's
laptop in the back office. Bottom nav + sheets on mobile; sidebar on desktop.

## Audience
- **Owners / network managers (właściciele)** — oversight across branches: costs, reports,
  network stock. Business-literate, not necessarily technical.
- **Branch managers (kierownicy/menadżerowie)** — build schedules, close daily reports,
  assign tasks, manage stock. On the floor and at a desk.
- **Shift workers (kelnerzy, kuchnia, obsługa)** — run checklists, read the chat, check the
  schedule, log stock movements. Often non-technical, phone-only, moving fast, sometimes
  gloved hands and poor lighting. Speed and legibility beat cleverness.

All Polish-speaking, Polish UI. Diacritics must render perfectly.

## Jobs to be done
1. Run opening/closing/Sanepid **checklists** from templates, split across people.
2. Coordinate the team over **chat** (network channel + per-branch channels).
3. Build, copy and publish the weekly **schedule**; collect availability.
4. Track **stock**: receipts, issues, low-stock alerts — per branch and network-wide.
5. File the **daily report** (worker notes + manager report with a closing lock).
6. Watch **cost %** (food / beverage / labor) per branch and across the network.

## Tone
Professional, warm, zero-fluff. Confident and calm, never loud. Sentence case, plain Polish,
no ALL-CAPS, no marketing clichés, no exclamation marks in success states. Numbers are
honest and specific.

## Design north star
On a phone, mid-shift: a worker should find the next thing to do in **one glance**. Status
must be readable by colour + label before reading a single word. Every screen answers
"where am I, what matters here, what do I do next" without effort.

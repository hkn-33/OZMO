# PRODUCT.md — OZMO

> Binding product context for design decisions. Read before any UI work.

## What it is
OZMO is the daily operations system for shift-based businesses with one or many locations.
It replaces the patchwork of Excel, chat threads and paper checklists with one system:
tasks, team chat, schedules, stock, daily reports and cost control. Industry presets help
with setup, but no core workflow assumes gastronomy, hotels or retail.

## Register
**Product** (design SERVES the work). This is a tool people use on shift, every day, fast.
Not a marketing surface — except the public landing page (`/`, anon), which is **brand**
register and is the one place identity leads.

## Platform
Web, **mobile-first**, installable PWA. Used on phones behind the bar and on a manager's
laptop in the back office. Bottom nav + sheets on mobile; sidebar on desktop.

## Audience
- **Owners (właściciele)** — oversight of one location or the whole company: exceptions,
  costs, reports and stock. Business-literate, not necessarily technical.
- **Branch managers (kierownicy/menadżerowie)** — build schedules, close daily reports,
  assign tasks, manage stock. On the floor and at a desk.
- **Shift workers (obsługa, recepcja, sprzedaż, magazyn)** — run checklists, read the chat, check the
  schedule, log stock movements. Often non-technical, phone-only, moving fast, sometimes
  gloved hands and poor lighting. Speed and legibility beat cleverness.

All Polish-speaking, Polish UI. Diacritics must render perfectly.

## Jobs to be done
1. Run opening, closing, safety and quality **checklists** from configurable templates.
2. Coordinate the team over **chat** (company channel + per-location channels).
3. Build, copy and publish the weekly **schedule**; collect availability.
4. Track **stock**: receipts, usage, waste and low-stock lists — per location and company-wide.
5. File the **daily report** (worker notes + manager report with a closing lock).
6. Watch configurable **costs and revenue** per location and across the company.

## Product defaults
- The first location is created automatically during onboarding.
- With one location, network controls and branch switching stay hidden.
- The dashboard leads with exceptions and actions required today, not vanity metrics.
- POS and accounting integrations are later work; manual entry and imports must remain useful alone.

## Tone
Professional, warm, zero-fluff. Confident and calm, never loud. Sentence case, plain Polish,
no ALL-CAPS, no marketing clichés, no exclamation marks in success states. Numbers are
honest and specific.

## Design north star
On a phone, mid-shift: a worker should find the next thing to do in **one glance**. Status
must be readable by colour + label before reading a single word. Every screen answers
"where am I, what matters here, what do I do next" without effort.

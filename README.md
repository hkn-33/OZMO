# OZMO

**System open-source do zarządzania firmą wielooddziałową.** Jedno miejsce zamiast Excela,
WhatsAppa i papierowych checklist — dla sieci kawiarni, restauracji, hoteli, sklepów, magazynów
i hurtowni. Nic branżowego nie jest zaszyte na sztywno: branżę wybierasz przy zakładaniu firmy,
a checklisty, kategorie kosztów i sekcje raportów są konfigurowalne.

## Moduły

- **Zadania i checklisty** — otwarcia, zamknięcia i kontrole z gotowych szablonów, widok listy i Kanban, przydzielanie, postęp na żywo.
- **Grafik pracy** — zmiany tygodniowe, dostępność zespołu, kopiowanie tygodnia, publikacja z powiadomieniami.
- **Czaty zespołu (realtime)** — kanał firmy i kanały oddziałów, wskaźnik pisania, historia z bazy.
- **Magazyn i inwentaryzacja** — przyjęcia/wydania, stany liczone z ruchów, alerty niskiego stanu, spis z natury (M12).
- **Raporty dnia** — raport pracownika i menadżera z blokadą zamknięcia zmiany do wypełnienia wymaganych sekcji.
- **Koszty i przychody** — własne kategorie, KPI per oddział i dla całej sieci, przychód zasilany z raportów.

Multi-tenant: **organizacja → oddziały → członkowie**, z rolami globalnymi (owner/admin/member)
i lokalnymi (manager/employee). Cała logika uprawnień jest w **RLS** (deny-by-default), nie w kliencie.

## Stack techniczny

| Warstwa | Technologia |
|---|---|
| Frontend | Nuxt 4 (Vue 3, SSR), PWA |
| Styling | Tailwind CSS v4 (CSS-first) + shadcn-vue |
| Backend / DB | Supabase (PostgreSQL, RLS, Realtime, Storage, pg_cron) |
| Auth | Supabase Auth (login po nazwie użytkownika lub e-mailu) |
| Typy | TypeScript, typy DB generowane z bazy |
| Testy | Playwright (E2E) |

## Self-host — szybki start

Wymagania: **Node 22+**, **Docker** (lokalny stack Supabase), **Supabase CLI 2.x**.

```bash
# 1. Zależności
npm install

# 2. Lokalny Supabase (Docker) — migracje + seed uruchamiają się automatycznie
supabase start
supabase db reset          # aplikuje migracje z supabase/migrations/ + supabase/seed.sql

# 3. Zmienne środowiskowe
cp .env.example .env        # uzupełnij URL + klucze z `supabase status`

# 4. Typy bazy (po każdej zmianie schematu)
npm run db:types

# 5. Dev
npm run dev                 # http://localhost:3000

# 6. Produkcja
npm run build && npm run preview
```

Zmienne w `.env` (patrz `.env.example`): `SUPABASE_URL`, `SUPABASE_KEY` (publishable/anon)
oraz `SUPABASE_SERVICE_KEY` (tylko po stronie serwera — nigdy w kliencie).

Wdrożenie na własnym serwerze: własny projekt Supabase (chmura lub self-host) + aplikacja Nuxt
za dowolnym hostingiem Node. Migracje z `supabase/migrations/` wgrywasz przez `supabase db push`
lub panel. Aby publiczne demo resetowało się co godzinę, włącz rozszerzenie `pg_cron`.

## Konto demo

Publiczne demo (`demo-public` / `OzmoDemo2026`) daje pełną swobodę klikania — dane resetują się
co godzinę (`pg_cron` → `private.reset_demo_org()`). Przy self-host oznaczasz organizację demo
flagą `organizations.is_public_demo = true`.

## Testy

```bash
npm run test:e2e            # Playwright (wymaga uruchomionego lokalnego Supabase)
```

## Licencja i model

OZMO jest wydawane na licencji **GNU AGPL-3.0** (patrz [`LICENSE`](./LICENSE)). Możesz je
uruchamiać, modyfikować i hostować samodzielnie za darmo; jeśli udostępniasz zmodyfikowaną wersję
przez sieć, musisz udostępnić także jej kod źródłowy.

**Wersja hostowana** (utrzymywana i rozwijana przez nas, z wsparciem) jest **płatna** —
to sposób finansowania rozwoju projektu open source.

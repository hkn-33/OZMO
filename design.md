# OZMO — Design Document

> System operacyjny dla sieci lokali (restauracje, hotele). Zastępuje Excela, WhatsAppa, papierowe checklisty i rozproszone narzędzia jednym systemem.
>
> **Ten dokument jest źródłem prawdy.** Każda zmiana architektury lub zakresu musi być najpierw odnotowana tutaj.

## 1. Wizja i zakres

- Docelowo: sieć ~12 lokali (oddziałów) w ramach jednej lub wielu firm.
- Użytkownicy: właściciel sieci, menadżerowie lokali, pracownicy zmianowi.
- Priorytet UX: **mobile-first**, prostota — pracownicy nie są techniczni. Maks. 2–3 kliknięcia do każdej codziennej akcji.
- Języki UI: polski (na start).

## 2. Stack techniczny

| Warstwa | Technologia | Uwagi |
|---|---|---|
| Frontend | Nuxt (Vue 3, SSR) | mobile-first, PWA-ready |
| Styling | Tailwind CSS | |
| Komponenty UI | shadcn-vue | komponenty kopiowane do `app/components/ui/` |
| Backend / DB | Supabase (PostgreSQL) | lokalny dev przez Supabase CLI + Docker, migracje w repo |
| Auth | Supabase Auth | email+hasło; zaproszenia mailowe |
| Real-time | Supabase Realtime | broadcast (czaty), postgres_changes (zadania, powiadomienia) |
| Storage | Supabase Storage | załączniki zadań/czatów, avatary |
| Typy | TypeScript wszędzie | typy DB generowane: `supabase gen types` |

Szczegóły wersji i konfiguracji: patrz sekcja 10 (uzupełniana po researchu / w trakcie budowy).

## 3. Architektura wysokopoziomowa

```
Przeglądarka (Nuxt SSR/SPA)
   │  @nuxtjs/supabase (sesja, klient)
   ▼
Supabase
   ├── Auth (JWT, role w app_metadata nie są źródłem prawdy — patrz RLS)
   ├── PostgreSQL + RLS (cała logika uprawnień na poziomie bazy)
   ├── Realtime (broadcast: czaty; postgres_changes: zadania, powiadomienia)
   ├── Storage (bucket: attachments, avatars)
   └── Edge Functions (tylko gdy konieczne: np. cron do powiadomień o terminach)
```

Zasady:
- **Logika uprawnień w RLS**, nie w kliencie. Klient tylko ukrywa UI.
- Brak własnego serwera API — Nuxt server routes tylko do rzeczy niemożliwych z klienta (np. operacje z service_role: tworzenie zaproszeń).
- Wszystkie migracje w `supabase/migrations/` — wersjonowane, odtwarzalne.

## 4. Model domeny (multi-tenant)

Hierarchia: **organizacja → oddziały (lokale) → członkowie**.

```
organizations          -- firma / sieć
  └── branches         -- lokal (restauracja, hotel)
        └── branch_members  -- przypisanie user↔lokal z rolą lokalną

org_members            -- przypisanie user↔organizacja z rolą globalną
profiles               -- dane użytkownika (1:1 z auth.users)
```

### Role i uprawnienia

Dwa poziomy ról:

**Rola w organizacji** (`org_members.role`):
| Rola | Uprawnienia |
|---|---|
| `owner` | wszystko: firmy, oddziały, ludzie, ustawienia, koszty całej sieci |
| `admin` | jak owner, bez usuwania organizacji i zarządzania ownerami |
| `member` | dostęp tylko do oddziałów, do których jest przypisany |

**Rola w oddziale** (`branch_members.role`):
| Rola | Uprawnienia |
|---|---|
| `manager` | zarządza lokalem: zadania, grafik, raporty, magazyn, zespół lokalu |
| `employee` | widzi i wykonuje swoje zadania, checklisty, czaty, swój grafik |

Owner/admin organizacji ma implicite dostęp `manager` do każdego oddziału (funkcja helper w SQL, nie duplikaty wierszy).

### Tabele rdzenia

```sql
profiles        (id → auth.users, full_name, avatar_url, phone)
organizations   (id, name, slug, created_by)
org_members     (org_id, user_id, role: owner|admin|member)
branches        (id, org_id, name, address, timezone, active)
branch_members  (branch_id, user_id, role: manager|employee, position text)
invitations     (id, org_id, branch_id?, email, role, token, expires_at, accepted_at)
```

### Strategia RLS

- Funkcje helper `security definer` (omijają rekursję RLS):
  - `is_org_member(org_id)`, `org_role(org_id)`, `has_branch_access(branch_id)`, `is_branch_manager(branch_id)`
- Każda tabela domenowa ma `org_id` (denormalizacja dla prostych polityk) + `branch_id` gdy dotyczy lokalu.
- Polityki: SELECT wg członkostwa, INSERT/UPDATE/DELETE wg roli.

## 5. Moduły

### M1. Zadania i checklisty
- Tabele: `tasks` (title, description, branch_id, status: todo|in_progress|done, priority, due_at, created_by), `task_assignees`, `checklist_templates` (org-level, items jsonb), `task_checklist_items` (task_id, label, done, done_by, done_at).
- Widoki: lista (filtry: status, przypisany, priorytet, termin), **Kanban** (drag&drop między kolumnami), szczegół zadania.
- Szablony startowe (seed): otwarcie lokalu, zamknięcie, sprzątanie, inwentaryzacja, Sanepid/HACCP.
- Z szablonu tworzy się zadanie z checklistą (kopiowanie itemów, nie referencja).

### M2. Czat przy zadaniach
- Tabela: `task_comments` (task_id, author_id, body, mentions uuid[]).
- @oznaczenia → wpis w `notifications`.
- Realtime: broadcast na kanał `task:{id}`.

### M3. Raport dnia (pracowniczy)
- Tabela: `day_notes` (branch_id, author_id, date, body, severity: info|issue).
- Prosty feed per lokal per dzień. Zero biurokracji: pole tekstowe + waga.

### M4. Powiadomienia
- Tabela: `notifications` (user_id, type, payload jsonb, read_at).
- Typy: task_assigned, mentioned, comment_on_my_task, task_due_soon, report_missing.
- Generowane triggerami DB (insert do task_assignees → notification) + cron (terminy).
- Dostarczanie: postgres_changes na `notifications` filtrowane po user_id; dzwoneczek + licznik.

### M5. Grafik pracy
- Tabele: `shifts` (branch_id, user_id, starts_at, ends_at, position, published bool), `availability` (user_id, branch_id, day, from, to), `shift_templates` (typowa obsada per dzień tygodnia).
- Widok tygodniowy per lokal; kopiowanie tygodnia; publikacja (draft → published → powiadomienia).
- „Automatyka" w MVP = podpowiedzi z szablonu obsady + dostępności (bez AI). Optymalizacja — faza 2.

### M6. Raport dzienny menadżerski
- Tabele: `manager_reports` (branch_id, date, status: draft|closed, closed_by, closed_at), `manager_report_sections` (report_id, section: utarg|kasa|sanepid|magazyn|zmiana, data jsonb, completed bool).
- **Blokada zamknięcia**: `status='closed'` możliwy tylko gdy wszystkie sekcje `completed` — CHECK przez trigger.
- Rozwijana checklista sekcji; utarg/kasa jako pola liczbowe → zasilają moduł kosztów.

### M7. Zarządzanie zespołem
- CRUD członków, zaproszenia mailem (server route + service_role), zmiana ról, przypisywanie do lokali, dezaktywacja.
- Widok struktury: organizacja → lokale → ludzie.

### M8. Magazyn i stany
- Tabele: `suppliers` (org-level), `products` (org-level: name, unit, category, min_stock per branch w `branch_product_settings`), `stock_levels` (branch_id, product_id, qty), `stock_movements` (branch_id, product_id, qty_delta, type: delivery|usage|waste|correction|transfer, note, doc_ref, created_by).
- WZ/dostawy = movement typu `delivery` z referencją dokumentu.
- Stan = suma ruchów (materializowane w `stock_levels` triggerem).
- Alert: stan < minimum → powiadomienie do menadżera.

### M9. Kontrola kosztów
- Tabele: `revenue_entries` (branch_id, date, amount — zasilane z raportu menadżerskiego), `cost_entries` (branch_id, date, category: food|beverage|labor|other, amount, source: manual|stock|payroll).
- Dashboard: Food Cost %, Beverage Cost %, Labor Cost % vs przychód; per lokal i per sieć; zakresy dat.
- MVP: wpisy ręczne + automatyczne z raportu dnia; integracje POS — przyszłość.

### M10. Czaty grupowe
- Tabele: `chat_channels` (org_id, branch_id nullable, type: org|branch|custom, name), `chat_members` (dla custom), `chat_messages` (channel_id, author_id, body, attachments).
- Auto-tworzone: 1 kanał ogólny sieci + 1 kanał per lokal (trigger przy tworzeniu branch).
- Realtime: broadcast; historia z DB (paginacja); nieprzeczytane: `chat_reads` (channel_id, user_id, last_read_at).

## 6. Realtime — zasady

| Funkcja | Mechanizm | Powód |
|---|---|---|
| Czaty (M2, M10) | broadcast + zapis do DB | niski lag, skala |
| Powiadomienia (M4) | postgres_changes na `notifications` | źródło = insert w DB |
| Kanban / zadania | postgres_changes na `tasks` per branch | rzadsze zmiany |
| Obecność w czacie | presence | opcjonalne, faza 2 |

## 7. Struktura projektu (Nuxt)

```
app/
  components/ui/        # shadcn-vue (generowane CLI)
  components/<moduł>/   # komponenty domenowe
  composables/          # useTasks, useChat, useNotifications...
  layouts/              # default (sidebar+bottom-nav mobile), auth
  middleware/           # auth, org-context
  pages/
    auth/               # login, register, accept-invite
    [org]/              # kontekst organizacji (slug)
      index.vue         # dashboard
      branches/[id]/    # kontekst lokalu: tasks, schedule, reports, stock, chat
      people/           # zespół
      costs/            # kosztowy dashboard
      chat/             # czaty
  stores/ (pinia)       # sesja, aktywna org/branch, licznik powiadomień
server/api/             # invitations, inne operacje service_role
supabase/
  migrations/
  seed.sql              # szablony checklist, dane demo
design.md               # TEN PLIK
```

## 8. Bezpieczeństwo i RODO

- RLS na **każdej** tabeli, deny-by-default.
- Klucz `service_role` tylko w server routes (env, nigdy w kliencie).
- Dane osobowe minimalne: imię, email, telefon (opcjonalny). Prawo do usunięcia: dezaktywacja + anonimizacja profilu.
- Storage: polityki dostępu per org/branch, pliki w ścieżkach `{org_id}/...`.
- Backupy: Supabase (chmura, po deployu); lokalnie — migracje + seed w git.

## 9. Fazy realizacji

| Faza | Zakres | Status |
|---|---|---|
| 0 | Scaffold: Nuxt + Tailwind + shadcn-vue + Supabase CLI + auth + layout | ⬜ |
| 1 | Rdzeń: organizacje, oddziały, zespół, role, zaproszenia (M7) | ⬜ |
| 2 | Zadania + checklisty + szablony + czat zadań + powiadomienia (M1, M2, M4) | ⬜ |
| 3 | Czaty grupowe + raport dnia + raport menadżerski (M10, M3, M6) | ⬜ |
| 4 | Grafik (M5) | ⬜ |
| 5 | Magazyn (M8) + koszty (M9) | ⬜ |
| 6 | Szlif: PWA, wydajność, testy E2E krytycznych ścieżek, RODO-czyszczenie | ⬜ |

Każda faza kończy się działającą aplikacją (migracje + UI + realtime tam gdzie trzeba).

## 10. Ustalenia techniczne (wersje, konfiguracja)

_Zweryfikowane 2026-07-09 (npm + oficjalne docs)._

| Pakiet | Wersja | Uwagi |
|---|---|---|
| `nuxt` | 4.x (4.4.8) | Nuxt 3 EOL; `srcDir = app/` domyślnie |
| `tailwindcss` | 4.x | CSS-first (`@theme`), przez `@tailwindcss/vite`, **bez** `@nuxtjs/tailwindcss` |
| `shadcn-vue` + `shadcn-nuxt` | 2.7.x | moduł `shadcn-nuxt` wymagany (auto-import); toast → **Sonner** |
| `@nuxtjs/supabase` | 2.x | SSR sesje przez cookies (`@supabase/ssr`), `useSupabaseClient/User` |
| `supabase` CLI | 2.x | `supabase gen types --lang typescript --local` |
| Node | 22 LTS | |

Decyzje z researchu:

- **Init:** `npm create nuxt@latest`, potem Tailwind przez Vite plugin, `nuxi module add shadcn-nuxt`, `nuxi prepare`, `shadcn-vue init`.
- **Realtime czaty:** **Broadcast from Database** (`realtime.broadcast_changes()` w triggerze na `chat_messages` / `task_comments`) — jeden fan-out niezależnie od liczby subskrybentów; lepiej skaluje niż postgres_changes.
- **Kanały prywatne:** `config: { private: true }` + polityki RLS na `realtime.messages` gated przez `realtime.topic()`. Public access w Realtime wyłączony.
- **Powiadomienia:** broadcast na kanał per-user (`user:{uuid}`) + trwała tabela `notifications` (unread przetrwa reconnect).
- **RLS:** Pattern B — tabele członkostwa + funkcje helper `security definer` (`set search_path = ''`, w schemacie `private`, nieeksponowane przez PostgREST). JWT claims NIE są źródłem prawdy.
- **Wydajność RLS:** zawsze `(select auth.uid())` w politykach (cache per-statement); filtrowanie od strony membership (`branch_id in (select ...)`), bez joinów w `using`.
- **SSR-width plugin** (`provideSSRWidth`) — przeciw hydration mismatch dla Sheet/Drawer.

### Odstępstwa z fazy 0 (scaffold, 2026-07-09)

- **`typescript` przypięty do 5.x (`^5.9.3`, devDependency).** TypeScript 7.0.2 (natywny `tsgo`) instaluje się domyślnie, ale rozbija `@vue/compiler-sfc` przy rozwiązywaniu importowanych typów (`defineProps<ToasterProps>()` w `ui/sonner/Sonner.vue`) — błąd „Failed to load TypeScript / No fs option". TS musi być obecny jako zależność projektu, żeby SFC compiler rozwiązał typy cross-package.
- **`create-nuxt` (v3.36.1) wymaga jawnych flag w trybie nieinteraktywnym:** `-t minimal` (template) oraz `--gitInit false` są obowiązkowe, inaczej przerywa z „Missing required argument".
- **`shadcn-vue init` nie jest w pełni nieinteraktywny** mimo `-y`: pyta o component library (wybrane **Reka UI**), icon library (**Lucide**, flaga `--icon-library`) i font (**Inter**, flaga `--font`). Component library trzeba potwierdzić Enterem (brak flagi).
- **Wersje zainstalowane:** `nuxt` 4.4.8, `@nuxtjs/supabase` 2.0.9, `shadcn-nuxt` 2.7.4, `tailwindcss`/`@tailwindcss/vite` 4.3.2, `reka-ui` 2.10.1, `@vueuse/core` 14.3.0, `vue-sonner` 2.0.9, Supabase CLI 2.109.1. Node 24.13 (repo deklaruje docelowo 22 LTS).
- **Ścieżka typów DB:** `supabase.types` ustawione na `~~/shared/types/database.types.ts` (zgodnie z Nuxt 4 `shared/` i skryptem `db:types`), zamiast domyślnego `~/types/...`.
- **Lokalny Supabase:** `enable_confirmations = false` (domyślnie w `config.toml`) — rejestracja od razu tworzy sesję (autoconfirm). Zweryfikowano signup + login (password grant) przez API GoTrue oraz redirect `/` → `/auth/login` dla niezalogowanych.
- Nazwa pakietu ustawiona na `ozmo`.

## 11. Konwencje

- Commity: Conventional Commits.
- Nazwy DB: snake_case, tabele w liczbie mnogiej.
- Wszystkie timestampy: `timestamptz`, czas lokalu wg `branches.timezone`.
- Komponenty domenowe: PascalCase z prefiksem modułu (`TaskKanban.vue`, `ChatWindow.vue`).
- Composables zwracają stan reaktywny + akcje; bez fetchowania w komponentach stron poza `useAsyncData`.

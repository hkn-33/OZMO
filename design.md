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

### Odstępstwa z fazy 1 (rdzeń multi-tenant M7, 2026-07-09)

- **Zaproszenia bez wysyłki e-mail (MVP).** `POST /api/invitations` zwraca link `/auth/invite/{token}` do skopiowania i przekazania ręcznie; realną wysyłkę maila dodamy później. Zaproszenia oczekujące można skopiować ponownie z zakładki „Zaproszenia" na `/people`.
- **Tworzenie zaproszenia idzie przez klienta z sesją użytkownika (RLS), nie service_role.** `serverSupabaseClient` + polityka `invitations_insert_admin` egzekwują, że tylko org admin może dodać zaproszenie — brak potrzeby service_role przy tworzeniu. `service_role` używany jest wyłącznie w `POST /api/invitations/accept` (zaproszony nie jest jeszcze członkiem, więc RLS by go zablokował).
- **`serverSupabaseUser` (@nuxtjs/supabase 2.x) zwraca *claims* JWT, nie obiekt `User`.** Id użytkownika to `user.sub` (nie `user.id`), e-mail to `user.email`. Kod server route korzysta z `user.sub`.
- **Polityka SELECT na `branches` używa `private.is_org_admin(org_id) OR private.is_branch_member(id)`, a nie `has_branch_access(id)`.** Powód: `has_branch_access` odczytuje tabelę `branches` w środku funkcji `stable security definer`, przez co przy `INSERT ... RETURNING` (używanym przez `.insert().select()` w supabase-js) polityka SELECT nie „widzi" świeżo wstawionego wiersza i insert kończy się błędem RLS. Dodano pomocniczą `private.is_branch_member(branch_id)` (czyta tylko `branch_members`). `has_branch_access` i `is_branch_manager` pozostają dla `branch_members` oraz przyszłych tabel branch-scoped (tam nie ma self-referencji do `branches`).
- **Granty tabelowe także dla `service_role`.** Mimo że `service_role` omija RLS (BYPASSRLS), lokalnie potrzebuje jawnych uprawnień tabelowych (`GRANT ... TO authenticated, service_role`), inaczej `permission denied` w route accept.
- **Pomocnicza `private.shares_org(user_id)`** dodana ponad zestaw z §4 — dla polityki SELECT na `profiles` (widoczność profili osób z tej samej organizacji).
- **Klucz serwerowy w env: `SUPABASE_SERVICE_KEY`.** Moduł loguje ostrzeżenie o deprecacji (sugeruje `NUXT_SUPABASE_SECRET_KEY`), ale zmienna działa. `serverSupabaseServiceRole` bierze `secretKey || serviceKey`.
- **Kontekst organizacji:** composable `useOrg()` (aktywna org w cookie `ozmo_active_org`, przełącznik w menu użytkownika przy >1 org). Globalny middleware `org-context` kieruje użytkowników bez organizacji na `/onboarding`. Zaproszenie przez wylogowanego użytkownika zachowuje token w query `?next=` przy logowaniu/rejestracji.
- **Zweryfikowano E2E (20/20) na lokalnym stacku + dev server:** RPC `create_organization` (twórca = owner), trigger profilu, tworzenie oddziału (admin), pełny cykl zaproszenia przez HTTP (utworzenie → akceptacja → idempotencja), guard 401 bez sesji, 403 dla nie-admina, izolacja RLS (user B nie widzi cudzej organizacji ani nieprzypisanych oddziałów, nie tworzy oddziałów), widoczność profili wg wspólnej organizacji.

### Odstępstwa z fazy 2 (zadania, checklisty, czat zadań, powiadomienia — M1/M2/M4, 2026-07-09)

- **Migracja `20260709160000_tasks_module.sql`.** Enumy `task_status`, `task_priority`, `notification_type`; tabele `tasks`, `task_assignees`, `checklist_templates` (org-level, `items jsonb`), `task_checklist_items`, `task_comments` (z denormalizowanymi `org_id`+`branch_id`), `notifications`. RLS deny-by-default z `(select auth.uid())` i helperami z fazy 1.
- **Nowe helpery `private.*`:** `can_access_task(task_id)` (członek oddziału zadania lub org admin), `manages_any_branch(org_id)` (manager dowolnego oddziału w org — do CUD szablonów), `can_access_task_topic(text)` (autoryzacja kanału realtime). Nie duplikują helperów z fazy 1 — budują na `is_branch_member`/`is_org_admin`.
- **Szablony startowe seedowane per-org triggerem, nie z `seed.sql`.** `AFTER INSERT` na `organizations` → `seed_default_checklist_templates()` kopiuje 5 polskich szablonów (Otwarcie lokalu, Zamknięcie lokalu, Sprzątanie, Inwentaryzacja, Kontrola Sanepid/HACCP), każdy 7–8 pozycji. `seed.sql` pozostaje org-agnostyczny (orgi powstają w aplikacji). Zadanie z szablonu **kopiuje** pozycje do `task_checklist_items`.
- **Powiadomienia — dostawa przez Broadcast from Database (nie `postgres_changes`).** Odstępstwo od tabeli w §6: dla spójności z §10 (skala/fan-out) wybrano broadcast na kanał `user:{uuid}` (trigger `broadcast_notification` → `realtime.send`). Trwała tabela `notifications` jest źródłem prawdy (unread przetrwa reconnect); dzwoneczek robi initial fetch + subskrybuje kanał.
- **Realtime czat zadań:** trigger `broadcast_task_comment` → `realtime.send(..., 'task:'||task_id, private => true)`. Triggery notyfikacyjne: `notify_task_assigned` (pomija samo-przypisanie wg `auth.uid()`), `notify_task_comment` (wzmianki → `mentioned`; przypisani + twórca → `comment_on_my_task`, z deduplikacją względem wzmianek i autora). `INSERT ... SELECT` z literałem enuma wymaga jawnego rzutu `::public.notification_type`.
- **Autoryzacja kanałów prywatnych = RLS SELECT na `realtime.messages`** (`extension = 'broadcast'`, gate przez `realtime.topic()`): `task:{id}` → dostęp do oddziału zadania, `user:{uuid}` → tylko właściciel. `alter table realtime.messages enable row level security`. **Zweryfikowano lokalnie (7/7):** A z dostępem subskrybuje i odbiera broadcast komentarza oraz powiadomienia; C bez dostępu jest odrzucany na obu topicach. Fallback: komentarze odświeżają się też przy powrocie fokusu okna.
- **UI:** `useBranch()` (aktywny oddział w cookie `ozmo_active_branch`, `LayoutBranchPicker` w nagłówku; ładowanie w `onMounted`, by uniknąć zagnieżdżonego async setup). `LayoutNotificationBell` (licznik nieprzeczytanych + realtime). Strona `/tasks` z zakładkami **Lista** / **Kanban** / **Szablony**. Szczegóły zadania w prawym **Sheet** (mobile i desktop — spójnie), deep-link z powiadomień przez `/tasks?task={id}`. Kanban drag&drop na natywnych zdarzeniach HTML5 (bez biblioteki), kolejność przez `position numeric` (`Date.now()` przy tworzeniu/upuszczeniu; bez reorderingu w kolumnie). Wzmianki `@` w komentarzu: prosty dropdown członków oddziału, `uuid` zapisywane w `mentions[]`. Dodano komponenty shadcn `checkbox` i `textarea`.
- **Zweryfikowano E2E (24/24 RLS/triggery + 7/7 realtime) na lokalnym stacku + SSR dev server:** A (owner) tworzy zadanie i przypisuje B → B dostaje `task_assigned`; B komentuje z `@A` → A dostaje `mentioned` (dedup: 1 powiadomienie/komentarz); samo-przypisanie bez powiadomienia; B zaznacza pozycję checklisty → `done_by = B`; B (employee) nie usuwa zadania (RLS), A (admin) usuwa; C z innej org/oddziału nie widzi zadań/komentarzy/szablonów/powiadomień i nie tworzy zadania w cudzym oddziale; nowa org dostaje 5 szablonów; SSR `/tasks` renderuje zadania (z ustawionym kontekstem oddziału).
- **Uwaga dev/lokalna:** po `supabase db reset` bywa `502` kong→auth (auth restartuje, kong trzyma stary upstream) — naprawia `docker restart supabase_kong_OZMO`. Listy branch-scoped są puste w SSR pierwszego żądania dopóki hydratacja nie ustawi cookies aktywnej org/oddziału (zachowanie wspólne z fazą 1); dane doładowują się po stronie klienta.

### Odstępstwa z fazy 3 (czaty grupowe, raport dnia, raport menadżerski — M10/M3/M6, 2026-07-09)

- **Migracja `20260709170000_group_chat_reports.sql`.** Enumy `chat_channel_type` (org|branch|custom), `day_note_severity` (info|issue), `manager_report_status` (draft|closed), `report_section` (utarg|kasa|sanepid|magazyn|zmiana). Tabele: `chat_channels`, `chat_members` (tylko custom), `chat_messages` (denormalizowane `org_id`+`branch_id`, `branch_id` nullable dla kanału org), `chat_reads` (PK channel_id+user_id); `day_notes`; `manager_reports`, `manager_report_sections`. RLS deny-by-default z `(select auth.uid())` i helperami z faz 1–2.
- **Nowe helpery `private.*`:** `can_access_channel(uuid)` (org member / branch member lub org admin / członek custom), `can_access_channel_topic(text)` (autoryzacja realtime `chat:{id}`), `can_access_report(uuid)` (dostęp do oddziału raportu), `can_manage_report(uuid)` (manager oddziału raportu). Budują na `is_org_member`/`is_branch_member`/`is_org_admin`/`has_branch_access`/`is_branch_manager` — bez duplikacji.
- **Auto-tworzenie kanałów triggerami (`security definer`):** `after insert on organizations` → kanał `org` „Ogólny"; `after insert on branches` → kanał `branch` nazwany jak oddział. Istniejące orgi/oddziały uzupełnione backfillem w migracji. Kanały powstają wyłącznie triggerami — **brak polityki INSERT** na `chat_channels` dla `authenticated` (klient nie tworzy kanałów w MVP; eliminuje to problem `INSERT ... RETURNING` z fazy 1). Kanały custom: schemat gotowy (`chat_members`), UI odłożone.
- **Wzmianki `@` w czacie grupowym pominięte (MVP)** — zgodnie ze specyfikacją (design.md nie wymaga ich w M10).
- **M6 — auto-tworzenie 5 sekcji** triggerem `after insert on manager_reports`. **Blokada zamknięcia + niezmienność** dwoma triggerami `before update`: (1) na `manager_reports` — przejście draft→closed dozwolone tylko gdy wszystkie 5 sekcji `completed`, ustawia `closed_by`/`closed_at`; każda edycja już zamkniętego raportu odrzucana; (2) na `manager_report_sections` — edycja sekcji zamkniętego raportu odrzucana. Sekcje CUD tylko przez trigger seedujący (definer) + polityka UPDATE dla managera; brak polityk INSERT/DELETE dla `authenticated`.
- **`manager_reports.created_by`** dodane ponad listę kolumn z §5 (potrzebne do `with check (created_by = auth.uid())` przy INSERT i do audytu autora szkicu).
- **Utarg → przychód (M9) odłożony do fazy 5.** `revenue_entries` NIE jest zasilane przy zamknięciu raportu. Ustalenie: moduł kosztów (faza 5) będzie czytał utarg z **zamkniętych** `manager_reports` (sekcja `utarg`: `gotowka`+`karta`+`inne`) — bez osobnej tabeli/duplikacji przy zamknięciu.
- **Realtime czatów grupowych:** trigger `broadcast_chat_message` → `realtime.send(..., 'chat:'||channel_id, private => true)`, event `new_message`. Autoryzacja kanału prywatnego = **dodatkowa** polityka SELECT na `realtime.messages` (`realtime_read_chat_topics`, gate `chat:%` + `can_access_channel_topic`), obok polityki `task:`/`user:` z fazy 2 (polityki permissive łączą się przez OR). `realtime.messages` ma RLS włączony od fazy 2.
- **UI:** `useChat()` (lista kanałów aktywnej org + licznik nieprzeczytanych = wiadomości po `chat_reads.last_read_at` z pominięciem własnych; `markRead` upsertuje `chat_reads`). Strona `/chat` dwupanelowa (lista kanałów / widok wiadomości; na mobile przełączanie z „wstecz"), `ChatWindow.vue`: historia paginowana (30/stronę, doładowanie starszych przy scrollu w górę z zachowaniem pozycji), realtime `chat:{id}`, autoscroll, mark-read na wejściu i po nowej wiadomości, separatory dni (Dzisiaj/Wczoraj/data), avatar+nazwa+godzina, Enter wysyła / Shift+Enter nowa linia. Strona `/reports` z zakładkami **Raport dnia** (`ReportsDayNotes` — date picker, feed z badge Info/Problem, szybki wpis, edycja/usuwanie własnych z tego dnia) i **Raport menadżerski** (`ReportsManagerReport` — date picker, karta raportu z akordeonem 5 sekcji, pola per kształt z §5, „Sekcja gotowa", wskaźnik postępu N/5, „Zamknij raport" nieaktywny do 5/5 z komunikatem; zamknięty raport = widok read-only z `closed_by`/`closed_at`). Dodano komponent shadcn `accordion`. Sidebar (`/chat`, `/reports`) był już podlinkowany — strony dopięte.
- **Zweryfikowano E2E (36/36 RLS/triggery + 4/4 realtime + 7/7 SSR) na lokalnym stacku + dev server:** auto-tworzenie kanałów org+branch (i backfill), B (employee) wysyła na kanał oddziału → A odbiera (historia + broadcast realtime), C (obca org) odrzucony na topicu i nie widzi kanałów/wiadomości (RLS), licznik nieprzeczytanych A rośnie i zeruje po mark-read, INSERT tylko jako self; B tworzy notatkę dnia i edytuje/usuwa własną, C nie widzi/nie tworzy; manager A tworzy raport → 5 sekcji, zamknięcie przy 3/5 odrzucone, przy 5/5 sukces (`closed_by=A`), edycja sekcji/raportu po zamknięciu odrzucona, B (employee) nie tworzy/nie edytuje raportu (RLS), C nic nie widzi; SSR `/chat` i `/reports` renderują 200 z treścią dla zalogowanego.

## 11. Konwencje

- Commity: Conventional Commits.
- Nazwy DB: snake_case, tabele w liczbie mnogiej.
- Wszystkie timestampy: `timestamptz`, czas lokalu wg `branches.timezone`.
- Komponenty domenowe: PascalCase z prefiksem modułu (`TaskKanban.vue`, `ChatWindow.vue`).
- Composables zwracają stan reaktywny + akcje; bez fetchowania w komponentach stron poza `useAsyncData`.

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
| 6 | Szlif: PWA, wydajność, testy E2E krytycznych ścieżek, RODO-czyszczenie | ✅ |
| 7 | Feedback: landing+cennik, subskrypcje+demo (M11), users po username, powiązania zadań, wskaźnik pisania, widok sieci magazynu, fix realtime, konto testowe | ✅ |

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

### Odstępstwa z fazy 4 (grafik pracy — M5, 2026-07-09)

- **Dwie migracje.** `20260709180000_shift_published_enum.sql` dodaje wartość enuma `notification_type = 'shift_published'` (`add value if not exists`) w osobnym pliku — `ALTER TYPE ... ADD VALUE` musi być zacommitowane przed użyciem; `supabase db reset` aplikuje pliki po kolei, więc rozdzielenie gwarantuje commit przed migracją modułu. `20260709180100_schedule_module.sql` zawiera tabele/triggery/RLS/RPC.
- **Tabele `shifts`, `availability`, `shift_templates`** z denormalizowanym `org_id`+`branch_id`. `shifts` ma CHECK `ends_at > starts_at`; `availability`/`shift_templates` CHECK `weekday between 0 and 6`. **Konwencja weekday: 0 = poniedziałek … 6 = niedziela** (UI startuje od poniedziałku, PL). Czasy dostępności/szablonów jako `time`; zmiany jako `timestamptz` (wyświetlane w `branches.timezone`).
- **Brak nowych helperów `private.*`** — RLS w całości na istniejących `is_branch_member` / `is_branch_manager` / `has_branch_access`. `shifts` SELECT: `is_branch_manager(branch_id) OR (published AND is_branch_member(branch_id))` (managerowie widzą szkice+opublikowane całego oddziału, pracownicy tylko opublikowane — widoczność całego grafiku pod przyszłe zamiany); CUD tylko manager. `availability` SELECT: `has_branch_access`; INSERT/UPDATE/DELETE: własne wiersze **lub** manager. `shift_templates` SELECT: `has_branch_access`; CUD manager.
- **Powiadomienie `shift_published` przez trigger `notify_shift_published`** (`after insert or update on shifts`): przy przejściu draft→published (lub wstawieniu jako published) wstawia powiadomienie do `user_id` zmiany, z **deduplikacją** (pomija, jeśli istnieje już `shift_published` dla tego samego `shift_id` — ponowna publikacja nie tworzy drugiego). Dostawa realtime reużywa triggera `broadcast_notification` z fazy 2 (kanał `user:{uuid}`) — **bez nowej polityki `realtime.messages`**.
- **RPC `copy_week_shifts(p_branch_id, from_week_start date, to_week_start date)`** (`security definer`, sprawdza `is_branch_manager` w środku): kopiuje zmiany tygodnia źródłowego do docelowego jako szkice (`published=false`), zachowując offsety dnia/godziny (`starts_at + (to-from)*interval '1 day'`) i stanowiska; zwraca liczbę. Filtr tygodnia po `starts_at` w strefie sesji DB (upraszczenie MVP; granice tygodnia mogą minimalnie różnić się od strefy oddziału — bez znaczenia dla typowych zmian w ciągu dnia).
- **UI:** strona `/schedule` (zakładki **Grafik** / **Dostępność** / **Szablony**; ostatnia tylko dla managera). `ScheduleWeekView` — nawigacja tygodniowa (prev/dziś/next, start w poniedziałek, PL nazwy dni), siatka 7 kolumn (desktop) / lista dni (mobile), zmiany z nazwiskiem, zakresem godzin i badge stanowiska; szkic = przerywana ramka + badge „Szkic"; własne zmiany podświetlone `ring`. Manager: dodaj/edytuj/usuń (`ScheduleShiftDialog`), „Kopiuj poprzedni tydzień" (RPC), „Opublikuj tydzień" (masowy `update` szkiców widocznego tygodnia → triggery powiadomień). **Podpowiedzi:** w kolumnie dnia i w dialogu „Obsada wg szablonu: N, zaplanowane: M" (z `shift_templates` vs liczba zmian dnia); w dialogu **miękkie ostrzeżenie** (nie blokuje) gdy dostępność pracownika nie pokrywa wybranych godzin. `ScheduleAvailability` — pracownik zarządza własną dostępnością, manager widzi grid zespołu. `ScheduleTemplates` — CRUD `shift_templates`. Konwersja czasu lokalnego oddziału ↔ ISO w `app/lib/tz.ts`; stałe dni tygodnia w `app/lib/schedule.ts`. Dzwoneczek (`shift_published` → ikona kalendarza, deep-link `/schedule`). Dashboard `index.vue`: karta „Twoja najbliższa zmiana" (najbliższa opublikowana zmiana użytkownika; renderowana po stronie klienta po hydratacji — jak lista „Moje oddziały", bo zależy od `user.id` niedostępnego w SSR pierwszego żądania; dodany `watch:[user]` wymusza pobranie po ustaleniu sesji).
- **Zweryfikowano E2E (27/27 RLS/triggery + 7/7 SSR) na lokalnym stacku + dev server:** A (owner+manager) tworzy szkic zmiany dla B → B nie widzi (RLS), A widzi; publikacja → B widzi + dokładnie jedno `shift_published` (dedup przy ponownej publikacji), payload wskazuje zmianę; B (employee) nie tworzy/nie edytuje zmian; B deklaruje dostępność, A ją widzi, B nie deklaruje za innego; A tworzy zmianę poza dostępnością B — dozwolone (ostrzeżenie tylko w UI); `copy_week_shifts` kopiuje N szkiców na kolejny tydzień (B ich nie widzi), B nie może wywołać RPC (Not authorized); C (obca org) nie widzi zmian/dostępności/szablonów i nie wstawia do cudzego oddziału; B widzi opublikowaną zmianę kolegi D z tego samego oddziału; A tworzy szablon (needed=2), czytelny dla podpowiedzi (B czyta, nie tworzy); SSR `/schedule` 200 z siatką tygodnia i akcjami managera, redirect 302 bez sesji.

### Odstępstwa z fazy 5 (magazyn M8 + koszty M9, 2026-07-09)

- **Dwie migracje.** `20260709190000_stock_low_enum.sql` dodaje wartość enuma `notification_type = 'stock_low'` (`add value if not exists`) w osobnym pliku — ta sama reguła kolejności co w fazie 4 (`ALTER TYPE ... ADD VALUE` musi być zacommitowane przed użyciem). `20260709190100_stock_costs_module.sql` zawiera nowe (świeże) enumy `stock_movement_type` (delivery|usage|waste|correction|transfer), `cost_category` (food|beverage|labor|other), `cost_source` (manual|stock|payroll) — tworzone i używane w jednym pliku (ograniczenie dotyczy tylko ADD VALUE do istniejącego enuma), tabele, triggery i RLS.
- **Tabele M8:** `suppliers`, `products` (org-level), `branch_product_settings` (PK branch_id+product_id, `min_stock`), `stock_levels` (PK branch_id+product_id, `qty`, materializowany), `stock_movements` (ledger INSERT-only). Wszystkie z denormalizowanym `org_id`. `stock_movements` ma CHECK znaku: `delivery > 0`; `usage`/`waste` `< 0`; `correction`/`transfer` dowolny znak; oraz `qty_delta <> 0`. Korekty przez ruch przeciwny typu `correction` (brak UPDATE/DELETE).
- **`stock_levels` utrzymywane wyłącznie triggerem** `apply_stock_movement` (`after insert on stock_movements`, security definer): upsert `qty += qty_delta`. Klient **nie ma uprawnień** do `stock_levels` poza SELECT (grant tylko `select` dla `authenticated`; brak polityk INSERT/UPDATE) — próba zapisu = `permission denied`. `stock_movements` niemutowalne przez brak grantu UPDATE/DELETE dla `authenticated` (tylko `select, insert`) — twardy błąd uprawnień zamiast cichego 0-rows.
- **Alert `stock_low` przy przekroczeniu progu (bez spamu):** w triggerze, gdy `nowy_stan < min_stock` **i** `poprzedni_stan >= min_stock` (przejście przez próg), powiadomienie trafia do **wszystkich managerów oddziału** (`branch_members` z rolą `manager`). Kolejne ruchy poniżej minimum nie generują nowego powiadomienia; ponowne wejście powyżej i zejście poniżej — tak. `min_stock` domyślnie 0, gdy brak wiersza w `branch_product_settings`; poprzedni stan traktowany jako 0, gdy brak wiersza w `stock_levels`. **Uwaga interpretacyjna:** „managerowie oddziału" = wiersze `branch_members.role='manager'`; właściciel/admin organizacji z domyślnym dostępem managera (bez wiersza w `branch_members`) nie jest adresatem — świadomie, by nie zalewać ownerów sieci alertami z każdego oddziału. Dostawa realtime reużywa triggera `broadcast_notification` z fazy 2 (`user:{uuid}`) — bez nowej polityki `realtime.messages`.
- **RLS M8:** `suppliers`/`products` SELECT = org member, CUD = `is_org_admin OR manages_any_branch` (reużyty helper z fazy 2). `branch_product_settings` SELECT = `has_branch_access`, CUD = `is_branch_manager`. `stock_levels` SELECT = `has_branch_access`. `stock_movements` SELECT = `has_branch_access`, INSERT = `has_branch_access AND created_by = auth.uid()`. **Brak nowych helperów `private.*`** — całość na helperach z faz 1–2.
- **Tabele M9:** `revenue_entries` (unique `branch_id,date,source`, `amount >= 0`, `source` text domyślnie `manager_report`) i `cost_entries` (`category cost_category`, `amount >= 0`, `source cost_source` domyślnie `manual`, `created_by`). RLS: SELECT = `has_branch_access`; `cost_entries` CUD = `is_branch_manager` (self przy INSERT); `revenue_entries` INSERT/UPDATE = `is_branch_manager` (ręczna korekta), bez DELETE.
- **Utarg → przychód realizuje fazę-3 ustalenie:** trigger `sync_revenue_from_report` (`after update on manager_reports`, definer) przy przejściu `draft→closed` liczy sumę `gotowka+karta+inne` z sekcji `utarg` i **upsertuje** `revenue_entries` (`on conflict (branch_id,date,source) do update`). Idempotentne: ponowne zamknięcie/edycja zamkniętego raportu i tak jest blokowane triggerem `enforce_manager_report_transition` z fazy 3, a unikat gwarantuje brak duplikatów przychodu.
- **UI:** strona `/stock` (sidebar „Magazyn" był już podlinkowany) z zakładkami **Stany** (`StockLevels` — tabela produkt/kategoria/stan+jednostka/min/status badge OK·Niski stan·Brak, szukajka, filtr kategorii, sort „najpierw niskie stany"; klik wiersza → `StockMovementHistory` w prawym Sheet, paginacja 20/stronę), **Przyjęcie/Wydanie** (`StockMovementForm` — wybór typu, produktu, ilości, dostawcy i nr WZ dla dostawy, tryb batch: dodaj wiele pozycji do listy → zapis zbiorczy jednym `insert`; znak `qty_delta` z typu, dla korekty/transferu przełącznik +/−), **Produkty** (`StockProducts`, manager/admin — CRUD produktów + inline edycja `min_stock` per oddział przez upsert `branch_product_settings`) i **Dostawcy** (`StockSuppliers`, manager/admin — CRUD). Strona `/costs` (sidebar „Koszty" był już podlinkowany): zakres dat z presetami (ten tydzień/ten miesiąc/poprzedni miesiąc/30 dni) + ręczne pola, karty KPI (Przychód, Food/Beverage/Labor Cost % dla oddziału), przełącznik **Oddział / Cała sieć** dla org adminów (agregacja + tabela porównania oddziałów), rozbicie kosztów wg kategorii z prostymi paskami CSS (szerokość div = % przychodu), oraz zarządzanie wpisami kosztów (lista + `CostsEntryDialog` add/edit/delete dla managera). Bez biblioteki wykresów. Dzwoneczek: typ `stock_low` (ikona `PackageX`, deep-link `/stock`), payload z `name` produktu pokazywany w podglądzie.
- **Zweryfikowano E2E (39/39 RLS/triggery/CHECK + 2/2 SSR) na lokalnym stacku + dev server:** A (owner+manager oddziału) tworzy produkt+dostawcę+`min_stock=5`; B (employee) nie tworzy produktu (RLS); B robi dostawę +10 → `stock_levels=10`, brak alertu; B zużycie −7 → `=3`, dokładnie jedno `stock_low` do A; kolejne −1 → `=2`, **brak** nowego alertu (bez spamu); dostawa +8 → `=10`, zużycie −9 → `=1`, **drugie** `stock_low` (ponowne przekroczenie); CHECK-i znaku (delivery>0, usage<0, delta≠0) odrzucone, korekta +2 przyjęta → `=3`; B nie zapisuje `stock_levels` (brak uprawnień), ruch UPDATE/DELETE odrzucony (niemutowalność), C (obca org) nie widzi produktów/ruchów/stanów i nie wstawia ruchu do cudzego oddziału. M9: zamknięcie raportu z utarg {1000,2000,0} → `revenue_entries` = 3000 (source `manager_report`); A dodaje koszt food=900 → Food Cost 30% policzalny; B (employee) nie CUD kosztów (RLS); C nic nie widzi; próba ponownej edycji zamkniętego raportu odrzucona, przychód pozostaje jednym wierszem 3000 (bez duplikacji). SSR `/stock` i `/costs` renderują 200 z treścią dla zalogowanego, 302 na `/auth/login` bez sesji.

### Odstępstwa z fazy 6 (szlif: PWA, E2E, RLS-audit, RODO, wydajność — 2026-07-09)

- **PWA przez `@vite-pwa/nuxt`.** Manifest (name „OZMO — system operacyjny dla sieci
  lokali", `lang: pl`, `theme_color: #262626` = kolor `--primary`, ikony 192/512 + maskable),
  service worker `registerType: autoUpdate`. Ikony to placeholdery „O" (biały pierścień na
  ciemnym kwadracie) generowane skryptem Node przez `zlib` (bez zależności; brak narzędzi
  SVG→PNG w środowisku) do `public/pwa-192x192.png`, `pwa-512x512.png`, `maskable-512x512.png`,
  `apple-touch-icon.png`. **Supabase nigdy nie jest cache'owany** (`runtimeCaching` NetworkOnly
  dla hostów supabase / `:54321`); precache tylko statyki. `devOptions.enabled: false`
  (SW wyłączony w dev). Zweryfikowano: build generuje `manifest.webmanifest` + `sw.js` +
  `workbox-*.js`.
- **E2E: Playwright (chromium), `tests/e2e/`, skrypt `npm run test:e2e`.** `playwright.config.ts`
  (baseURL `localhost:3000`, `webServer: npm run dev`, `workers: 1`, screenshoty/trace na
  porażce, `globalSetup` = health-check lokalnego Supabase). Seeding przez `service_role`
  (unikalne slugi/e-maile na przebieg → powtarzalność bez sprzątania); ścieżki feature'owe
  napędzane UI. **8 testów, wszystkie PASS:** (1) rejestracja→onboarding→org→pulpit,
  (2) oddział→zaproszenie→drugi użytkownik akceptuje→widzi oddział, (3) zadanie z szablonem→
  powiadomienie przypisanego (badge)→toggle checklisty→komentarz z `@`, (4) czat grupowy
  realtime między dwoma kontekstami, (5) raport menadżerski: blokada zamknięcia do 5/5 → zamknięcie,
  (6) magazyn: dostawa+zużycie poniżej minimum → `stock_low`, (7) RODO guard ostatniego właściciela,
  (8) RODO usunięcie konta (anonimizacja, brak logowania, treść zachowana).
  - **Kluczowy wzorzec testów:** po twardej nawigacji trzeba poczekać na hydrację Nuxt
    (`#__nuxt.__vue_app__`) — interakcja przed hydracją wywołuje natywny submit formularza.
- **Błędy aplikacji wykryte i naprawione przez E2E (migracje 20260709200100/200200 + zmiany UI):**
  1. **Embed `profiles(...)` z `branch_members`/`org_members` nie działał** („Could not find a
     relationship … in the schema cache") — kolumny miały FK tylko do `auth.users` (nieeksponowane
     przez PostgREST), więc listy członków/przypisań/autorów wracały puste. Fix: `20260709200100_profiles_embed_fk.sql`
     dodaje FK `branch_members.user_id`/`org_members.user_id → public.profiles(id)` (1:1 z auth.users).
  2. **Aktywny oddział nie ustawiał się przy pierwszym twardym wejściu na stronę branch-scoped**
     — SSR pierwszego żądania zwracał pustą listę (brak sesji), `loaded=true` blokował kliencki
     refetch. Fix: `BranchPicker` i `chat.vue` wymuszają kliencki reload gdy lista pusta
     (`load(!list.length)` w `onMounted`).
  3. **Insert `created_by`/`author_id` bywał `undefined` po twardym wejściu** — kliencki
     `useSupabaseUser().value` to wtedy *claims* JWT (`.sub`, bez `.id`). Fix: `20260709200200_owner_defaults.sql`
     ustawia `DEFAULT auth.uid()` na kolumnach własności (tasks, task_comments, day_notes,
     manager_reports, cost_entries, revenue_entries, stock_movements, chat_messages, shifts,
     checklist_templates). **Uwaga:** dla insertu pojedynczego wiersza supabase-js pomija klucz
     `undefined` (default działa), ale dla **bulk insert** wysyła kolumnę jako `null` (default
     pominięty) — dlatego `StockMovementForm` **nie wysyła już `created_by`** (polega na DEFAULT).
  4. **`/settings` czytał/zapisywał profil z `id=undefined`** (ten sam claims-problem). Fix:
     `settings.vue` używa `uid = user.value?.id ?? user.value?.sub`.
- **Znane, świadome ograniczenie:** kliencki `useSupabaseUser().value.id` bywa `undefined`
  bezpośrednio po twardym przeładowaniu (obiekt to claims JWT dopóki klient nie odświeży sesji).
  W realnym użyciu strony osiąga się nawigacją SPA (po logowaniu `user` ma `.id`), więc nie
  dotyka to zwykłych przepływów; mutacje własności są odporne dzięki `DEFAULT auth.uid()`,
  a odczyty i tak są filtrowane RLS po `auth.uid()`. Realtime powiadomień (`user:{id}`) po
  twardym reloadzie może użyć złego kanału, ale dzwoneczek i tak robi initial fetch z tabeli.
- **Audyt RLS — werdykt: brak realnych luk, migracja naprawcza niepotrzebna** (pełny raport:
  `docs/rls-audit.md`). 29/29 tabel z RLS deny-by-default; każda polityka opakowuje `auth.uid()`
  w `(select …)`; `anon` bez dostępu do danych (tylko domyślne `TRIGGER/TRUNCATE/REFERENCES`
  Supabase); funkcje `security definer` w `public` to triggery (niewywoływalne przez PostgREST)
  + 2 celowe RPC (`create_organization`, `copy_week_shifts`) sprawdzające uprawnienia wewnętrznie;
  `realtime.messages` z RLS; 0 bucketów Storage.
- **RODO — strategia BAN + ANONIMIZACJA** (nie twardy DELETE), wymuszona topologią FK
  (raport: `docs/rodo.md`): `profiles.id → auth.users ON DELETE CASCADE` (twardy delete skasowałby
  anonimizowany profil) + autorstwo (`author_id`/`created_by`) z `ON DELETE NO ACTION` (twardy
  delete odrzucany, dopóki jest jakakolwiek treść). Route `POST /api/account/delete`
  (`service_role`): guard ostatniego właściciela org z innymi członkami (409, komunikat PL),
  anonimizacja profilu, usunięcie `org_members`/`branch_members`/`availability`, ban +
  anonimizacja e-maila w `auth.users` (Admin API). UI: `/settings` (zmiana imienia/telefonu/hasła,
  „Usuń konto" z type-to-confirm „USUŃ") + link w menu użytkownika i menu mobilnym.
- **Wydajność — 2 brakujące indeksy** (`20260709200000_phase6_indexes.sql`): `tasks(branch_id, status)`
  (Kanban/lista), `notifications(user_id) where read_at is null` (nieprzeczytane). Pozostałe
  z listy już istniały (`notifications(user_id, created_at DESC)`, `chat_messages(channel_id, created_at)`,
  `stock_movements(branch_id, product_id, created_at DESC)`, `shifts(branch_id, starts_at)`) — nie
  duplikowano. `nuxt build` czysty (bez red flagów; łączny bundle ~1.9 MB gzip). `db:types` po
  reset generuje jedynie 2 nowe relacje do `profiles`.
- **Weryfikacja:** `supabase db reset` (10 migracji, czysto) + `db restart kong` (znany quirk) +
  `db:types` + `nuxt build` — wszystko OK; pełny E2E 8/8 PASS na świeżo zresetowanej bazie.

### Odstępstwa z fazy 7 (runda feedbacku użytkowników, 2026-07-09)

Cztery migracje: `20260709210000_phase7_username.sql`, `..210100_phase7_subscriptions.sql`,
`..210200_phase7_task_links.sql`, `..210300_phase7_slug_and_typing.sql`.

**1. Landing + cennik (publiczne `/`).** `@nuxtjs/supabase` `redirectOptions.exclude`
rozszerzone o `'/'` — niezalogowani widzą landing zamiast redirectu na login.
`pages/index.vue` ma `layout: false` i renderuje `<Landing />` dla anonima albo
`<NuxtLayout name="default">` z pulpitem dla zalogowanego. `components/Landing.vue`:
hero (PL), 6 modułów, 3 pakiety (placeholder: Starter 149 / Pro 249 / Sieć 399 zł/mc
per lokal, „ceny wkrótce"), CTA → `/auth/register`, stopka. Markup semantyczny/prosty
(osobny pass designu później). Rejestracja: podtytuł „Załóż konto i przetestuj OZMO
w trybie demo".

**2. Subskrypcje + bramka demo (M11).** Enum `plan` (demo|starter|pro|network), tabela
`subscriptions` (org_id unique, plan default demo, status, current_period_end, created_at).
Trigger `handle_new_org_subscription` (`after insert on organizations`) tworzy wiersz
`demo`. **Backfill istniejących orgów → `network`** (funkcjonalne). RLS: SELECT dla
członków org; **brak polityk zapisu dla klienta** (webhooki Stripe później → service_role).
`useSubscription()` (plan + `isDemo`). **Bramka demo = UI-only (Stripe później):**
`useDemoGuard().guard(fn)` uruchamia `fn` albo otwiera wspólny `UpgradeModal.vue`
(renderowany raz w `layouts/default.vue`, stan w `useState`). Wpięte we wszystkie
podstawowe akcje create/edit/delete: nowe zadanie, komentarz/checklista/przypisania/
usuń w `TasksDetailSheet`, szablony, oddziały, dodanie pracownika/zmiana ról/przypisania
(people), wysyłka czatu, ruch magazynowy, produkty/dostawcy, notatka dnia, tworzenie/
zamknięcie raportu, zmiana/publikacja/kopiowanie grafiku, dostępność, wpisy kosztów,
powiązania zadań. **Przykładowe dane demo** seeduje `seed_demo_samples(org, owner)`
wywoływane **tylko** przez `create_organization` (ścieżka onboardingu) — orgy tworzone
przez service_role (testy, `seed.sql`) są czyste i podnoszone do `network`. Sample: 1
oddział „Przykład:", 3 zadania, 2 wiadomości org, 2 produkty + stany; owinięte w
`exception when others` (nie blokują utworzenia org).

**3. Użytkownicy po nazwie (bez maili).** `profiles.username` (unikat przez
`unique index (lower(username))`, bez zależności citext). Trigger `handle_new_user`
generuje unikalny username z metadanych albo local-part e-maila (sanityzacja
`[a-z0-9_.-]`, sufiks numeryczny przy kolizji); backfill istniejących. Route
`POST /api/members` (service_role): tworzy konto `${username}@users.ozmo.local`,
`email_confirm`, `user_metadata {username, full_name, must_change_password}`, **hasło
tymczasowe (pokazywane raz)**, wpisuje org_members (+ branch_members). Autoryzacja:
org admin **albo** manager oddziału dodający do własnego oddziału. Login: pole „Nazwa
użytkownika lub e-mail" — wejście bez `@` → `${input}@users.ozmo.local`; ścieżka e-mail
zachowana. Pierwsze logowanie: `must_change_password` → redirect na
`/auth/change-password` (login sprawdza flagę z odpowiedzi + globalny middleware jako
zabezpieczenie); po zmianie hasła **`refreshSession()`** przed nawigacją (JWT niesie
metadane z chwili wydania — bez odświeżenia middleware zapętla redirect). Stary flow
zaproszeń e-mail zachowany (API + strony), przeniesiony z UI głównego do przycisku
„Zaproś e-mailem" w zakładce Zaproszenia. People pokazuje `@username`.

**4. Bez slugów w UI.** Nowa sygnatura `create_organization(_name text)` — slug
generowany wewnątrz RPC (slugifikacja nazwy + losowy sufiks przy kolizji). Onboarding =
tylko pole nazwy. 2-argumentowa wersja RPC pozostaje (nieużywana z UI). URL-e i tak nie
używają slugów.

**5. Fix realtime czatu (krytyczny).** Przyczyna „wiadomości dopiero po odświeżeniu"
w praktyce była już częściowo pokryta (`setAuth` w komponentach). Dodano plugin
`realtime-auth.client.ts`: `supabase.realtime.setAuth(token)` przy starcie i przy każdej
zmianie sesji (`onAuthStateChange`) — token realtime zawsze świeży. **Realny bug znaleziony
przy okazji wskaźnika pisania:** po twardym wejściu na stronę `useSupabaseUser().value`
to *claims* JWT (`.sub`, bez `.id`) — payload broadcastu miał `id: undefined`, więc
odbiorca go odrzucał. Fix: `myId() = user.id ?? user.sub` (ten sam wzorzec co §10 faza 6).
Zweryfikowano E2E: wiadomość wysłana w kontekście A pojawia się w B < ~3 s bez
przeładowania.

**6. Wskaźnik pisania.** `useTypingIndicator(selfId)` (ephemeryczny broadcast, event
`typing` na tym samym kanale `chat:{id}`; wygasa po 3 s bez zdarzeń; wysyłka throttlowana
1/2 s). Wysyłka broadcastu z klienta na kanał prywatny wymaga **polityki INSERT na
`realtime.messages`** (`realtime_write_chat_topics`, gate `chat:%` + `can_access_channel_topic`)
— obok polityk SELECT z faz 2/3. Zweryfikowano node + E2E (dwa konteksty). Wątki
komentarzy: composable reużywalny, na razie wpięty tylko w czat grupowy.

**7. Powiązania zadań.** Tabela `task_links` (PK `task_id,linked_task_id`, CHECK
`task_id<>linked_task_id`, `created_by default auth.uid()`). Trigger `enforce_task_link`
wymusza tę samą organizację obu zadań i odrzuca odwrotną parę (semantyka symetryczna —
jeden wiersz, zapytania w obu kierunkach). RLS: SELECT/DELETE gdy `can_access_task` po
którejkolwiek stronie; INSERT gdy dostęp do obu + `created_by=auth.uid()`. UI:
`TasksDetailSheet` sekcja „Powiązane zadania" — lista z badge statusu (klik → otwiera
zadanie przez emit `open`), dodawanie przez search-combobox zadań oddziału, usuwanie.

**8. Magazyn — widok sieci + konto testowe.** `components/stock/Network.vue`: zakładka
„Cała sieć" (tylko org admin) — matryca produkt × oddział (desktop `Table` z
`overflow-x-auto`; mobile `Accordion` z rozbiciem per oddział), komórki na czerwono
poniżej `min_stock`, kolumna „Razem". **Konto testowe w `seed.sql`** (idempotentne przez
guard na istnienie `demo@users.ozmo.local`; auth.users z `extensions.crypt`+identities):
login **demo / Demo1234!**, org „Restauracje Bella" (network), 3 oddziały, 6 dodatkowych
pracowników (PL), 10 zadań z checklistami/komentarzami, wiadomości org+oddziały, notatki
dnia, 1 raport zamknięty (→ przychód) + 1 szkic, zmiany bieżącego tygodnia + dostępność,
15 produktów + stany/ruchy (część poniżej minimum), dostawcy, koszty+przychód (~20 dni)
dla sensownych KPI. `seedOrgWithUsers` (testy) podnosi org do `network`.

**Weryfikacja:** `supabase db reset` (14 migracji + seed) czysto; `db restart kong`;
`db:types`; `nuxt build` czysto; **Playwright 13/13 PASS** na świeżym resecie
(01 onboarding bez slug, 02 dodanie po username + login + zmiana hasła, 03–07 bez zmian
działania, 04 live chat + typing w dwóch kontekstach, 08 landing z cennikiem dla anonima,
09 klik „Nowe zadanie" w orgu demo → UpgradeModal, 10 powiązania zadań add/nawigacja,
11 matryca „Cała sieć" + login demo/Demo1234! pokazuje pulpit z danymi).

### Odstępstwa z fazy 8 (redesign wizualny — hierarchia + tożsamość, 2026-07-09)

- **Problem:** cały UI „zlewał się" — domyślny motyw shadcn (neutral) miał wszystkie tokeny w
  skali szarości (`oklch(… 0 0)`), a `--background` i `--card` były identyczną czystą bielą, więc
  karty nie odróżniały się od tła; statusy (todo/in_progress/done, OK/niski/brak, szkic/zamknięty)
  renderowały się jako te same szare plakietki. Font Inter ładowany z CDN Google (zakazane).
- **Rozwiązanie (tylko restyling, bez zmian funkcjonalnych):** pełny system tokenów w
  `app/assets/css/tailwind.css` (hierarchia powierzchni canvas/surface/inset, marka terakota,
  semantyczne kolory stanów solid+soft, cieplejsze neutralne, tinted-shadow), samodzielnie
  hostowane fonty zmienne (`@fontsource-variable/figtree` + `.../bricolage-grotesque`, subset
  latin-ext → pełne polskie znaki), semantyczne warianty `Badge`, poprawione `Tabs`/`Table`,
  przeprojektowany shell (`layouts/default.vue`) i strona landing (`components/Landing.vue`).
  PWA `theme_color` → `#b55424`. Pełny opis w §12.
- **Pliki:** `app/assets/css/tailwind.css`, `nuxt.config.ts`, `app/layouts/default.vue`,
  `app/components/Landing.vue`, `app/components/ui/{badge,tabs,table}/*`,
  `app/components/tasks/{ListView,Kanban}.vue`, `app/components/stock/Levels.vue`,
  `app/components/reports/{DayNotes,ManagerReport}.vue`, `PRODUCT.md`.
- **Weryfikacja:** `nuxt build` czysto; Playwright 13/13; kontrast tekstu i plakietek ≥ WCAG AA.

## 11. Konwencje

- Commity: Conventional Commits.
- Nazwy DB: snake_case, tabele w liczbie mnogiej.
- Wszystkie timestampy: `timestamptz`, czas lokalu wg `branches.timezone`.
- Komponenty domenowe: PascalCase z prefiksem modułu (`TaskKanban.vue`, `ChatWindow.vue`).
- Composables zwracają stan reaktywny + akcje; bez fetchowania w komponentach stron poza `useAsyncData`.

## 12. System designu (design system)

> Wiążący dla całego projektu. Źródło prawdy: `app/assets/css/tailwind.css` (tokeny
> `:root`/`.dark` + `@theme inline`, Tailwind v4 CSS-first) konsumowane przez prymitywy
> shadcn-vue w `app/components/ui/`. Kolejność zmian: najpierw tokeny, potem prymitywy,
> na końcu markup stron. Pełny kontekst produktowy: `PRODUCT.md`.

### 12.1 Tożsamość i strategia koloru
Marka OZMO = **ciepłe, niezawodne narzędzie dla gastronomii/hotelarstwa**, nie chłodny SaaS.
Ciepło niesie akcent **terakota** + subtelnie ciepły canvas + krojowy font nagłówkowy — nigdy
beżowe tło ani fioletowe gradienty. Strategia: **restrained** w produkcie (neutralne + jeden
akcent z intencją), odrobinę odważniej na landingu.

### 12.2 Powierzchnie — hierarchia, która naprawia „zlewanie się"
Trzy celowe tony (fundament redesignu):
- `--background` — **canvas** aplikacji, ciepła biel łamana `oklch(0.977 0.004 75)`.
- `--card` / `--popover` — **powierzchnie** nad canvasem, czysta biel `oklch(1 0 0)`.
- `--muted` — **wcięcia**: nagłówki tabel, tło segmentów tabów, zebra, drugorzędne chipy.
Karty (białe) na ciepłym canvasie → strefy czytelne bez ciężkich obramowań. Nigdy karta-w-karcie.

### 12.3 Marka i stany
- `--primary` terakota `oklch(0.56 0.14 44)` (≈ `#b55424`): filled CTA, aktywna nawigacja,
  focus ring, linki. Używać **oszczędnie** — jedna akcja główna na strefę.
- Semantyczna skala stanów (zarezerwowana, nigdy dekoracyjna), każdy w parze **solid** + **soft**
  (plakietki używają soft): `success` zieleń `~152` (zrobione/opublikowane/OK/na stanie),
  `warning` bursztyn `~74` (w trakcie/niski stan/szkic/wysoki priorytet), `info` błękit `~242`
  (do zrobienia/notatka info), `destructive` czerwień `~25` (pilne/problem/brak/usuń).
- Mapy statusów (wiążące): zadanie status todo→info, in_progress→warning, done→success;
  priorytet low→outline, normal→secondary, high→warning, urgent→destructive; magazyn OK→success,
  niski→warning, brak→destructive; raport szkic→warning, zamknięty→success; notatka info→info,
  problem→danger.

### 12.4 Typografia
Samodzielnie hostowane fonty zmienne (`@fontsource-variable`, bez CDN), subset latin-ext → pełne
polskie znaki.
- **Nagłówki/display — Bricolage Grotesque Variable** (`--font-heading`): `h1–h4` + wordmark,
  `letter-spacing: -0.015em`, `text-wrap: balance`.
- **Body/UI — Figtree Variable** (`--font-sans`): humanistyczny, ciepły, czytelny dla osób
  nietechnicznych. Parowanie na osi kontrastu (humanist body vs display grotesque).
- Liczby: `tabular-nums` w tabelach i komórkach danych.
- Skala: tytuł strony `text-2xl`/`3xl` bold · sekcja `text-lg` semibold · body `text-sm`/`base`
  · meta `text-xs`/`sm` muted. Bez WERSALIKÓW w polskim.

### 12.5 Kształt, elewacja, layout
- `--radius` 0.625rem (10px); karty/sheety `rounded-xl` (14px); inputy/przyciski `md`; plakietki pill.
  Jeden system promieni (bez 24px+).
- Cienie ocieplone (`--shadow-*` w `oklch(0.24 0.03 55 / …)`), nigdy czysta czerń; karty `shadow-sm`,
  popovery/sheety/dialogi `shadow-md`/`lg`. Obramowania o krok mocniejsze niż stock.
- Shell: wydzielona strefa **sidebar** (`--sidebar`, cofa się), **sticky** rozmyty header, treść na
  canvasie; mobile: rozmyty **bottom-nav** z safe-area, cele dotykowe ≥44px. Aktywna nawigacja =
  marka (`bg-primary/10 text-primary font-semibold`). Rytm sekcji `space-y-6`.
- Strefa nagłówka strony spójna wszędzie: `h1` + linia kontekstu (muted) + jedna akcja główna.

### 12.6 Prymitywy (delty względem stock shadcn)
- **Badge** — dodane warianty soft: `success`/`warning`/`info`/`danger`.
- **Tabs** — aktywny trigger jako wyraźna biała karta na muted torze.
- **Table** — pasek nagłówka `muted`, małe semibold muted etykiety, `tabular-nums`, czytelne linie.
- **Card/Button/Input** — dziedziczą tokeny; primary terakota, focus ring marki.

### 12.7 Dostępność i anty-slop
- Kontrast body i plakietek zweryfikowany ≥ WCAG AA (soft-fg = ciemny koniec rampy danego hue).
- Zakazane (nie przywracać): fioletowo-niebieskie gradienty AI, gradient-text, glassmorphism
  domyślnie, beżowy/kremowy body, ikona-kafelek-nad-nagłówkiem, wersalikowe „eyebrow" nad każdą
  sekcją, karta-w-karcie, kolorowe paski-boczne, Inter-do-wszystkiego, fonty z CDN.

# Audyt RLS — OZMO (faza 6)

Data: 2026-07-09. Zakres: wszystkie migracje `supabase/migrations/*` (fazy 0–5) +
stan żywej bazy lokalnej (zapytania do `pg_policies`, `pg_class`, `information_schema`,
`pg_proc`). Metodologia: audyt na podstawie **rzeczywistego stanu bazy** po pełnym
`supabase db reset`, nie tylko lektury SQL.

## Werdykt

**Brak realnych luk. Nie była potrzebna migracja naprawcza.**

- Wszystkie **29 tabel** domenowych w `public` ma włączone RLS (`relrowsecurity = true`),
  deny-by-default (żadna tabela z RLS nie ma zera polityk — sprawdzone zapytaniem
  „tables with RLS and no policy" → pusty wynik).
- **Każda** polityka opakowuje `auth.uid()` w `(select auth.uid())` (reguła wydajności
  RLS z design.md §10). Zapytanie wykrywające „gołe" `auth.uid()` w `qual`/`with_check`
  zwróciło pusty wynik.
- **`anon` nie ma dostępu** do żadnej tabeli domenowej: brak `SELECT/INSERT/UPDATE/DELETE`
  dla roli `anon` (jedynie domyślne `TRIGGER/TRUNCATE/REFERENCES` — patrz uwaga niżej).
- Funkcje `security definer` będące funkcjami wyzwalaczy nie są wywoływalne przez
  PostgREST; dwa celowe RPC (`create_organization`, `copy_week_shifts`) mają odebrane
  `EXECUTE` od `public` i sprawdzają uprawnienia wewnętrznie.
- `realtime.messages` ma RLS włączony z politykami SELECT bramkującymi kanały
  `task:`/`user:`/`chat:`.
- **Brak bucketów Storage** (0) — nie ma jeszcze polityk storage do audytu.

## Macierz tabela × operacja

Legenda: ✔ = polityka dla `authenticated`; „trigger" = wiersze tworzone/utrzymywane
wyłącznie funkcją `security definer` (brak polityki dla klienta = deny-by-default,
celowo); „RPC" = wstawianie przez dedykowany `security definer` RPC; — = brak polityki
(operacja zablokowana dla klienta, celowo).

| Tabela | SELECT | INSERT | UPDATE | DELETE | Uwaga |
|---|---|---|---|---|---|
| profiles | ✔ self/wspólna org | trigger `handle_new_user` | ✔ self | — | brak kasowania (patrz RODO) |
| organizations | ✔ member | RPC `create_organization` | ✔ admin | ✔ owner | |
| org_members | ✔ same org | ✔ admin (owner tylko przez owner) | ✔ admin | ✔ admin | |
| branches | ✔ admin/branch-member | ✔ admin | ✔ admin | ✔ admin | |
| branch_members | ✔ branch access | ✔ manager | ✔ manager | ✔ manager | |
| invitations | ✔ admin | ✔ admin | ✔ admin | ✔ admin | akceptacja przez service_role (route) |
| tasks | ✔ branch access | ✔ member | ✔ member | ✔ manager | |
| task_assignees | ✔ task access | ✔ task access | — | ✔ task access | |
| task_checklist_items | ✔ task access | ✔ task access | ✔ task access | ✔ task access | |
| task_comments | ✔ task access | ✔ author | — | — | ledger niemutowalny |
| checklist_templates | ✔ member | ✔ admin/manager | ✔ admin/manager | ✔ admin/manager | |
| notifications | ✔ own | trigger `notify_*` | ✔ own (read_at) | — | brak klienckiego insert/delete |
| chat_channels | ✔ access | trigger `create_*_chat_channel` | — | — | kanały tworzone triggerem |
| chat_members | ✔ access | — | — | — | schemat custom (UI odłożone) |
| chat_messages | ✔ access | ✔ author | — | — | ledger niemutowalny |
| chat_reads | ✔ own | ✔ own | ✔ own | — | |
| day_notes | ✔ branch access | ✔ member (self) | ✔ own/manager | ✔ own/manager | |
| manager_reports | ✔ branch access | ✔ manager (self) | ✔ manager | — | zamykanie/niezmienność przez triggery |
| manager_report_sections | ✔ branch access | trigger `seed_report_sections` | ✔ manager | — | |
| revenue_entries | ✔ branch access | ✔ manager | ✔ manager | — | zasilane też triggerem z raportu |
| cost_entries | ✔ branch access | ✔ manager (self) | ✔ manager | ✔ manager | |
| shifts | ✔ manager lub (published + member) | ✔ manager | ✔ manager | ✔ manager | |
| availability | ✔ branch access | ✔ own/manager | ✔ own/manager | ✔ own/manager | |
| shift_templates | ✔ branch access | ✔ manager | ✔ manager | ✔ manager | |
| suppliers | ✔ member | ✔ admin/manager | ✔ admin/manager | ✔ admin/manager | |
| products | ✔ member | ✔ admin/manager | ✔ admin/manager | ✔ admin/manager | |
| branch_product_settings | ✔ branch access | ✔ manager | ✔ manager | ✔ manager | |
| stock_levels | ✔ branch access | trigger `apply_stock_movement` | trigger | — | materializowany stan |
| stock_movements | ✔ branch access | ✔ member (self) | — | — | ledger niemutowalny |

Wszystkie SELECT filtrują od strony członkostwa przez helpery `private.*`
(`is_org_member`, `is_org_admin`, `has_branch_access`, `is_branch_manager`,
`is_branch_member`, `can_access_task`, `can_access_channel`, `can_access_report`,
`shares_org`), wszystkie `security definer`, `set search_path = ''`, w schemacie
`private` nieeksponowanym przez PostgREST (grant tylko dla `authenticated`).

## Zweryfikowane punkty kontrolne

1. **Każda tabela z RLS** — 29/29 `relrowsecurity = true`, brak `FORCE` (właściciel i
   `service_role` z `BYPASSRLS` celowo omijają — używane tylko w server routes).
2. **Brak polityki bez `(select auth.uid())`** — 0 trafień.
3. **`anon` bez dostępu do danych** — `anon` nie ma `SELECT/INSERT/UPDATE/DELETE` na
   żadnej tabeli `public`. Widoczne dla `anon` są jedynie `TRIGGER/TRUNCATE/REFERENCES`
   (domyślne granty Supabase, nie dają dostępu do wierszy; `TRUNCATE` nieosiągalny przez
   API PostgREST i niewrażliwy na RLS — standard Supabase, nie stanowi luki).
4. **`security definer` w schemacie `public`** — 17 funkcji. 15 to funkcje wyzwalaczy
   (`return trigger`): PostgREST ich nie eksponuje i nie da się ich wywołać jako RPC
   (wymagają kontekstu triggera). 2 to celowe punkty wejścia RPC:
   - `create_organization(text,text)` — `revoke ... from public`, `grant ... to authenticated`;
     wewnętrznie sprawdza `auth.uid() is not null`, tworzy org + członkostwo owner atomowo.
   - `copy_week_shifts(uuid,date,date)` — `grant ... to authenticated`; wewnętrznie
     sprawdza `is_branch_manager`.
5. **`realtime.messages`** — RLS włączony; polityki `realtime_read_task_or_user_topics`
   i `realtime_read_chat_topics` (SELECT) bramkują kanały prywatne przez `realtime.topic()`.
6. **Storage** — 0 bucketów. Brak polityk storage do audytu (do zaadresowania, gdy
   pojawią się załączniki/avatary; wg design.md §8 ścieżki `{org_id}/...`).

## Uwagi / dług do przyszłych faz

- Storage bez bucketów — polityki dostępu per org/branch trzeba będzie dodać wraz z
  modułem załączników.
- `anon` z domyślnym `TRUNCATE` (grant Supabase) — teoretycznie do odebrania
  (`revoke truncate on all tables in schema public from anon`), ale nieeksploatowalny
  przez publiczne API; pozostawione jako standard Supabase.

# RODO — dane osobowe i prawo do usunięcia (OZMO)

Data: 2026-07-09 (faza 6).

## Jakie dane osobowe przechowujemy

Minimalny zakres (design.md §8):

| Dane | Gdzie | Cel |
|---|---|---|
| E-mail | `auth.users.email` | logowanie, zaproszenia, identyfikacja |
| Imię i nazwisko | `profiles.full_name` | wyświetlanie w zespole, przypisaniach, czatach |
| Telefon (opcjonalny) | `profiles.phone` | kontakt w ramach lokalu |
| Avatar (opcjonalny) | `profiles.avatar_url` | UI (obecnie brak Storage) |
| Powiązania | `org_members`, `branch_members`, `availability` | przynależność do organizacji/oddziału, dostępność |
| Autorstwo treści | `task_comments.author_id`, `chat_messages.author_id`, `stock_movements.created_by`, `tasks.created_by`, `manager_reports.*`, `day_notes.author_id`, `task_checklist_items.done_by`, `shifts.created_by`, itd. | integralność operacyjna i audyt |

## Analiza kluczy obcych (dlaczego nie twardy DELETE)

Zweryfikowane więzy do `auth.users` (`confdeltype`):

- **CASCADE** (`on delete cascade`): `profiles.id`, `org_members`, `branch_members`,
  `availability`, `notifications`, `chat_reads`, `chat_members`, `task_assignees.user_id`,
  `shifts.user_id`.
- **NO ACTION** (blokuje usunięcie, dopóki istnieją wiersze): `task_comments.author_id`,
  `chat_messages.author_id`, `stock_movements.created_by`, `tasks.created_by`,
  `checklist_templates.created_by`, `cost_entries.created_by`, `day_notes.author_id`,
  `manager_reports.closed_by`/`created_by`, `revenue_entries.created_by`,
  `shifts.created_by`, `task_checklist_items.done_by`, `organizations.created_by`,
  `invitations.invited_by`.

Wnioski:

1. Twardy `DELETE FROM auth.users` **kaskadowo skasowałby `profiles`** — anonimizacja
   profilu „nie przeżyłaby" usunięcia.
2. Twardy `DELETE` zostałby **odrzucony** przez PostgreSQL, gdy tylko użytkownik jest
   autorem czegokolwiek (komentarz, wiadomość, ruch magazynowy, utworzone zadanie,
   zamknięty raport, utworzona organizacja, wysłane zaproszenie) — bo te FK mają
   `NO ACTION`. Zachowujemy tę treść (uzasadniony interes: integralność danych
   operacyjnych i audytu), więc twardy delete jest niewykonalny bez niszczenia treści.

**Wybrana strategia: BAN + ANONIMIZACJA** (soft-delete). Jest to jedyne czyste,
działające podejście spójne z „zachowaj treść autorstwa".

## Co robi usunięcie konta (`POST /api/account/delete`)

Route wymaga zalogowania (`serverSupabaseUser`), działa `service_role` (Nitro).
Kroki:

1. **Blokada ostatniego właściciela.** Jeśli użytkownik jest jedynym `owner`
   organizacji, która ma innych członków → `409` z komunikatem PL:
   „Jesteś jedynym właścicielem organizacji, która ma innych członków. Przekaż
   najpierw rolę właściciela innej osobie, a potem usuń konto." (chroni org przed
   pozostawieniem bez właściciela).
2. **Anonimizacja profilu:** `full_name → 'Usunięty użytkownik'`, `phone → null`,
   `avatar_url → null`.
3. **Usunięcie więzów PII:** kasuje wiersze `org_members`, `branch_members`,
   `availability` dla użytkownika (odbiera dostęp do organizacji i oddziałów).
4. **Ban + anonimizacja `auth.users`** przez Admin API: `ban_duration ≈ 100 lat`
   (blokuje logowanie), `email → deleted+{uuid}@ozmo.invalid` (usuwa e-mail PII),
   `user_metadata`/`app_metadata` wyczyszczone.
5. Klient po sukcesie wywołuje `supabase.auth.signOut()` i wraca na `/auth/login`.

Efekt: użytkownik nie może się zalogować, jego dane osobowe (e-mail, imię, telefon,
avatar) znikają lub są zanonimizowane, dostęp do organizacji jest odebrany.

## Co jest zachowywane i dlaczego (retencja)

- **Treść autorstwa** (komentarze, wiadomości czatu, ruchy magazynowe, zadania,
  raporty, notatki dnia, pozycje checklist) — zachowywana bez danych osobowych.
  `author_id`/`created_by` wskazuje na zbanowany, zanonimizowany wpis `auth.users`
  (brak e-maila/nazwiska). Podstawa: uzasadniony interes — integralność operacyjna
  i audyt sieci lokali (np. kto przyjął dostawę, kto zamknął raport).
- **Wpis `auth.users`** — zachowywany w stanie zbanowanym, wyłącznie jako docelowy
  klucz obcy dla powyższej treści; pozbawiony danych osobowych.

## UI

Strona **`/settings`** („Ustawienia konta"):
- edycja `full_name`, `phone`;
- zmiana hasła (`supabase.auth.updateUser`);
- „Usuń konto" z dialogiem type-to-confirm (wpisz `USUŃ`), sekcja oznaczona kolorem
  destrukcyjnym z opisem skutków.

Link „Ustawienia" w menu użytkownika (sidebar) i w menu mobilnym.

## Znane ograniczenia / dług

- Istniejący access token użytkownika pozostaje ważny do wygaśnięcia (~1 h) mimo bana;
  klient natychmiast się wylogowuje. Pełne unieważnienie sesji serwerowo można dodać
  później (np. `admin.auth.admin.signOut`).
- Brak Storage → brak plików do usunięcia; gdy pojawią się avatary/załączniki, trzeba
  będzie dodać kasowanie obiektów w ścieżce `{org_id}/...` do tego route.

# OZMO

[![Nuxt 4](https://img.shields.io/badge/Nuxt-4-00DC82?logo=nuxtdotjs&logoColor=white)](https://nuxt.com/)
[![Supabase](https://img.shields.io/badge/Supabase-PostgreSQL-3FCF8E?logo=supabase&logoColor=white)](https://supabase.com/)
[![Node.js 22+](https://img.shields.io/badge/Node.js-22%2B-5FA04E?logo=nodedotjs&logoColor=white)](https://nodejs.org/)
[![AGPL-3.0](https://img.shields.io/badge/licencja-AGPL--3.0-blue)](./LICENSE)

Open-source’owy system codziennych operacji dla firm pracujących zmianowo — od jednego
lokalu po wiele oddziałów. Zastępuje arkusze, komunikatory i papierowe checklisty jednym
miejscem do zarządzania zadaniami, zespołem, magazynem i raportami.

OZMO jest aplikacją wielodostępową: **organizacja → oddziały → członkowie**. Uprawnienia są
egzekwowane w PostgreSQL przez RLS, nie tylko ukrywane w interfejsie.

## Funkcje

- zadania, checklisty, szablony oraz widoki listy i Kanban,
- tygodniowy grafik pracy, dostępność zespołu i publikacja zmian,
- czat organizacji i oddziałów z Realtime,
- magazyn, ruchy towarowe, alerty stanów i inwentaryzacje,
- raporty dnia pracownika i menadżera,
- koszty, przychody i wskaźniki dla jednego lub wielu oddziałów,
- role organizacyjne i oddziałowe chronione przez deny-by-default RLS,
- instalowalna, mobilna aplikacja PWA.

## Stos technologiczny

| Warstwa | Technologia |
| --- | --- |
| Aplikacja | Nuxt 4, Vue 3, TypeScript, SSR, PWA |
| Interfejs | Tailwind CSS 4, shadcn-vue, Reka UI, Lucide |
| Backend | Supabase PostgreSQL, Auth, RLS, Realtime, Storage, pg_cron |
| Testy | Playwright E2E i bezpośrednie testy RLS |

## Uruchomienie lokalne

Wymagania:

- Node.js 22 lub nowszy,
- Docker,
- Supabase CLI 2.x.

```bash
git clone https://github.com/hkn-33/OZMO.git
cd OZMO
npm ci

supabase start
supabase db reset

cp .env.example .env
# Uzupełnij .env wartościami z `supabase status`.

npm run db:types
npm run dev
```

Aplikacja będzie dostępna pod adresem <http://localhost:3000>.

### Zmienne środowiskowe

| Zmienna | Zastosowanie |
| --- | --- |
| `SUPABASE_URL` | Adres lokalnego lub zdalnego projektu Supabase |
| `SUPABASE_KEY` | Klucz publishable/anon używany przez klienta |
| `SUPABASE_SERVICE_KEY` | Klucz serwerowy dla tras Nitro; nigdy nie trafia do klienta |

Przykładowe wartości i komentarze znajdują się w [`.env.example`](./.env.example). Nie commituj
pliku `.env` ani prawdziwych kluczy.

## Przydatne polecenia

```bash
npm run dev          # serwer deweloperski
npm run build        # build produkcyjny
npm run preview      # podgląd buildu
npm run db:types     # typy TypeScript z lokalnej bazy
npm run test:e2e     # testy Playwright
node tests/rls/phase9.mjs
```

Testy E2E i RLS wymagają uruchomionego lokalnego Supabase oraz poprawnego pliku `.env`.

## Publiczne demo

Wbudowane konto demonstracyjne pozwala sprawdzić aplikację bez tworzenia własnej organizacji:

```text
login: demo-public
hasło: OzmoDemo2026
```

To celowo publiczne dane logowania. Organizacja demo ma flagę
`organizations.is_public_demo = true`, a jej dane są resetowane co godzinę przez `pg_cron`.

## Wdrożenie

1. Utwórz projekt Supabase lub uruchom własny stack.
2. Zastosuj migracje poleceniem `supabase db push`.
3. Ustaw zmienne środowiskowe na serwerze aplikacji.
4. Zbuduj aplikację poleceniem `npm run build` i uruchom `.output/server/index.mjs`.
5. Włącz `pg_cron`, jeśli publiczne demo ma resetować się automatycznie.

Operacje wymagające klucza serwerowego są wykonywane wyłącznie przez trasy w `server/api/`.

## Rozwój projektu

Przed zmianą schematu dodaj nową migrację w `supabase/migrations/`, zregeneruj typy i uruchom
najwęższy pasujący test. Dla zmian przekrojowych zakończ pracę poleceniem `npm run build`.
Szczegóły produktu i interfejsu opisują [`PRODUCT.md`](./PRODUCT.md) oraz
[`design.md`](./design.md).

## Licencja

Kod jest udostępniany na licencji [GNU AGPL-3.0](./LICENSE). Możesz go modyfikować i hostować
samodzielnie; udostępniając zmodyfikowaną wersję przez sieć, musisz udostępnić również jej kod
źródłowy. Utrzymywana wersja hostowana jest płatnym sposobem finansowania rozwoju projektu.

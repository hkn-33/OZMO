<script setup lang="ts">
import {
  ListChecks,
  MessagesSquare,
  CalendarDays,
  Package,
  FileText,
  Wallet,
  Check,
  X,
  ArrowRight,
  Building2,
  Users,
  Rocket,
  Coffee,
  UtensilsCrossed,
  Hotel,
  ShoppingBag,
  Warehouse,
  Truck,
  Code,
  PlayCircle,
} from '@lucide/vue'

const { enterDemo, signingIn } = useDemo()
const GITHUB_URL = 'https://github.com/hkn-33/OZMO'

// Grafik tygodniowy do podglądu w hero: kolor = rola (Wong, cat-1..5), stabilny per stanowisko.
const week = [
  { day: 'Pon', date: '14', shifts: [{ who: 'Anna', time: '7-15', cat: 1 }, { who: 'Marek', time: '12-20', cat: 3 }] },
  { day: 'Wt', date: '15', shifts: [{ who: 'Ewa', time: '8-16', cat: 3 }] },
  { day: 'Śr', date: '16', shifts: [{ who: 'Anna', time: '7-15', cat: 1 }, { who: 'Piotr', time: '14-22', cat: 2 }] },
  { day: 'Czw', date: '17', shifts: [{ who: 'Marek', time: '12-20', cat: 3 }] },
  { day: 'Pt', date: '18', shifts: [{ who: 'Ewa', time: '8-16', cat: 3 }, { who: 'Anna', time: '7-15', cat: 1 }] },
]
const roles = [
  { label: 'Kierownik', cat: 1 },
  { label: 'Obsługa', cat: 3 },
  { label: 'Magazyn', cat: 2 },
]
const chipTint = (cat: number) => ({ backgroundColor: `color-mix(in oklab, var(--cat-${cat}) 15%, var(--card))` })
const barFill = (cat: number) => ({ backgroundColor: `color-mix(in oklab, var(--cat-${cat}) 55%, var(--card))` })
const dot = (cat: number) => ({ backgroundColor: `var(--cat-${cat})` })

const features = [
  {
    key: 'zadania',
    icon: ListChecks,
    title: 'Zadania i checklisty',
    desc: 'Otwarcia, zamknięcia i kontrole z gotowych szablonów. Przydzielasz je osobom, a postęp widać na żywo.',
  },
  { key: 'grafik', icon: CalendarDays, title: 'Grafik pracy', desc: 'Układaj zmiany, zbieraj dostępność i publikuj tydzień jednym kliknięciem.' },
  { key: 'czaty', icon: MessagesSquare, title: 'Czaty zespołu', desc: 'Kanał firmy i kanały oddziałów w miejscu ustaleń, bez WhatsAppa.' },
  { key: 'magazyn', icon: Package, title: 'Magazyn i inwentaryzacja', desc: 'Przyjęcia, wydania i alerty o niskich stanach, bez arkuszy.' },
  { key: 'raporty', icon: FileText, title: 'Raporty dnia', desc: 'Raport pracownika i menadżera z blokadą zamknięcia zmiany.' },
  { key: 'koszty', icon: Wallet, title: 'Koszty i przychody', desc: 'Własne kategorie, liczone automatycznie per oddział i dla całej sieci.' },
]
const costBars = [42, 68, 55, 83]

const steps = [
  { icon: Building2, title: 'Załóż firmę i oddziały', desc: 'Utwórz konto i dodaj tyle lokalizacji, ile prowadzisz. Bez karty i bez wdrożeniowca.' },
  { icon: Users, title: 'Dodaj zespół', desc: 'Zapraszasz ludzi po nazwie użytkownika. Nie musisz zbierać adresów e-mail.' },
  { icon: Rocket, title: 'Pracujcie w jednym systemie', desc: 'Grafik, zadania i czaty działają od pierwszej zmiany, na telefonie i komputerze.' },
]

const industries = [
  { icon: Coffee, label: 'Kawiarnie' },
  { icon: UtensilsCrossed, label: 'Restauracje' },
  { icon: Hotel, label: 'Hotele' },
  { icon: ShoppingBag, label: 'Sklepy' },
  { icon: Warehouse, label: 'Magazyny' },
  { icon: Truck, label: 'Hurtownie' },
]

const plans = [
  {
    name: 'Starter',
    price: '149',
    tagline: 'Dla jednego oddziału, który chce ogarnąć podstawy.',
    highlight: false,
    features: ['Zadania i checklisty', 'Czaty zespołu', 'Raporty dnia'],
  },
  {
    name: 'Pro',
    price: '249',
    tagline: 'Dla firm, które planują grafik i pilnują magazynu.',
    highlight: true,
    features: ['Wszystko ze Starter', 'Grafik pracy', 'Magazyn i inwentaryzacja', 'Raport menadżerski'],
  },
  {
    name: 'Sieć',
    price: '399',
    tagline: 'Dla sieci z wieloma oddziałami i widokiem na całość.',
    highlight: false,
    features: ['Wszystko z Pro', 'Koszty i przychody', 'Priorytetowe wsparcie'],
  },
]

const statusQuo = [
  'Osobny grafik w arkuszu',
  'Ustalenia rozsypane po WhatsAppie',
  'Papierowe checklisty na zapleczu',
  'Zeszyt magazynowy',
  'Raporty przepisywane ręcznie',
]
const withOzmo = [
  'Wszystko w jednej aplikacji',
  'Cały zespół widzi to samo',
  'Dane liczone automatycznie',
  'Historia zmian i raportów',
  'Dostęp z telefonu i komputera',
]

const faq = [
  {
    q: 'Czy mogę przetestować OZMO przed zakupem?',
    a: 'Tak. Zakładasz konto za darmo, dodajesz oddział i sprawdzasz system na własnych danych. Bez podawania karty.',
  },
  {
    q: 'Co z danymi i RODO?',
    a: 'Twoje dane trzymamy na serwerach w Unii Europejskiej. To Ty decydujesz, kto ma do nich dostęp, a konta pracowników możesz w każdej chwili wyłączyć.',
  },
  {
    q: 'Czy OZMO działa na telefonie?',
    a: 'Tak. To aplikacja webowa (PWA), którą instalujesz na telefonie i komputerze. Zespół pracuje głównie na telefonie.',
  },
  {
    q: 'Ile trwa wdrożenie?',
    a: 'Zwykle jedno popołudnie. Zakładasz oddziały, zapraszasz zespół i ruszacie na najbliższej zmianie. Wdrożeniowiec nie jest potrzebny.',
  },
  {
    q: 'Czy muszę zbierać e-maile pracowników?',
    a: 'Nie. Ludzi dodajesz po nazwie użytkownika, a oni logują się na telefonie.',
  },
]
</script>

<template>
  <div class="min-h-svh bg-background text-foreground">
    <!-- Nagłówek -->
    <header
      class="sticky top-0 z-40 border-b border-border/70 bg-background/85 backdrop-blur supports-[backdrop-filter]:bg-background/70"
    >
      <div class="mx-auto flex h-16 max-w-6xl items-center justify-between px-5 sm:px-6">
        <a href="#" class="flex items-center gap-2.5">
          <span
            class="grid size-8 place-items-center rounded-lg bg-primary font-heading text-base font-bold text-primary-foreground"
            aria-hidden="true"
          >O</span>
          <span class="font-heading text-xl font-bold tracking-tight">OZMO</span>
        </a>
        <nav class="flex items-center gap-1 sm:gap-2">
          <a href="#funkcje" class="hidden rounded-md px-3 py-2 text-sm font-medium text-muted-foreground transition-colors hover:text-foreground sm:block">Funkcje</a>
          <a href="#cennik" class="hidden rounded-md px-3 py-2 text-sm font-medium text-muted-foreground transition-colors hover:text-foreground sm:block">Cennik</a>
          <NuxtLink to="/auth/login" class="hidden sm:block">
            <Button variant="ghost">Zaloguj się</Button>
          </NuxtLink>
          <Button variant="outline" :disabled="signingIn" @click="enterDemo">
            {{ signingIn ? 'Otwieram…' : 'Wypróbuj demo' }}
          </Button>
          <NuxtLink to="/auth/register" class="hidden sm:block">
            <Button>Wypróbuj za darmo</Button>
          </NuxtLink>
        </nav>
      </div>
    </header>

    <!-- Hero: split, treść po lewej + żywy podgląd produktu po prawej -->
    <section class="relative overflow-hidden">
      <div
        aria-hidden="true"
        class="pointer-events-none absolute inset-0 -z-10 opacity-60 [background-image:linear-gradient(to_right,var(--border)_1px,transparent_1px),linear-gradient(to_bottom,var(--border)_1px,transparent_1px)] [background-size:44px_44px] [mask-image:radial-gradient(ellipse_58%_54%_at_50%_0%,black,transparent_82%)]"
      ></div>

      <div class="mx-auto max-w-6xl px-5 pt-14 pb-16 sm:px-6 sm:pt-20 lg:pt-24">
        <div class="grid items-center gap-12 lg:grid-cols-[1.02fr_0.98fr] lg:gap-14">
          <div class="ozmo-rise">
            <h1 class="max-w-xl font-heading text-4xl font-bold leading-[1.06] tracking-tight sm:text-5xl lg:text-[3.35rem]">
              System do zarządzania <span class="text-primary">firmą wielooddziałową</span>
            </h1>
            <p class="mt-5 max-w-md text-lg leading-relaxed text-muted-foreground">
              Zadania, grafik, czaty, magazyn i raporty w jednej aplikacji. Zamiast Excela,
              WhatsAppa i papierowych checklist.
            </p>
            <div class="mt-8 flex flex-col gap-3 sm:flex-row">
              <NuxtLink to="/auth/register">
                <Button size="lg" class="w-full gap-2 sm:w-auto">
                  Wypróbuj za darmo <ArrowRight class="size-4" />
                </Button>
              </NuxtLink>
              <Button size="lg" variant="outline" class="w-full gap-2 sm:w-auto" :disabled="signingIn" @click="enterDemo">
                <PlayCircle class="size-4" /> {{ signingIn ? 'Otwieram demo…' : 'Wypróbuj demo' }}
              </Button>
            </div>
          </div>

          <!-- Podgląd: okno grafiku + pływające karty zadania i czatu -->
          <div class="ozmo-rise ozmo-rise-2 relative">
            <!-- Okno grafiku -->
            <div class="overflow-hidden rounded-2xl border border-border bg-card">
              <div class="flex items-center justify-between border-b border-border bg-muted/60 px-4 py-3">
                <div class="flex items-center gap-2">
                  <CalendarDays class="size-4 text-primary" />
                  <span class="text-sm font-semibold">Grafik</span>
                  <span class="text-xs text-muted-foreground">Tydzień 14-20 lip</span>
                </div>
                <span class="flex gap-1" aria-hidden="true">
                  <span class="size-2 rounded-full bg-border"></span>
                  <span class="size-2 rounded-full bg-border"></span>
                  <span class="size-2 rounded-full bg-border"></span>
                </span>
              </div>
              <div class="grid grid-cols-5 gap-1.5 p-3">
                <div v-for="col in week" :key="col.day" class="min-w-0">
                  <div class="mb-1.5 flex items-baseline justify-center gap-1 text-center">
                    <span class="text-[11px] font-semibold text-foreground">{{ col.day }}</span>
                    <span class="text-[10px] text-muted-foreground">{{ col.date }}</span>
                  </div>
                  <div class="space-y-1">
                    <div
                      v-for="s in col.shifts"
                      :key="s.who + s.time"
                      class="rounded-md px-1.5 py-1 text-left"
                      :style="chipTint(s.cat)"
                    >
                      <p class="flex items-center gap-1 truncate text-[11px] font-medium leading-tight text-foreground">
                        <span class="size-1.5 shrink-0 rounded-full" :style="dot(s.cat)"></span>
                        {{ s.who }}
                      </p>
                      <p class="text-[10px] leading-tight text-muted-foreground tabular-nums">{{ s.time }}</p>
                    </div>
                  </div>
                </div>
              </div>
              <div class="flex flex-wrap items-center gap-x-4 gap-y-1.5 border-t border-border px-4 py-2.5">
                <span v-for="r in roles" :key="r.label" class="inline-flex items-center gap-1.5 text-[11px] text-muted-foreground">
                  <span class="size-2 rounded-full" :style="{ backgroundColor: `var(--cat-${r.cat})` }"></span>
                  {{ r.label }}
                </span>
              </div>
            </div>

            <!-- Pływająca karta zadania (kanban) -->
            <div
              class="mt-4 rounded-xl border border-border bg-card p-3 shadow-sm sm:mt-0 sm:absolute sm:-bottom-6 sm:-left-6 sm:w-56"
            >
              <div class="flex items-center justify-between">
                <span class="text-xs font-semibold">Otwarcie oddziału</span>
                <Badge variant="warning" class="text-[10px]">Wysoki</Badge>
              </div>
              <div class="mt-2 space-y-1.5">
                <div class="flex items-center gap-2 text-[11px] text-muted-foreground">
                  <span class="grid size-3.5 place-items-center rounded-[4px] bg-success text-success-foreground"><Check class="size-2.5" /></span>
                  Wyczyść i uzupełnij ekspres
                </div>
                <div class="flex items-center gap-2 text-[11px] text-muted-foreground">
                  <span class="grid size-3.5 place-items-center rounded-[4px] bg-success text-success-foreground"><Check class="size-2.5" /></span>
                  Sprawdź temperatury lodówek
                </div>
                <div class="flex items-center gap-2 text-[11px] text-muted-foreground">
                  <span class="size-3.5 shrink-0 rounded-[4px] border border-input"></span>
                  Odbierz dostawę
                </div>
              </div>
              <p class="mt-2 text-[10px] font-medium text-muted-foreground tabular-nums">2 / 3 gotowe</p>
            </div>

            <!-- Pływająca wiadomość z czatu -->
            <div
              class="mt-4 flex items-start gap-2.5 rounded-xl border border-border bg-card p-3 shadow-sm sm:mt-0 sm:absolute sm:-top-5 sm:-right-5 sm:w-56"
            >
              <span class="grid size-7 shrink-0 place-items-center rounded-full bg-primary/12 text-[11px] font-semibold text-primary" aria-hidden="true">MK</span>
              <div class="min-w-0">
                <p class="text-[11px] font-semibold leading-tight">Marek K.</p>
                <p class="mt-0.5 text-[11px] leading-snug text-muted-foreground">Dostawa przyjęta, wszystko się zgadza.</p>
              </div>
            </div>
          </div>
        </div>
      </div>
    </section>

    <!-- Pasek-teza -->
    <section class="border-y border-border bg-sidebar">
      <div class="mx-auto max-w-6xl px-5 py-11 sm:px-6">
        <p class="max-w-4xl font-heading text-xl font-semibold leading-snug tracking-tight sm:text-2xl">
          Jeden system zamiast pięciu. Grafik, komunikator, checklisty, magazyn i raporty przestają
          żyć w osobnych plikach i zaczynają pracować razem.
        </p>
      </div>
    </section>

    <!-- Funkcje: bento z rytmem -->
    <section id="funkcje" class="mx-auto max-w-6xl px-5 py-16 sm:px-6 sm:py-20">
      <div class="max-w-2xl">
        <h2 class="font-heading text-3xl font-bold tracking-tight sm:text-4xl">
          Wszystko, czym zarządzasz każdego dnia
        </h2>
        <p class="mt-3 text-muted-foreground">
          Sześć modułów, które zastępują rozproszone narzędzia i papier.
        </p>
      </div>

      <div class="mt-10 grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
        <!-- Zadania: szeroki kafelek z żywą checklistą -->
        <article class="flex flex-col justify-between rounded-2xl border border-border bg-gradient-to-br from-primary/[0.06] to-card p-6 sm:col-span-2">
          <div>
            <ListChecks class="size-6 text-primary" />
            <h3 class="mt-4 font-heading text-xl font-bold tracking-tight">{{ features[0].title }}</h3>
            <p class="mt-2 max-w-md text-sm text-muted-foreground">{{ features[0].desc }}</p>
          </div>
          <div class="mt-5 grid gap-2 sm:grid-cols-2">
            <div class="flex items-center gap-2.5 rounded-lg border border-border bg-card px-3 py-2">
              <span class="grid size-4 place-items-center rounded-[5px] bg-success text-success-foreground"><Check class="size-3" /></span>
              <span class="text-sm">Otwarcie oddziału</span>
            </div>
            <div class="flex items-center gap-2.5 rounded-lg border border-border bg-card px-3 py-2">
              <span class="grid size-4 place-items-center rounded-[5px] bg-success text-success-foreground"><Check class="size-3" /></span>
              <span class="text-sm">Kontrola temperatur</span>
            </div>
            <div class="flex items-center gap-2.5 rounded-lg border border-border bg-card px-3 py-2">
              <span class="size-4 shrink-0 rounded-[5px] border border-input"></span>
              <span class="text-sm text-muted-foreground">Odbiór dostawy</span>
            </div>
            <div class="flex items-center gap-2.5 rounded-lg border border-border bg-card px-3 py-2">
              <span class="size-4 shrink-0 rounded-[5px] border border-input"></span>
              <span class="text-sm text-muted-foreground">Zamknięcie kasy</span>
            </div>
          </div>
        </article>

        <!-- Grafik: mini-strip zmian w kolorach ról -->
        <article class="rounded-2xl border border-border bg-card p-6 transition-colors hover:border-primary/40">
          <CalendarDays class="size-6 text-primary" />
          <h3 class="mt-4 font-heading text-lg font-bold tracking-tight">{{ features[1].title }}</h3>
          <p class="mt-2 text-sm text-muted-foreground">{{ features[1].desc }}</p>
          <div class="mt-4 flex gap-1.5">
            <div v-for="(col, i) in week.slice(0, 4)" :key="i" class="flex-1 space-y-1">
              <div
                v-for="s in col.shifts.slice(0, 2)"
                :key="s.who + s.time"
                class="h-5 rounded"
                :style="barFill(s.cat)"
                aria-hidden="true"
              ></div>
            </div>
          </div>
        </article>

        <!-- Czaty: dymki -->
        <article class="rounded-2xl border border-border bg-card p-6 transition-colors hover:border-primary/40">
          <MessagesSquare class="size-6 text-primary" />
          <h3 class="mt-4 font-heading text-lg font-bold tracking-tight">{{ features[2].title }}</h3>
          <p class="mt-2 text-sm text-muted-foreground">{{ features[2].desc }}</p>
          <div class="mt-4 space-y-2">
            <div class="w-fit max-w-full rounded-xl rounded-tl-sm bg-muted px-3 py-1.5 text-xs">Kto bierze poranną zmianę?</div>
            <div class="ml-auto w-fit max-w-full rounded-xl rounded-tr-sm bg-primary px-3 py-1.5 text-xs text-primary-foreground">Ja mogę wejść o 7.</div>
          </div>
        </article>

        <!-- Magazyn: wiersze stanów z alertem -->
        <article class="rounded-2xl border border-border bg-card p-6 transition-colors hover:border-primary/40">
          <Package class="size-6 text-primary" />
          <h3 class="mt-4 font-heading text-lg font-bold tracking-tight">{{ features[3].title }}</h3>
          <p class="mt-2 text-sm text-muted-foreground">{{ features[3].desc }}</p>
          <div class="mt-4 space-y-1.5 text-xs">
            <div class="flex items-center justify-between rounded-lg border border-border px-3 py-1.5">
              <span>Mleko</span><span class="tabular-nums text-muted-foreground">24 / 15</span>
            </div>
            <div class="flex items-center justify-between rounded-lg bg-warning-soft px-3 py-1.5 text-warning-soft-foreground">
              <span class="font-medium">Kawa ziarnista</span><span class="tabular-nums font-medium">8 / 20</span>
            </div>
          </div>
        </article>

        <!-- Raporty -->
        <article class="rounded-2xl border border-border bg-card p-6 transition-colors hover:border-primary/40">
          <FileText class="size-6 text-primary" />
          <h3 class="mt-4 font-heading text-lg font-bold tracking-tight">{{ features[4].title }}</h3>
          <p class="mt-2 text-sm text-muted-foreground">{{ features[4].desc }}</p>
          <div class="mt-4 space-y-2">
            <div class="h-2 w-4/5 rounded-full bg-muted" aria-hidden="true"></div>
            <div class="h-2 w-3/5 rounded-full bg-muted" aria-hidden="true"></div>
            <Badge variant="success" class="mt-1 text-[10px]">Raport zamknięty</Badge>
          </div>
        </article>

        <!-- Koszty: szeroki kafelek z mini-wykresem -->
        <article class="grid gap-6 rounded-2xl border border-border bg-card p-6 transition-colors hover:border-primary/40 sm:col-span-2 sm:grid-cols-[1fr_auto] sm:items-center">
          <div>
            <Wallet class="size-6 text-primary" />
            <h3 class="mt-4 font-heading text-lg font-bold tracking-tight">{{ features[5].title }}</h3>
            <p class="mt-2 max-w-md text-sm text-muted-foreground">{{ features[5].desc }}</p>
          </div>
          <div class="flex h-24 items-end gap-2.5" aria-hidden="true">
            <div
              v-for="(h, i) in costBars"
              :key="i"
              class="w-8 rounded-t-md"
              :style="{ height: `${h}%`, backgroundColor: `var(--chart-${i + 1})` }"
            ></div>
          </div>
        </article>
      </div>
    </section>

    <!-- Jak to działa -->
    <section class="border-t border-border bg-sidebar">
      <div class="mx-auto max-w-6xl px-5 py-16 sm:px-6 sm:py-20">
        <h2 class="max-w-2xl font-heading text-3xl font-bold tracking-tight sm:text-4xl">
          Zaczynasz w kilka minut
        </h2>
        <ol class="mt-10 grid gap-8 sm:grid-cols-3 sm:gap-6">
          <li v-for="(s, i) in steps" :key="s.title" class="relative">
            <div class="flex items-center gap-3">
              <span class="grid size-10 place-items-center rounded-xl border border-border bg-card text-primary">
                <component :is="s.icon" class="size-5" />
              </span>
              <span class="font-heading text-2xl font-bold tabular-nums text-border">{{ i + 1 }}</span>
            </div>
            <h3 class="mt-4 font-heading text-lg font-bold tracking-tight">{{ s.title }}</h3>
            <p class="mt-2 text-sm text-muted-foreground">{{ s.desc }}</p>
          </li>
        </ol>
      </div>
    </section>

    <!-- Branże -->
    <section class="mx-auto max-w-6xl px-5 py-16 sm:px-6 sm:py-20">
      <h2 class="max-w-2xl font-heading text-3xl font-bold tracking-tight sm:text-4xl">
        Dla każdej firmy z wieloma lokalizacjami
      </h2>
      <div class="mt-8 grid grid-cols-2 gap-3 sm:grid-cols-3 lg:grid-cols-6">
        <div
          v-for="ind in industries"
          :key="ind.label"
          class="flex items-center gap-3 rounded-xl border border-border bg-card px-4 py-3.5"
        >
          <component :is="ind.icon" class="size-5 shrink-0 text-muted-foreground" />
          <span class="text-sm font-medium">{{ ind.label }}</span>
        </div>
      </div>
    </section>

    <!-- Cennik -->
    <section id="cennik" class="border-t border-border bg-sidebar">
      <div class="mx-auto max-w-6xl px-5 py-16 sm:px-6 sm:py-20">
        <div class="max-w-2xl">
          <h2 class="font-heading text-3xl font-bold tracking-tight sm:text-4xl">Prosty cennik za oddział</h2>
          <p class="mt-3 text-muted-foreground">
            Ceny wkrótce. Rozliczenie miesięczne, naliczane za każdy oddział.
          </p>
        </div>

        <div class="mt-10 grid items-start gap-6 lg:grid-cols-3">
          <article
            v-for="p in plans"
            :key="p.name"
            class="relative flex h-full flex-col rounded-2xl border bg-card p-6"
            :class="p.highlight ? 'border-primary ring-1 ring-primary/25 lg:-mt-3 lg:mb-3' : 'border-border'"
          >
            <Badge v-if="p.highlight" class="absolute -top-3 left-6">Najczęściej wybierany</Badge>
            <h3 class="font-heading text-xl font-bold tracking-tight">{{ p.name }}</h3>
            <p class="mt-1.5 min-h-10 text-sm text-muted-foreground">{{ p.tagline }}</p>
            <div class="mt-5 flex items-baseline gap-1.5">
              <span class="font-heading text-4xl font-bold tracking-tight tabular-nums">{{ p.price }} zł</span>
              <span class="text-sm text-muted-foreground">/ mc za oddział</span>
            </div>
            <div class="my-6 h-px bg-border"></div>
            <ul class="flex-1 space-y-2.5 text-sm">
              <li v-for="feat in p.features" :key="feat" class="flex items-start gap-2.5">
                <span class="mt-0.5 grid size-4 shrink-0 place-items-center rounded-full bg-success-soft text-success-soft-foreground">
                  <Check class="size-3" />
                </span>
                <span>{{ feat }}</span>
              </li>
            </ul>
            <NuxtLink to="/auth/register" class="mt-8 block">
              <Button class="w-full" :variant="p.highlight ? 'default' : 'outline'">Wypróbuj za darmo</Button>
            </NuxtLink>
          </article>
        </div>

        <!-- Self-host: cicha, czwarta opcja -->
        <div class="mt-6 flex flex-col items-start justify-between gap-4 rounded-2xl border border-dashed border-border bg-card p-6 sm:flex-row sm:items-center">
          <div class="flex items-start gap-3">
            <Code class="mt-0.5 size-5 shrink-0 text-muted-foreground" />
            <div>
              <h3 class="font-heading text-lg font-bold tracking-tight">Self-host — za darmo, na własnym serwerze</h3>
              <p class="mt-1 text-sm text-muted-foreground">
                OZMO jest oprogramowaniem open source (licencja AGPL-3.0). Uruchom je samodzielnie
                i korzystaj bez opłat. Wersja hostowana przez nas jest płatna.
              </p>
            </div>
          </div>
          <a :href="GITHUB_URL" target="_blank" rel="noopener" class="shrink-0">
            <Button variant="outline" class="gap-2"><Code class="size-4" /> Kod na GitHub</Button>
          </a>
        </div>

        <!-- Konto demo -->
        <p class="mt-6 text-center text-sm text-muted-foreground">
          Chcesz tylko rozejrzeć się bez zakładania konta?
          <button class="font-medium text-primary hover:underline" :disabled="signingIn" @click="enterDemo">
            Otwórz publiczne demo
          </button>
          — dane resetują się co godzinę.
        </p>

        <!-- Porównanie ze status quo -->
        <div class="mt-14">
          <h3 class="font-heading text-xl font-bold tracking-tight">Rozproszone narzędzia kontra jeden system</h3>
          <div class="mt-5 grid gap-4 md:grid-cols-2">
            <div class="rounded-2xl border border-border bg-card p-6">
              <p class="text-sm font-semibold text-muted-foreground">Bez OZMO</p>
              <ul class="mt-4 space-y-2.5 text-sm">
                <li v-for="item in statusQuo" :key="item" class="flex items-start gap-2.5 text-muted-foreground">
                  <X class="mt-0.5 size-4 shrink-0" />
                  <span>{{ item }}</span>
                </li>
              </ul>
              <p class="mt-4 border-t border-border pt-4 text-sm font-medium">Efekt: chaos i błędy przy ręcznym przepisywaniu.</p>
            </div>
            <div class="rounded-2xl border border-primary/40 bg-card p-6">
              <p class="text-sm font-semibold text-primary">Z OZMO</p>
              <ul class="mt-4 space-y-2.5 text-sm">
                <li v-for="item in withOzmo" :key="item" class="flex items-start gap-2.5">
                  <Check class="mt-0.5 size-4 shrink-0 text-primary" />
                  <span>{{ item }}</span>
                </li>
              </ul>
              <p class="mt-4 border-t border-border pt-4 text-sm font-medium">Efekt: jedno źródło prawdy dla całej sieci.</p>
            </div>
          </div>
        </div>
      </div>
    </section>

    <!-- FAQ -->
    <section class="mx-auto max-w-3xl px-5 py-16 sm:px-6 sm:py-20">
      <h2 class="font-heading text-3xl font-bold tracking-tight sm:text-4xl">Częste pytania</h2>
      <Accordion type="single" collapsible class="mt-8 w-full">
        <AccordionItem v-for="(item, i) in faq" :key="i" :value="`faq-${i}`">
          <AccordionTrigger class="text-base font-semibold">{{ item.q }}</AccordionTrigger>
          <AccordionContent class="text-sm leading-relaxed text-muted-foreground">
            {{ item.a }}
          </AccordionContent>
        </AccordionItem>
      </Accordion>
    </section>

    <!-- Domykający CTA -->
    <section class="mx-auto max-w-6xl px-5 pb-20 sm:px-6">
      <div class="overflow-hidden rounded-3xl border border-border bg-primary px-6 py-14 text-center text-primary-foreground sm:px-12">
        <h2 class="mx-auto max-w-2xl font-heading text-3xl font-bold tracking-tight sm:text-4xl">
          Uporządkuj swoją firmę już dziś
        </h2>
        <p class="mx-auto mt-4 max-w-xl text-primary-foreground/85">
          Załóż konto, dodaj pierwszy oddział i sprawdź OZMO na najbliższej zmianie.
        </p>
        <NuxtLink to="/auth/register" class="mt-8 inline-block">
          <Button size="lg" variant="secondary" class="gap-2">
            Wypróbuj za darmo <ArrowRight class="size-4" />
          </Button>
        </NuxtLink>
      </div>
    </section>

    <!-- Stopka -->
    <footer class="border-t border-border">
      <div class="mx-auto flex max-w-6xl flex-col items-center justify-between gap-4 px-5 py-8 text-sm text-muted-foreground sm:flex-row sm:px-6">
        <div class="flex items-center gap-2">
          <span class="grid size-6 place-items-center rounded-md bg-primary text-[11px] font-bold text-primary-foreground" aria-hidden="true">O</span>
          <span class="font-heading font-bold text-foreground">OZMO</span>
        </div>
        <span>© {{ new Date().getFullYear() }} OZMO. System do zarządzania firmą wielooddziałową.</span>
        <div class="flex items-center gap-4">
          <a :href="GITHUB_URL" target="_blank" rel="noopener" class="inline-flex items-center gap-1.5 font-medium text-foreground transition-colors hover:text-primary">
            <Code class="size-4" /> GitHub
          </a>
          <NuxtLink to="/auth/login" class="font-medium text-foreground transition-colors hover:text-primary">Zaloguj się</NuxtLink>
        </div>
      </div>
    </footer>
  </div>
</template>

<style scoped>
.ozmo-rise {
  animation: ozmo-rise 0.7s cubic-bezier(0.16, 1, 0.3, 1) both;
}
.ozmo-rise-2 {
  animation-delay: 0.12s;
}
@keyframes ozmo-rise {
  from {
    opacity: 0;
    transform: translateY(16px);
  }
  to {
    opacity: 1;
    transform: translateY(0);
  }
}
@media (prefers-reduced-motion: reduce) {
  .ozmo-rise {
    animation: none;
  }
}
</style>

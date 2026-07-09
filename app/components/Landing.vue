<script setup lang="ts">
import {
  ListChecks,
  MessagesSquare,
  CalendarDays,
  Package,
  FileText,
  Wallet,
  Check,
  ArrowRight,
  UserPlus,
  Building2,
  Rocket,
} from '@lucide/vue'

const steps = [
  { icon: UserPlus, title: 'Załóż konto', desc: 'Bez karty, bez wdrożeniowca. Kilka minut i jesteś w środku.' },
  { icon: Building2, title: 'Dodaj lokale i zespół', desc: 'Zaproś kierowników i pracowników, ustaw oddziały i role.' },
  { icon: Rocket, title: 'Ruszasz z pierwszą zmianą', desc: 'Checklisty, grafik i czaty działają od pierwszego dnia.' },
]

const plans = [
  {
    name: 'Starter',
    price: '149',
    tagline: 'Dla pojedynczego lokalu, który chce ogarnąć podstawy.',
    highlight: false,
    features: ['Zadania i checklisty', 'Czaty zespołu', 'Raporty dnia'],
  },
  {
    name: 'Pro',
    price: '249',
    tagline: 'Dla lokali, które planują grafik i pilnują magazynu.',
    highlight: true,
    features: ['Wszystko ze Starter', 'Grafik pracy', 'Raport menadżerski', 'Magazyn i stany'],
  },
  {
    name: 'Sieć',
    price: '399',
    tagline: 'Dla właścicieli kilku lokali z widokiem na całą sieć.',
    highlight: false,
    features: ['Wszystko z Pro', 'Kontrola kosztów', 'Priorytetowe wsparcie'],
  },
]
</script>

<template>
  <div class="min-h-svh bg-background text-foreground">
    <!-- Nagłówek -->
    <header
      class="sticky top-0 z-40 border-b border-border/60 bg-background/80 backdrop-blur supports-[backdrop-filter]:bg-background/65"
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
          <NuxtLink to="/auth/login">
            <Button variant="ghost">Zaloguj się</Button>
          </NuxtLink>
          <NuxtLink to="/auth/register">
            <Button>Załóż konto</Button>
          </NuxtLink>
        </nav>
      </div>
    </header>

    <!-- Hero: asymetryczny, treść po lewej + podgląd produktu po prawej -->
    <section class="mx-auto max-w-6xl px-5 pt-14 pb-10 sm:px-6 sm:pt-20 lg:pt-24">
      <div class="grid items-center gap-12 lg:grid-cols-[1.05fr_0.95fr] lg:gap-10">
        <div class="ozmo-rise">
          <span class="inline-flex items-center gap-2 rounded-full border border-border bg-card px-3 py-1 text-xs font-medium text-muted-foreground shadow-xs">
            <span class="size-1.5 rounded-full bg-success"></span>
            System operacyjny dla gastronomii i hotelarstwa
          </span>
          <h1 class="mt-5 font-heading text-4xl font-bold leading-[1.05] tracking-tight sm:text-5xl lg:text-[3.4rem]">
            System operacyjny dla <span class="text-primary">sieci restauracji i hoteli</span>
          </h1>
          <p class="mt-5 max-w-xl text-lg leading-relaxed text-muted-foreground">
            Zadania, grafik, magazyn, raporty i czaty w jednym miejscu, zamiast Excela,
            WhatsAppa i papierowych checklist. Na telefonie i na komputerze.
          </p>
          <div class="mt-8 flex flex-col gap-3 sm:flex-row">
            <NuxtLink to="/auth/register">
              <Button size="lg" class="w-full gap-2 sm:w-auto">
                Zacznij za darmo <ArrowRight class="size-4" />
              </Button>
            </NuxtLink>
            <NuxtLink to="#cennik">
              <Button size="lg" variant="outline" class="w-full sm:w-auto">Zobacz pakiety</Button>
            </NuxtLink>
          </div>
          <p class="mt-4 text-sm text-muted-foreground">
            Bez karty. Polski interfejs. Działa na telefonie zespołu.
          </p>
        </div>

        <!-- Podgląd produktu: mini-wersja realnego ekranu Zadań -->
        <div class="ozmo-rise ozmo-rise-2 relative">
          <div
            aria-hidden="true"
            class="pointer-events-none absolute -inset-6 -z-10 rounded-[2rem] bg-primary/5 blur-2xl"
          ></div>
          <div class="overflow-hidden rounded-2xl border border-border bg-card shadow-lg">
            <div class="flex items-center justify-between border-b border-border bg-muted/50 px-4 py-3">
              <div class="flex items-center gap-2">
                <span class="grid size-6 place-items-center rounded-md bg-primary text-[11px] font-bold text-primary-foreground">O</span>
                <span class="text-sm font-semibold">Zadania</span>
                <span class="text-xs text-muted-foreground">· Bella Centrum</span>
              </div>
              <span class="flex gap-1">
                <span class="size-2 rounded-full bg-border"></span>
                <span class="size-2 rounded-full bg-border"></span>
                <span class="size-2 rounded-full bg-border"></span>
              </span>
            </div>
            <div class="space-y-2.5 p-4">
              <div class="rounded-xl border border-border p-3">
                <p class="text-sm font-medium">Otwarcie lokalu</p>
                <div class="mt-2 flex flex-wrap items-center gap-1.5">
                  <Badge variant="warning" class="text-[10px]">Wysoki</Badge>
                  <Badge variant="warning" class="text-[10px]">W trakcie</Badge>
                  <span class="ml-1 inline-flex items-center gap-1 text-xs text-muted-foreground">
                    <ListChecks class="size-3" /> 2/4
                  </span>
                </div>
              </div>
              <div class="rounded-xl border border-border p-3">
                <p class="text-sm font-medium">Naprawa ekspresu</p>
                <div class="mt-2 flex flex-wrap items-center gap-1.5">
                  <Badge variant="destructive" class="text-[10px]">Pilny</Badge>
                  <Badge variant="info" class="text-[10px]">Do zrobienia</Badge>
                </div>
              </div>
              <div class="rounded-xl border border-border p-3">
                <p class="text-sm font-medium text-muted-foreground line-through">Zamknięcie kasy</p>
                <div class="mt-2 flex flex-wrap items-center gap-1.5">
                  <Badge variant="secondary" class="text-[10px]">Normalny</Badge>
                  <Badge variant="success" class="text-[10px]">Zrobione</Badge>
                </div>
              </div>
              <div class="flex items-center gap-2 rounded-xl bg-warning-soft px-3 py-2.5 text-warning-soft-foreground">
                <Package class="size-4 shrink-0" />
                <span class="text-xs font-medium">Niski stan: Kawa ziarnista, 8 kg (min. 20)</span>
              </div>
            </div>
          </div>
        </div>
      </div>
    </section>

    <!-- Pasek-teza: inny format sekcji -->
    <section class="border-y border-border bg-sidebar">
      <div class="mx-auto max-w-6xl px-5 py-10 sm:px-6">
        <p class="max-w-4xl font-heading text-xl font-semibold leading-snug tracking-tight sm:text-2xl">
          Jeden system zamiast pięciu narzędzi. Kierownik widzi całą zmianę,
          pracownik wie, co robić, a właściciel ma podgląd na całą sieć.
        </p>
      </div>
    </section>

    <!-- Funkcje: bento z rytmem, bez powtarzalnej siatki kart -->
    <section id="funkcje" class="mx-auto max-w-6xl px-5 py-16 sm:px-6 sm:py-20">
      <h2 class="max-w-2xl font-heading text-3xl font-bold tracking-tight">
        Wszystko, czego potrzebuje sieć lokali
      </h2>
      <p class="mt-3 max-w-xl text-muted-foreground">
        Sześć modułów, które codziennie robią różnicę: od pierwszej checklisty po koszty na koniec miesiąca.
      </p>

      <div class="mt-10 grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
        <!-- Duży kafelek marki z mini-wizualizacją -->
        <article class="flex flex-col justify-between rounded-2xl bg-primary p-6 text-primary-foreground sm:col-span-2 lg:row-span-2">
          <div>
            <ListChecks class="size-7" />
            <h3 class="mt-4 font-heading text-2xl font-bold tracking-tight">Zadania i checklisty</h3>
            <p class="mt-2 max-w-md text-primary-foreground/85">
              Otwarcia, zamknięcia i Sanepid z gotowych szablonów. Przydzielasz osobom,
              a postęp widać na żywo, pozycja po pozycji.
            </p>
          </div>
          <div class="mt-6 space-y-2">
            <div class="flex items-center gap-3 rounded-xl bg-primary-foreground/10 px-3 py-2.5">
              <Check class="size-4 shrink-0" /> <span class="text-sm">Wyczyść i uzupełnij ekspres</span>
            </div>
            <div class="flex items-center gap-3 rounded-xl bg-primary-foreground/10 px-3 py-2.5">
              <Check class="size-4 shrink-0" /> <span class="text-sm">Sprawdź temperatury w lodówkach</span>
            </div>
            <div class="flex items-center gap-3 rounded-xl bg-primary-foreground/10 px-3 py-2.5 opacity-60">
              <span class="size-4 shrink-0 rounded-[4px] border border-primary-foreground/50"></span>
              <span class="text-sm">Odbierz dostawę warzyw</span>
            </div>
          </div>
        </article>

        <!-- Ciemny kafelek dla kontrastu -->
        <article class="rounded-2xl bg-foreground p-6 text-background">
          <MessagesSquare class="size-6" />
          <h3 class="mt-4 font-heading text-lg font-bold tracking-tight">Czaty zespołu</h3>
          <p class="mt-2 text-sm text-background/75">
            Kanał sieci i kanały lokali. Koniec z chaosem na WhatsAppie.
          </p>
        </article>

        <article class="rounded-2xl border border-border bg-card p-6 shadow-sm transition-shadow hover:shadow-md">
          <CalendarDays class="size-6 text-primary" />
          <h3 class="mt-4 font-heading text-lg font-bold tracking-tight">Grafik pracy</h3>
          <p class="mt-2 text-sm text-muted-foreground">
            Układaj i publikuj zmiany, zbieraj dostępność, kopiuj tygodnie.
          </p>
        </article>

        <article class="rounded-2xl border border-border bg-card p-6 shadow-sm transition-shadow hover:shadow-md">
          <Package class="size-6 text-primary" />
          <h3 class="mt-4 font-heading text-lg font-bold tracking-tight">Magazyn i stany</h3>
          <p class="mt-2 text-sm text-muted-foreground">
            Przyjęcia, wydania i alerty o niskich stanach, bez Excela.
          </p>
        </article>

        <article class="rounded-2xl border border-border bg-card p-6 shadow-sm transition-shadow hover:shadow-md">
          <FileText class="size-6 text-primary" />
          <h3 class="mt-4 font-heading text-lg font-bold tracking-tight">Raporty dnia</h3>
          <p class="mt-2 text-sm text-muted-foreground">
            Raport pracowniczy i menadżerski z blokadą zamknięcia.
          </p>
        </article>

        <article class="rounded-2xl border border-border bg-card p-6 shadow-sm transition-shadow hover:shadow-md sm:col-span-2 lg:col-span-1">
          <Wallet class="size-6 text-primary" />
          <h3 class="mt-4 font-heading text-lg font-bold tracking-tight">Kontrola kosztów</h3>
          <p class="mt-2 text-sm text-muted-foreground">
            Food, Beverage i Labor Cost % per lokal i cała sieć, liczone automatycznie.
          </p>
        </article>
      </div>
    </section>

    <!-- Jak zacząć: realny 3-krokowy ciąg -->
    <section class="border-t border-border bg-sidebar">
      <div class="mx-auto max-w-6xl px-5 py-16 sm:px-6 sm:py-20">
        <h2 class="font-heading text-3xl font-bold tracking-tight">Od rejestracji do pierwszej zmiany</h2>
        <div class="mt-10 grid gap-6 sm:grid-cols-3">
          <div v-for="(s, i) in steps" :key="s.title" class="relative">
            <div class="flex items-center gap-3">
              <span class="grid size-10 place-items-center rounded-xl bg-card text-primary shadow-sm">
                <component :is="s.icon" class="size-5" />
              </span>
              <span class="font-heading text-sm font-semibold text-muted-foreground">Krok {{ i + 1 }}</span>
            </div>
            <h3 class="mt-4 font-heading text-lg font-bold tracking-tight">{{ s.title }}</h3>
            <p class="mt-2 text-sm text-muted-foreground">{{ s.desc }}</p>
          </div>
        </div>
      </div>
    </section>

    <!-- Cennik -->
    <section id="cennik" class="mx-auto max-w-6xl px-5 py-16 sm:px-6 sm:py-20">
      <div class="max-w-2xl">
        <h2 class="font-heading text-3xl font-bold tracking-tight">Pakiety</h2>
        <p class="mt-3 text-muted-foreground">
          Ceny wkrótce — skontaktuj się z nami. Rozliczenie za lokal, miesięcznie.
        </p>
      </div>
      <div class="mt-10 grid items-start gap-6 lg:grid-cols-3">
        <article
          v-for="p in plans"
          :key="p.name"
          class="relative flex h-full flex-col rounded-2xl border bg-card p-6 shadow-sm"
          :class="p.highlight ? 'border-primary shadow-md ring-1 ring-primary/30 lg:-mt-3 lg:mb-3' : 'border-border'"
        >
          <Badge v-if="p.highlight" class="absolute -top-3 left-6">Najczęściej wybierany</Badge>
          <h3 class="font-heading text-xl font-bold tracking-tight">{{ p.name }}</h3>
          <p class="mt-1.5 min-h-10 text-sm text-muted-foreground">{{ p.tagline }}</p>
          <div class="mt-5 flex items-baseline gap-1.5">
            <span class="font-heading text-4xl font-bold tracking-tight tabular-nums">{{ p.price }} zł</span>
            <span class="text-sm text-muted-foreground">/ mc za lokal</span>
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
            <Button class="w-full" :variant="p.highlight ? 'default' : 'outline'">
              Wybierz {{ p.name }}
            </Button>
          </NuxtLink>
        </article>
      </div>
    </section>

    <!-- Domykający CTA -->
    <section class="mx-auto max-w-6xl px-5 pb-20 sm:px-6">
      <div class="overflow-hidden rounded-3xl bg-foreground px-6 py-14 text-center text-background sm:px-12">
        <h2 class="mx-auto max-w-2xl font-heading text-3xl font-bold tracking-tight sm:text-4xl">
          Gotowy uporządkować swoją sieć?
        </h2>
        <p class="mx-auto mt-4 max-w-xl text-background/75">
          Załóż konto, dodaj pierwszy lokal i przetestuj OZMO na najbliższej zmianie.
        </p>
        <NuxtLink to="/auth/register" class="mt-8 inline-block">
          <Button size="lg" class="gap-2">Zacznij za darmo <ArrowRight class="size-4" /></Button>
        </NuxtLink>
      </div>
    </section>

    <!-- Stopka -->
    <footer class="border-t border-border">
      <div class="mx-auto flex max-w-6xl flex-col items-center justify-between gap-4 px-5 py-8 text-sm text-muted-foreground sm:flex-row sm:px-6">
        <div class="flex items-center gap-2">
          <span class="grid size-6 place-items-center rounded-md bg-primary text-[11px] font-bold text-primary-foreground">O</span>
          <span class="font-heading font-bold text-foreground">OZMO</span>
        </div>
        <span>© {{ new Date().getFullYear() }} OZMO. System operacyjny dla sieci lokali.</span>
        <NuxtLink to="/auth/login" class="font-medium text-foreground transition-colors hover:text-primary">Zaloguj się</NuxtLink>
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

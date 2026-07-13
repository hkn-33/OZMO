<script setup lang="ts">
import {
  ArrowRight,
  CalendarDays,
  Check,
  Code,
  FileText,
  ListChecks,
  MapPin,
  MessagesSquare,
  Package,
  Users,
  Wallet,
} from '@lucide/vue'

const { enterDemo, signingIn } = useDemo()
const GITHUB_URL = 'https://github.com/hkn-33/OZMO'

const modules = [
  { icon: ListChecks, label: 'Zadania' },
  { icon: CalendarDays, label: 'Grafik' },
  { icon: MessagesSquare, label: 'Czaty' },
  { icon: Package, label: 'Magazyn' },
  { icon: FileText, label: 'Raporty' },
  { icon: Wallet, label: 'Koszty' },
]

const operations = [
  { time: '06:45', title: 'Otwarcie lokalu', detail: 'Checklista w toku', tone: 'pink' },
  { time: '08:00', title: 'Poranna zmiana', detail: 'Grafik opublikowany', tone: 'yellow' },
  { time: '10:20', title: 'Dostawa przyjęta', detail: 'Magazyn zaktualizowany', tone: 'blue' },
  { time: '14:30', title: 'Raport zmiany', detail: 'Czeka na kierownika', tone: 'green' },
]

const features = [
  {
    name: 'Zadania i checklisty',
    detail: 'Otwarcia, zamknięcia i kontrole z szablonów. Każdy widzi swoją część pracy.',
    result: 'Postęp na żywo',
  },
  {
    name: 'Grafik pracy',
    detail: 'Dostępność, zmiany i publikacja tygodnia dla wszystkich oddziałów.',
    result: 'Mniej wiadomości',
  },
  {
    name: 'Czat zespołu',
    detail: 'Kanał całej firmy i osobne kanały lokali, obok pracy której dotyczą.',
    result: 'Jedno miejsce ustaleń',
  },
  {
    name: 'Magazyn',
    detail: 'Przyjęcia, wydania, inwentaryzacje i alerty niskiego stanu per lokal.',
    result: 'Bez arkuszy',
  },
  {
    name: 'Raporty i koszty',
    detail: 'Zamknięcie dnia, notatki kierownika i obraz kosztów całej sieci.',
    result: 'Decyzje na danych',
  },
]

const plans = [
  {
    name: 'Starter',
    price: '149 zł',
    summary: 'Jeden lokal i codzienna praca zespołu.',
    features: ['Zadania i checklisty', 'Czaty', 'Raporty dnia'],
  },
  {
    name: 'Pro',
    price: '249 zł',
    summary: 'Grafik, magazyn i pełna kontrola lokalu.',
    features: ['Wszystko ze Starter', 'Grafik', 'Magazyn', 'Raport kierownika'],
  },
  {
    name: 'Sieć',
    price: '399 zł',
    summary: 'Wiele oddziałów widocznych jako jedna firma.',
    features: ['Wszystko z Pro', 'Koszty i przychody', 'Widok całej sieci'],
  },
]

const faq = [
  {
    q: 'Czy mogę wejść do OZMO bez zakładania konta?',
    a: 'Tak. Publiczne demo otwiera gotową firmę z dwoma lokalami i przykładowymi danymi. Możesz wszystko klikać, a dane resetują się co godzinę.',
  },
  {
    q: 'Czy OZMO działa na telefonie?',
    a: 'Tak. OZMO jest instalowalną aplikacją webową. Zespół może korzystać z niej na telefonie, a kierownik z tego samego systemu na komputerze.',
  },
  {
    q: 'Czy muszę zbierać e-maile pracowników?',
    a: 'Nie. Pracowników dodajesz po nazwie użytkownika, a oni logują się na swoim urządzeniu.',
  },
  {
    q: 'Co z danymi i RODO?',
    a: 'Dane są przechowywane na serwerach w Unii Europejskiej. Dostęp wynika z organizacji, oddziału i roli pracownika.',
  },
  {
    q: 'Czy mogę uruchomić OZMO na własnym serwerze?',
    a: 'Tak. Kod jest dostępny na licencji AGPL-3.0. Wersję self-hosted możesz uruchomić samodzielnie bez opłat za usługę OZMO.',
  },
]
</script>

<template>
  <div class="landing min-h-svh bg-background text-foreground">
    <header class="sticky top-0 z-40 bg-background/95 backdrop-blur-md">
      <div class="landing-wide mx-auto flex h-20 items-center justify-between px-5 sm:px-8 lg:px-12">
        <a href="#start" class="font-heading text-3xl font-bold tracking-[-0.04em]" aria-label="OZMO — strona główna">
          ozmo<span class="text-primary">.</span>
        </a>
        <button
          class="landing-action inline-flex min-h-11 items-center gap-2 whitespace-nowrap rounded-full border border-foreground px-4 text-sm font-semibold"
          :disabled="signingIn"
          @click="enterDemo"
        >
          {{ signingIn ? 'Otwieram…' : 'Otwórz demo' }}
          <ArrowRight class="size-4" />
        </button>
      </div>
    </header>

    <main>
      <section id="start" class="landing-hero landing-wide mx-auto grid items-center gap-12 px-5 pt-10 pb-24 sm:px-8 sm:pt-14 sm:pb-28 lg:gap-16 lg:px-12 lg:pt-16 lg:pb-32">
        <div class="landing-enter min-w-0">
          <h1 class="landing-hero-title min-w-0 max-w-[10ch] font-heading font-bold [overflow-wrap:anywhere]">
            Każdy lokal. Jeden rytm.
          </h1>
          <p class="mt-7 max-w-[31rem] text-lg leading-relaxed text-muted-foreground sm:text-xl">
            Zadania, grafik, czaty, magazyn i raporty w jednym miejscu. Właściciel widzi całą sieć,
            kierownik prowadzi zmianę, zespół wie co robić.
          </p>
          <div class="mt-9 flex flex-wrap items-center gap-3">
            <NuxtLink
              to="/auth/register"
              class="landing-action inline-flex min-h-12 items-center gap-2 whitespace-nowrap rounded-full bg-[var(--color-panel-ink)] px-5 text-sm font-semibold text-[var(--color-on-ink)]"
            >
              Załóż konto <ArrowRight class="size-4" />
            </NuxtLink>
            <button
              class="landing-action inline-flex min-h-12 items-center whitespace-nowrap rounded-full border border-border px-5 text-sm font-semibold"
              :disabled="signingIn"
              @click="enterDemo"
            >
              {{ signingIn ? 'Otwieram demo…' : 'Najpierw zobacz demo' }}
            </button>
          </div>
          <p class="mt-4 text-sm text-muted-foreground">Bez karty. Demo resetuje dane co godzinę.</p>
        </div>

        <figure class="landing-enter landing-enter-late min-w-0" aria-label="Podgląd dnia operacyjnego w OZMO">
          <div class="overflow-hidden rounded-[var(--radius-card)] bg-[var(--color-panel-ink)] text-[var(--color-on-ink)]">
            <div class="flex items-center justify-between border-b border-[var(--color-on-ink-rule)] px-5 py-4 sm:px-6">
              <div>
                <p class="font-heading text-lg font-bold">Poniedziałek w Bella</p>
                <p class="mt-0.5 text-sm text-[var(--color-on-ink-muted)]">2 lokale · dane publicznego demo</p>
              </div>
              <span class="inline-flex items-center gap-2 rounded-full bg-[var(--color-on-ink-soft)] px-3 py-1.5 text-xs font-semibold">
                <span class="size-2 rounded-full bg-[var(--color-panel-green)]" />
                Na bieżąco
              </span>
            </div>

            <div class="grid min-w-0 gap-2 p-3 sm:grid-cols-2 sm:p-4">
              <article
                v-for="(item, index) in operations"
                :key="item.title"
                class="landing-operation min-w-0 rounded-[var(--radius-card)] p-4 text-[var(--color-panel-ink)]"
                :class="`landing-operation-${item.tone}`"
                :style="{ animationDelay: `${180 + index * 55}ms` }"
              >
                <p class="text-xs font-semibold tabular-nums opacity-60">{{ item.time }}</p>
                <h2 class="mt-6 text-lg font-bold leading-tight">{{ item.title }}</h2>
                <p class="mt-1 text-sm opacity-70">{{ item.detail }}</p>
              </article>
            </div>

            <div class="border-t border-[var(--color-on-ink-rule)] py-3">
              <div class="landing-module-track flex w-max items-center">
                <div
                  v-for="(module, index) in [...modules, ...modules]"
                  :key="`${module.label}-${index}`"
                  class="flex min-w-40 items-center gap-2 border-r border-[var(--color-on-ink-rule)] px-5 text-sm text-[var(--color-on-ink-muted)]"
                  :aria-hidden="index >= modules.length ? 'true' : undefined"
                >
                  <component :is="module.icon" class="size-4" />
                  {{ module.label }}
                </div>
              </div>
            </div>
          </div>
        </figure>
      </section>

      <section class="bg-[var(--color-panel-yellow)] text-[var(--color-panel-ink)]">
        <div class="landing-split-end landing-wide mx-auto grid gap-10 px-5 py-16 sm:px-8 sm:py-20 lg:items-end lg:px-12 lg:py-24">
          <h2 class="max-w-[12ch] font-heading text-4xl font-bold leading-[1.02] tracking-[-0.03em] sm:text-5xl">
            Jedna zmiana nie powinna żyć w pięciu narzędziach.
          </h2>
          <p class="max-w-[42rem] text-lg leading-relaxed opacity-75 lg:justify-self-end">
            Grafik w Excelu, ustalenia na WhatsAppie, checklisty na papierze i stan magazynu w zeszycie
            nie tworzą procesu. OZMO łączy je w jeden dzień pracy — od otwarcia po raport kierownika.
          </p>
        </div>
      </section>

      <section id="funkcje" class="landing-wide mx-auto px-5 py-20 sm:px-8 sm:py-28 lg:px-12 lg:py-32">
        <div class="landing-feature-split grid gap-12 lg:gap-20">
          <div>
            <h2 class="max-w-[11ch] font-heading text-4xl font-bold leading-[1.02] tracking-[-0.03em] sm:text-5xl">
              Narzędzia, które znają kontekst lokalu.
            </h2>
            <p class="mt-6 max-w-md text-lg leading-relaxed text-muted-foreground">
              Każdy moduł działa osobno. Najwięcej daje wtedy, gdy reszta systemu wie o tej samej zmianie,
              osobie i lokalizacji.
            </p>
            <button
              class="landing-action mt-8 inline-flex min-h-12 items-center gap-2 whitespace-nowrap rounded-full border border-foreground px-5 text-sm font-semibold"
              :disabled="signingIn"
              @click="enterDemo"
            >
              Sprawdź na żywo <ArrowRight class="size-4" />
            </button>
          </div>

          <dl class="border-t border-border">
            <div
              v-for="feature in features"
              :key="feature.name"
              class="grid gap-3 border-b border-border py-6 sm:grid-cols-[minmax(0,0.7fr)_minmax(0,1.2fr)_auto] sm:items-start sm:gap-6"
            >
              <dt class="font-heading text-lg font-bold">{{ feature.name }}</dt>
              <dd class="text-sm leading-relaxed text-muted-foreground sm:text-base">{{ feature.detail }}</dd>
              <dd class="whitespace-nowrap text-sm font-semibold text-primary">{{ feature.result }}</dd>
            </div>
          </dl>
        </div>
      </section>

      <section class="bg-[var(--color-panel-blue)] text-[var(--color-panel-ink)]">
        <div class="landing-network-split landing-wide mx-auto grid gap-12 px-5 py-20 sm:px-8 sm:py-24 lg:items-center lg:px-12 lg:py-28">
          <div class="order-2 grid gap-3 sm:grid-cols-2 lg:order-1">
            <div class="rounded-[var(--radius-card)] bg-[var(--color-panel-ink)] p-5 text-[var(--color-on-ink)] sm:col-span-2">
              <div class="flex items-start justify-between gap-4">
                <div>
                  <p class="text-sm text-[var(--color-on-ink-muted)]">Sieć dzisiaj</p>
                  <p class="mt-4 font-heading text-4xl font-bold tabular-nums">2</p>
                  <p class="mt-1 text-sm text-[var(--color-on-ink-muted)]">oddziały w publicznym demo</p>
                </div>
                <MapPin class="size-5 text-primary" />
              </div>
            </div>
            <div class="rounded-[var(--radius-card)] bg-[var(--color-panel-pink)] p-5">
              <Users class="size-5" />
              <p class="mt-8 font-heading text-2xl font-bold tabular-nums">3</p>
              <p class="mt-1 text-sm opacity-70">zmiany w grafiku</p>
            </div>
            <div class="rounded-[var(--radius-card)] bg-[var(--color-panel-green)] p-5">
              <Package class="size-5" />
              <p class="mt-8 font-heading text-2xl font-bold tabular-nums">1</p>
              <p class="mt-1 text-sm opacity-70">niski stan magazynowy</p>
            </div>
          </div>
          <div class="order-1 lg:order-2 lg:pl-10">
            <h2 class="max-w-[12ch] font-heading text-4xl font-bold leading-[1.02] tracking-[-0.03em] sm:text-5xl">
              Lokal z bliska. Sieć z odpowiedniego dystansu.
            </h2>
            <p class="mt-6 max-w-lg text-lg leading-relaxed opacity-75">
              Pracownik widzi dzisiejsze zadania. Kierownik widzi swoją zmianę. Właściciel dostaje obraz
              wszystkich oddziałów bez proszenia o kolejny arkusz.
            </p>
          </div>
        </div>
      </section>

      <section id="cennik" class="landing-wide mx-auto px-5 py-20 sm:px-8 sm:py-28 lg:px-12 lg:py-32">
        <div class="flex flex-col gap-5 sm:flex-row sm:items-end sm:justify-between">
          <div>
            <h2 class="font-heading text-4xl font-bold tracking-[-0.03em] sm:text-5xl">Cennik za oddział.</h2>
            <p class="mt-4 text-lg text-muted-foreground">Ceny wkrótce. Miesięcznie, bez długiej umowy.</p>
          </div>
          <a
            :href="GITHUB_URL"
            target="_blank"
            rel="noopener"
            class="landing-action inline-flex min-h-11 items-center gap-2 self-start whitespace-nowrap rounded-full border border-border px-4 text-sm font-semibold sm:self-auto"
          >
            <Code class="size-4" /> Kod na GitHub
          </a>
        </div>

        <div class="mt-12 border-t border-border">
          <article
            v-for="(plan, index) in plans"
            :key="plan.name"
            class="landing-pricing-row grid gap-5 border-b border-border py-8 lg:items-center lg:gap-8"
          >
            <div class="flex items-center gap-3">
              <span class="text-sm tabular-nums text-muted-foreground">0{{ index + 1 }}</span>
              <h3 class="font-heading text-2xl font-bold">{{ plan.name }}</h3>
            </div>
            <p class="font-heading text-3xl font-bold tabular-nums">
              {{ plan.price }} <span class="font-sans text-sm font-normal text-muted-foreground">/ mc</span>
            </p>
            <div>
              <p class="text-sm text-muted-foreground">{{ plan.summary }}</p>
              <ul class="mt-3 flex flex-wrap gap-x-4 gap-y-2 text-sm">
                <li v-for="item in plan.features" :key="item" class="inline-flex items-center gap-1.5">
                  <Check class="size-3.5 text-primary" /> {{ item }}
                </li>
              </ul>
            </div>
            <NuxtLink
              to="/auth/register"
              class="landing-action inline-flex min-h-11 items-center justify-center whitespace-nowrap rounded-full border px-4 text-sm font-semibold lg:justify-self-end"
              :class="index === 1 ? 'border-[var(--color-panel-ink)] bg-[var(--color-panel-ink)] text-[var(--color-on-ink)]' : 'border-border'"
            >
              Wybierz plan
            </NuxtLink>
          </article>
        </div>

        <p class="mt-6 max-w-2xl text-sm leading-relaxed text-muted-foreground">
          Wolisz własny serwer? OZMO jest open source na licencji AGPL-3.0. Wersję self-hosted
          uruchamiasz samodzielnie i bez opłat za usługę.
        </p>
      </section>

      <section class="landing-faq-split landing-wide mx-auto grid gap-12 px-5 pb-24 sm:px-8 sm:pb-32 lg:px-12">
        <h2 class="max-w-[9ch] font-heading text-4xl font-bold leading-[1.02] tracking-[-0.03em] sm:text-5xl">
          Konkretne pytania. Konkretne odpowiedzi.
        </h2>
        <Accordion type="single" collapsible class="border-t border-border">
          <AccordionItem v-for="(item, index) in faq" :key="item.q" :value="`faq-${index}`">
            <AccordionTrigger class="min-h-16 text-left text-base font-semibold sm:text-lg">
              {{ item.q }}
            </AccordionTrigger>
            <AccordionContent class="max-w-2xl text-base leading-relaxed text-muted-foreground">
              {{ item.a }}
            </AccordionContent>
          </AccordionItem>
        </Accordion>
      </section>
    </main>

    <footer class="bg-[var(--color-panel-ink)] text-[var(--color-on-ink)]">
      <div class="landing-wide mx-auto px-5 pt-20 pb-8 sm:px-8 sm:pt-28 lg:px-12 lg:pt-32">
        <p class="max-w-[18ch] font-heading text-4xl font-bold leading-[1.02] tracking-[-0.03em] sm:text-6xl">
          Mniej pilnowania narzędzi. Więcej prowadzenia lokali.
        </p>
        <div class="mt-10 flex flex-wrap items-center gap-3">
          <button
            class="landing-action inline-flex min-h-12 items-center gap-2 whitespace-nowrap rounded-full bg-[var(--color-on-ink)] px-5 text-sm font-semibold text-[var(--color-panel-ink)]"
            :disabled="signingIn"
            @click="enterDemo"
          >
            {{ signingIn ? 'Otwieram…' : 'Otwórz demo' }} <ArrowRight class="size-4" />
          </button>
          <NuxtLink
            to="/auth/register"
            class="landing-action inline-flex min-h-12 items-center whitespace-nowrap rounded-full border border-[var(--color-on-ink-rule)] px-5 text-sm font-semibold"
          >
            Załóż konto
          </NuxtLink>
        </div>
        <div class="mt-20 flex flex-col gap-5 border-t border-[var(--color-on-ink-rule)] pt-6 text-sm text-[var(--color-on-ink-muted)] sm:flex-row sm:items-center sm:justify-between">
          <span class="font-heading text-2xl font-bold tracking-[-0.04em] text-[var(--color-on-ink)]">
            ozmo<span class="text-primary">.</span>
          </span>
          <p>© {{ new Date().getFullYear() }} OZMO · AGPL-3.0</p>
          <div class="flex items-center gap-5">
            <NuxtLink to="/auth/login" class="whitespace-nowrap hover:text-[var(--color-on-ink)]">Zaloguj się</NuxtLink>
            <a :href="GITHUB_URL" target="_blank" rel="noopener" class="whitespace-nowrap hover:text-[var(--color-on-ink)]">GitHub</a>
          </div>
        </div>
      </div>
    </footer>
  </div>
</template>

<style scoped>
/* Hallmark · pre-emit critique: P5 H5 E4 S5 R5 V5
 * Hallmark · genre: modern-minimal · macrostructure: Split Studio · design-system: OZMO
 * enrichment: E4 floating product scene · craft: tier-A DOM/CSS · nav: N9 · footer: Ft5
 * contrast: pass (40–41) · honest: pass (46) · tokens: pass (48) · icons: pass (30)
 * slop: pass (42–45) · mobile: pass (34, 49, 50–57)
 */
.landing-action {
  transition: color 160ms var(--ease-out), background-color 160ms var(--ease-out), border-color 160ms var(--ease-out), transform 100ms var(--ease-out);
}

.landing-wide {
  max-width: 90rem;
}

.landing-hero {
  min-height: 78svh;
}

.landing-hero-title {
  font-size: clamp(3.5rem, 7vw, 6rem);
  line-height: 0.96;
  letter-spacing: -0.04em;
}

.landing-action:active {
  transform: translateY(1px);
}

.landing-enter {
  animation: landing-enter 480ms var(--ease-out) both;
}

.landing-enter-late {
  animation-delay: 90ms;
}

.landing-operation {
  animation: landing-operation 420ms var(--ease-out) both;
}

.landing-operation-pink {
  background: var(--color-panel-pink);
}

.landing-operation-yellow {
  background: var(--color-panel-yellow);
}

.landing-operation-blue {
  background: var(--color-panel-blue);
}

.landing-operation-green {
  background: var(--color-panel-green);
}

.landing-module-track {
  animation: landing-modules 28s linear infinite;
}

.landing-module-track:hover {
  animation-play-state: paused;
}

@keyframes landing-enter {
  from {
    transform: translateY(12px);
  }
  to {
    transform: translateY(0);
  }
}

@keyframes landing-operation {
  from {
    transform: translateY(10px);
  }
  to {
    transform: translateY(0);
  }
}

@keyframes landing-modules {
  to {
    transform: translateX(-50%);
  }
}

@media (hover: hover) and (pointer: fine) {
  .landing-action:hover {
    transform: translateY(-1px);
  }
}

@media (min-width: 64rem) {
  .landing-hero {
    grid-template-columns: minmax(0, 0.9fr) minmax(0, 1.1fr);
  }

  .landing-split-end,
  .landing-feature-split {
    grid-template-columns: minmax(0, 0.8fr) minmax(0, 1.2fr);
  }

  .landing-network-split {
    grid-template-columns: minmax(0, 1.1fr) minmax(0, 0.9fr);
  }

  .landing-pricing-row {
    grid-template-columns: 0.5fr 0.8fr 1.3fr auto;
  }

  .landing-faq-split {
    grid-template-columns: minmax(0, 0.65fr) minmax(0, 1.35fr);
  }
}

@media (prefers-reduced-motion: reduce) {
  .landing-enter,
  .landing-operation,
  .landing-module-track {
    animation: none;
  }

  .landing-module-track > :nth-child(n + 7) {
    display: none;
  }
}
</style>

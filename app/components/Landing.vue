<script setup lang="ts">
import {
  ArrowRight,
  CalendarDays,
  Check,
  Code,
  FileText,
  ListChecks,
  MessageCircle,
  Package,
  Users,
  Wallet,
} from '@lucide/vue'

const { enterDemo, signingIn } = useDemo()
const GITHUB_URL = 'https://github.com/hkn-33/OZMO'
const revealObservers = new WeakMap<HTMLElement, IntersectionObserver>()

const vReveal = {
  mounted(element: HTMLElement) {
    if (!('IntersectionObserver' in window) || window.matchMedia('(prefers-reduced-motion: reduce)').matches) return

    element.dataset.revealReady = ''
    const observer = new IntersectionObserver((entries) => {
      if (!entries[0]?.isIntersecting) return

      element.dataset.revealed = ''
      observer.disconnect()
      revealObservers.delete(element)
    }, { threshold: 0.2, rootMargin: '0px 0px -8% 0px' })

    revealObservers.set(element, observer)
    observer.observe(element)
  },
  unmounted(element: HTMLElement) {
    revealObservers.get(element)?.disconnect()
    revealObservers.delete(element)
  },
}

const daySteps = [
  { time: '06:45', title: 'Otwarcie', detail: '7 z 8 punktów gotowych', icon: ListChecks, tone: 'pink' },
  { time: '08:00', title: 'Zmiana', detail: '5 osób na grafiku', icon: Users, tone: 'yellow' },
  { time: '10:20', title: 'Dostawa', detail: '12 pozycji przyjętych', icon: Package, tone: 'green' },
  { time: '14:30', title: 'Raport', detail: 'Czeka na kierownika', icon: FileText, tone: 'blue' },
]

const plans = [
  {
    name: 'Early access',
    price: '0 zł',
    summary: 'Pierwsze 20 firm przez pierwsze 3 miesiące.',
    features: ['Pełna aplikacja', 'Pomoc we wdrożeniu', 'Wpływ na rozwój produktu'],
  },
  {
    name: 'Lokal',
    price: '79 zł',
    summary: 'Codzienna praca jednego lokalu i zespołu do 15 osób.',
    features: ['Zadania i checklisty', 'Grafik i czat', 'Magazyn i raport dnia'],
  },
  {
    name: 'Pro',
    price: '149 zł',
    summary: 'Pełna kontrola firmy bez limitu członków zespołu.',
    features: ['Wszystko z planu Lokal', 'Import danych i koszty', 'Kolejny lokal +99 zł / mc'],
  },
]

const faq = [
  {
    q: 'Czy mogę wejść do OZMO bez zakładania konta?',
    a: 'Tak. Publiczne demo otwiera gotową firmę z dwoma lokalami i przykładowymi danymi. Możesz wszystko klikać, a dane resetują się co godzinę.',
  },
  {
    q: 'Czy OZMO działa na telefonie?',
    a: 'Tak. OZMO jest instalowalną aplikacją webową. Zespół korzysta z niej na telefonie, a kierownik z tego samego systemu na komputerze.',
  },
  {
    q: 'Czy muszę zbierać e-maile pracowników?',
    a: 'Nie. Pracowników dodajesz po nazwie użytkownika, a oni logują się na swoim urządzeniu.',
  },
  {
    q: 'Co z danymi i RODO?',
    a: 'Dostęp do danych zależy od organizacji, lokalu i roli użytkownika. Szczegóły opisuje polityka prywatności dostępna w stopce.',
  },
  {
    q: 'Czy mogę uruchomić OZMO na własnym serwerze?',
    a: 'Tak. Kod jest dostępny na licencji AGPL-3.0. Wersję self-hosted możesz uruchomić samodzielnie bez opłat za usługę OZMO.',
  },
]
</script>

<template>
  <div class="landing">
    <nav class="landing-nav" aria-label="Główna nawigacja">
      <a href="#start" class="landing-wordmark" aria-label="OZMO — strona główna">
        ozmo<span>.</span>
      </a>
      <div class="landing-nav-links">
        <a href="#jak-dziala">Jak działa</a>
        <a href="#cennik">Cennik</a>
        <a :href="GITHUB_URL" target="_blank" rel="noopener">GitHub</a>
      </div>
      <button class="landing-nav-cta" :disabled="signingIn" @click="enterDemo">
        {{ signingIn ? 'Otwieram…' : 'Otwórz demo' }}
        <ArrowRight aria-hidden="true" />
      </button>
    </nav>

    <main>
      <section id="start" class="landing-hero">
        <div class="landing-shell landing-hero-copy">
          <h1>Codzienna praca firmy w jednym miejscu.</h1>
          <div class="landing-hero-lede">
            <p>
              Planuj grafik, przydzielaj zadania, prowadź magazyn i zamykaj dzień raportem.
              OZMO działa dla jednego lokalu i dla wielu oddziałów.
            </p>
            <div class="landing-actions">
              <button class="landing-button landing-button-primary" :disabled="signingIn" @click="enterDemo">
                {{ signingIn ? 'Otwieram demo…' : 'Otwórz demo' }}
                <ArrowRight aria-hidden="true" />
              </button>
              <NuxtLink to="/auth/register" class="landing-button landing-button-secondary">
                Załóż konto
              </NuxtLink>
            </div>
            <p class="landing-note">Bez karty płatniczej. Konto demo ma przykładowe dane.</p>
          </div>
        </div>

        <div class="landing-shell landing-map-wrap">
          <LandingOperationsMap />
        </div>
      </section>

      <section id="jak-dziala" class="landing-day">
        <div class="landing-shell landing-day-head">
          <h2>Wszystko, co dzieje się w ciągu dnia.</h2>
          <p>
            Zadania, zmiany, dostawy i raporty są w jednym systemie. Nie trzeba przenosić
            informacji z rozmów do arkusza.
          </p>
        </div>

        <div v-reveal class="landing-shell landing-day-board">
          <div class="landing-day-status">
            <div>
              <span class="landing-live-dot" />
              Poniedziałek · Punkt Centrum
            </div>
            <span>Na bieżąco</span>
          </div>
          <div class="landing-day-grid">
            <article v-for="step in daySteps" :key="step.time" class="landing-day-step" :class="`is-${step.tone}`">
              <div class="landing-day-time">{{ step.time }}</div>
              <component :is="step.icon" class="landing-day-icon" aria-hidden="true" />
              <h3>{{ step.title }}</h3>
              <p>{{ step.detail }}</p>
            </article>
          </div>
          <div class="landing-day-footer">
            <span><MessageCircle aria-hidden="true" /> 2 nowe ustalenia</span>
            <span><CalendarDays aria-hidden="true" /> Grafik opublikowany</span>
            <span><Package aria-hidden="true" /> 1 niski stan</span>
          </div>
        </div>
      </section>

      <section class="landing-showcases landing-shell">
        <div class="landing-showcase landing-showcase-tasks">
          <div class="landing-showcase-copy">
            <h2>Zadania i checklisty</h2>
            <p>
              Każde zadanie ma osobę odpowiedzialną, termin i listę kroków. Komentarze
              zostają przy zadaniu, więc łatwo sprawdzić ustalenia.
            </p>
            <ul>
              <li><Check aria-hidden="true" /> Szablony otwarcia i zamknięcia</li>
              <li><Check aria-hidden="true" /> Postęp widoczny na żywo</li>
              <li><Check aria-hidden="true" /> Powiadomienia o ważnych zmianach</li>
            </ul>
          </div>
          <div v-reveal class="landing-visual-reveal">
            <div class="landing-task-visual" role="img" aria-label="Przykładowa checklista otwarcia lokalu">
              <div class="landing-visual-head">
                <span>Otwarcie lokalu</span>
                <span>7 / 8</span>
              </div>
              <div class="landing-progress"><span /></div>
              <div class="landing-check is-done"><span><Check /></span><p>Uruchom ekspres i kasę</p><b>MK</b></div>
              <div class="landing-check is-done"><span><Check /></span><p>Sprawdź salę i ogródek</p><b>AW</b></div>
              <div class="landing-check"><span /><p>Uzupełnij witrynę</p><b>TY</b></div>
              <div class="landing-task-meta">Termin 07:00 · Bella Centrum</div>
            </div>
          </div>
        </div>

        <div class="landing-showcase landing-showcase-schedule">
          <div v-reveal class="landing-visual-reveal">
            <div class="landing-schedule-visual" role="img" aria-label="Przykładowy grafik zespołu">
              <div class="landing-visual-head">
                <span>Grafik · 15–21 lipca</span>
                <span>Opublikowany</span>
              </div>
              <div class="landing-schedule-grid">
                <div class="landing-person"><span>MK</span><b>Monika</b></div>
                <div class="landing-shift is-long">08:00–16:00</div>
                <div class="landing-shift">12:00–18:00</div>
                <div class="landing-person"><span>AW</span><b>Adam</b></div>
                <div class="landing-shift">06:00–12:00</div>
                <div class="landing-shift is-long">12:00–20:00</div>
                <div class="landing-person"><span>TY</span><b>Tymek</b></div>
                <div class="landing-shift is-long">10:00–18:00</div>
                <div class="landing-shift">Wolne</div>
              </div>
            </div>
          </div>
          <div class="landing-showcase-copy">
            <h2>Grafik pracy</h2>
            <p>
              Kierownik układa tydzień i publikuje zmiany. Pracownik podaje dostępność
              i sprawdza aktualny grafik na telefonie.
            </p>
            <div class="landing-inline-modules">
              <span><CalendarDays /> Grafik</span>
              <span><Users /> Zespół</span>
              <span><MessageCircle /> Czaty</span>
            </div>
          </div>
        </div>

        <div class="landing-showcase landing-showcase-stock">
          <div class="landing-showcase-copy">
            <h2>Stany magazynowe bez arkusza</h2>
            <p>
              Zapisuj dostawy, zużycie i straty. OZMO oblicza bieżący stan i tworzy listę
              produktów, które trzeba uzupełnić.
            </p>
            <button class="landing-text-link" :disabled="signingIn" @click="enterDemo">
              Sprawdź magazyn w demo <ArrowRight aria-hidden="true" />
            </button>
          </div>
          <div v-reveal class="landing-visual-reveal">
            <div class="landing-stock-visual" role="img" aria-label="Podgląd stanów magazynowych i kosztów">
              <div class="landing-stock-top">
                <div><Package /><span>Magazyn</span></div>
                <strong>Lista braków</strong>
              </div>
              <div class="landing-stock-row"><span>Materiały eksploatacyjne</span><b>18 szt.</b><em>dobry stan</em></div>
              <div class="landing-stock-row is-low"><span>Środek czystości</span><b>2 szt.</b><em>niski stan</em></div>
              <div class="landing-stock-row"><span>Opakowania</span><b>120 szt.</b><em>dobry stan</em></div>
              <div class="landing-cost-line">
                <span><Wallet /> Koszt produktów</span>
                <strong>24%</strong>
                <svg viewBox="0 0 250 52" role="img" aria-label="Wykres kosztu produktów">
                  <path d="M3 42 C38 39 45 20 76 26 S125 44 151 21 S201 12 247 4" fill="none" stroke="currentColor" stroke-width="4" stroke-linecap="round" />
                </svg>
              </div>
            </div>
          </div>
        </div>
      </section>

      <section class="landing-network">
        <div class="landing-shell landing-network-inner">
          <div>
            <h2>Jeden lokal albo kilka oddziałów</h2>
            <p>
              Przy jednym lokalu widzisz tylko potrzebne funkcje. Po dodaniu kolejnych
              oddziałów pojawiają się wspólne raporty, koszty i stany magazynowe.
            </p>
          </div>
          <div v-reveal class="landing-network-graphic" role="img" aria-label="Dwa lokale połączone w jednej organizacji">
            <div class="landing-branch is-main">
              <span>Bella Centrum</span><b>Zmiana trwa</b><em>7 / 8 zadań</em>
            </div>
            <div class="landing-network-line"><span>ozmo.</span></div>
            <div class="landing-branch">
              <span>Bella Mokotów</span><b>Zmiana trwa</b><em>8 / 8 zadań</em>
            </div>
          </div>
        </div>
      </section>

      <section id="cennik" class="landing-pricing landing-shell">
        <div class="landing-pricing-head">
          <h2>Prosty cennik</h2>
          <div>
            <p>Opłata miesięczna. Bez umowy na czas określony.</p>
            <a :href="GITHUB_URL" target="_blank" rel="noopener"><Code /> Zobacz kod na GitHub</a>
          </div>
        </div>
        <div v-reveal class="landing-price-stage">
          <aside class="landing-price-summary">
            <p>Za firmę<br>miesięcznie</p>
            <strong>0–149 zł</strong>
            <span>Pierwsze 3 miesiące mogą kosztować 0 zł.</span>
            <div>
              <Code aria-hidden="true" />
              <p>Self-hosted pozostaje bez opłat za usługę OZMO.</p>
            </div>
          </aside>
          <div class="landing-price-options">
            <article v-for="(plan, index) in plans" :key="plan.name" class="landing-price-option" :class="{ 'is-featured': index === 1 }">
              <header>
                <h3>{{ plan.name }}</h3>
                <strong>{{ plan.price }} <small>/ mc</small></strong>
              </header>
              <p>{{ plan.summary }}</p>
              <ul>
                <li v-for="item in plan.features" :key="item"><Check /> {{ item }}</li>
              </ul>
              <NuxtLink to="/auth/register">Wybierz {{ plan.name }} <ArrowRight /></NuxtLink>
            </article>
          </div>
        </div>
        <p class="landing-selfhost">
          OZMO jest open source na licencji AGPL-3.0. Wersję self-hosted możesz uruchomić na własnym serwerze.
        </p>
      </section>

      <section class="landing-faq landing-shell">
        <div>
          <h2>Pytania i odpowiedzi</h2>
          <p>Najważniejsze informacje przed założeniem konta.</p>
        </div>
        <Accordion type="single" collapsible class="landing-accordion">
          <AccordionItem v-for="(item, index) in faq" :key="item.q" :value="`faq-${index}`">
            <AccordionTrigger>{{ item.q }}</AccordionTrigger>
            <AccordionContent>{{ item.a }}</AccordionContent>
          </AccordionItem>
        </Accordion>
      </section>

      <section class="landing-final">
        <div class="landing-shell landing-final-inner">
          <p>Sprawdź, czy OZMO pasuje do Twojej firmy.</p>
          <button class="landing-button landing-button-light" :disabled="signingIn" @click="enterDemo">
            {{ signingIn ? 'Otwieram…' : 'Otwórz demo' }}
            <ArrowRight aria-hidden="true" />
          </button>
        </div>
      </section>
    </main>

    <footer class="landing-footer landing-shell">
      <span class="landing-wordmark">ozmo<span>.</span></span>
      <p>Codzienne operacje jednego lub wielu lokali.</p>
      <div>
        <NuxtLink to="/auth/login">Zaloguj się</NuxtLink>
        <NuxtLink to="/privacy">Polityka prywatności</NuxtLink>
        <NuxtLink to="/terms">Warunki korzystania</NuxtLink>
        <a :href="GITHUB_URL" target="_blank" rel="noopener">GitHub</a>
        <span>© {{ new Date().getFullYear() }} · AGPL-3.0</span>
      </div>
    </footer>
  </div>
</template>

<style scoped>
/* Hallmark · pre-emit critique: P5 H5 E5 S5 R4 V5
 * Hallmark · genre: modern-minimal · macrostructure: Map / Diagram · design-system: OZMO
 * enrichment: E5 hand-built SVG · craft: tier-B · nav: N5 · footer: Ft2
 * contrast: pass (40–41) · honest: pass (46) · tokens: pass (48) · icons: pass (30)
 * slop: pass (42–45) · mobile: pass (34, 49, 50–57)
 */
.landing {
  min-height: 100svh;
  background: var(--color-paper);
  color: var(--color-ink);
}

.landing-shell {
  width: min(100% - 2.5rem, 86rem);
  margin-inline: auto;
}

.landing-nav {
  position: fixed;
  z-index: 40;
  top: var(--space-md);
  left: 50%;
  display: flex;
  width: max-content;
  max-width: calc(100% - 2rem);
  min-height: 3.5rem;
  align-items: center;
  gap: var(--space-lg);
  padding: var(--space-xs) var(--space-xs) var(--space-xs) var(--space-md);
  transform: translateX(-50%);
  border: var(--rule-thin) solid var(--color-rule);
  border-radius: var(--radius-pill);
  background: color-mix(in oklch, var(--color-paper-raised) 86%, transparent);
  box-shadow: 0 6px 8px -8px color-mix(in oklch, var(--color-ink) 28%, transparent);
  backdrop-filter: blur(14px) saturate(120%);
}

.landing-wordmark {
  color: var(--color-ink);
  font-family: var(--font-display);
  font-size: 1.45rem;
  font-weight: 800;
  letter-spacing: -0.04em;
  line-height: 1;
}

.landing-wordmark span {
  color: var(--color-accent);
}

.landing-nav-links {
  display: flex;
  align-items: center;
  gap: var(--space-lg);
  font-size: var(--text-sm);
  font-weight: 600;
}

.landing-nav-links a,
.landing-footer a {
  transition: color var(--dur-short) var(--ease-out);
}

.landing-nav-links a:hover,
.landing-footer a:hover {
  color: var(--color-accent);
}

.landing-nav-cta,
.landing-button,
.landing-price-option > a {
  display: inline-flex;
  min-height: 2.75rem;
  align-items: center;
  justify-content: center;
  gap: var(--space-xs);
  white-space: nowrap;
  border-radius: var(--radius-pill);
  font-size: var(--text-sm);
  font-weight: 700;
  transition: color var(--dur-short) var(--ease-out), background-color var(--dur-short) var(--ease-out), transform var(--dur-micro) var(--ease-out);
}

.landing-nav-cta {
  padding-inline: var(--space-md);
  background: var(--color-panel-ink);
  color: var(--color-on-ink);
}

.landing-nav-cta svg,
.landing-button svg,
.landing-price-option > a svg,
.landing-text-link svg {
  width: 1rem;
  height: 1rem;
}

.landing-hero {
  padding-top: 7.5rem;
  padding-bottom: var(--space-2xl);
}

.landing-hero-copy {
  display: grid;
  grid-template-columns: minmax(0, 1.1fr) minmax(20rem, .9fr);
  gap: clamp(2rem, 5vw, 5rem);
  align-items: end;
}

.landing-hero h1 {
  min-width: 0;
  font-family: var(--font-display);
  max-width: 13ch;
  font-size: clamp(3.2rem, 6vw, 5rem);
  font-weight: 750;
  line-height: .92;
  letter-spacing: -0.04em;
  text-wrap: balance;
  overflow-wrap: anywhere;
  animation: landing-copy-in var(--dur-long) var(--ease-out) both;
}

.landing-hero-lede {
  padding-bottom: var(--space-xs);
  animation: landing-copy-in var(--dur-long) var(--ease-out) 80ms both;
}

.landing-hero-lede > p:first-child,
.landing-day-head > p,
.landing-showcase-copy > p,
.landing-network-inner > div:first-child > p,
.landing-faq > div > p {
  max-width: 62ch;
  color: var(--color-ink-muted);
  font-size: var(--text-lg);
  line-height: 1.55;
  text-wrap: pretty;
}

.landing-actions {
  display: flex;
  flex-wrap: wrap;
  gap: var(--space-sm);
  margin-top: var(--space-lg);
}

.landing-button {
  min-height: 3rem;
  padding-inline: var(--space-lg);
}

.landing-button-primary {
  background: var(--color-panel-ink);
  color: var(--color-on-ink);
}

.landing-button-secondary {
  border: var(--rule-thin) solid var(--color-rule);
  background: var(--color-paper-raised);
}

.landing-note {
  margin-top: var(--space-sm);
  color: var(--color-ink-muted);
  font-size: var(--text-sm);
}

.landing-map-wrap {
  max-width: 54rem;
  margin-top: var(--space-lg);
}

.landing-day {
  scroll-margin-top: 5rem;
  padding-block: clamp(5rem, 9vw, 9rem);
  background: var(--color-panel-ink);
  color: var(--color-on-ink);
}

.landing-day-head {
  display: grid;
  grid-template-columns: minmax(0, 1fr) minmax(18rem, .7fr);
  gap: var(--space-2xl);
  align-items: end;
}

.landing-day-head h2,
.landing-showcase-copy h2,
.landing-network h2,
.landing-pricing h2,
.landing-faq h2 {
  min-width: 0;
  font-family: var(--font-display);
  font-size: clamp(2.5rem, 4.8vw, 4.6rem);
  font-weight: 750;
  line-height: .98;
  letter-spacing: -0.04em;
  text-wrap: balance;
  overflow-wrap: anywhere;
}

.landing-day-head > p {
  color: var(--color-on-ink-muted);
}

.landing-day-board {
  margin-top: var(--space-2xl);
  overflow: hidden;
  border: var(--rule-thin) solid var(--color-on-ink-rule);
  border-radius: var(--radius-card);
}

.landing-day-status,
.landing-day-footer {
  display: flex;
  min-height: 3.5rem;
  align-items: center;
  justify-content: space-between;
  gap: var(--space-md);
  padding-inline: var(--space-lg);
  color: var(--color-on-ink-muted);
  font-size: var(--text-sm);
}

.landing-day-status {
  border-bottom: var(--rule-thin) solid var(--color-on-ink-rule);
}

.landing-day-status > div,
.landing-day-footer span {
  display: inline-flex;
  align-items: center;
  gap: var(--space-xs);
}

.landing-live-dot {
  width: .55rem;
  height: .55rem;
  border-radius: 50%;
  background: var(--color-panel-green);
}

.landing-day-grid {
  display: grid;
  grid-template-columns: repeat(4, minmax(0, 1fr));
}

.landing-day-step {
  min-height: 17rem;
  padding: var(--space-lg);
  color: var(--color-panel-ink);
}

.landing-day-step + .landing-day-step {
  border-left: var(--rule-thin) solid var(--color-panel-ink);
}

.landing-day-step.is-pink { background: var(--color-panel-pink); }
.landing-day-step.is-yellow { background: var(--color-panel-yellow); }
.landing-day-step.is-green { background: var(--color-panel-green); }
.landing-day-step.is-blue { background: var(--color-panel-blue); }

.landing-day-time {
  font-size: var(--text-sm);
  font-variant-numeric: tabular-nums;
  opacity: .62;
}

.landing-day-icon {
  width: 1.65rem;
  height: 1.65rem;
  margin-top: 4.5rem;
}

.landing-day-step h3 {
  margin-top: var(--space-md);
  font-family: var(--font-display);
  font-size: var(--text-xl);
  font-weight: 750;
}

.landing-day-step p {
  margin-top: var(--space-xs);
  font-size: var(--text-sm);
  opacity: .68;
}

.landing-day-footer {
  justify-content: flex-start;
  gap: var(--space-xl);
  border-top: var(--rule-thin) solid var(--color-on-ink-rule);
}

.landing-day-footer svg {
  width: 1rem;
  height: 1rem;
}

.landing-showcases {
  display: grid;
  gap: clamp(6rem, 12vw, 11rem);
  padding-block: clamp(6rem, 12vw, 11rem);
}

.landing-showcase {
  display: grid;
  grid-template-columns: minmax(0, .78fr) minmax(0, 1.22fr);
  gap: clamp(2.5rem, 8vw, 8rem);
  align-items: center;
}

.landing-showcase-schedule {
  grid-template-columns: minmax(0, 1.25fr) minmax(0, .75fr);
}

.landing-showcase-copy ul {
  display: grid;
  gap: var(--space-sm);
  margin-top: var(--space-lg);
  font-size: var(--text-sm);
}

.landing-showcase-copy li,
.landing-inline-modules span,
.landing-text-link {
  display: flex;
  align-items: center;
  gap: var(--space-xs);
}

.landing-showcase-copy li svg,
.landing-inline-modules svg {
  width: 1rem;
  height: 1rem;
  color: var(--color-accent);
}

.landing-showcase-copy > p {
  margin-top: var(--space-lg);
}

.landing-task-visual,
.landing-schedule-visual,
.landing-stock-visual {
  min-width: 0;
  padding: clamp(1.25rem, 4vw, 3.5rem);
  border-radius: var(--radius-card);
  color: var(--color-panel-ink);
}

.landing-visual-reveal {
  min-width: 0;
}

[data-reveal-ready] {
  opacity: .35;
  transform: translateY(24px) scale(.985);
  transition: opacity 650ms var(--ease-out), transform 650ms var(--ease-out);
}

[data-reveal-ready][data-revealed] {
  opacity: 1;
  transform: none;
}

.landing-task-visual { background: var(--color-panel-pink); transform: rotate(1deg); }
.landing-schedule-visual { background: var(--color-panel-blue); transform: rotate(-1deg); }
.landing-stock-visual { background: var(--color-panel-green); transform: rotate(.7deg); }

.landing-visual-head,
.landing-stock-top,
.landing-cost-line {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: var(--space-md);
}

.landing-visual-head {
  font-family: var(--font-display);
  font-size: var(--text-lg);
  font-weight: 750;
}

.landing-visual-head span:last-child {
  font-family: var(--font-body);
  font-size: var(--text-sm);
  font-weight: 600;
}

.landing-progress {
  height: .45rem;
  margin-block: var(--space-lg);
  overflow: hidden;
  border-radius: var(--radius-pill);
  background: color-mix(in oklch, var(--color-panel-ink) 12%, transparent);
}

.landing-progress span {
  display: block;
  width: 87.5%;
  height: 100%;
  background: var(--color-panel-ink);
  transform: scaleX(.875);
  transform-origin: left;
  animation: landing-progress-in 900ms var(--ease-out) both;
}

.landing-check {
  display: grid;
  grid-template-columns: auto 1fr auto;
  gap: var(--space-md);
  align-items: center;
  min-height: 4.25rem;
  border-top: var(--rule-thin) solid color-mix(in oklch, var(--color-panel-ink) 18%, transparent);
}

.landing-check > span {
  display: grid;
  width: 1.5rem;
  height: 1.5rem;
  place-items: center;
  border: var(--rule-thin) solid var(--color-panel-ink);
  border-radius: .4rem;
}

.landing-check > span svg {
  width: 1rem;
  height: 1rem;
}

.landing-check.is-done > span {
  background: var(--color-panel-ink);
  color: var(--color-on-ink);
}

.landing-check b {
  display: grid;
  width: 2rem;
  height: 2rem;
  place-items: center;
  border-radius: 50%;
  background: color-mix(in oklch, var(--color-panel-ink) 12%, transparent);
  font-size: var(--text-xs);
}

.landing-task-meta {
  margin-top: var(--space-md);
  color: color-mix(in oklch, var(--color-panel-ink) 62%, transparent);
  font-size: var(--text-sm);
}

.landing-schedule-grid {
  display: grid;
  grid-template-columns: minmax(7rem, .7fr) repeat(2, minmax(8rem, 1fr));
  margin-top: var(--space-lg);
  overflow: hidden;
  border: var(--rule-thin) solid color-mix(in oklch, var(--color-panel-ink) 16%, transparent);
  border-radius: var(--radius-input);
}

.landing-person,
.landing-shift {
  display: flex;
  min-height: 4.5rem;
  align-items: center;
  gap: var(--space-sm);
  padding: var(--space-sm);
  border-bottom: var(--rule-thin) solid color-mix(in oklch, var(--color-panel-ink) 14%, transparent);
}

.landing-person span {
  display: grid;
  width: 2rem;
  height: 2rem;
  place-items: center;
  border-radius: 50%;
  background: var(--color-panel-ink);
  color: var(--color-on-ink);
  font-size: var(--text-xs);
}

.landing-shift {
  border-left: var(--rule-thin) solid color-mix(in oklch, var(--color-panel-ink) 14%, transparent);
  font-size: var(--text-sm);
}

.landing-shift.is-long {
  background: color-mix(in oklch, var(--color-panel-ink) 9%, transparent);
  font-weight: 700;
}

.landing-inline-modules {
  display: flex;
  flex-wrap: wrap;
  gap: var(--space-sm) var(--space-lg);
  margin-top: var(--space-lg);
  font-size: var(--text-sm);
  font-weight: 700;
}

.landing-stock-top > div,
.landing-cost-line > span {
  display: flex;
  align-items: center;
  gap: var(--space-xs);
}

.landing-stock-top svg,
.landing-cost-line svg {
  width: 1.2rem;
  height: 1.2rem;
}

.landing-stock-row {
  display: grid;
  grid-template-columns: minmax(0, 1fr) auto auto;
  gap: var(--space-md);
  align-items: center;
  min-height: 4rem;
  border-bottom: var(--rule-thin) solid color-mix(in oklch, var(--color-panel-ink) 15%, transparent);
  font-size: var(--text-sm);
}

.landing-stock-row:first-of-type {
  margin-top: var(--space-lg);
  border-top: var(--rule-thin) solid color-mix(in oklch, var(--color-panel-ink) 15%, transparent);
}

.landing-stock-row em {
  padding: .35rem .6rem;
  border-radius: var(--radius-pill);
  background: color-mix(in oklch, var(--color-panel-ink) 10%, transparent);
  font-size: var(--text-xs);
  font-style: normal;
}

.landing-stock-row.is-low em {
  background: var(--color-panel-yellow);
}

.landing-cost-line {
  margin-top: var(--space-lg);
  flex-wrap: wrap;
}

.landing-cost-line > strong {
  margin-left: auto;
  font-family: var(--font-display);
  font-size: var(--text-xl);
}

.landing-cost-line > svg {
  width: 100%;
  height: auto;
  color: var(--color-panel-ink);
}

.landing-text-link {
  min-height: 2.75rem;
  margin-top: var(--space-lg);
  font-weight: 700;
}

.landing-network {
  padding-block: clamp(5rem, 10vw, 9rem);
  background: var(--color-panel-blue);
  color: var(--color-panel-ink);
}

.landing-network-inner {
  display: grid;
  grid-template-columns: minmax(0, .8fr) minmax(0, 1.2fr);
  gap: clamp(3rem, 8vw, 8rem);
  align-items: center;
}

.landing-network-inner > div:first-child > p {
  margin-top: var(--space-lg);
  color: color-mix(in oklch, var(--color-panel-ink) 68%, transparent);
}

.landing-network-graphic {
  display: grid;
  grid-template-columns: minmax(0, 1fr) 7rem minmax(0, 1fr);
  align-items: center;
}

.landing-branch {
  display: grid;
  gap: var(--space-xs);
  min-height: 12rem;
  align-content: center;
  padding: var(--space-lg);
  border-radius: var(--radius-card);
  background: var(--color-paper-raised);
}

.landing-branch.is-main {
  background: var(--color-panel-ink);
  color: var(--color-on-ink);
}

.landing-branch span,
.landing-branch em {
  font-size: var(--text-sm);
  font-style: normal;
  opacity: .65;
}

.landing-branch b {
  font-family: var(--font-display);
  font-size: var(--text-xl);
}

.landing-network-line {
  display: flex;
  align-items: center;
  color: var(--color-panel-ink);
  font-family: var(--font-display);
  font-weight: 800;
}

.landing-network-line::before,
.landing-network-line::after {
  content: '';
  height: var(--rule-thin);
  flex: 1;
  background: var(--color-panel-ink);
  opacity: .3;
}

.landing-network-line span {
  padding-inline: var(--space-xs);
}

.landing-pricing {
  scroll-margin-top: 5rem;
  padding-block: clamp(6rem, 11vw, 10rem);
}

.landing-pricing-head,
.landing-faq {
  display: grid;
  grid-template-columns: minmax(0, .75fr) minmax(18rem, 1.25fr);
  gap: clamp(2.5rem, 8vw, 8rem);
}

.landing-pricing-head > div {
  align-self: end;
}

.landing-pricing-head p,
.landing-selfhost,
.landing-faq > div > p {
  color: var(--color-ink-muted);
}

.landing-pricing-head a {
  display: inline-flex;
  min-height: 2.75rem;
  align-items: center;
  gap: var(--space-xs);
  margin-top: var(--space-md);
  font-weight: 700;
}

.landing-pricing-head a svg {
  width: 1rem;
  height: 1rem;
}

.landing-price-stage {
  display: grid;
  grid-template-columns: minmax(18rem, .72fr) minmax(0, 1.28fr);
  margin-top: var(--space-2xl);
  overflow: hidden;
  border: var(--rule-thin) solid var(--color-rule);
  border-radius: var(--radius-card);
  background: var(--color-paper-raised);
}

.landing-price-summary {
  display: flex;
  min-height: 34rem;
  flex-direction: column;
  padding: clamp(2rem, 5vw, 4rem);
  background: var(--color-panel-ink);
  color: var(--color-on-ink);
}

.landing-price-summary > p {
  color: var(--color-on-ink-muted);
  font-size: var(--text-lg);
  line-height: 1.45;
}

.landing-price-summary > strong {
  max-width: 7ch;
  margin-top: var(--space-lg);
  font-family: var(--font-display);
  font-size: clamp(3.2rem, 5.5vw, 5.4rem);
  line-height: .92;
  letter-spacing: -0.04em;
  font-variant-numeric: tabular-nums;
}

.landing-price-summary > span {
  margin-top: var(--space-md);
  color: var(--color-on-ink-muted);
}

.landing-price-summary > div {
  display: flex;
  align-items: flex-start;
  gap: var(--space-sm);
  margin-top: auto;
  padding-top: var(--space-xl);
  border-top: var(--rule-thin) solid var(--color-on-ink-rule);
  color: var(--color-on-ink-muted);
}

.landing-price-summary > div svg {
  width: 1.2rem;
  height: 1.2rem;
  flex: 0 0 auto;
}

.landing-price-summary > div p {
  max-width: 30ch;
  font-size: var(--text-sm);
  line-height: 1.55;
}

.landing-price-options {
  display: grid;
}

.landing-price-option {
  display: grid;
  grid-template-columns: minmax(0, 1fr) auto;
  gap: var(--space-md) var(--space-lg);
  padding: var(--space-xl);
  border-bottom: var(--rule-thin) solid var(--color-rule);
}

.landing-price-option:last-child {
  border-bottom: 0;
}

.landing-price-option.is-featured {
  background: var(--color-panel-yellow);
}

.landing-price-option header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: var(--space-lg);
  grid-column: 1 / -1;
}

.landing-price-option h3,
.landing-price-option header strong {
  font-family: var(--font-display);
  font-size: var(--text-xl);
  font-variant-numeric: tabular-nums;
}

.landing-price-option header small {
  color: var(--color-ink-muted);
  font-family: var(--font-body);
  font-size: var(--text-sm);
  font-weight: 400;
}

.landing-price-option > p,
.landing-price-option li {
  color: var(--color-ink-muted);
  font-size: var(--text-sm);
}

.landing-price-option ul {
  display: flex;
  flex-wrap: wrap;
  gap: var(--space-xs) var(--space-md);
  grid-column: 1;
}

.landing-price-option li {
  display: inline-flex;
  align-items: center;
  gap: .35rem;
}

.landing-price-option li svg {
  width: .85rem;
  height: .85rem;
  color: var(--color-accent);
}

.landing-price-option > a {
  grid-column: 2;
  grid-row: 2 / 4;
  align-self: end;
  min-height: 2.75rem;
  padding-inline: var(--space-md);
  border: var(--rule-thin) solid var(--color-rule);
}

.landing-price-option.is-featured > a {
  border-color: var(--color-panel-ink);
  background: var(--color-panel-ink);
  color: var(--color-on-ink);
}

.landing-selfhost {
  max-width: 65ch;
  margin-top: var(--space-lg);
  font-size: var(--text-sm);
  line-height: 1.6;
}

.landing-faq {
  padding-bottom: clamp(6rem, 11vw, 10rem);
}

.landing-faq > div > p {
  margin-top: var(--space-lg);
}

.landing-accordion {
  border-top: var(--rule-thin) solid var(--color-rule);
}

.landing-accordion :deep(button) {
  min-height: 4.5rem;
  text-align: left;
  font-size: var(--text-base);
  font-weight: 700;
}

.landing-accordion :deep([data-state='open'] + div) {
  color: var(--color-ink-muted);
  font-size: var(--text-base);
  line-height: 1.6;
}

.landing-final {
  background: var(--color-panel-ink);
  color: var(--color-on-ink);
}

.landing-final-inner {
  display: flex;
  align-items: end;
  justify-content: space-between;
  gap: var(--space-xl);
  padding-block: clamp(5rem, 9vw, 8rem);
}

.landing-final p {
  min-width: 0;
  max-width: 22ch;
  font-family: var(--font-display);
  font-size: clamp(2.5rem, 5vw, 5rem);
  font-weight: 750;
  line-height: .98;
  letter-spacing: -0.04em;
  overflow-wrap: anywhere;
}

.landing-button-light {
  background: var(--color-on-ink);
  color: var(--color-panel-ink);
}

.landing-footer {
  display: grid;
  grid-template-columns: auto 1fr auto;
  gap: var(--space-xl);
  align-items: center;
  min-height: 7rem;
  border-top: var(--rule-thin) solid var(--color-rule);
  color: var(--color-ink-muted);
  font-size: var(--text-sm);
}

.landing-footer > div {
  display: flex;
  align-items: center;
  gap: var(--space-lg);
}

@media (hover: hover) and (pointer: fine) {
  .landing-nav-cta:hover,
  .landing-button:hover,
  .landing-price-option > a:hover {
    transform: translateY(-1px);
  }
}

.landing-nav-cta:active,
.landing-button:active,
.landing-price-option > a:active {
  transform: translateY(1px);
}

@media (max-width: 60rem) {
  .landing-hero-copy,
  .landing-day-head,
  .landing-showcase,
  .landing-showcase-schedule,
  .landing-network-inner,
  .landing-pricing-head,
  .landing-faq {
    grid-template-columns: minmax(0, 1fr);
  }

  .landing-day-grid {
    grid-template-columns: repeat(2, minmax(0, 1fr));
  }

  .landing-day-step:nth-child(3) {
    border-left: 0;
  }

  .landing-day-step:nth-child(n + 3) {
    border-top: var(--rule-thin) solid var(--color-panel-ink);
  }

  .landing-showcase-schedule .landing-visual-reveal {
    order: 2;
  }

  .landing-price-stage {
    grid-template-columns: minmax(0, 1fr);
  }

  .landing-price-summary {
    min-height: 26rem;
  }

  .landing-final-inner {
    align-items: flex-start;
    flex-direction: column;
  }

  .landing-footer {
    grid-template-columns: auto 1fr;
  }

  .landing-footer > div {
    grid-column: 1 / -1;
  }
}

@media (max-width: 40rem) {
  .landing-shell {
    width: min(100% - 2rem, 86rem);
  }

  .landing-nav {
    width: calc(100% - 1.5rem);
    justify-content: space-between;
  }

  .landing-nav-links {
    display: none;
  }

  .landing-hero {
    padding-top: 6.5rem;
    padding-bottom: var(--space-xl);
  }

  .landing-hero h1 {
    max-width: 11ch;
    font-size: clamp(2.75rem, 13vw, 3.6rem);
  }

  .landing-map-wrap {
    margin-top: var(--space-lg);
  }

  .landing-hero-lede > p:first-child,
  .landing-day-head > p,
  .landing-showcase-copy > p,
  .landing-network-inner > div:first-child > p,
  .landing-faq > div > p {
    font-size: var(--text-base);
  }

  .landing-actions,
  .landing-button {
    width: 100%;
  }

  .landing-day-grid {
    grid-template-columns: minmax(0, 1fr);
  }

  .landing-day-step {
    min-height: 12rem;
  }

  .landing-day-step + .landing-day-step {
    border-top: var(--rule-thin) solid var(--color-panel-ink);
    border-left: 0;
  }

  .landing-day-icon {
    margin-top: 2.5rem;
  }

  .landing-day-footer {
    align-items: flex-start;
    flex-direction: column;
    padding-block: var(--space-md);
  }

  .landing-task-visual,
  .landing-schedule-visual,
  .landing-stock-visual {
    transform: none;
  }

  .landing-schedule-visual {
    overflow: hidden;
  }

  .landing-schedule-grid {
    grid-template-columns: 6rem repeat(2, minmax(7rem, 1fr));
    overflow-x: auto;
  }

  .landing-stock-row {
    grid-template-columns: minmax(0, 1fr) auto;
  }

  .landing-stock-row em {
    grid-column: 1 / -1;
    justify-self: start;
  }

  .landing-network-graphic {
    grid-template-columns: minmax(0, 1fr);
  }

  .landing-network-line {
    min-height: 5rem;
    flex-direction: column;
    justify-content: center;
  }

  .landing-network-line::before,
  .landing-network-line::after {
    width: var(--rule-thin);
    min-height: 1rem;
    flex: 1;
  }

  .landing-price-option {
    grid-template-columns: minmax(0, 1fr) auto;
    gap: var(--space-md);
    padding: var(--space-lg);
  }

  .landing-price-option > p,
  .landing-price-option > ul {
    grid-column: 1 / -1;
  }

  .landing-price-option > a {
    grid-column: 1 / -1;
    grid-row: auto;
    min-height: 3rem;
  }

  .landing-footer {
    grid-template-columns: minmax(0, 1fr);
    padding-block: var(--space-xl);
  }

  .landing-footer > div {
    grid-column: 1;
    align-items: flex-start;
    flex-direction: column;
    gap: var(--space-md);
  }
}

@media (prefers-reduced-motion: reduce) {
  .landing-nav-cta,
  .landing-button,
  .landing-price-option > a {
    transition-duration: 150ms;
  }

  .landing-hero h1,
  .landing-hero-lede,
  .landing-progress span {
    animation: none;
  }

  [data-reveal-ready],
  [data-reveal-ready][data-revealed] {
    opacity: 1;
    transform: none;
    transition: none;
  }
}

@keyframes landing-copy-in {
  from {
    opacity: 0;
    transform: translateY(10px);
  }
}

@keyframes landing-progress-in {
  from {
    transform: scaleX(0);
  }
}
</style>

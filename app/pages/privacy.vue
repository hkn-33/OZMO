<script setup lang="ts">
definePageMeta({ layout: false })
useHead({ title: 'Polityka prywatności — OZMO' })
</script>

<template>
  <div class="min-h-svh bg-[var(--color-paper)] text-[var(--color-ink)]">
    <header class="border-b border-[var(--color-rule)]">
      <div class="mx-auto flex min-h-20 max-w-4xl items-center justify-between gap-4 px-4">
        <NuxtLink to="/" class="font-heading text-2xl font-extrabold tracking-[-0.04em]">ozmo<span class="text-[var(--color-accent)]">.</span></NuxtLink>
        <NuxtLink to="/" class="text-sm font-semibold text-[var(--color-ink-muted)] hover:text-[var(--color-ink)]">Wróć na stronę główną</NuxtLink>
      </div>
    </header>

    <main class="mx-auto max-w-4xl px-4 py-12 sm:py-20">
      <p class="text-sm text-[var(--color-ink-muted)]">Ostatnia aktualizacja: 14 lipca 2026 r.</p>
      <h1 class="mt-3 text-4xl font-bold tracking-tight sm:text-6xl">Polityka prywatności</h1>
      <div class="mt-8 rounded-xl border border-[var(--color-rule)] bg-[var(--color-panel-yellow)] p-4 text-sm leading-6">
        <strong>Dokument roboczy.</strong> Przed uruchomieniem hostowanej usługi trzeba uzupełnić pełną nazwę operatora, adres oraz e-mail do spraw prywatności.
      </div>

      <div class="mt-12 space-y-10 text-[var(--color-ink-muted)] [&_h2]:text-2xl [&_h2]:font-semibold [&_h2]:text-[var(--color-ink)] [&_li]:leading-7 [&_p]:leading-7 [&_section]:space-y-3 [&_ul]:list-disc [&_ul]:space-y-1 [&_ul]:pl-6">
        <section>
          <h2>1. Kto odpowiada za dane</h2>
          <p>W hostowanej wersji OZMO administratorem danych konta, rozliczeń i bezpieczeństwa usługi jest operator OZMO. Jego dane identyfikacyjne zostaną podane przed uruchomieniem usługi produkcyjnej.</p>
          <p>Firma korzystająca z OZMO jest administratorem danych swoich pracowników i danych wprowadzanych w ramach organizacji. Operator OZMO przetwarza te dane na jej polecenie jako podmiot przetwarzający. Przy samodzielnym hostowaniu administratorem jest podmiot, który uruchomił daną instancję.</p>
        </section>

        <section>
          <h2>2. Jakie dane przetwarzamy</h2>
          <ul>
            <li>dane konta: adres e-mail, nazwa użytkownika, imię, numer telefonu i informacje o roli,</li>
            <li>dane organizacji i lokali,</li>
            <li>grafiki, dostępność i informacje o zespole,</li>
            <li>zadania, checklisty, wiadomości, pliki i raporty,</li>
            <li>dane magazynowe, kosztowe i rozliczeniowe wpisane przez użytkowników,</li>
            <li>dane techniczne potrzebne do logowania, bezpieczeństwa i usuwania błędów.</li>
          </ul>
        </section>

        <section>
          <h2>3. Po co i na jakiej podstawie</h2>
          <ul>
            <li>prowadzenie konta i świadczenie usługi — wykonanie umowy,</li>
            <li>obsługa płatności i obowiązków księgowych — obowiązek prawny,</li>
            <li>ochrona kont, zapobieganie nadużyciom i diagnostyka — prawnie uzasadniony interes operatora,</li>
            <li>wiadomości marketingowe — wyłącznie po uzyskaniu zgody.</li>
          </ul>
        </section>

        <section>
          <h2>4. Komu dane mogą być przekazywane</h2>
          <p>Dane mogą otrzymywać dostawcy hostingu aplikacji, bazy danych, poczty, kopii zapasowych i płatności, wyłącznie w zakresie potrzebnym do działania usługi. Aktualna lista dostawców i region przechowywania danych muszą zostać uzupełnione przed uruchomieniem wersji hostowanej.</p>
          <p>Jeżeli dostawca przetwarza dane poza Europejskim Obszarem Gospodarczym, operator musi zastosować podstawę transferu wymaganą przez RODO, na przykład standardowe klauzule umowne.</p>
        </section>

        <section>
          <h2>5. Jak długo przechowujemy dane</h2>
          <p>Dane konta i organizacji są przechowywane przez czas korzystania z usługi. Po usunięciu konta dane są usuwane lub anonimizowane, z wyjątkiem informacji wymaganych przez prawo oraz czasowo przechowywanych w kopiach zapasowych. Dokładne okresy retencji zostaną podane przed uruchomieniem usługi produkcyjnej.</p>
        </section>

        <section>
          <h2>6. Twoje prawa</h2>
          <p>Możesz żądać dostępu do danych, ich poprawienia, usunięcia, ograniczenia przetwarzania, przeniesienia oraz wnieść sprzeciw. Zgodę można wycofać w dowolnym momencie. Możesz też złożyć skargę do Prezesa Urzędu Ochrony Danych Osobowych.</p>
          <p>W sprawach danych pracowniczych najpierw skontaktuj się z firmą, która utworzyła Twoje konto w OZMO.</p>
        </section>

        <section>
          <h2>7. Pliki cookie</h2>
          <p>OZMO używa plików cookie niezbędnych do logowania oraz zapamiętania aktywnej organizacji i lokalu. Obecnie aplikacja nie używa reklamowych ani analitycznych plików cookie. Jeżeli to się zmieni, mechanizm zgody i ta polityka muszą zostać zaktualizowane przed ich włączeniem.</p>
        </section>

        <section>
          <h2>8. Bezpieczeństwo i zmiany</h2>
          <p>Dostęp do danych jest ograniczany na podstawie organizacji, lokalu i roli użytkownika. Stosujemy uwierzytelnianie, szyfrowane połączenia i kontrolę dostępu w bazie danych.</p>
          <p>Istotne zmiany polityki będą komunikowane w aplikacji. Archiwalna data aktualizacji znajduje się na początku dokumentu.</p>
        </section>
      </div>
    </main>
  </div>
</template>

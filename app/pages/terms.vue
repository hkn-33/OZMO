<script setup lang="ts">
definePageMeta({ layout: false })
useHead({ title: 'Warunki korzystania — OZMO' })
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
      <h1 class="mt-3 text-4xl font-bold tracking-tight sm:text-6xl">Warunki korzystania</h1>
      <div class="mt-8 rounded-xl border border-[var(--color-rule)] bg-[var(--color-panel-yellow)] p-4 text-sm leading-6">
        <strong>Dokument roboczy.</strong> Przed sprzedażą usługi trzeba uzupełnić dane operatora, zasady płatności, okres wypowiedzenia i procedurę reklamacji.
      </div>

      <div class="mt-12 space-y-10 text-[var(--color-ink-muted)] [&_h2]:text-2xl [&_h2]:font-semibold [&_h2]:text-[var(--color-ink)] [&_p]:leading-7 [&_section]:space-y-3">
        <section>
          <h2>1. Zakres usługi</h2>
          <p>OZMO służy do organizowania codziennej pracy firmy: zadań, grafików, komunikacji, magazynu, raportów i kosztów. Warunki dotyczą wersji hostowanej. Wersja uruchamiana samodzielnie podlega licencji AGPL-3.0.</p>
        </section>

        <section>
          <h2>2. Konto i organizacja</h2>
          <p>Użytkownik odpowiada za prawidłowe dane konta i ochronę danych logowania. Właściciel organizacji odpowiada za zapraszanie użytkowników, nadawanie im ról oraz zgodność danych pracowników wprowadzanych do systemu z prawem.</p>
        </section>

        <section>
          <h2>3. Dozwolone korzystanie</h2>
          <p>Nie wolno używać OZMO do naruszania prawa, praw innych osób, bezpieczeństwa usługi ani do prób uzyskania dostępu do cudzych danych. Konto może zostać czasowo zablokowane, gdy jest to potrzebne do zatrzymania nadużycia lub zagrożenia.</p>
        </section>

        <section>
          <h2>4. Demo i early access</h2>
          <p>Publiczne demo zawiera przykładowe dane i może być regularnie resetowane. Early access może obejmować funkcje w trakcie zmian. Informacje ważne dla codziennej pracy należy zachować także poza usługą, dopóki produkt pozostaje w tej fazie.</p>
        </section>

        <section>
          <h2>5. Opłaty</h2>
          <p>Ceny widoczne na stronie są cenami miesięcznymi. Płatne rozliczenia nie zostały jeszcze uruchomione. Przed ich włączeniem warunki zostaną uzupełnione o podatki, termin płatności, odnowienie, zmianę planu, wypowiedzenie i zwroty.</p>
        </section>

        <section>
          <h2>6. Dostępność i dane</h2>
          <p>Operator będzie usuwał awarie w rozsądnym czasie, ale na etapie early access nie gwarantuje konkretnego poziomu dostępności. Użytkownik powinien eksportować dane, których utrata mogłaby zatrzymać działalność firmy.</p>
        </section>

        <section>
          <h2>7. Zakończenie korzystania</h2>
          <p>Użytkownik może przestać korzystać z usługi i zażądać usunięcia konta. Zasady eksportu danych, okres przechowywania po zakończeniu umowy i wypowiedzenie zostaną doprecyzowane przed uruchomieniem płatności.</p>
        </section>

        <section>
          <h2>8. Odpowiedzialność i prawo</h2>
          <p>OZMO wspiera zarządzanie pracą, ale nie zastępuje księgowości, systemu fiskalnego, dokumentacji wymaganej przepisami ani profesjonalnej porady. Pełne zasady odpowiedzialności, reklamacji i właściwego prawa zostaną uzupełnione wraz z danymi operatora przed zawarciem pierwszej płatnej umowy.</p>
        </section>
      </div>
    </main>
  </div>
</template>

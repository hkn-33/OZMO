<script setup lang="ts">
import {
  ListChecks,
  MessagesSquare,
  CalendarDays,
  Package,
  FileText,
  Wallet,
  Check,
} from '@lucide/vue'

const features = [
  { icon: ListChecks, title: 'Zadania i checklisty', desc: 'Otwarcia, zamknięcia, Sanepid — z szablonów, z podziałem na osoby.' },
  { icon: MessagesSquare, title: 'Czaty zespołu', desc: 'Kanał sieci i kanały lokali. Koniec z chaosem na WhatsAppie.' },
  { icon: CalendarDays, title: 'Grafik pracy', desc: 'Układaj i publikuj zmiany, zbieraj dostępność, kopiuj tygodnie.' },
  { icon: Package, title: 'Magazyn i stany', desc: 'Przyjęcia, wydania, alerty o niskich stanach — bez Excela.' },
  { icon: FileText, title: 'Raporty dnia', desc: 'Raport pracowniczy i menadżerski z blokadą zamknięcia.' },
  { icon: Wallet, title: 'Kontrola kosztów', desc: 'Food/Beverage/Labor Cost % per lokal i cała sieć.' },
]

const plans = [
  {
    name: 'Starter',
    price: '149',
    highlight: false,
    features: ['Zadania i checklisty', 'Czaty zespołu', 'Raporty dnia'],
  },
  {
    name: 'Pro',
    price: '249',
    highlight: true,
    features: ['Wszystko ze Starter', 'Grafik pracy', 'Raport menadżerski', 'Magazyn i stany'],
  },
  {
    name: 'Sieć',
    price: '399',
    highlight: false,
    features: ['Wszystko z Pro', 'Kontrola kosztów', 'Priorytetowe wsparcie'],
  },
]
</script>

<template>
  <div class="min-h-svh bg-background text-foreground">
    <!-- Nagłówek -->
    <header class="mx-auto flex max-w-6xl items-center justify-between px-6 py-4">
      <span class="text-xl font-bold tracking-tight">OZMO</span>
      <nav class="flex items-center gap-2">
        <NuxtLink to="/auth/login">
          <Button variant="ghost">Zaloguj się</Button>
        </NuxtLink>
        <NuxtLink to="/auth/register">
          <Button>Załóż konto</Button>
        </NuxtLink>
      </nav>
    </header>

    <!-- Hero -->
    <section class="mx-auto max-w-3xl px-6 py-16 text-center sm:py-24">
      <h1 class="text-4xl font-bold tracking-tight sm:text-5xl">
        System operacyjny dla sieci restauracji i hoteli
      </h1>
      <p class="mt-6 text-lg text-muted-foreground">
        OZMO zastępuje Excela, WhatsAppa i papierowe checklisty jednym systemem.
        Zadania, grafik, magazyn, raporty i czaty — wszystko w jednym miejscu,
        na telefonie i na komputerze.
      </p>
      <div class="mt-8 flex flex-wrap justify-center gap-3">
        <NuxtLink to="/auth/register">
          <Button size="lg">Zacznij za darmo</Button>
        </NuxtLink>
        <NuxtLink to="/#pricing">
          <Button size="lg" variant="outline">Zobacz pakiety</Button>
        </NuxtLink>
      </div>
    </section>

    <!-- Funkcje -->
    <section class="mx-auto max-w-6xl px-6 py-12">
      <h2 class="text-center text-2xl font-bold tracking-tight">Wszystko, czego potrzebuje sieć lokali</h2>
      <div class="mt-10 grid gap-6 sm:grid-cols-2 lg:grid-cols-3">
        <Card v-for="f in features" :key="f.title">
          <CardHeader>
            <component :is="f.icon" class="size-6 text-primary" />
            <CardTitle class="mt-2 text-base">{{ f.title }}</CardTitle>
            <CardDescription>{{ f.desc }}</CardDescription>
          </CardHeader>
        </Card>
      </div>
    </section>

    <!-- Cennik -->
    <section id="pricing" class="mx-auto max-w-6xl px-6 py-16">
      <h2 class="text-center text-2xl font-bold tracking-tight">Pakiety</h2>
      <p class="mt-2 text-center text-sm text-muted-foreground">
        Ceny wkrótce — skontaktuj się z nami. Cena za lokal miesięcznie.
      </p>
      <div class="mt-10 grid gap-6 lg:grid-cols-3">
        <Card
          v-for="p in plans"
          :key="p.name"
          :class="p.highlight ? 'border-primary shadow-md' : ''"
        >
          <CardHeader>
            <CardTitle class="flex items-center justify-between">
              {{ p.name }}
              <Badge v-if="p.highlight">Popularny</Badge>
            </CardTitle>
            <CardDescription>
              <span class="text-3xl font-bold text-foreground">{{ p.price }} zł</span>
              / mc za lokal
            </CardDescription>
          </CardHeader>
          <CardContent>
            <ul class="space-y-2 text-sm">
              <li v-for="feat in p.features" :key="feat" class="flex items-start gap-2">
                <Check class="mt-0.5 size-4 shrink-0 text-primary" />
                <span>{{ feat }}</span>
              </li>
            </ul>
          </CardContent>
          <CardFooter>
            <NuxtLink to="/auth/register" class="w-full">
              <Button class="w-full" :variant="p.highlight ? 'default' : 'outline'">
                Wybierz {{ p.name }}
              </Button>
            </NuxtLink>
          </CardFooter>
        </Card>
      </div>
    </section>

    <!-- Stopka -->
    <footer class="border-t">
      <div class="mx-auto flex max-w-6xl flex-col items-center justify-between gap-2 px-6 py-8 text-sm text-muted-foreground sm:flex-row">
        <span class="font-semibold text-foreground">OZMO</span>
        <span>© {{ new Date().getFullYear() }} OZMO. System operacyjny dla sieci lokali.</span>
        <NuxtLink to="/auth/login" class="hover:underline">Zaloguj się</NuxtLink>
      </div>
    </footer>
  </div>
</template>

# Kontrakt tokenów designu 2026 — WIĄŻĄCY dla wszystkich agentów UI

Kierunek: „Slate & Cobalt" (research 2026-07-09; wzorce: Linear/Attio/Vercel). Jasny motyw domyślny. Cienkie ramki 1px zamiast cieni. Jeden akcent. Wybór użytkownika: kobalt.

```css
/* :root (light) */
--background:        oklch(98.5% 0.002 247.8);  /* canvas: gray-50, chłodny */
--card:              oklch(100% 0 0);            /* powierzchnia: biel */
--border:            oklch(92.8% 0.006 264.5);  /* gray-200, hairline wszędzie */
--foreground:        oklch(21% 0.034 264.7);    /* gray-900 */
--muted-foreground:  oklch(55.4% 0.046 257.4);  /* slate-500 */
--primary:           oklch(54.6% 0.245 262.9);  /* kobalt blue-600 — JEDYNY akcent */
/* .dark: canvas oklch(20% .02 260), card oklch(23% .02 260), border oklch(30% .02 260) — nigdy #000 */

/* skala kategoryczna (grafik: role/typy zmian; Wong colorblind-safe) */
--cat-1: #0072B2;  /* niebieski */
--cat-2: #E69F00;  /* pomarańczowy */
--cat-3: #009E73;  /* morski */
--cat-4: #CC79A7;  /* różowo-fioletowy */
--cat-5: #D55E00;  /* cynober — ostatni w kolejności użycia */
```

Zasady:
- Semantyczne statusy (success/warning/info/destructive z fazy 8) zostają — dostroić do chłodnej szarości (bez ciepłych tint w cieniach/tłach).
- Cienie: brak na kartach/panelach; delikatny cień tylko dropdown/modal/toast.
- Radius: baza 0.5rem (przyciski/inputy 6px, karty 8-12px, badge pill).
- Fonty: Inter (body/UI) + Inter Display lub cięższy weight na nagłówki — JEDNA rodzina, self-hosted (@fontsource). Usunąć Bricolage Grotesque i Figtree.
- Terakota/beż z fazy 8: usunąć całkowicie (tokeny, theme_color PWA → kobalt).
- Grafik: kolor = rola/typ zmiany (cat-1..5, przypisanie stabilne per stanowisko w oddziale); szkic = opacity ~60% + dashed border 1px + plakietka „Szkic"; urlop/niedostępność = zarezerwowany szary wzór (nigdy z palety kategorycznej).
- Kolor NIGDY nie niesie dwóch znaczeń naraz (rola ≠ status ≠ dekoracja).
- Kontrast: WCAG AA dla tekstu i badge — policzyć przy zmianach.
- Mobile: bottom nav max 5 pozycji, tap targety ≥44px, jawny przycisk „wstecz" w widokach szczegółów (PWA bez systemowego back).
- Ton: spokojny, profesjonalny — zero maskotek/konfetti; puste stany = jedna akcja + jedno zdanie.

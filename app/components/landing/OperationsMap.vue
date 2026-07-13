<template>
  <figure class="operations-map" aria-labelledby="operations-map-title">
    <figcaption id="operations-map-title" class="sr-only">
      OZMO łączy zadania, grafik, zespół, magazyn, raporty i koszty dla wszystkich lokali.
    </figcaption>

    <svg class="operations-map-desktop" viewBox="0 0 1200 620" role="img" aria-hidden="true">
      <g class="map-lines" fill="none" stroke="var(--color-panel-rule)" stroke-width="2">
        <path d="M300 145 C430 145 436 260 540 292" />
        <path d="M600 100 C600 190 600 210 600 255" />
        <path d="M900 145 C770 145 764 260 660 292" />
        <path d="M300 475 C430 475 436 360 540 328" />
        <path d="M600 520 C600 430 600 410 600 365" />
        <path d="M900 475 C770 475 764 360 660 328" />
      </g>
      <g class="map-signals" fill="var(--color-accent)">
        <circle r="5">
          <animateMotion dur="3.8s" repeatCount="indefinite" path="M300 145 C430 145 436 260 540 292" />
        </circle>
        <circle r="5">
          <animateMotion begin="-1.4s" dur="4.2s" repeatCount="indefinite" path="M900 145 C770 145 764 260 660 292" />
        </circle>
        <circle r="5">
          <animateMotion begin="-.8s" dur="3.6s" repeatCount="indefinite" path="M300 475 C430 475 436 360 540 328" />
        </circle>
        <circle r="5">
          <animateMotion begin="-2.1s" dur="4s" repeatCount="indefinite" path="M900 475 C770 475 764 360 660 328" />
        </circle>
      </g>

      <g class="map-node" style="--delay: 80ms" transform="translate(90 70)">
        <rect width="250" height="150" rx="18" fill="var(--color-panel-pink)" />
        <text x="22" y="34" class="map-label">Zadania</text>
        <g transform="translate(22 58)">
          <rect width="18" height="18" rx="5" fill="var(--color-panel-ink)" />
          <path d="m5 9 3 3 6-7" fill="none" stroke="var(--color-on-ink)" stroke-width="2" />
          <rect x="30" y="2" width="145" height="7" rx="3.5" fill="var(--color-panel-ink)" opacity=".75" />
          <rect x="30" y="15" width="96" height="6" rx="3" fill="var(--color-panel-ink)" opacity=".22" />
          <rect y="40" width="18" height="18" rx="5" fill="none" stroke="var(--color-panel-ink)" stroke-width="2" />
          <rect x="30" y="42" width="168" height="7" rx="3.5" fill="var(--color-panel-ink)" opacity=".75" />
          <rect x="30" y="55" width="118" height="6" rx="3" fill="var(--color-panel-ink)" opacity=".22" />
        </g>
      </g>

      <g class="map-node" style="--delay: 140ms" transform="translate(475 30)">
        <rect width="250" height="145" rx="18" fill="var(--color-panel-yellow)" />
        <text x="22" y="34" class="map-label">Grafik</text>
        <g transform="translate(22 58)" fill="var(--color-panel-ink)">
          <rect width="206" height="52" rx="8" opacity=".08" />
          <rect x="12" y="12" width="44" height="9" rx="4.5" opacity=".28" />
          <rect x="64" y="12" width="58" height="9" rx="4.5" opacity=".7" />
          <rect x="130" y="12" width="64" height="9" rx="4.5" opacity=".28" />
          <rect x="12" y="31" width="72" height="9" rx="4.5" opacity=".7" />
          <rect x="92" y="31" width="102" height="9" rx="4.5" opacity=".28" />
        </g>
      </g>

      <g class="map-node" style="--delay: 200ms" transform="translate(860 70)">
        <rect width="250" height="150" rx="18" fill="var(--color-panel-blue)" />
        <text x="22" y="34" class="map-label">Zespół</text>
        <g transform="translate(22 58)">
          <circle cx="36" cy="32" r="27" fill="var(--color-panel-ink)" opacity=".9" />
          <circle cx="102" cy="32" r="27" fill="var(--color-panel-ink)" opacity=".65" />
          <circle cx="168" cy="32" r="27" fill="var(--color-panel-ink)" opacity=".4" />
          <circle cx="53" cy="52" r="7" fill="var(--color-panel-green)" stroke="var(--color-panel-blue)" stroke-width="4" />
          <circle cx="119" cy="52" r="7" fill="var(--color-panel-green)" stroke="var(--color-panel-blue)" stroke-width="4" />
        </g>
      </g>

      <g class="map-node" style="--delay: 260ms" transform="translate(90 400)">
        <rect width="250" height="150" rx="18" fill="var(--color-panel-green)" />
        <text x="22" y="34" class="map-label">Magazyn</text>
        <g transform="translate(22 60)" fill="none" stroke="var(--color-panel-ink)" stroke-width="5">
          <path d="M3 13h200M3 54h200" opacity=".2" />
          <path d="M18 10v48M188 10v48" />
          <rect x="38" width="34" height="31" rx="4" fill="var(--color-panel-ink)" stroke="none" opacity=".8" />
          <rect x="82" y="10" width="45" height="21" rx="4" fill="var(--color-panel-ink)" stroke="none" opacity=".35" />
          <rect x="137" y="35" width="34" height="21" rx="4" fill="var(--color-panel-ink)" stroke="none" opacity=".65" />
        </g>
      </g>

      <g class="map-node" style="--delay: 320ms" transform="translate(475 445)">
        <rect width="250" height="145" rx="18" fill="var(--color-panel-pink)" />
        <text x="22" y="34" class="map-label">Raport dnia</text>
        <g transform="translate(22 62)" fill="none" stroke="var(--color-panel-ink)" stroke-width="5" stroke-linecap="round">
          <path d="M4 48 44 30 78 38 118 12 156 22 202 2" />
          <circle cx="202" cy="2" r="7" fill="var(--color-panel-ink)" stroke="none" />
        </g>
      </g>

      <g class="map-node" style="--delay: 380ms" transform="translate(860 400)">
        <rect width="250" height="150" rx="18" fill="var(--color-panel-yellow)" />
        <text x="22" y="34" class="map-label">Koszty</text>
        <g transform="translate(22 57)" fill="var(--color-panel-ink)">
          <rect width="130" height="10" rx="5" opacity=".18" />
          <rect y="22" width="196" height="10" rx="5" opacity=".18" />
          <rect y="44" width="168" height="10" rx="5" opacity=".18" />
          <text x="155" y="15" class="map-value">24%</text>
        </g>
      </g>

      <g class="map-hub" transform="translate(480 225)">
        <rect width="240" height="170" rx="85" fill="var(--color-panel-ink)" />
        <text x="120" y="102" text-anchor="middle" class="map-brand">ozmo<tspan class="map-brand-dot">.</tspan></text>
      </g>
    </svg>

    <svg class="operations-map-mobile" viewBox="0 0 360 760" role="img" aria-hidden="true">
      <path class="map-mobile-line" d="M180 98V662" fill="none" stroke="var(--color-panel-rule)" stroke-width="2" />
      <circle class="map-signals" r="5" fill="var(--color-accent)">
        <animateMotion dur="5s" repeatCount="indefinite" path="M180 98V662" />
      </circle>
      <g class="map-hub" transform="translate(70 20)">
        <rect width="220" height="110" rx="55" fill="var(--color-panel-ink)" />
        <text x="110" y="69" text-anchor="middle" class="map-brand">ozmo<tspan class="map-brand-dot">.</tspan></text>
      </g>
      <g v-for="(node, index) in mobileNodes" :key="node.label" class="map-node" :style="{ '--delay': `${80 + index * 60}ms` }" :transform="`translate(${index % 2 ? 86 : 18} ${154 + index * 96})`">
        <rect width="256" height="74" rx="16" :fill="node.color" />
        <text x="18" y="31" class="map-label">{{ node.label }}</text>
        <text x="18" y="53" class="map-caption-dark">{{ node.detail }}</text>
        <circle cx="229" cy="37" r="14" fill="var(--color-panel-ink)" opacity=".12" />
        <path d="m223 37 4 4 8-9" fill="none" stroke="var(--color-panel-ink)" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round" />
      </g>
    </svg>
  </figure>
</template>

<script setup lang="ts">
const mobileNodes = [
  { label: 'Zadania', detail: 'checklisty i odpowiedzialność', color: 'var(--color-panel-pink)' },
  { label: 'Grafik', detail: 'zmiany całego zespołu', color: 'var(--color-panel-yellow)' },
  { label: 'Czaty', detail: 'ustalenia przy pracy', color: 'var(--color-panel-blue)' },
  { label: 'Magazyn', detail: 'stany każdego lokalu', color: 'var(--color-panel-green)' },
  { label: 'Raporty', detail: 'zamknięcie dnia', color: 'var(--color-panel-pink)' },
  { label: 'Koszty', detail: 'wynik całej sieci', color: 'var(--color-panel-yellow)' },
]
</script>

<style scoped>
.operations-map {
  margin: 0;
}

.operations-map-desktop {
  display: block;
  width: 100%;
  height: auto;
}

.operations-map-mobile {
  display: none;
  width: 100%;
  height: auto;
}

.map-label,
.map-value,
.map-brand {
  fill: var(--color-panel-ink);
  font-family: var(--font-display);
  font-weight: 700;
}

.map-label {
  font-size: 20px;
}

.map-value {
  font-size: 23px;
}

.map-brand {
  fill: var(--color-on-ink);
  font-size: 40px;
  letter-spacing: -1.6px;
}

.map-brand-dot {
  fill: var(--color-accent);
}

.map-caption-dark {
  font-family: var(--font-body);
  font-size: 13px;
}

.map-caption-dark {
  fill: var(--color-panel-ink);
  opacity: .62;
}

.map-node,
.map-hub {
  animation: map-node-in 650ms var(--ease-out) both;
  animation-delay: var(--delay, 0ms);
}

.map-hub {
  animation-delay: 0ms;
}

.map-lines path {
  stroke-dasharray: 360;
  stroke-dashoffset: 360;
  animation: map-line-draw 900ms var(--ease-out) 180ms forwards;
}

.map-signals {
  filter: drop-shadow(0 0 5px color-mix(in srgb, var(--color-accent) 55%, transparent));
}

.map-hub .map-brand {
  transform-box: fill-box;
  transform-origin: center;
  animation: map-logo-in 650ms var(--ease-out) 300ms both;
}

@keyframes map-node-in {
  from {
    opacity: 0;
  }
}

@keyframes map-line-draw {
  to {
    stroke-dashoffset: 0;
  }
}

@keyframes map-logo-in {
  from {
    opacity: 0;
    transform: scale(.82);
  }
}

@media (max-width: 40rem) {
  .operations-map-desktop {
    display: none;
  }

  .operations-map-mobile {
    display: block;
  }
}

@media (prefers-reduced-motion: reduce) {
  .map-node,
  .map-hub,
  .map-hub .map-brand,
  .map-lines path {
    animation: none;
  }

  .map-lines path {
    stroke-dashoffset: 0;
  }

  .map-signals {
    display: none;
  }
}
</style>

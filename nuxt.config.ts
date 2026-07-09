// https://nuxt.com/docs/api/configuration/nuxt-config
import tailwindcss from '@tailwindcss/vite'

export default defineNuxtConfig({
  compatibilityDate: '2025-07-15',
  devtools: { enabled: true },
  css: ['~/assets/css/tailwind.css'],

  vite: {
    plugins: [tailwindcss()],
  },

  modules: ['shadcn-nuxt', '@nuxtjs/supabase', '@vite-pwa/nuxt'],

  shadcn: {
    prefix: '',
    componentDir: '@/components/ui',
  },

  pwa: {
    registerType: 'autoUpdate',
    manifest: {
      name: 'OZMO — system operacyjny dla sieci lokali',
      short_name: 'OZMO',
      description:
        'System operacyjny dla sieci lokali: zadania, grafik, magazyn, raporty i czaty w jednym miejscu.',
      lang: 'pl',
      theme_color: '#262626',
      background_color: '#ffffff',
      display: 'standalone',
      start_url: '/',
      scope: '/',
      icons: [
        { src: '/pwa-192x192.png', sizes: '192x192', type: 'image/png' },
        { src: '/pwa-512x512.png', sizes: '512x512', type: 'image/png' },
        {
          src: '/maskable-512x512.png',
          sizes: '512x512',
          type: 'image/png',
          purpose: 'maskable',
        },
      ],
    },
    workbox: {
      // Precache built static assets only.
      globPatterns: ['**/*.{js,css,html,ico,png,svg,woff,woff2}'],
      navigateFallback: undefined,
      runtimeCaching: [
        {
          // Supabase (REST/Auth/Realtime/Storage) — never cache; always hit network.
          urlPattern: ({ url }) =>
            url.hostname.includes('supabase') ||
            /127\.0\.0\.1:54321|localhost:54321/.test(url.host),
          handler: 'NetworkOnly',
        },
      ],
    },
    client: {
      installPrompt: false,
    },
    devOptions: {
      // Keep SW disabled in dev to avoid caching surprises during development.
      enabled: false,
    },
  },

  supabase: {
    redirectOptions: {
      login: '/auth/login',
      callback: '/auth/confirm',
      exclude: ['/auth/*'],
    },
    types: '~~/shared/types/database.types.ts',
  },
})
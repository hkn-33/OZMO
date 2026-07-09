<script setup lang="ts">
import { FileText, Download } from '@lucide/vue'
import { useAttachments, type Attachment } from '~/composables/useAttachments'

const props = defineProps<{ attachments?: Attachment[] | null }>()
const { signedUrl, isImage, formatSize } = useAttachments()

const urls = ref<Record<string, string>>({})

watch(
  () => props.attachments,
  async (atts) => {
    for (const a of atts ?? []) {
      if (!urls.value[a.path]) {
        const u = await signedUrl(a.path)
        if (u) urls.value = { ...urls.value, [a.path]: u }
      }
    }
  },
  { immediate: true, deep: true },
)
</script>

<template>
  <div v-if="attachments?.length" class="mt-1.5 flex flex-wrap gap-2">
    <template v-for="a in attachments" :key="a.path">
      <a
        v-if="isImage(a)"
        :href="urls[a.path]"
        target="_blank"
        rel="noopener"
        class="block"
      >
        <img
          v-if="urls[a.path]"
          :src="urls[a.path]"
          :alt="a.name"
          class="max-h-40 max-w-[12rem] rounded-md border object-cover"
        />
        <span v-else class="inline-block h-24 w-32 animate-pulse rounded-md border bg-muted" />
      </a>
      <a
        v-else
        :href="urls[a.path]"
        target="_blank"
        rel="noopener"
        download
        class="inline-flex max-w-[14rem] items-center gap-1.5 rounded-md border bg-card px-2.5 py-1.5 text-xs hover:bg-accent"
      >
        <FileText class="size-4 shrink-0 text-muted-foreground" />
        <span class="min-w-0 flex-1 truncate">{{ a.name }}</span>
        <span class="shrink-0 text-muted-foreground">{{ formatSize(a.size) }}</span>
        <Download class="size-3.5 shrink-0 text-muted-foreground" />
      </a>
    </template>
  </div>
</template>

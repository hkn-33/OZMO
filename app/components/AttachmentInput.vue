<script setup lang="ts">
import { Paperclip, X, Loader2 } from '@lucide/vue'
import { useAttachments, type Attachment } from '~/composables/useAttachments'

const props = defineProps<{
  orgId: string
  branchId?: string | null
  context: string
  disabled?: boolean
}>()

const model = defineModel<Attachment[]>({ default: () => [] })

const { upload, remove, formatSize } = useAttachments()
const input = ref<HTMLInputElement | null>(null)
const uploading = ref(0)

const ACCEPT =
  'image/png,image/jpeg,image/gif,image/webp,application/pdf,.doc,.docx,.xls,.xlsx,.txt,.csv'

function pick() {
  input.value?.click()
}

async function onChange(e: Event) {
  const files = (e.target as HTMLInputElement).files
  if (!files) return
  for (const file of Array.from(files)) {
    uploading.value++
    const att = await upload(file, {
      orgId: props.orgId,
      branchId: props.branchId ?? null,
      context: props.context,
    })
    uploading.value--
    if (att) model.value = [...model.value, att]
  }
  if (input.value) input.value.value = ''
}

async function removeAt(i: number) {
  const a = model.value[i]
  if (a) await remove(a.path)
  model.value = model.value.filter((_, idx) => idx !== i)
}
</script>

<template>
  <div class="space-y-1.5">
    <input
      ref="input"
      type="file"
      multiple
      :accept="ACCEPT"
      class="hidden"
      @change="onChange"
    />
    <div v-if="model.length || uploading" class="flex flex-wrap gap-1.5">
      <span
        v-for="(a, i) in model"
        :key="a.path"
        class="inline-flex max-w-[12rem] items-center gap-1 rounded-md border bg-muted px-2 py-1 text-xs"
      >
        <span class="truncate">{{ a.name }}</span>
        <span class="shrink-0 text-muted-foreground">{{ formatSize(a.size) }}</span>
        <button
          type="button"
          class="shrink-0 opacity-60 hover:opacity-100"
          @click="removeAt(i)"
        >
          <X class="size-3" />
        </button>
      </span>
      <span
        v-for="n in uploading"
        :key="`u${n}`"
        class="inline-flex items-center gap-1 rounded-md border px-2 py-1 text-xs text-muted-foreground"
      >
        <Loader2 class="size-3 animate-spin" /> Wysyłanie…
      </span>
    </div>
    <Button
      type="button"
      variant="ghost"
      size="sm"
      class="h-7 gap-1 px-2 text-xs text-muted-foreground"
      :disabled="disabled"
      @click="pick"
    >
      <Paperclip class="size-3.5" /> Załącznik
    </Button>
  </div>
</template>

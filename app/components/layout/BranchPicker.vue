<script setup lang="ts">
import { Building2, ChevronsUpDown, Check } from '@lucide/vue'

const { branches, activeBranch, activeBranchId, setActive, load } = useBranch()
const { activeOrgId } = useOrg()

onMounted(() => load(!branches.value.length))
watch(activeOrgId, () => load(true))
</script>

<template>
  <DropdownMenu v-if="branches.length > 1">
    <DropdownMenuTrigger as-child>
      <Button variant="outline" size="sm" class="max-w-[12rem] gap-2">
        <Building2 class="size-4 shrink-0" />
        <span class="truncate">{{ activeBranch?.name ?? 'Wybierz oddział' }}</span>
        <ChevronsUpDown class="size-4 shrink-0 opacity-60" />
      </Button>
    </DropdownMenuTrigger>
    <DropdownMenuContent align="start" class="w-56">
      <DropdownMenuLabel class="text-xs text-muted-foreground">Oddział</DropdownMenuLabel>
      <DropdownMenuItem
        v-for="b in branches"
        :key="b.id"
        @select="setActive(b.id)"
      >
        <Check
          class="mr-2 size-4"
          :class="b.id === activeBranchId ? 'opacity-100' : 'opacity-0'"
        />
        <span class="truncate">{{ b.name }}</span>
      </DropdownMenuItem>
    </DropdownMenuContent>
  </DropdownMenu>
  <div
    v-else-if="activeBranch"
    class="inline-flex min-h-9 max-w-[12rem] items-center gap-2 px-1 text-sm font-medium text-muted-foreground"
  >
    <Building2 class="size-4 shrink-0" />
    <span class="truncate">{{ activeBranch.name }}</span>
  </div>
</template>

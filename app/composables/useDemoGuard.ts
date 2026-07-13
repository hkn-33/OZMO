/**
 * Bramka trybu demo. `guard(fn)` uruchamia akcję w pełnej wersji, a w organizacji
 * demo otwiera wspólny `UpgradeModal` zamiast wykonać mutację.
 * Stan modalu współdzielony przez `useState`, sam modal renderowany raz w layoucie.
 */
export function useDemoGuard() {
  const { isDemo, load } = useSubscription()
  const upgradeOpen = useState<boolean>('demo.upgradeOpen', () => false)

  function block() {
    if (!isDemo.value) return false
    upgradeOpen.value = true
    return true
  }

  function guard<T>(fn: () => T): T | void {
    if (block()) return
    return fn()
  }

  return { block, guard, isDemo, upgradeOpen, load }
}

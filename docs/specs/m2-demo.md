# M2 Demo Script — Vault Manager UI (P1-11)

Demonstrates the M2 milestone centerpiece (PRD FR-2.1–2.5): create a
2-person family with relationships, passport + address history, and a
custom field, entirely against `VaultAPI.FakeVaultClient` — no real
`Vault.xpc`/`VaultStore` wiring exists yet (that's `VaultManagerUI`'s
declared "fake first, then real service" scope; App-level composition-root
wiring of a real `TicketIssuing`/`VaultUnlocking` is `[INTEGRATION]`
follow-up, see `Packages/VaultManagerUI/CLAUDE.md`).

## Harness

`VaultWindowView` takes its dependencies as constructor arguments — there is
no App entry point yet, so exercise it via a throwaway SwiftUI preview/host
inside `Packages/VaultManagerUI` wired like this:

```swift
let client = FakeVaultClient()
let clock = InMemoryAuthFreshnessClock()
VaultWindowView(
    unlock: VaultUnlockViewModel(
        client: client,
        unlocker: FakeVaultUnlocker(client: client, authFreshnessClock: clock),
        recoveryCodeProvider: FakeRecoveryCodeProvider()
    ),
    profiles: ProfileListViewModel(client: client, tickets: FakeTicketIssuer(authFreshnessClock: clock)),
    detailViewModel: { personID in
        ProfileDetailViewModel(personID: personID, client: client, tickets: FakeTicketIssuer(authFreshnessClock: clock))
    }
)
```

## Demo steps (target: ≤ 5 minutes, no documentation needed by the user)

1. **Unlock.** Window opens locked (`UnlockView`); click "Unlock with Touch
   ID" (a no-op success in the fake harness — real biometry is
   `Vault.xpc`'s job).
2. **Create two people.** In the sidebar, add "Priya Shah" (kind: Person)
   and "Sam Shah" (kind: Person).
3. **Link them.** Once both exist, the "Add Relationship" row appears; set
   From = Priya, To = Sam, kind = spouse, click Link.
4. **Add a passport (sensitive).** Select Priya, scroll to "Add Field":
   section `identity`, path suffix `passport.number`, kind `string`,
   sensitivity `sensitive`, value `X1234567`. It appears under Identity,
   masked (`••••••••`) immediately — writing a sensitive field itself needs
   fresh auth, same as reading one (`PolicyRules` row 3 doesn't distinguish
   operation), which the harness's just-completed unlock already satisfies.
5. **Reveal it.** Click "Reveal" next to the passport field — plaintext
   appears; a `RevealAuditLog` entry is emitted (section + sensitivity only,
   never the value — verify via Console.app filtering
   `subsystem:com.vaultform.app category:VaultManagerUI.reveal`).
6. **Copy it.** Click "Copy" — pasteboard receives the value via the
   transient/concealed convention with a 30s auto-clear (CLAUDE.md §7.4).
7. **Add address history.** Scroll to the "Address" history section, set a
   start date, leave "Ongoing" checked, click Add. Add a second, earlier,
   non-overlapping range — no warning. Add a third range that overlaps the
   first — the ⚠️ overlap warning appears (advisory only, not a block).
8. **Add a custom field.** In "Add Field", set section `custom`, path suffix
   `notes`, kind `string`, sensitivity `standard`, value "Prefers email
   contact." It appears immediately, unmasked (`custom.notes`).
9. **Lock.** Click the toolbar "Lock" button (or wait out the idle timeout)
   — the window falls back to `UnlockView`, and every field re-masks on next
   unlock (no revealed value persists across a lock cycle).

## Out of scope for this script

- Recovery-code one-time reveal ceremony (`RecoveryCodeRevealView`) — wired
  and unit-tested (`VaultUnlockViewModelTests`), but nothing in step 1–9
  triggers it; a real onboarding flow decides when to call
  `revealRecoveryCodeOnce()`, which is App-composition-root scope.
- Screenshot exclusion (`NSWindow.sharingType = .none`) — a property of the
  hosting `NSWindow`, set by whoever creates that window; not exercisable
  from a SwiftUI preview harness.

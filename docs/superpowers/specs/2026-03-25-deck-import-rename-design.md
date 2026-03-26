# Deck Import Rename Design

**Goal**

When importing a deck from the deck manager, if the imported deck name matches an existing saved deck name, force the player to enter a new unique name before the deck can be saved.

**Current Context**

- Deck import is initiated and completed in `scenes/deck_manager/DeckManager.gd`.
- `DeckImporter` only fetches and assembles `DeckData`; it does not persist decks.
- `CardDatabase.save_deck(deck)` persists the deck immediately and does not currently validate duplicate names.

**Chosen Approach**

Handle duplicate-name resolution in `DeckManager` after import completes and before calling `CardDatabase.save_deck(deck)`.

This keeps persistence logic simple and localizes the new UX to the screen that owns deck import.

**Behavior**

1. Import finishes normally.
2. If the imported `deck.deck_name` is unique, save immediately.
3. If the name conflicts with an existing deck name, show a modal rename dialog.
4. The dialog has no cancel path.
5. The confirm action stays disabled until the entered name:
   - is not empty after trimming
   - is different from every existing deck name
6. Once confirmed, update `deck.deck_name` and continue the existing save/success flow.

**UI Design**

- Reuse the deck manager screen.
- Build the rename dialog dynamically in `DeckManager.gd` to avoid a broad `.tscn` change.
- Dialog contents:
  - title: duplicate-name warning
  - message: explain that a new name is required
  - `LineEdit` prefilled with the imported name
  - inline validation label
  - confirm button only
- The dialog should not be dismissible via cancel or close affordances.

**Validation Rules**

- Exact-name match against existing saved deck names.
- Ignore leading and trailing whitespace when validating and saving the new name.
- Imported deck ID is not treated as a conflict exemption; only the name matters for this flow.

**Testing**

- Add tests for:
  - duplicate detection helper behavior
  - validation of empty and duplicate names
  - import completion saving immediately when name is unique
  - import completion pausing for rename when name conflicts
  - rename confirmation saving under the new unique name

**Risks**

- Tests that persist decks must clean up after themselves.
- UI tests should avoid network and focus on post-import behavior only.

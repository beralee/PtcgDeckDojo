# VS_AI Opponent Hand View Design

**Goal**

Add a debug-only battle UI action so the player can inspect the AI opponent's current hand during `VS_AI` matches.

**Current Context**

- The top bar already hosts debug/utility actions such as `宙斯帮我`.
- `BattleScene.gd` already contains a reusable read-only card gallery overlay for discard, deck, and prize viewing.
- The user only wants this feature in `VS_AI`, not in local two-player mode.

**Chosen Approach**

Reuse the existing read-only gallery overlay and add a new top-bar button labeled `对手手牌`.

This keeps the feature UI-only, avoids introducing another overlay system, and matches the user's goal of quickly checking whether the AI is making good decisions.

**Behavior**

1. Add a new button `对手手牌` immediately to the left of `宙斯帮我`.
2. Show the button only when `GameManager.current_mode == GameManager.GameMode.VS_AI`.
3. Clicking the button opens a read-only thumbnail gallery of the opponent's current hand.
4. The gallery title uses `对手手牌（N 张）`.
5. Cards in the gallery may open detail view, but cannot be selected for gameplay.
6. No game rules, AI rules, or hand ownership logic changes.

**Testing**

- Add UI tests for:
  - button exists in `BattleScene`
  - button is hidden outside `VS_AI`
  - button is visible in `VS_AI`
  - opening the viewer renders the expected number of opponent hand card previews

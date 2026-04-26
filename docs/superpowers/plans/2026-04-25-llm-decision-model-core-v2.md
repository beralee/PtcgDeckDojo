# LLM Decision Model Core v2

Date: 2026-04-25
Status: design baseline

## Why This Exists

The first LLM tree runtime solved latency by calling the LLM once per turn, but its model was still too shallow:

- The LLM knew generic actions like `play_trainer` and `attack`.
- The rules executor knew only a small set of `fact` conditions.
- The model did not explicitly represent the follow-up choices created by real card effects.

That is not enough for strong play. A correct model must understand the actual deck cards, the effect implementation, and the board consequences.

This document defines the next standard decision model using two decks as anchors:

- Charizard Pidgeot, deck `575716`
- Raging Bolt Ogerpon, deck `575718`
- Gardevoir, deck `578647`
- Miraidon, deck `575720`

These two decks cover the important shape of decisions:

- Stage 2 evolution planning
- Rare Candy jump evolution
- on-evolve energy assignment
- once-per-turn universal search
- self-KO damage-counter placement
- search/discard trainer chains
- energy routing and attack-cost math
- attack selection with post-attack costs
- gust/switch/retreat target choice
- recursive energy acceleration with self-damage
- fast Basic bench setup and top-deck energy acceleration

## Core Principle

The LLM does not output illegal executable operations. It outputs a structured strategic tree. The rules layer owns legality, candidate enumeration, and exact execution.

The LLM tree should answer:

- What line am I trying to complete?
- Which card effect should I use if available?
- Which target should that effect prefer?
- What should I do if the search/draw/evolution result changes the state?

The rules executor should answer:

- Is this action currently legal?
- Which concrete `CardInstance` or `PokemonSlot` matches the intent?
- Which branch conditions are true now?
- Which interaction candidates are legal for this step?

## Real Card Coverage: Charizard Pidgeot

Deck cards with high strategic impact:

- `Charizard ex` / `喷火龙ex`: Stage 2 attacker. On evolve, `Infernal Reign` attaches up to 3 Basic Fire Energy from deck to own Pokemon. Attack `Burning Darkness` costs `RR`, damage `180 + 30 * opponent_prizes_taken`.
- `Pidgeot ex` / `大比鸟ex`: Stage 2 engine. Ability `Quick Search` once per turn, shared per player, searches any 1 card from deck to hand.
- `Dusknoir` / `黑夜魔灵`: Stage 2 utility. Ability self-KOs and places 13 damage counters on one opponent Pokemon.
- `Dusclops` / `彷徨夜灵`: Stage 1 utility. Ability self-KOs and places 5 damage counters on one opponent Pokemon.
- `Rare Candy` / `神奇糖果`: Item. Select Stage 2 from hand and a valid Basic target. Cannot be first turn or on a just-played Basic.
- `Arven` / `派帕`: Supporter. Search 1 Item and 1 Tool.
- `Buddy-Buddy Poffin` / `友好宝芬`: Item. Search up to 2 low-HP Basics to bench.
- `Ultra Ball` / `高级球`: Item. Discard cost, search Pokemon.
- `Nest Ball` / `巢穴球`: Item. Search Basic Pokemon to bench.
- `Forest Seal Stone` / `森林封印石`: Tool. VSTAR search ability when attached to V Pokemon.
- `Lumineon V` / `霓虹鱼V`: Bench-enter ability to search a Supporter.
- `Rotom V` / `洛托姆V`: End-turn draw engine, also enables Forest Seal Stone.
- `Counter Catcher` / `反击捕捉器`, `Boss's Orders` / `老大的指令`: gust target selection.
- `Collapsed Stadium` / `崩塌的竞技场`: stadium with bench-size consequences.

Charizard-specific model requirements:

- Represent an evolution line as a planned object, not only individual cards.
- Know whether a Stage 2 is reachable by normal evolution or Rare Candy.
- Model `Rare Candy` as an action with two required interaction intents: `stage2_card` and `target_pokemon`.
- Model `Infernal Reign` as an on-evolve triggered ability with assignment intents: source Fire Energy from deck to target Pokemon slots.
- Model `Quick Search` as a shared once-per-turn search intent.
- Model Dusknoir/Dusclops as self-KO abilities whose target is chosen by prize swing and damage-counter math.
- Model whether using Dusknoir gives the opponent a prize and whether that unlocks opponent comeback cards.

## Real Card Coverage: Raging Bolt Ogerpon

Deck cards with high strategic impact:

- `Raging Bolt ex` / `猛雷鼓ex`: Basic Ancient attacker. Main attack consumes attached energy and scales damage by discarded energy count.
- `Teal Mask Ogerpon ex` / `厄诡椪 碧草面具ex`: Basic engine. Ability attaches Grass Energy from hand to itself and draws.
- `Professor Sada's Vitality` / `奥琳博士的气魄`: Supporter. Assign up to 2 Basic Energy from discard to Ancient Pokemon, then draw 3.
- `Earthen Vessel` / `大地容器`: Item. Discard 1 hand card, search up to 2 Basic Energy.
- `Radiant Greninja` / `光辉甲贺忍蛙`: Ability discards 1 Energy from hand, draws 2.
- `Energy Retrieval` / `能量回收`: Recover Basic Energy from discard to hand.
- `Pokegear 3.0` / `宝可装置3.0`: Search Supporter from top cards.
- `Trekking Shoes` / `健行鞋`: top-deck keep/discard draw decision.
- `Switch Cart` / `交替推车`, `Prime Catcher`, `Pokemon Catcher`, `Boss's Orders`: switch/gust choices.
- `Bravery Charm` / `勇气护符`: attach target must prefer fragile active or next attacker.
- `Temple of Sinnoh` / `神奥神殿`: special energy suppression, matchup-dependent.

Raging-Bolt-specific model requirements:

- Model exact energy gaps by type. `Lightning` and `Fighting` unlock attack; `Grass` usually belongs to Ogerpon.
- Model discard as resource creation, not only cost. Discarding Energy can enable Sada.
- Model hand safety. Do not spend all hand resources just to make current board look good.
- Model attack discard cost. The attack can destroy next-turn readiness, so tree must include reload branches.
- Model Sada as assignment from discard sources to Ancient targets, with exact source-target pairing.
- Model Ogerpon ability as self-attach plus draw, not normal manual attachment.

## Real Card Coverage: Gardevoir

Deck cards with high strategic impact:

- `Gardevoir ex` / `沙奈朵ex`: Stage 2 engine. Ability `Psychic Embrace` attaches Basic Psychic Energy from discard to a Psychic Pokemon and places 2 damage counters on that target. This is repeatable, but cannot KO the target.
- `Kirlia` / `奇鲁莉安`: Stage 1 engine. Ability `Refinement` discards 1 card and draws 2, turning hand cards into discard fuel and deeper setup.
- `Ralts` / `拉鲁拉丝`: Basic shell. Multiple copies must survive into Kirlia/Gardevoir.
- `Drifloon`, `Drifblim`, `Scream Tail`: attackers whose damage depends on attached Psychic Energy or damage-counter math.
- `Munkidori` / `愿增猿`: moves damage counters from own board to opponent if dark energy is attached.
- `Radiant Greninja` / `光辉甲贺忍蛙`: discards Energy to draw 2, enabling Psychic Embrace fuel.
- `Technical Machine: Evolution` / `招式学习器 进化`: attack/tool line that evolves benched Basics.
- `Earthen Vessel`, `Ultra Ball`, `Buddy-Buddy Poffin`, `Arven`, `Rare Candy`, `Super Rod`, `Night Stretcher`: setup, fuel creation, and recovery.

Gardevoir-specific model requirements:

- Model `Psychic Embrace` as energy assignment with a self-damage constraint. The target must survive the added counters.
- Model repeated ability use as a loop controlled by a policy, not as one fixed action.
- Model attacker readiness by both Energy count and remaining HP after Embrace damage.
- Model discard creation separately from discard waste. Psychic Energy in discard is fuel; key Stage 2/search cards are not.
- Model TM Evolution as an attack/tool setup route that changes next-turn board shape.
- Model Munkidori counter movement as a damage-counter source-target-count interaction.

## Real Card Coverage: Miraidon

Deck cards with high strategic impact:

- `Miraidon ex` / `密勒顿ex`: Basic engine. Ability `Tandem Unit` searches up to 2 Basic Lightning Pokemon from deck to bench.
- `Electric Generator` / `电气发生器`: Item. Looks at top cards and assigns found Basic Lightning Energy to benched Lightning Pokemon.
- `Iron Hands ex` / `铁臂膀ex`: main attacker. Can take extra prize with the correct attack.
- `Raikou V`: efficient early attacker.
- `Raichu V`: late burst attacker. Attack discards attached Lightning Energy, so discard quantity must be controlled.
- `Zapdos`: Lightning damage booster and secondary attacker.
- `Forest Seal Stone`: VSTAR search attached to a V Pokemon.
- `Prime Catcher`, `Boss's Orders`, `Switch Cart`, `Rescue Board`, `Heavy Baton`: target control, pivoting, and energy preservation.
- `Radiant Greninja`, `Squawkabilly ex`, `Fezandipiti ex`: draw/recovery engines.

Miraidon-specific model requirements:

- Model bench slot budgeting. The deck can flood Basics, but board slots are scarce.
- Model `Tandem Unit` as search-to-bench with role priorities: engine, attacker, pivot, draw support.
- Model `Electric Generator` as assignment from a probabilistic/top-deck source to benched Lightning targets. It should prefer attackers that can attack soon, not random Lightning Pokemon.
- Model `Raichu V` attack discard as a late-game finisher, not a normal mid-game attack.
- Model tools as target-specific: Forest Seal Stone to V, Heavy Baton to energy-heavy attacker, Rescue Board to pivot.
- Model fast-prize pressure: if an attack can take an extra prize or KO an engine, it should dominate setup churn.

## Standard Turn Tree Schema

```json
{
  "decision_tree": {
    "goal": "complete_stage2_engine | immediate_ko | setup_next_attacker | reload_after_attack | stabilize_hand",
    "actions": [],
    "branches": [
      {
        "when": [{ "fact": "..." }],
        "actions": [
          {
            "type": "play_trainer",
            "card": "<name or name_en from JSON>",
            "intent": "complete_engine_piece",
            "interactions": {
              "search_item": { "prefer": ["Rare Candy"] },
              "search_tool": { "prefer": ["Forest Seal Stone"] },
              "discard_cards": { "policy": "preserve_engine_and_next_turn" },
              "search_cards": { "prefer": ["Charizard ex"] },
              "stage2_card": { "prefer": ["Charizard ex"] },
              "target_pokemon": { "prefer_role": "primary_attacker_lane" },
              "energy_assignments": {
                "source_filter": { "energy_type": "Fire" },
                "target_policy": "ready_current_or_next_attacker"
              },
              "self_ko_target": { "target_policy": "best_prize_or_engine_ko" },
              "counter_distribution": { "target_policy": "maximize_multi_ko" }
            }
          }
        ],
        "then": {}
      }
    ],
    "fallback_actions": [{ "type": "end_turn" }]
  },
  "reasoning": "one sentence"
}
```

The new field is `interactions`. It is the missing bridge between strategic plans and card-effect execution.

## Standard Action Types

Current action types remain valid:

- `play_basic_to_bench`
- `attach_energy`
- `attach_tool`
- `evolve`
- `play_trainer`
- `play_stadium`
- `use_ability`
- `retreat`
- `attack`
- `end_turn`

The model must treat these as high-level choices. Any action that opens follow-up choices must include `interactions`.

## Standard Interaction Types

These are the required standard interaction ids and policies.

Search interactions:

- `search_cards`: generic deck search.
- `search_pokemon`: Pokemon search.
- `search_item`: Item search, used by Arven.
- `search_tool`: Tool search, used by Arven.
- `search_energy`: Basic Energy search, used by Earthen Vessel.
- `search_supporter`: Supporter search, used by Lumineon V.
- `stage2_card`: Rare Candy selected Stage 2.
- `search_to_bench`: search directly to bench, used by Miraidon ex style abilities and Nest Ball/Poffin-like effects.

Discard interactions:

- `discard_cards`: generic discard cost.
- `discard_card`: single discard.
- `discard_energy`: discard energy for abilities like Radiant Greninja.
- `discard_basic_energy`: energy-specific discard.
- `attack_energy_discard`: attack-cost or attack-effect discard, such as Raging Bolt.

Assignment interactions:

- `energy_assignments`: source energy to target Pokemon, used by Infernal Reign and deck-attach abilities.
- `psychic_embrace_assignments`: discard Psychic Energy to own Psychic target with self-damage safety.
- `electric_generator_assignments`: top-deck Lightning Energy to benched Lightning Pokemon.
- `sada_assignments`: discard Basic Energy to Ancient target.
- `tool_target`: Tool attachment target.
- `target_pokemon`: generic field target.
- `source_pokemon`: source field target for move-counter effects.

Board-control interactions:

- `gust_target`: opponent bench target to move active.
- `switch_target`: own bench target to switch active.
- `retreat_target`: own bench target after retreat.
- `send_out`: replacement after KO.

Damage-counter interactions:

- `self_ko_target`: Dusknoir/Dusclops single target for placed counters.
- `counter_distribution`: distribute N counters across opponent board.
- `move_counter_source`: own damaged Pokemon source.
- `move_counter_target`: opponent Pokemon target.
- `counter_count`: number of counters to move.
- `self_damage_limit`: max safe self-damage accepted for an energy acceleration line.

Recovery interactions:

- `recover_card`: discard-to-hand target.
- `recover_pokemon`: Pokemon recovery.
- `recover_energy`: Energy recovery.
- `shuffle_back_cards`: discard-to-deck recovery, such as Super Rod.

Optional yes/no interactions:

- `discard_stadium_choice`
- `use_optional_effect`
- `keep_or_discard_top_card`

## Standard Facts

The executor should evolve toward these fact groups.

Turn-rule facts:

- `can_attack`
- `can_use_supporter`
- `energy_not_attached`
- `supporter_not_used`
- `retreat_not_used`
- `is_first_turn`
- `going_first`
- `vstar_power_unused`

Card/zone facts:

- `zone_has_card`
- `zone_has_card_type`
- `zone_has_energy_type`
- `deck_has_search_target`
- `hand_has_card`
- `discard_has_card`
- `prize_has_card_known`
- `has_bench_space`

Evolution facts:

- `can_evolve_slot`
- `can_rare_candy`
- `has_stage2_bridge`
- `stage2_line_online`
- `engine_online`
- `attacker_line_online`

Ability facts:

- `ability_available`
- `shared_ability_unused`
- `on_evolve_ability_pending`
- `bench_enter_ability_pending`
- `ability_locked`
- `special_energy_suppressed`
- `can_loop_ability`
- `ability_target_survives_self_damage`

Combat facts:

- `active_attack_ready`
- `slot_attack_ready`
- `exact_energy_gap`
- `can_take_prize`
- `can_take_multi_prize`
- `opponent_can_ko_active_next_turn`
- `bench_target_in_counter_ko_range`
- `opponent_active_ko_with_attack`
- `opponent_bench_ko_with_counters`

Resource facts:

- `hand_size_at_least`
- `hand_would_remain_playable`
- `deck_count_at_least`
- `discard_basic_energy_count_at_least`
- `next_attacker_mapped`
- `current_attacker_mapped`
- `bench_slots_reserved`
- `hand_after_line_playable`

## Target Policies

LLM should not score every candidate itself. It should choose one of these policies and let rules compute candidates.

Search policies:

- `complete_primary_engine`: find Pidgeot ex, Rare Candy, or missing Basic.
- `complete_primary_attacker`: find Charizard ex, Raging Bolt ex, or needed evolution bridge.
- `ready_attack_this_turn`: find exact card that enables attack now.
- `preserve_next_turn`: find recovery or hand-stability card.
- `find_gust_for_ko`: find Boss/Counter Catcher/Prime Catcher.
- `find_energy_access`: find Earthen Vessel, Energy Retrieval, or exact energy.

Discard policies:

- `discard_energy_for_reload`: prefer energy that enables Sada or Ogerpon.
- `discard_low_future_value`: preserve Stage 2 pieces, Rare Candy, one Supporter, next attacker.
- `discard_for_lethal_only`: discard minimum attached energy needed for KO.
- `discard_dead_duplicate`: discard redundant setup card after engine is online.

Energy assignment policies:

- `ready_current_attacker`
- `ready_next_attacker`
- `enable_retreat_pivot`
- `feed_engine_self_attach`
- `avoid_wasting_wrong_type`
- `preserve_attack_cost_energy`
- `embrace_until_exact_damage_or_safe_hp`
- `generator_to_best_benched_lightning_attacker`

Damage-counter policies:

- `best_prize_or_engine_ko`
- `finish_damaged_bench`
- `set_up_future_multi_ko`
- `avoid_giving_prize_unless_value_positive`
- `move_self_damage_to_finish_ko`

Switch/gust policies:

- `promote_ready_attacker`
- `promote_wall_or_low_prize`
- `gust_for_immediate_ko`
- `gust_engine_piece`
- `gust_stranded_high_retreat`

## Example: Charizard Pidgeot Tree Fragment

```text
ROOT goal=complete_stage2_engine
- if can_rare_candy(Charizard ex, Charmander) and deck_has_energy_type(Fire, 2)
  - play_trainer Rare Candy
    interactions:
      stage2_card -> prefer Charizard ex
      target_pokemon -> primary_attacker_lane
    then:
      use_ability Charizard ex / Infernal Reign
      interactions:
        energy_assignments -> ready_current_or_next_attacker
- else if can_rare_candy(Pidgeot ex, Pidgey)
  - play_trainer Rare Candy
    interactions:
      stage2_card -> prefer Pidgeot ex
      target_pokemon -> engine_lane
    then:
      use_ability Pidgeot ex / Quick Search
      interactions:
        search_cards -> ready_attack_this_turn or complete_primary_attacker
- else if ability_available(Dusknoir) and self_ko_value_positive
  - use_ability Dusknoir / Cursed Blast
    interactions:
      self_ko_target -> best_prize_or_engine_ko
- fallback:
   setup Charmander/Pidgey, attach Fire, end_turn
```

## Example: Raging Bolt Ogerpon Tree Fragment

```text
ROOT goal=immediate_ko_or_reload
- if active_attack_ready and can_take_prize
  - attack Raging Bolt ex
    interactions:
      attack_energy_discard -> discard_for_lethal_only
    then:
      reload_after_attack branch next turn
- else if hand_has_card(Earthen Vessel)
  - play_trainer Earthen Vessel
    interactions:
      discard_cards -> discard_energy_for_reload
      search_energy -> exact_missing_energy_or_sada_reload
- else if can_use_supporter and discard_basic_energy_count_at_least(1) and hand_has_card(Professor Sada's Vitality)
  - play_trainer Professor Sada's Vitality
    interactions:
      sada_assignments -> ready_current_or_next_attacker
- else if ability_available(Teal Mask Ogerpon ex)
  - use_ability Teal Mask Ogerpon ex
    interactions:
      energy_assignments -> feed_engine_self_attach
- fallback:
   attach exact missing L/F to Raging Bolt or G to Ogerpon, end_turn
```

## Example: Gardevoir Tree Fragment

```text
ROOT goal=build_shell_or_convert
- if shell_not_online and hand_has_card(Buddy-Buddy Poffin)
  - play_trainer Buddy-Buddy Poffin
    interactions:
      search_pokemon -> complete_primary_engine
- else if can_evolve_slot(Kirlia from Ralts)
  - evolve Kirlia onto Ralts
- else if ability_available(Kirlia / Refinement)
  - use_ability Kirlia
    interactions:
      discard_cards -> discard_energy_for_embrace_or_low_future_value
- else if ability_available(Gardevoir ex / Psychic Embrace)
  - use_ability Gardevoir ex
    interactions:
      psychic_embrace_assignments -> embrace_until_exact_damage_or_safe_hp
- fallback:
   preserve hand, recover attackers, end_turn
```

## Example: Miraidon Tree Fragment

```text
ROOT goal=fast_pressure
- if ability_available(Miraidon ex / Tandem Unit) and has_bench_space
  - use_ability Miraidon ex
    interactions:
      search_to_bench -> engine_then_attacker_board
- else if hand_has_card(Electric Generator)
  - play_trainer Electric Generator
    interactions:
      electric_generator_assignments -> generator_to_best_benched_lightning_attacker
- else if attack_ready(Iron Hands ex) and can_take_extra_prize
  - attack Iron Hands ex
- else if attack_ready(Raichu V) and lethal_requires_burst
  - attack Raichu V
    interactions:
      attack_energy_discard -> discard_for_lethal_only
- fallback:
   attach Lightning to nearest attacker, pivot, end_turn
```

## Implementation Plan

1. Add a reusable interaction-intent model.

Files:

- `scripts/ai/LLMInteractionIntentBridge.gd`
- `scripts/ai/LLMDecisionTreeExecutor.gd`
- `scripts/ai/LLMTurnPlanPromptBuilder.gd`
- `scripts/ai/LLMDeckCapabilityExtractor.gd`

Required changes:

- Parse `interactions` from tree actions.
- Pass selected action interaction intent into all resolver paths.
- Support assignment, field slot, counter distribution, and dialog steps, not just basic pick lists.

2. Expand executor facts.

Add facts for:

- Rare Candy legality.
- evolution line readiness.
- ability availability by name.
- exact energy gaps.
- KO math.
- bench counter KO ranges.
- deck search availability.
- hand safety.

3. Add deck card capability extraction.

For a given deck id:

- Read deck JSON.
- Read each card JSON.
- Map `effect_id` through known effect registry categories.
- Emit a deck capability summary for the prompt: cards, possible actions, possible interaction ids, strategic roles.

Implemented baseline:

- `LLMDeckCapabilityExtractor` reads the current player's real `CardData` from hand, deck, discard, prizes, and board.
- It emits `deck_capabilities.cards[]`, `action_types`, `interaction_ids`, and `strategic_roles`.
- The prompt now receives `deck_capabilities` and requires the LLM to use only known card names and supported interaction ids.

4. Update prompt.

The prompt must include:

- `deck_capabilities`
- supported facts
- supported target policies
- required interaction ids for each card effect

5. Add focused tests.

Charizard:

- Rare Candy branch selects Charizard ex/Pidgeot ex and correct Basic target.
- Infernal Reign routes Fire to Charizard or pivot depending on current readiness.
- Pidgeot Quick Search chooses missing engine/attack card.
- Dusknoir self-KO targets a KO/prize-positive opponent slot.

Raging Bolt:

- Earthen Vessel discard/search creates Sada fuel and exact missing energy.
- Radiant Greninja discards the energy that improves reload, not random energy.
- Sada assignment pairs source energy to the correct Ancient target.
- Raging Bolt attack discards only enough energy for lethal when possible.

## Non-Negotiables

- Card names come from card JSON `name` / `name_en`.
- LLM cannot invent interaction ids.
- Unsupported facts do not match.
- Rules layer owns legality.
- Every effect that opens a UI choice must map to a standard interaction type or explicit fallback.

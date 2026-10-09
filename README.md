# LebrosSupplies (Windower 4)

Initial **v0.1.0 observation build** for the *Lebros Supplies* Assault. Load `LebrosSupplies.lua` on every participating character.

## What works

- Scans nearby `Imperial Stormer` entities, retaining each distinct server ID.
- Recomputes **provisional** nearby soldier groups from x/y/z Euclidean distances (default 6 yalms).
- Marks clusters containing 2 or 3 NPCs as possible groups; highlights three-member groups as stewpot priority.
- Scans available Windower temporary-item records for six known provision types; broadcasts observations through Windower IPC.
- Displays a small draggable HUD with soldiers seen, provisional clusters, current targeted ID/estimated points, and shared food observations.
- Provides manual bookkeeping commands synchronized across clients.

## Commands

```text
//lua load LebrosSupplies
//lsupply status
//lsupply inspect
//lsupply radius 6
//lsupply record seafood stewpot
//lsupply record bison steak
//lsupply record coeurl sub
//lsupply record bison jerky
//lsupply record pea soup
//lsupply record white bread
//lsupply full
```

`record` adds **estimated** points to the currently targeted soldier. For a stewpot, it applies to all soldiers in that observed 2- or 3-member cluster. `full` manually marks the currently selected soldier confirmed satisfied after checking NPC dialogue.

## Why automatic feeding is NOT enabled yet

Talking to an Imperial Stormer automatically consumes whatever eligible temporary food the character carries. Until actual food-selection behavior and exact confirmation messages are verified, automatic interactions can waste limited supplies. V0.1.0 **does not automatically interact, feed, trade, or spend items**.

Spatial clusters are only hypotheses: incomplete mob-array visibility, floors, close adjacent groups, or unusual spacing can misclassify membership. Do not interpret a cluster as proof of the server's actual stewpot AoE group. Any `record` call is manually asserted bookkeeping, not an observed transaction. Temporary item structure may vary; if food is not detected, compare Windower's inventory records.

## Planned next iteration

Capture actual NPC dialogue and before/after food inventory changes on successful delivery, then introduce a transactional feeding scheduler with one pending interaction at a time, IPC claim locks, ID-specific confirmation, and explicit group-completion validation.

Mission references:
- https://www.bg-wiki.com/ffxi/Lebros_Supplies
- https://wikiwiki.jp/ffxi/%E3%82%A2%E3%83%88%E3%83%AB%E3%82%AC%E3%83%B3%E3%81%AE%E7%A7%98%E5%AE%9D/%E3%82%A2%E3%82%B5%E3%83%AB%E3%83%88/%E3%83%AC%E3%83%99%E3%83%AD%E3%82%B9%E9%A2%A8%E7%A9%B4

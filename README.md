# LebrosSupplies (Windower 4)

**v0.4.1 — single-coordinator feeding prototype**

All six clients load the addon. One explicitly named character coordinates; other clients report sightings and food stock and execute only addressed feeding jobs.

## In-game setup

```text
//send @all lua r LebrosSupplies
//lsupply coordinator Terrasjr
//lsupply plan
//lsupply status
```

Replace Terrasjr with whichever character you want coordinating. **Coordinator selection is mandatory** and broadcasts via IPC; no automatic leader inference. The coordinator can be any party member. Reloading all clients requires selecting it again.

## Player-confirmed group sizes

Target an Imperial Stormer and type `//lsup 2` to confirm the targeted soldier belongs to a two-soldier group, or `//lsup 3` for a three-soldier group. This sends its **server ID** and the player-confirmed group size to the coordinator over IPC. The marker is not keyed by NPC name and resets when zoning. Use `//lsup plan` to view all confirmed markers and assignments.

**No automatic feeding is issued to unmarked soldiers.** Seafood Stewpots are reserved for explicitly marked 3-member groups, not spatially guessed ones, **until two distinct three-member groups have received a confirmed stewpot consumption**. After that, the coordinator releases remaining stewpots for explicitly marked two-member groups. It derives a stable sorted triple of nearby soldier server IDs to ensure a repeated interaction in the same group cannot count as the second group. Incomplete or ambiguous three-soldier sightings do not unlock the reserve. A marker applies to the targeted soldier ID only. The other soldiers in a group can be marked individually when approached.

## Operation

Each client reports nearby Imperial Stormer **server IDs, indices, positions, distances**, plus temporary food observations. The coordinator merges reports, estimates spatial groups using a configurable radius (default 6 yalms), and assigns one NPC interaction to an in-range worker. A Seafood Stewpot is reserved for a player-confirmed **three-soldier** group. The worker checks the exact mob ID/index, range, and its available food before issuing one interaction packet. It waits for inventory depletion and reports confirmed consumption; the coordinator does not automatically retry unresolved jobs.

**Important limitation:** An actual food consumption is not proof that a soldier is fully satisfied, nor that nearby soldiers received stewpot credit. Spatial clusters are provisional. Initial automatic feeding is limited to characters carrying **one food type**; with mixed provision types, it intentionally does not guess what the server will consume. We still need to validate actual Windower temporary-food visibility and packet interaction on a live run. This is an incremental implementation, not a proven unattended clear.

## Commands

```text
//lsup 2                     # target soldier belongs to 2-person group
//lsup 3                     # target soldier belongs to 3-person group
//lsup coordinator <character>
//lsupply coordinator auto     # disable coordinator / automatic assignments
//lsupply plan                 # inspect coordinator job states
//lsupply status
//lsupply inspect
//lsupply radius 6
//lsupply record seafood stewpot
//lsupply full
```

The last two bookkeeping commands remain manual for confirmed dialogue. Use `record` only for a known successful feeding, and `full` only after confirmed satisfaction.

## Safety

- All clients must use the same addon version.
- Do not run simultaneous competing NPC automation.
- No automatic retry when transaction outcome is unknown.
- The coordinator never sends blanket broadcast feeding commands.
- Player-confirmed group classification is mandatory before any automatic feeding.
- IPC assignment is scoped to one character, one mob ID/index, one food type, and one job number.
- If the temporary-item scanner cannot see your food, the coordinator cannot schedule its consumption.
- Unknown server food-selection behavior is a hard stop for mixed inventories.

Code: `LebrosSupplies.lua`.

### Stewpot priority state

Run `//lsup plan` on the coordinator to see `3-group stewpots 0/2`, `1/2`, or `2/2` and whether the reserve is unlocked. This records two **distinct group-level consumption events**, not proven satisfaction of every soldier; the addon does not claim that inventory reduction proves NPC satisfaction. All state resets when zoning.

### Strict three-soldier stewpot priority (v0.3.2)

Until the coordinator has confirmed stewpot consumption for **both** distinct three-soldier groups, it **will not assign ordinary food to soldiers marked `//lsup 3`**. Their priority is stewpot-first, even if another character with ordinary food is closer. Once the two priority deliveries have happened, remaining stewpot stock can be assigned to marked two-soldier groups. If no stewpot is available, the marked three-soldier group waits instead of consuming ordinary provisions.

### Coordinator poke-and-confirm (v0.4.1)

An Imperial Stormer does **not** open a choice menu. The assigned worker sends one NPC interaction (poke), waits for the game dialogue and temporary-food inventory decrease, then reports confirmed consumption to the coordinator. No outgoing `0x05B` menu response or option index is sent. An unresolved attempt remains unresolved; it is not retried automatically.

The feeding code has not yet been live-tested. In particular, the temporary-item container exposed by the client's Windower build still needs to be verified during normal play.

### Party-wide food HUD (v0.6.2)

The HUD shows each party member individually in party order, including the coordinator. Stock reports refresh via IPC. Each row lists held food types and quantities, **EMPTY - RESTOCK** for a recent report with no recognized temporary provisions, or **NO RECENT REPORT** when a member has not reported in eight seconds (including newly loaded clients). This distinguishes zero food from missing telemetry. Group and target progress remain visible above the food rows. Item visibility depends on the Windower temporary-item API; unrecognized temporary food can falsely appear as empty and needs an in-game check.

### Compact HUD (v0.6.2)

One line per player in party order. Blank cluster lines are suppressed, and supplies appear vertically beneath the current target. `OFFLINE / STALE` means no recent IPC stock report. `TEMP ITEMS UNKNOWN` means the client's `get_items().temporary` container is not exposed as a table. `RESTOCK / VERIFY` means the container was readable but no food names matched; confirm item detection before assuming it is empty. This is deliberately different from claiming an unverified empty scan means no food.

### Windower HUD layout (v0.6.2)

The in-game layout uses **three Windower `texts` objects**, not one giant concatenated string: a header/target panel, a left-aligned character-name column, and a right-aligned provision-status column. Six clients appear on six separate rows. Target group status (`UNMARKED`, `GROUP 2`, `GROUP 3`) and accumulated feeding value appear above the inventory rows. This is a native text-object approximation, not an HTML-style card; actual font spacing and layering need in-game confirmation.

### Assignment handoff fix (v0.6.2)

Fixed an IPC parser offset: a worker assignment is `lebrosc|assign|worker|job|NPC id|NPC index|food`, and the worker now reads fields 3-7 rather than 2-6. The coordinator also checks that a soldier has not already received a job during the current candidate iteration. When a worker rejects a scoped assignment, it logs the actual reason (NPC not visible, index mismatch, range, food not detected, or mixed food). An empty/undetected temporary-food inventory still prevents feeding; this is independent of the IPC fix.

### Repeat partial feeds (v0.6.3)

After a worker confirms that food was consumed, the coordinator releases that soldier for another assignment after a two-second cooldown **if their cumulative feeding ledger remains below 7 points**. Only `completed` jobs become eligible again; `assigned` and `uncertain` jobs stay blocked to avoid duplicate interactions. A worker cannot receive overlapping active assignments. A soldier with confirmed `full` status is skipped regardless of estimated points. Feeding points remain estimates from confirmed item consumption, not independently verified NPC satisfaction.

### Automatic Yazuhma restocking (v0.7.0)

The addon automatically requests provisions from **Yazuhma** when a character returns within 4.5 yalms carrying no recognized food. If Yazuhma is still on her dispense cooldown, the addon retries the NPC poke at most once every **5 seconds**. The loop stops as soon as temporary food appears and never runs during an active feeding transaction. It does not move characters back to Yazuhma: movement remains manual or controlled by another addon. Commands: `//lsup restock on` or `//lsup restock off`. Enabled by default.

The stock scanner must detect temporary items for the retry loop to know when to stop. If the HUD shows `UNKNOWN` or `VERIFY STOCK` while the character actually carries food, turn restocking off until detection is corrected. No in-game runtime or Lua syntax check has been confirmed for this version.

### Solo soldier classification (v0.7.1)

Target a lone Imperial Stormer and enter `//lsup 1` to mark that exact NPC server ID as a **solo soldier**. Like `//lsup 2` and `//lsup 3`, this is sent to the coordinator over IPC and displayed as `GROUP 1` in the target HUD. Solo soldiers receive ordinary food while the two three-soldier stewpot reservations remain outstanding. Once both priority three-person groups have consumed stewpots, remaining stewpots may also be used on solo soldiers. The food-point ledger and retry rules remain per soldier.

### Recover pre-interaction range failures (v0.7.2)

If a worker rejects a coordinator assignment **before poking** because the soldier is out of range, not visible, has a changed index, or the worker is busy, the job becomes `retryable`. When an in-range worker is available again and the cooldown has passed, the coordinator may issue a fresh assignment. Jobs whose outcome may include food consumption (`no-inventory-change`, timed out after interaction) remain blocked as uncertain. Correcting the retry state does not clear group markings or per-soldier food points.

### Stewpot preference, not requirement (v0.7.3)

A three-soldier group receives priority for Seafood Stewpot **when a matching in-range worker can currently deliver one**. If no valid stewpot delivery is available, ordinary food is permitted immediately. This prevents group-three starvation when no stewpot is held or nearby. Existing two-group stewpot reservation and eventual release rules remain in place.

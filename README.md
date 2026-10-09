# LebrosSupplies (Windower 4)

**v0.3.0 — single-coordinator feeding prototype**

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

**No automatic feeding is issued to unmarked soldiers.** Seafood Stewpots are reserved for explicitly marked 3-member groups, not spatially guessed ones. A marker applies to the targeted soldier ID only. The other soldiers in a group can be marked individually when approached.

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

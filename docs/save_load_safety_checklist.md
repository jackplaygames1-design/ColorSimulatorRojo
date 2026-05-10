# Color Simulator Save/Load Safety Checklist

Run these before any beta publish after touching persistence.

## Test A: Fresh Player
- Intentionally reset Studio test data with `game.ReplicatedStorage.StudioResetProfile:Invoke()` or the existing reset flow.
- Join.
- Confirm Output shows `DataManager [load]` with `brushes=1`, `sectors=1`, and no load-failure warning.
- Verify starter brush exists.
- Hatch one Color.
- Equip the Color.
- Buy/equip one non-starter brush.
- Unlock Orange.
- Leave and rejoin.
- Confirm Output shows the same or higher `colorAmount`, `brushes`, and `sectors`.
- Confirm inventory, equipped Color, owned brush, equipped brush, and Orange unlock are still present.

## Test B: Existing Player Protection
- Join with a profile that already has Colors, non-starter brushes, and Orange unlocked.
- Do nothing.
- Leave and rejoin.
- Confirm no `DATA LOSS PROTECTION` warnings appear.
- Confirm profile summary counts did not drop.

## Test C: Destructive Save Guard
- In Studio, use Explorer to temporarily clear `PetData.Inventory` or set `PaintTools.Owned` to `StarterBrush` on a loaded profile with existing data.
- Trigger a save by leaving or changing a watched value.
- Confirm Output warns `DATA LOSS PROTECTION: blocked save`.
- Rejoin and confirm the old cloud/session data was not overwritten by the destructive snapshot.

## Test D: Migration Safety
- Run `game.ReplicatedStorage.TestPetMigration:Invoke(oldProfileTable)` with an old profile table that has pets/tools/worlds but missing newer fields.
- Confirm the printed summary keeps Color amount, brush count, and unlocked sectors.
- Confirm only missing fields are added.

## Test E: Load Failure Safety
- Temporarily force DataStore load failure in Studio with datastore enabled, or test in a controlled place with DataStore access blocked.
- Confirm the player is kicked with a data-load message.
- Confirm no save runs for that player afterward.

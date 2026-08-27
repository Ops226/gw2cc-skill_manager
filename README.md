# SkillManager

A recreation of the GW2Minion **SkillManager** addon for GW2CC.

Pick a profile for your profession, build an ordered list of skills, and gate each
one behind condition groups. All the conditions in a group must pass; any group
passing makes the skill castable, and the group that passed decides whether the
skill goes at the enemy, at you, or at a friend.

## Using it

Enable **SkillManager** in Settings, then pick it in Settings, Combat. The sword
button in the top menu opens the window.

- **Current Profile** picks among the profiles saved for your class. One is
  selected as soon as a character is in the world: the last one you used on that
  class, or the first available if there is no record. The three small buttons
  next to it re-read the folder, create a new profile, and import a `.sm`.
- **Save Changes** only appears once something has been edited.
- **Fight Range** either follows the longest range among your castable skills or
  pins a distance you type.
- **Swap Weapons** on Automatic lets the rotation switch weapon sets, kits,
  attunements and legends on its own.
- **Network Latency** is added to every skill's cast time, so a high ping stops the
  rotation interrupting its own casts.
- **Run without a target** keeps the rotation ticking when nothing is targeted.
  GW2CC normally only runs a combat routine once you have an attack target;
  GW2Minion had no such rule, and profiles rely on self-heals firing out of combat.

Click a skill tile to edit it. A tile lights green when every gate has passed and
the rotation would fire it next, cyan while it is casting, and amber while
selected; anything unavailable stays dim, with the recharge sweeping over it.
Drag tiles to reorder them; the list is the priority order. Dragging is disabled
while the filter box has text.

In the Skill Set Editor, an underwater weapon set is labelled **(aquatic)**, as is
any skill that only exists underwater. A weapon set that offers nothing the
previous one did not is dropped from the column: a character with only one set
equipped still reports weapons in both, because `CharacterState` mirrors them so
they show on either bar, and taken at face value that listed the same set twice.
Hovering a set names it as well as its weapons. Where two skills in a palette share a name
-- the halves of a chain, or a land and underwater pair -- the id is shown beside
them so they can be told apart. Tooltips always carry the id.

Profiles live in `user://plugins/skill_manager/profiles`.

## What changed from the original

The GUI, the labels, the tooltips and the evaluation order are reproduced as they
were. Four things could not be, or should not have been, carried across.

### Skill palettes are derived, not hardcoded

GW2Minion shipped 217 hand-written palettes across ten Lua files, each listing its
skills by id and carrying its own activation code. Here the skills come from the
client's own `SkillPaletteDef` data: a speculative `CharacterState` is handed to
`Manager.skill.compute_skill_bar` to ask what the bar *would* be on another weapon
set or in another attunement. Only the activation behaviour is written by hand,
and it reduces to four families -- weapon sets, profession states, transformations
and the always-available common set.

The upshot is that palettes never go stale when ArenaNet changes a skill, and
there is no icon cache or GW2 web API involved.

### Five conditions were broken and are fixed

Their editors are unchanged, so profiles keep working; only the evaluation was
wrong.

| Condition | What the Lua did |
| --- | --- |
| `Buff (Name)` | read a field that was never assigned, so it could never return true |
| `Alive` | tested that a value existed rather than what it was, so corpses read as alive |
| `Last Transform ID` | read the *current* transform, making it a duplicate of `Transform ID` |
| `Casting (Name)` | was byte-identical to `Casting (ID)`; only the picker differs |
| `Casting (Last Name)` | likewise, against `Casting (Last ID)` |

Two conditions read state the client does not expose. `Power2`, documented as
"Necro Sand Shades or Thief Malice", reports thief malice or specter shadow force;
a necromancer reports zero. `Clone` and `Pet` are told apart by ownership -- a pet
is the agent its owner's kennel points at, and anything else with an owner counts
as a clone.

### The custom code editors are GDScript

Both the per-skill condition editor and the profile level Main Menu editor take
GDScript instead of Lua. The snippet is compiled once into
`func evaluate(skill, context)` and a failure is logged a single time rather than
once per frame. The info badge in the Skill Editor lists everything on `context`.

Both editors autocomplete as you type, with keyword highlighting and bracket
matching. The options are reflected out of the real scripts and the engine's own
ClassDB rather than kept in a list, so `context.` offers whatever `Context`
actually has today and `context.player.` offers whatever `AgentChar` actually
has. Chains resolve as far as the type information goes --
`context.player.skill_bar.cooldowns` completes at every step. Preloaded imports
and engine plumbing are filtered out so the useful members sit at the top.

### Icon buttons are larger

GW2Minion drew its icon buttons at 13 to 15 pixels. That reads fine in ImGui and
is uncomfortably small here, so they sit at 16, 20 and 26 instead -- clickable
without turning the profile row into a toolbar. The sizes live in `ui/Style.gd`.

### The palette is easier on the eyes

GW2Minion painted its tiles in fully saturated primaries: pure red for every skill
that could not be cast right now, pure green for the ones that could. Since most
of a rotation is on cooldown most of the time, that meant a wall of red.

The states carry the same meaning here, but only the things worth looking at take
colour: ready is green, casting is cyan, selected is amber, unsaved changes are
amber, and everything unavailable is a dim neutral. The hues follow the accents
the rest of GW2CC already uses.

Everything else is built from a single surface, lifted straight out of the house
theme's `LineEdit/styles/normal`: a dark inset fill with a two pixel near-black
border. The stock `Button` style is a light parchment with near-black text, which
next to that surface reads as a row of glaring bars and swallows the icons whole,
so the windows carry a small local theme that swaps buttons, option buttons,
panels and the code editors onto the same surface and flips the text to suit.
`LineEdit` itself is left alone -- it is the reference the rest matches.

### Windows will not shrink out from under their contents

The editors are fixed-size windows, as they were in the original. Godot's text
metrics are not ImGui's, though, so the Skill Editor's two-column detail grid
genuinely needs about 680 pixels rather than the 600 the Lua laid out for. Each
window measures its contents on open and takes that as a floor, never below the
original design size, so dragging one narrow can no longer cut the right hand
column and the row buttons off the edge.

Long dropdowns are capped at twelve rows and scroll past that. The condition
picker is thirty-six entries, the buff list forty-six, and the skill name pickers
run to hundreds -- all of which otherwise render as one menu taller than the
screen.

### Units

Ranges are shown and typed in **Godot units** by default. **Distance Units** in
the main window switches them to the raw GW2 figures GW2Minion used, the numbers
you would read off the wiki.

Profiles store the GW2 figure either way, so flipping the setting only changes
what you read; it can never change how a rotation behaves. A Godot unit is worth
32 GW2 units, so those fields keep three decimals and step in quarters -- 500 GW2
is exactly 15.625u, and it survives a round trip through the field unchanged.

Cooldowns stay in milliseconds, so thresholds carried over from an old profile
still mean the same thing.

## Importing GW2Minion profiles

The third button on the profile row takes a `.sm` file and converts it.

A `.sm` is a Lua chunk whose body is one table literal, in a small enough subset
to read directly, so no Lua runtime is involved. Two things do not survive
verbatim, and the import reports both rather than leaving you to notice later:

- **Skill sets.** GW2Minion had its own palette names (`Thief_shortbow`). A skill
  is placed instead by finding which of the derived palettes actually contains
  its id, so it lands in the right set whatever the old name was. The dodge and
  weapon-swap pseudo-skills keep their original ids and map to the common set.
- **Custom Lua.** Anything beyond the default `return true` is kept as comments
  above a `return true`, so the intent survives for you to port to GDScript
  without the snippet failing to compile in the meantime.

Everything else -- the action order, condition groups, cast targets, combo chains,
fight range -- carries across as it was. A profile for another profession imports
fine but stays hidden until you play that class, and the import says so.

## Layout

```
Ingame.gd              plugin root: combat routine, profiles, settings
resources/             the saved data model
  Profile.gd           the action list plus the per-profile settings
  Skill.gd             one action, its verdict, and the combo chain
  ConditionGroup.gd    one AND-ed set plus its cast target
  Condition.gd         condition base class, editor helpers, discovery
  conditions/          the 36 conditions, one file each
runtime/
  Context.gd           per-tick snapshot of the game state
  Runner.gd            the cast loop
  SkillState.gd        cooldowns and charges in the units profiles expect
  SkillCatalog.gd      the id-to-name list the name pickers use
  ScriptSandbox.gd     compiles the user snippets
  palettes/            palette families and the registry that derives them
ui/                    the five windows and their widgets
```

Adding a condition means dropping a script into `resources/conditions/` that
extends `Condition.gd` and overrides `_get_uid`, `_evaluate` and `_build_editor`.
It shows up in the picker on the next load.

Discovery walks that directory, trying `res://` first and then the path as the
client sees it on disk, because a plugin shipped as a folder lives outside the
pck and cannot be listed through `res://` even though its scripts load fine from
there. If neither listing works the shipped set is registered from the `SHIPPED`
manifest in `Condition.gd` instead, so the picker is never empty. Add your script
to that list as well if it needs to survive every packaging.

# Quest Completist+

A small World of Warcraft Forever addon that shows a quest's level in front of its name, `[12] Quest Name`, in three places:

1. **The map.** The list that appears when you hover a Quest Completist icon on the world map.
2. **An NPC's quest list.** Both kinds: the gossip window (an NPC with talk options and quests) and the quest greeting window (an NPC with quests only).
3. **A single quest's window.** The title on the accept, not-finished-yet, and hand-in pages.

It is a separate addon. It does not change any file of Quest Completist, DialogKey, or the game, so updating those never removes it.

Quest Completist+ is not made by, or affiliated with, the authors of Quest Completist or DialogKey.

## Where the level comes from

- Quest Completist's own quest data, when Quest Completist is installed. This is the same level its quest list shows.
- The game's own level for the quest, when Quest Completist is not installed or does not know the quest.
- A quest with no known level keeps its plain name.

Without Quest Completist, places 2 and 3 still work with the game's level; place 1 is Quest Completist's own list and needs it.

## DialogKey

DialogKey (Numy Edition) numbers the lines of an NPC's quest list (`1.`, `2.`, ...). With both addons a line reads `1. [12] Quest Name`.

If you prefer `[12] Quest Name`, tick **Hide DialogKey's numbers** in the game's Options, AddOns, Quest Completist+. DialogKey's number keys keep working, because DialogKey picks a line by its position, not by its text. Note that DialogKey can skip unfinished quests when it counts, so without the numbers the screen no longer says which key is which line.

## Install

Copy the `QuestCompletistPlus` folder into `World of Warcraft\_forever_\Interface\AddOns\` and restart the game.

## How it works, and its limits

The addon only runs after the game's and the other addons' own code (`hooksecurefunc`, `HookScript`) and then adjusts the text they wrote. Nothing is replaced.

- The map list is found by the shape of Quest Completist's tooltip text. If a Quest Completist update changes that shape, the list goes back to plain names until this addon is updated. Nothing breaks.
- Hiding DialogKey's numbers relies on two of DialogKey's internal names. If a DialogKey update changes them, its numbers come back. Nothing breaks.
- The game's ornate quest title font draws numbers and brackets plain, so `[12]` beside an ornate name looks like two fonts. By default the addon therefore draws the whole title of an NPC's quest window in the standard font, the one the quest's text uses. Untick **Quest title in the standard font** in Options, AddOns, Quest Completist+ to keep the ornate font. The quest log's own view is not changed.

The addon keeps a small saved file (`QuestCompletistPlusDB`) with counts of what it wrote and skipped in each place, a few recent examples, and quests where Quest Completist's level and the game's level differ. It is there for troubleshooting and is never sent anywhere.

## Tested with

- World of Warcraft Forever 1.60.1 (Interface 16001)
- Quest Completist 114.5
- DialogKey - Numy Edition v1.2.62

## Development

    luac -p QuestCompletistPlus/QuestCompletistPlus.lua
    lua tests/test.lua QuestCompletistPlus/QuestCompletistPlus.lua
    python package.py

The test runs the addon outside the game against stand-ins shaped like the code it hooks. `package.py` writes `dist/QuestCompletistPlus-<version>.zip`.

## License

MIT. See `LICENSE`.

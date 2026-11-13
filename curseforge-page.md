# CurseForge project page: what to enter

Entered once when the project is created. Release notes go in each file's changelog, not here.

- **Name:** Quest Completist+
- **Game:** World of Warcraft
- **Summary (one line):** Shows quest levels as [12] Quest Name on Quest Completist's map icons, in NPC quest lists, and in the quest window. For WoW Forever.
- **Category:** Quests & Leveling
- **License:** MIT License
- **Source:** https://github.com/sato942/quest-completist-plus
- **Issues:** https://github.com/sato942/quest-completist-plus/issues
- **File to upload:** `dist/QuestCompletistPlus-1.2.0.zip` (made by `python package.py`), game version WoW Forever 1.60.1, release type Release, changelog: the 1.2.0 and 1.1.0 sections of `CHANGELOG.md`.

## Description (paste as is)

**Quest Completist+** shows a quest's level in front of its name, `[12] Quest Name`, in three places:

1. **The map:** the list that appears when you hover a Quest Completist icon on the world map.
2. **An NPC's quest list:** the gossip window and the quest greeting window.
3. **A single quest's window:** the title on the accept, not-finished-yet, and hand-in pages.

It is a separate addon that runs beside Quest Completist. It changes no file of Quest Completist, DialogKey, or the game, so updating them never removes it.

**Where the level comes from**

- Quest Completist's own quest data when it is installed: the same level its quest list shows.
- The game's own level when Quest Completist is missing or does not know the quest.
- A quest with no known level keeps its plain name.

Without Quest Completist, the NPC quest list and the quest window still work; the map list is Quest Completist's own and needs it.

**DialogKey**

DialogKey numbers the lines of an NPC's quest list, so a line reads `1. [12] Quest Name`. If you prefer `[12] Quest Name`, tick **Hide DialogKey's numbers** in Options, AddOns, Quest Completist+. DialogKey's number keys keep working.

**Quest title font**

The game's ornate quest title font draws numbers plain, so the title of an NPC's quest window is drawn in the standard font, where the level and the name match. Untick **Quest title in the standard font** in the same options to keep the ornate font.

**Good to know**

- Made for World of Warcraft Forever (Interface 16001). Tested with Quest Completist 114.5 and DialogKey - Numy Edition v1.2.62.
- If an update to Quest Completist or DialogKey changes how they write their text, this addon's change in that one place stops until it is updated. Nothing breaks.
- Not made by, or affiliated with, the authors of Quest Completist or DialogKey.

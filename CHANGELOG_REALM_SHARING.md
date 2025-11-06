# Realm-Wide Blacklist Sharing - Implementation Summary

## Overview
Billy's BlackList now shares the blacklist across all characters on the same realm, similar to how pfUI handles cross-character settings.

## How It Works

### Storage Structure
```lua
BlackListedPlayers = {
    ["RealmName1"] = {
        {name = "Player1", reason = "Ninja looter", ...},
        {name = "Player2", reason = "Toxic", ...},
        ...
    },
    ["RealmName2"] = {
        {name = "Player3", reason = "AFK in dungeon", ...},
        ...
    }
}
```

### Key Points
- **Realm-based storage**: Each realm has its own blacklist table
- **Cross-character sharing**: All characters on the same realm see the same blacklist
- **Realm isolation**: Characters on different realms maintain separate blacklists
- **SavedVariables**: Data persists across sessions via WoW's SavedVariables system

## Changes Made

### 1. BillyBlackListFunctions.lua
- **Simplified `GetActiveList()`**: Now always returns the realm-wide list
  - Removed character-specific mode logic (not needed)
  - Simple realm-based lookup: `BlackListedPlayers[GetRealmName()]`
  
- **Updated all data access**: All functions now use `GetActiveList()` instead of direct access
  - `AddPlayer()` - uses `GetActiveList()`
  - `RemovePlayer()` - uses `GetActiveList()`
  - `UpdateDetails()` - uses `GetActiveList()`
  - `GetNumBlackLists()` - uses `GetActiveList()`
  - `GetNameByIndex()` - uses `GetActiveList()`
  - `GetPlayerByIndex()` - uses `GetActiveList()`
  - `RemoveExpired()` - uses `GetActiveList()`

### 2. BillyBlackList.lua
- **Enhanced VARIABLES_LOADED handler**: 
  - Displays load message showing number of blacklisted players for the realm
  - Shows helpful message about realm-wide sharing
  
- **Added new `/blinfo` command**: 
  - Shows character name, realm name, and number of blacklisted players
  - Confirms realm-wide sharing is active
  - Helpful for users to understand the feature

### 3. README.md
- **Documented realm-wide sharing**: Added section explaining how the feature works
- **Added `/blinfo` command**: Documented the new information command
- **User-friendly explanation**: Clear description of cross-character behavior

## Testing Recommendations

1. **Single Character Test**:
   - Add a player to blacklist on Character A
   - Verify the player appears in the list
   - Check `/blinfo` shows correct count

2. **Multi-Character Test** (same realm):
   - Add player "TestPlayer1" on Character A
   - Log out and log in with Character B (same realm)
   - Verify "TestPlayer1" appears in Character B's blacklist
   - Add player "TestPlayer2" on Character B
   - Log back to Character A
   - Verify both players appear in the blacklist

3. **Multi-Realm Test**:
   - Add player "RealmTest1" on Realm A (any character)
   - Create/use character on Realm B
   - Verify "RealmTest1" does NOT appear on Realm B's blacklist
   - Verify each realm maintains separate lists

4. **Expiry Test**:
   - Add a player with 1-week expiry
   - Verify expiry works across characters on same realm

## Benefits

✅ **Convenience**: Maintain one blacklist per realm, not per character  
✅ **Consistency**: All your alts on a realm share knowledge of problem players  
✅ **No Configuration**: Works automatically, just like pfUI  
✅ **Backward Compatible**: Existing blacklists are preserved and work correctly  
✅ **Industry Standard**: Matches behavior of popular addons like pfUI  

## Technical Notes

- Uses WoW's native SavedVariables system (declared in .toc file)
- Compatible with Lua 5.0 (WoW Classic 1.12)
- No external dependencies required
- Minimal performance impact (simple table lookups)
- Data structure is straightforward and easy to debug

## User Experience

When users log in, they'll see:
```
BlackList: Hooks installed
BlackList: Loaded 5 blacklisted player(s) for realm 'Turtle WoW'
BlackList: All characters on this realm share the same blacklist
```

Using `/blinfo`:
```
==========================================
BillyBlackList Information
==========================================
Character: MyCharacter
Realm: Turtle WoW
Blacklisted Players: 5
Sharing Mode: Realm-Wide (All Characters)
==========================================
All characters on 'Turtle WoW' share this blacklist!
Use /blinfo to view this information again.
```

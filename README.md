# Billy's Blacklist

*"You've disappointed me for the last time." - Wise raid leader*

Enhanced for Turtle WoW (Classic 1.12)

Billy's Blacklist is a World of Warcraft addon that adds a comprehensive player blacklist system to your game. This system helps prevent you from associating with unwanted users

## Why a blacklist?

This addon exists to manage your group invite and raid state, it helps you filter players you do not want to play with. While the ignore list is useful, it does not prevent those players from being present during your events.

## What it does

Billy's Blacklist adds a new "BlackList" icon to your minimap, similar to other addons. You can add players with detailed information including their level, class, race, and a custom reason for blacklisting them. The addon can warn you with text and sound when you interact with blacklisted players, and optionally block communication or party invites from them.

The addon now includes a comprehensive options menu where you can control exactly how BlackList behaves. You can choose to block whispers, prevent party invitations, get warnings when a blacklisted player joins your party and more

## How to use it

**Slash Commands:**

Add players to your blacklist:
- `/blacklist` or `/bl` - Add your current target to the blacklist
- `/blacklist PlayerName` or `/bl PlayerName` - Add a player by name
- `/blacklist PlayerName Reason text` - Add a player with a custom reason

Remove players from your blacklist:
- `/removeblacklist PlayerName` or `/removebl PlayerName` - Remove a player from the blacklist

Check your current group:
- `/blcheck` - Scan your party or raid for blacklisted players

**Using the UI:**

You can also manage your blacklist through the interface:
- Click the BlackList minimap icon to open the main window
- Use the "Add Player" button to add someone to your blacklist
- Click on a player's name to view or edit their details and reason
- Use the "Remove" button to remove the selected player

When you have someone targeted, BlackList will automatically fill in their details like level, class, and race. You can edit this information later in the details window.

**Temporary Blacklisting:**

BlackList supports automatic expiry for temporary blacklists:
- When viewing a player's details, use the "Duration" dropdown to set how long they should remain blacklisted
- Choose from: Forever (permanent), 1 Week, 2 Weeks, 3 Weeks, or 4 Weeks
- The expiry date is shown in the details window (e.g., "Expires: Never" or "Expires: 02:30PM on Nov 11, 2025")
- Use this if you're feeling generous and want the person to have a second chance

## Options and features

Click the "Options" button in the BlackList tab to access detailed settings:

**General Settings:**
- Play warning sounds - controls whether you hear audio alerts
- Warn when targeting - shows messages when you target blacklisted players

**Communication:**
- Prevent whispers from blacklisted players (they get an auto-ignore response)
- Warn when blacklisted players whisper you

**Group Management:**
- Prevent blacklisted players from inviting you to groups
- Prevent yourself from accidentally inviting blacklisted players
- Warn when blacklisted players join your party or raid

## pfUI Integration

BlackList now automatically integrates with pfUI when that addon is active! If you're using pfUI to enhance your Classic WoW interface, BlackList will detect it and style all its frames (options menu, details window, etc.) to match pfUI's modern look and feel.

When pfUI is not present, BlackList falls back to standard Classic WoW styling, so it works perfectly either way.

## Credits

This addon is based on the original https://github.com/Zerf/BlackList addon, and then heavily modified to adapt to my needs.
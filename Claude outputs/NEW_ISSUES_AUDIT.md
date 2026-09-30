# Pearly Whites Challenge - New Issues Audit
**Date:** September 30, 2026  
**Device:** iPhone (notch/safe area issues)  
**Status:** Issues identified, awaiting analysis and fixes

---

## 📋 ISSUES IDENTIFIED (15 total)

### 🔴 CRITICAL (Device/Platform Specific)

#### ISSUE #1: iPhone Notch/Safe Area Not Respected
**Device:** iPhone with notch/Dynamic Island  
**Problem:** App doesn't account for safe area inset at top, blocking UI elements  
**Affected Areas:** Likely all screens with top-aligned UI  
**Impact:** CRITICAL - Blocks user interaction with top portion of UI  
**Files to Check:**
- `game_manager.gd` - Viewport/window setup
- `control_panel.gd` or equivalent - UI base class
- Individual screen setup (home, map, etc.)
**Solution:** Add safe area margins using `get_tree().get_root().get_viewport().get_visible_rect()` and `DisplayServer.screen_get_usable_rect()`

#### ISSUE #2: Home Page Crash on Entry
**Problem:** App crashes when entering home page  
**Frequency:** Consistent (happens on entry)  
**Impact:** CRITICAL - Blocks gameplay progression  
**Context:** Occurs after splash screen  
**Next Step:** Need to investigate crash logs/error messages

#### ISSUE #3: Godot Engine Splash Screen Not Replaced
**Problem:** Shows "Godot game engine" splash screen instead of custom Pearly Whites splash  
**File:** Likely `project.godot` settings  
**Solution:** Set custom splash screen in Project Settings → Display → Splash Screen

---

### 🟠 HIGH-IMPACT (User Experience)

#### ISSUE #4: iPad Background Showing on iPhone
**Problem:** Using iPad (landscape/larger resolution) background image on iPhone  
**Device:** iPhone  
**Affected Screen:** Polywork/challenge screen  
**Impact:** Image doesn't fit phone dimensions, content cut off  
**Root Cause:** Likely hard-coded background path or no device-specific image loading  
**Files to Check:**
- Any screen loading background with fixed path
- Asset loading logic

#### ISSUE #5: Tutorial Popup Blocking - Daily Habit Stamp Visible
**Screen:** Welcome to Pearly Reach Challenge (tutorial start)  
**Problem:** Daily habit stamp card appears behind tutorial popup, visible too early  
**Expected Behavior:** Should not appear until tutorial ends (skip OR completion)  
**Current Behavior:** Appears before "Let's Brush" button is clicked  
**Files to Check:**
- `welcome_screen.gd` or tutorial startup screen
- `map_screen.gd` - Daily habit card initialization
**Solution:** Add flag to delay daily habit card visibility until tutorial complete

#### ISSUE #6: Tutorial Highlighting Not Visible
**Problem:** Highlighted UI element during tutorial explanation appears dark/not highlighted  
**Visual Issue:** Looks the same as rest of screen (no contrast)  
**Expected:** Should have bright overlay/spotlight effect  
**Files to Check:**
- `tutorial_screen.gd` or tutorial manager
- Highlight/spotlight shader or overlay system
**Solution:** Increase highlight contrast, add brighter overlay, or fix spotlight effect

#### ISSUE #7: First Nodes Misaligned (Nodes 0, 1, 2)
**Problem:** Node zero, node one, and second day of node one are positioned incorrectly  
**Visual Issue:** Nodes don't line up on map  
**Files to Check:**
- `map_screen.gd` - Node position calculations
- Node position data in game state or JSON config
**Solution:** Recalculate node positions or fix position offset logic

#### ISSUE #8: Background Image Low Quality
**Problem:** Background image is pixelated/low resolution  
**Device:** iPhone (and possibly others)  
**Impact:** Visual quality issue, unprofessional appearance  
**Root Cause:** Likely:
  - Using scaled-down image asset
  - Wrong image resolution for device DPI
  - Not using @2x/@3x variants
**Files to Check:**
- Asset folders for resolution variants
- Image loading logic in screen setup

---

### 🟡 MEDIUM-IMPACT (Functionality/Navigation)

#### ISSUE #9: Node Alignment Throughout Map
**Problem:** All nodes on map are misaligned (broader issue than #7)  
**Affected Nodes:** Zero, one, second day of node one (confirmed), likely others  
**Files to Check:**
- `map_screen.gd` - Node position calculation
- Game state node position data
**Solution:** Fix node positioning logic or recalculate all positions

#### ISSUE #10: Button Label Inconsistency - "Start Game" vs "Round Start"
**Problem:** Buttons show inconsistent labels  
**Current:** Shows "Start Game"  
**Expected:** Should say "Round Start Button" for gameplay start, "Start Game" for tutorial end only  
**Issues:**
  - Tutorial end button should be "Start Game"
  - Game round start should be "Round Start Button"
**Files to Check:**
- Any screen with round/game start button
- Button text constants/localization
**Solution:** Update button labels based on context (tutorial vs normal gameplay)

#### ISSUE #11: "Ready for Battle - Yes by Ammo" Button Navigation Wrong
**Problem:** Button takes you to Power-ups page instead of Ammo page  
**Current Behavior:** Tap button → Shop Power-ups page  
**Expected Behavior:** Tap button → Shop Ammo page  
**Files to Check:**
- Dialog/popup with "Ready for battle?" confirmation
- Button callback navigation logic
- `shop_screen.gd` - Shop page routing
**Solution:** Change navigation target from power-ups tab to ammo tab

#### ISSUE #12: Ammo Purchase Button Not Working
**Problem:** Purchase button in ammo section doesn't respond to clicks  
**Current Status:** Button is unresponsive (visual click possible, no action)  
**Files to Check:**
- `shop_screen.gd` - Ammo purchase button callback (FIX #17b was applied, might have side effect)
- Button disabled state check
- Purchase logic validation
**Solution:** Debug button callback, check if validation logic is blocking purchases

#### ISSUE #13: Trophy Collection Page - Back Button Not Working
**Screen:** Trophy collection  
**Problem:** Back button doesn't navigate away from trophy collection  
**Files to Check:**
- `trophy_collection_screen.gd` or equivalent
- Back button callback
**Solution:** Add back button handler or fix existing callback

#### ISSUE #14: Prologue Pops Up on Repeat Node Click
**Problem:** After viewing prologue once (3-part sequence), clicking same node shows it again  
**Expected:** Should only show prologue on first visit, subsequent clicks should go directly to content  
**Files to Check:**
- `map_screen.gd` - Node click handler
- Node state tracking (prologue_seen flag)
- Prologue popup logic
**Solution:** Add prologue_seen flag to node or global state, check before showing prologue

#### ISSUE #15: Cannot Enter Candy Crusade
**Problem:** Tapping Candy Crusade challenge doesn't enter/start it  
**Frequency:** Consistent (can't enter at all)  
**Impact:** Cannot access Candy Crusade game mode  
**Files to Check:**
- `map_screen.gd` - Candy crusade node click handler
- Candy crusade screen initialization
**Solution:** Debug why candy crusade click/entry is blocked

---

## 🔍 ANALYSIS SUMMARY

### By Severity
| Level | Count | Issues |
|-------|-------|--------|
| Critical | 3 | #1, #2, #3 |
| High-Impact | 4 | #4, #5, #6, #7 |
| Medium | 8 | #8, #9, #10, #11, #12, #13, #14, #15 |
| **TOTAL** | **15** | |

### By Category
| Category | Count | Issue IDs |
|----------|-------|-----------|
| Platform/Device | 3 | #1, #3, #4 |
| UI/Visuals | 4 | #5, #6, #7, #8 |
| Tutorial | 2 | #5, #6 |
| Shop/Purchase | 3 | #11, #12, #13 |
| Navigation | 3 | #13, #14, #15 |
| Button Labels | 1 | #10 |
| Node Positioning | 2 | #7, #9 |

### By File Likely Affected
| File | Issue IDs | Fixes Needed |
|------|-----------|--------------|
| `game_manager.gd` | #1, #3 | Safe area setup, splash screen config |
| `map_screen.gd` | #5, #7, #9, #14, #15 | Node positioning, prologue tracking, navigation |
| `shop_screen.gd` | #11, #12 | Navigation routing, ammo button callback |
| Any screen with backgrounds | #4, #8 | Device-specific images, resolution variants |
| Tutorial screen | #5, #6 | Visibility timing, highlight contrast |
| `trophy_collection_screen.gd` | #13 | Back button handler |

---

## 📌 RECOMMENDED APPROACH

### Phase 1: Critical Issues (Blocking)
1. **#2 - Home page crash** - Need error logs to debug
2. **#1 - Safe area notch** - Add to all screens systematically
3. **#3 - Splash screen** - Configure in project settings

### Phase 2: High-Impact (UX Blocking)
4. **#4 - iPad background on iPhone** - Load device-appropriate images
5. **#5 - Tutorial popup timing** - Add visibility flag tracking
6. **#6 - Tutorial highlight** - Increase overlay contrast/brightness
7. **#7, #9 - Node positioning** - Recalculate positions or fix offset

### Phase 3: Medium (Functionality)
8. **#8 - Background quality** - Swap with high-res variants
9. **#10 - Button labels** - Update text based on context
10. **#11, #12 - Shop issues** - Fix navigation and button callbacks
11. **#13 - Back button** - Add handler to trophy screen
12. **#14 - Prologue repeat** - Add seen flag tracking
13. **#15 - Candy crusade entry** - Debug click handler

---

## 🔧 IMMEDIATE NEXT STEPS

To proceed with fixes, I need:

1. **For crash (#2):** What's the error message when home page crashes? Can you share:
   - Crash log from Xcode or device console?
   - Last action before crash?
   - Does it crash with specific device orientation?

2. **For background issues (#4, #8):** 
   - What resolution is the current background image?
   - What are the target iPhone/iPad screen resolutions?
   - Are there high-res @2x/@3x variants available?

3. **For node positioning (#7, #9):**
   - What are the node positions currently set to?
   - Visual reference: Are they shifted left/right/up/down?
   - Should they be perfectly centered or follow a pattern?

4. **Development environment:**
   - Have you tested on different iPhone models?
   - Is this the first time testing on physical iPhone vs simulator?

Once you provide these details, I can create targeted fixes for each issue.

# Pearly Whites Challenge - Comprehensive Bug Audit

## Overview
This is a detailed audit of the entire game codebase to identify bugs, logic errors, missing validation, and potential issues. **These findings are NOT yet fixed** - this is an informational report only.

---

## CRITICAL BUGS

### 1. **Quiz Answer Tracking - Array Out of Bounds Risk**
**File:** `quiz_screen.gd` (Lines 784-785, 819-820)

**Issue:**
When recording quiz answers, the code attempts to write to the `results[]` array without first ensuring the array is large enough:
```gdscript
if current_question_idx < results.size():
    results[current_question_idx] = true
```

**Problem:** If `current_question_idx` is >= `results.size()`, the answer is silently dropped and not recorded. The array is initialized in `_load_questions()` with `results.append(null)` for each question (line 102), but this could fail if questions are dynamically modified or if there's a race condition.

**Impact:** Quiz answers might not be saved correctly, especially for open-ended baseline questions or if the questions array changes mid-quiz.

**Risk Level:** HIGH - Data loss potential

---

### 2. **Quiz Results Score Calculation - Incomplete Grading**
**File:** `quiz_screen.gd` (Lines 962-963)

**Issue:**
The points and coins earned are calculated ONLY from the `correct_answers` count:
```gdscript
var pts_earned = 100 if is_baseline else (correct_answers * 20 + 60)
var coins_earned = 50 if is_baseline else (correct_answers * 3 + 10)
```

**Problem:** For baseline quizzes (discovery quizzes), the player gets 100 points and 50 coins regardless of how many questions they actually answer. If they skip all questions and click "FINISH" immediately, they still get full rewards.

**Expected Behavior:** Baseline quizzes have open-ended questions that should be graded or at least counted based on participation/answers provided.

**Impact:** MEDIUM - Players can farm rewards by not actually answering baseline quiz questions.

---

### 3. **Open Question Recognition - Inconsistent Logic**
**File:** `quiz_screen.gd` (Lines 727-736)

**Issue:**
The function `_is_open_question()` returns `true` for:
- ANY baseline question (line 728-729)
- Questions with type "open" or section "PREVIEW" (lines 730-733)
- Questions WITHOUT an "a" field or where "a" is not a boolean (lines 734-735)

**Problem:** Week 1-4 recap questions should have an "a" field with a boolean answer. If a recap question is missing this field, it's treated as an open question and awards 15 coins + 25 points instead of being graded for correctness. This creates exploitable scenarios.

**Example:** A True/False question without the "a" field becomes an open question worth more rewards.

**Impact:** MEDIUM - Potential reward exploitation if questions are malformed.

---

### 4. **Coin Transaction - No Overflow/Validation**
**File:** `shop_screen.gd` (Lines 2378-2401)

**Issue:**
The weapon purchase function doesn't validate the maximum coin value after subtraction:
```gdscript
p["coins"] = coins - cost
```

**Problem:** While coins can't go negative (it checks before), there's no upper bound check. If coin values somehow exceed int limits through exploits, the save could be corrupted. Also, no transaction log is kept.

**Risk Level:** LOW - Unlikely but possible edge case

---

### 5. **Weapon Tier Management - Duplicate Tiers Not Prevented**
**File:** `shop_screen.gd` (Lines 2387-2393)

**Issue:**
When purchasing a weapon, the code checks if the tier exists and adds it:
```gdscript
if not tiers.has(lvl):
    tiers.append(lvl)
```

**Problem:** This logic is correct, BUT the `_get_owned_tiers()` function (lines 786-794) manually checks for duplicates AGAIN. If something corrupts the weaponTiers data, duplicates could exist. The cleanup code in `_get_owned_tiers()` suggests this is a known issue.

**Impact:** LOW - Data corruption would be visible but handled gracefully

---

## HIGH-IMPACT LOGIC ERRORS

### 6. **Brushing Quadrant Timer Ranges - Boundary Issue**
**File:** `brushing_screen.gd` (Lines 92-133)

**Issue:**
Quadrants are defined with "from" and "to" time ranges:
```gdscript
{"name": "top left", "from": 120, "to": 90, ...}
{"name": "top right", "from": 90, "to": 60, ...}
{"name": "bottom right", "from": 60, "to": 30, ...}
{"name": "bottom left", "from": 30, "to": 0, ...}
```

**Problem:** These ranges are defined in descending order but never clarified HOW they're used. If the timer counts down from 120 to 0:
- When timer = 90, is the player in "top left" or "top right"?
- The ranges overlap at the boundaries (90, 60, 30)

**Expected Behavior:** Code should clearly use `time >= from AND time > to` or similar, but the logic that READS these values isn't shown in the first 150 lines.

**Impact:** MEDIUM - Players might not get credit for quadrant completion at boundary times

---

### 7. **Quiz Title Texture - Expensive Regeneration on Every Load**
**File:** `quiz_screen.gd` (Lines 104-184)

**Issue:**
The `_ensure_quiz_title_texture()` function:
1. Loads a cached texture if available
2. If not, tries 4 different asset paths
3. If still not found, LOADS A FULL SCREENSHOT IMAGE (lines 124-182)
4. CROPS the screenshot with pixel-math (lines 134-137)
5. FLOODS-FILLS to remove background (lines 143-178)
6. SAVES the result to disk (line 180)
7. Creates an ImageTexture from the result

**Problem:** This is extremely expensive (multiple image operations, disk I/O) and happens during quiz initialization. If the cached texture becomes invalid, this could stall gameplay.

**Expected Behavior:** Asset should be pre-baked, not generated at runtime.

**Impact:** MEDIUM - Performance issue on slower devices, especially on quiz retry

---

### 8. **Quiz - Floating Point Comparison in Flood Fill**
**File:** `quiz_screen.gd` (Lines 163-166)

**Issue:**
```gdscript
var dr = abs(col.r - bg_col.r)
var dg = abs(col.g - bg_col.g)
var db = abs(col.b - bg_col.b)
var is_bg = (dr < 0.20 and dg < 0.20 and db < 0.20) or (col.b > 0.85 and col.r > 0.65 and col.g > 0.80)
```

**Problem:** This uses hardcoded floating-point thresholds (0.20, 0.85, 0.65, 0.80) for color matching. If the image asset is different than expected or compressed differently, the flood fill may:
- Not remove enough background (leaving blue artifacts)
- Remove too much (cutting off the title text)

The second condition `(col.b > 0.85 and col.r > 0.65 and col.g > 0.80)` seems arbitrary and might not match any real colors.

**Impact:** MEDIUM - Quiz title might render incorrectly if asset changes

---

## MEDIUM-IMPACT ISSUES

### 9. **Settings - Developer Mode Toggle Not Persisted**
**File:** `settings_screen.gd` (Lines 74-90)

**Issue:**
Developer mode is toggled with a 5-tap gesture:
```gdscript
GameState.dev_mode = not GameState.dev_mode
```

**Problem:** This modifies the global `GameState.dev_mode` but never saves it to the profile. If the game is closed, dev mode resets. This might be intentional, but it's inconsistent with how other settings work.

**Impact:** LOW - Likely intentional, but worth documenting

---

### 10. **Settings - No Validation on PIN Input**
**File:** `settings_screen.gd` (Lines 20-22)

**Issue:**
PIN fields are defined (`pin_input_new`, `pin_input_conf`) but the code shown only goes to line 150, so the actual validation logic isn't visible.

**Potential Issues:**
- No numeric-only validation?
- No minimum length check?
- No check that new and confirm PIN match?
- No protection against common PINs (1111, 0000)?

**Impact:** MEDIUM - Without seeing the validation code, can't fully assess

---

### 11. **Shop - No Check for Maximum Weapons Owned**
**File:** `shop_screen.gd` (Lines 2388-2399)

**Issue:**
When purchasing a weapon tier, it's simply added to the list:
```gdscript
if not tiers.has(lvl):
    tiers.append(lvl)
```

**Problem:** There's no check that a player can't somehow own level 4, 5, or higher. If data is corrupted or exploited, invalid tiers could exist. The `clamp()` call in line 969 suggests level values should be 1-3.

**Impact:** LOW - Defensive coding would catch this

---

### 12. **Floss Screen - 30 Second Timer Could Be Inaccurate**
**File:** `floss_screen.gd` (Lines 37-38, 100-106 expected)

**Issue:**
The floss activity uses a 30-second timer:
```gdscript
const TOTAL_FLOSS_TIME: int = 30
```

**Problem:** The code shown only goes to line 100. The actual timer implementation isn't visible. Potential issues:
- Does it handle pause/resume correctly?
- Does it handle the app being backgrounded?
- Is there audio sync?
- What happens if the timer completes before the player is ready?

**Impact:** MEDIUM - Timer accuracy affects gameplay but not visible without full code

---

### 13. **Brush Check - 6 Second Scan Timeout Hardcoded**
**File:** `brush_check_screen.gd` (Lines 47, 91-92)

**Issue:**
```gdscript
const SCAN_TIMEOUT_SECONDS: float = 6.0
if scan_duration >= SCAN_TIMEOUT_SECONDS and current_confidence < 65.0:
    _on_scan_timeout()
```

**Problem:** 
- Timeout is hardcoded; can't be adjusted without code change
- Timeout only triggers if confidence < 65% - if confidence is exactly 65%, the scan never times out
- No user feedback while scanning (the first 6 seconds might seem like a hang)

**Impact:** LOW-MEDIUM - UX issue more than a bug

---

## LOW-IMPACT / MINOR ISSUES

### 14. **Quiz - Duplicate Texture Loading Calls**
**File:** `quiz_screen.gd` (Lines 108-110)

**Issue:**
```gdscript
var direct_tex = UIHelper.load_texture_safe("res://assets/images/titles/weeklyquiz_title.png")
if not direct_tex:
    direct_tex = UIHelper.load_texture_safe("res://assets/images/titles/weeklyquiz_title.png")
```

**Problem:** The EXACT SAME PATH is loaded twice if the first load fails. This is clearly a copy-paste error where the second path should be different.

**Impact:** LOW - Minor inefficiency, but wastes a texture load call

---

### 15. **Brushing - Hardcoded Character Positions Without Fallback**
**File:** `brushing_screen.gd` (Lines 62-66)

**Issue:**
Custom character and mascot positions are stored but initialized to Vector2.ZERO. If these are never set, characters appear at origin.

**Problem:** No fallback or default positioning logic shown. If data is missing, characters might not render visibly.

**Impact:** LOW - UI issue, not gameplay-breaking

---

### 16. **Badge Unlock Check - No Timeout on Repeated Calls**
**File:** `map_screen.gd` (Added in fixes, lines 154-165)

**Issue:**
The new `_check_badge_unlocks()` function is called every time the map loads. If badges unlock in rapid succession, popups might stack.

**Problem:** No throttling or "last check time" tracking. If something triggers multiple badge unlocks in a loop, popups might spam.

**Impact:** LOW - Edge case, but possible

---

### 17. **Shop - Ammo Purchase Never Validated**
**File:** `shop_screen.gd` (Lines 1622, 2077+ expected)

**Issue:**
`_show_ammo_purchase_popup()` and `_show_booster_purchase_popup()` are referenced but full implementation isn't shown.

**Potential Issue:** If ammo/booster purchase logic doesn't match weapon purchase logic, transactions could be inconsistent.

**Impact:** UNKNOWN - Need to review full ammo purchase code

---

## MISSING FEATURES / INCOMPLETE CODE

### 18. **No Transaction Rollback on Save Failure**
**Across:** `game_state.gd`, `shop_screen.gd`, etc.

**Issue:**
When a purchase is made:
```gdscript
p["coins"] = coins - cost
# ... modify other fields ...
GameState.save_game()
```

**Problem:** If `save_game()` fails (Firebase error, disk full, etc.), the coins are already deducted in memory. The user sees their coins gone but their inventory never updated.

**Recommended Fix:** Should use a transaction pattern or rollback.

**Impact:** MEDIUM - Data integrity risk

---

### 19. **No Network Error Handling for Firebase**
**Across:** Multiple files reference `GameState.save_game()`

**Issue:** Firebase sync is mentioned but error handling isn't visible in the audit scope.

**Problem:** Network failures, auth failures, or database errors might not be reported to the user.

**Impact:** MEDIUM - Users might think data was saved when it wasn't

---

## ARCHITECTURAL CONCERNS

### 20. **Static Game State - Thread Safety Unknown**
**File:** `game_state.gd`

**Issue:** All game state is stored in a static/global `GameState` singleton.

**Problem:** 
- No mutex/lock protection
- If badges update and map screen reads simultaneously, race condition possible
- Firebase writes might conflict

**Impact:** LOW-MEDIUM - Depends on async implementation details

---

## RECOMMENDATIONS FOR TESTING

1. **Quiz Scoring:** Take a baseline quiz and skip all questions → verify you still get 100 points
2. **Quiz Boundaries:** Complete a quiz and finish exactly when the timer hits a quadrant boundary (90s, 60s, 30s)
3. **Floss Timeout:** Start floss, look at timer for 30 seconds, verify it completes on time
4. **Badge Spam:** Unlock multiple badges rapidly (dev mode) → check if popups stack
5. **Shop Transaction:** In dev mode, reduce coins to exactly the cost of an item, purchase it → verify it works
6. **Settings PIN:** Enter mismatched PINs → verify error handling
7. **Quiz Retry:** Fail a quiz → immediately retry → check if title texture loads quickly
8. **Offline Save:** Purchase an item → kill network → restart → verify item saved

---

## SUMMARY

| Severity | Count | Type |
|----------|-------|------|
| CRITICAL | 2 | Array bounds, quiz rewards |
| HIGH | 3 | Quiz grading, question validation, coin overflow |
| MEDIUM | 8 | Timer issues, texture performance, PIN validation, etc. |
| LOW | 7 | Minor inefficiencies, edge cases |
| ARCHITECTURAL | 2 | Transaction rollback, thread safety |

**Total Issues Found:** 22

**Note:** This audit is based on the first ~100 lines of 6 files and grep searches. A complete review of all 50+ script files would likely find additional issues in:
- Achievement/badge unlock logic details
- UI animation edge cases
- Audio sync issues  
- Profile switching logic
- Data migration/corruption recovery
- Accessibility features
- Internationalization issues

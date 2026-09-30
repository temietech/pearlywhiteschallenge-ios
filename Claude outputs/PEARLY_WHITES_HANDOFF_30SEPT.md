# Pearly Whites Challenge: Full Hand-off for the Next AI (30 Sept 2026)

Compiled from the three chats pasted in `stepsfortoday.txt` plus what this session (chat 2) can see. Duplicates are merged. Anything that only appears in one chat is tagged with its source. **Nothing listed as "done" below has been verified on the user's computer unless it says so.** Times are the user's local time (UTC+3).

- **Chat 1**: the chat that did the popup, voice, notification and plugin work (14:39 to 16:28).
- **Chat 2**: this session (map/quiz rollback investigation, UIHelper parser fix, badges back button, Bonbon Bash, GLB compression).
- **Chat 3**: the chat that did the camera permission, splash screen, Candy Crusade, map recovery and git work.

---

## 0. Ground rules (read before touching anything)

1. **The user has been burned by overwrites today.** Three different chats wrote to the same folder. Files went back to older versions (map_screen.gd, quiz_screen.gd, main.gd, others).
2. **Before changing any file:** read it fresh from the user's folder, note its size and modified time, and compare with the table in section 3. Never edit from a cached or staged copy.
3. **One file at a time.** After each write, read it back from the user's folder and confirm the size and the specific lines changed. Report the file, the new size and what was verified.
4. **Do not write in bulk, and do not pass a stale copy.** If a file's size or time is not what you expect, stop and ask.
5. **Ask the user to close Summer Engine / Godot completely** before writing any file. The editor re-saves open scripts and is a likely cause of some overwrites (Chat 3 says so about map_screen.gd).
6. **Do not use "restore", "rewind" or "discard" actions** in the chat app or the editor. They roll back other files.
7. **Nothing built today has been tested on a device.** Do not report a feature as working. Say it is written and untested.
8. **Do not create new files inside `scripts/` that Godot could load by accident.** Recovery copies use `.gd.txt` names on purpose.
9. **User's environment:**
   - Engine: Godot-based (they use Summer Engine).
   - Project path: `C:\Users\temie\Documents\Personal Life\Pearly White\Challenge\App\Pearly Whites Challenge`
   - Target: iOS (iPhone and iPad). Builds go through Git and a GitHub workflow, and use Git Bash.
   - Debugger showed 82 errors in the last screenshot (16:42).
   - Apple-oriented items: privacy policy, parental gate, COPPA considerations, App Store build number.

---

## 1. What the user asked for, in order (merged, no duplicates)

### Before 12:20 and only known from summaries (no wording, no times)
- Flossing should be asked "every time you brush".
- 7 questions on day 28.
- Move the points and the streak display.
- Shop purchase popup.
- Prologue and keyboard fixes.
- The "got it" popup appears twice.
- No music until Start Brushing.
- Volume sliders and on/off buttons in audio settings.
- White backing on the leave-early popup.
- Map screen (around 13:00, from the status note `game_review_status.md`):
  - Remove drag-and-drop so nodes stay fixed.
  - 70 node positions (saved in `map_layout.json`).
  - Start and finish buttons 20% bigger.
  - Node 0 uses `start_btn.png`; finish node uses `finishbtn.png`.
  - Tutorial and daily stamp card must not appear on the same screen.
- Brushing screen (same note): make Sir Crown larger; make the speech bubble bigger and move it right and down; text must fit the bubble.
- Audio (same note): character voices and narration 30% louder (`VOICE_GAIN` 1.3), music and effects unchanged.

### From Chat 2 (this session), in order
1. Candy Crusade: remove the target image in the middle, because it distracts.
2. Confirm camera permission is asked after the privacy policy, and that everything needed for camera testing (including MediaPipe) is on.
3. Bonbon Bash on iPhone: minions come out beside the holes instead of from inside.
4. "These errors must be fixed pls" (the `UIHelper` parser error).
5. Badges screen: title should be an image, not text; back button doesn't respond.
6. Why the project is 640 MB (wanted 300) and the iOS app 340 MB (wanted 200): led to GLB compression, which was abandoned at 16:39.
7. Player Setup screen: "Submit Answer" button. The user says it used to be something else and can't remember what. **Unresolved.**
8. Rollback investigation (read-only), then the pasted-chat question, then this hand-off.

### From Chat 1 (with times)
1. 14:39: the leave-early page needs a white popup behind it.
2. 14:59: the voice sounds like Arab English, not British English, especially on the brushing page.
3. 15:00: remove the target image in the middle of Candy Crusade (repeat of Chat 2 item 1).
4. 15:03: sound turned off on the brushing page can't be turned back on from settings.
5. 15:34 to 15:53: how push notifications work; the approved list; "connect it to godot"; 7 am and 7 pm; 7:30 for the daily reward. The user dropped the badge and reward-chest notifications and asked the AI to download the plugin itself.
6. 16:07 to 16:28: the user uses Summer Engine; screenshots asking what to do, whether the plugin zip is in the right place, and the plugin warning screenshot.
7. 17:09 and 17:25: the two read-only investigation requests.

### From Chat 3 (in order; times not visible)
1. Camera permission after the privacy policy, plus the App Store build number.
2. Git Bash steps to commit and push.
3. Splash screen fill for iPhone and iPad.
4. Whether it was only 4 files (advice).
5. Three Candy Crusade changes: chest item closer to the camera, minion spawn rush, halved knockback.
6. The `UIHelper` errors.
7. "Why padlocks, why nodes moved, why not `start_btn.png`" on the map.
8. Investigations: where the save data is, whether compression caused the rollback, the other chats, file-time clues, the recovered map file, the recovery snapshot branch, questions for the other chats.

---

## 2. Per-file / per-page instructions for the AI

Each entry: **what the user wants**, **what was done (and by which chat)**, **what the AI must do next**.

### 2.1 `scripts/map_screen.gd` (map page)
- **Wants:** fixed nodes (no dragging), the 70 positions from `map_layout.json`, start/finish 20% bigger (`Vector2(46, 32) * 1.2`), node 0 = `start_btn.png`, finish = `finishbtn.png`, **no padlock icons**, tutorial and daily stamp card not on the same screen, scroll position saved and restored.
- **History:** rolled back at about 12:24 (new `.uid`) and overwritten again at 14:43. At 14:43 it matched `map_screen-1.gd` plus a few "FIX:" edits. Chat 1 edited it at 14:41 to 14:43 (prologue/keyboard). Chat 3 rewrote it from an old lineage and reports the disk size (36,601) doesn't match what it saved (35,361), so the editor may have re-saved it.
- **Recovery copies:** Chat 3 saved `Claude outputs/map_screen_RECOVERED_1425.gd.txt` and `map_screen_CURRENT_before_restore.gd.txt`. Chat 2's staged copy of the device file (33,981 bytes, from the 13:31 modification) is probably the same content as the 14:25 recovery. **This is unverified; compare before trusting either.**
- **AI must:** read the current file; diff against `map_screen_RECOVERED_1425.gd.txt` and `map_layout.json`; restore only the missing wanted features; confirm no `_input`/`dragging_node`/`edit_mode` and no padlock code remain; verify the start/finish sizing and both textures; separate the tutorial and daily stamp card behaviour; do not touch anything else.

### 2.2 `scripts/quiz_screen.gd`
- **Wants:** prologue and keyboard fixes; quiz answer tracking with array bounds protection (from the 14:00 status note).
- **History:** rewritten at 14:43 (same second as `map_screen.gd`; same size, 40,824). Chat 1 edited it at 14:41 to 14:43. Chat 2's staged copy is 40,826 bytes.
- **AI must:** read current; confirm the prologue and keyboard handling still exist; do not replace with any older copy without a diff.

### 2.3 `scripts/ui_helper.gd`
- **Wants:** no parser errors; keyboard handling for input fields.
- **History:** Chat 2 fixed a missing `)` on the `line_edit.focus_entered.connect(...)` call (about line 3229). Chat 3 says it rewrote only the keyboard block at the end. Chat 1 added keyboard functions. **These three edits may conflict.** Chat 3 says this is the only file it verified on the PC.
- **AI must:** read the file; count parentheses; confirm no duplicate keyboard functions; confirm `UIHelper` resolves in dependent scripts (the error was `Could not resolve class 'UIHelper' at line 129,9`); check the debugger error count.

### 2.4 `scripts/settings_screen.gd`
- **Wants:** audio settings with volume sliders and on/off buttons; sound turned off on the brushing page must be turnable back on; notification settings.
- **History:** Chat 1 edited it at 14:41 to 14:43 (keyboard); added a Master Mute toggle at 15:04 (may not restart the music); added notification hooks at 15:42 to 15:53. Chat 3 shows possible overwrites.
- **AI must:** confirm the sliders and on/off buttons exist; confirm un-muting restarts music and narration; confirm the notification hooks; test in the editor before claiming success.

### 2.5 `scripts/badges_screen.gd`
- **Wants:** a working back button; an **image** title instead of text.
- **History:** Chat 2 added `var back_btn: TextureButton`, protected it in `_rebuild_ui()`, and created it only once in `_build_ui()`. The image title was **not** confirmed done.
- **AI must:** verify the back button fix is on the device; ask which image to use for the title, then implement it; confirm taps work on a phone.

### 2.6 `scripts/whack_screen.gd` (Bonbon Bash)
- **Wants:** minions come out of the holes, not beside them, on iPhone.
- **History:** Chat 2 changed `_relayout()` so the board uses `UIHelper.safe_top` and `UIHelper.safe_bottom` (`top_bound = 165.0 + safe_top`, `bottom_bound = cur_h - 75.0 - safe_bottom`). Untested on a device.
- **AI must:** confirm the change is on the device; if minions are still offset, inspect how each minion's position is computed relative to its hole.

### 2.7 `scripts/brushing_screen.gd`
- **Wants:** larger Sir Crown; larger, repositioned speech bubble with fitting text; British English voice; no music until Start Brushing; leave-early popup with white backing; sound off/on working; the flossing prompt "every time you brush".
- **History:** Chat 1 added the British voice picker (needs a British voice on the phone). The leave-early popup already had a white card, so Chat 1 changed nothing; the user still says it needs a white popup behind it. **Unresolved.**
- **AI must:** ask the user for a screenshot of the leave-early popup; verify the crown/bubble constants; confirm music starts only on Start Brushing; confirm the voice on a real device.

### 2.8 `scripts/audio_manager.gd`
- **Wants:** voices 30% louder; British voice; music only after Start Brushing; mute that can be reversed.
- **History:** `VOICE_GAIN` 1.3 was set; Chat 1 added the British voice picker.
- **AI must:** verify `VOICE_GAIN` is still applied to `play_character_voice()` and `play_voice_narration()`; verify mute/unmute restarts playback.

### 2.9 `scripts/start_screen.gd` (splash)
- **Wants:** splash background fills the iPhone and iPad screen.
- **History:** Chat 3 edited this **only in its own copy**. The PC file is still the old 4,116-byte version.
- **AI must:** re-read the PC file and apply the scaling change (fill/cover behaviour for iPhone and iPad), then verify.

### 2.10 `scripts/main.gd`
- **Wants:** camera permission asked after the privacy policy; notification scheduling hook; prologue behaviour.
- **History:** Chat 3 edited it for the camera flow (the code appears on the PC). Chat 1 added notification hooks. Device size was 19,742 at 14:51. My staged copy at 14:36 was smaller.
- **AI must:** confirm the camera-after-privacy sequence and the notification initialisation are both present.

### 2.11 `scripts/brush_check_screen.gd` (camera / MediaPipe)
- **Wants:** camera opens for testing; MediaPipe active.
- **History:** Chat 3 edited it; camera code is on the PC. Chat 2 wrote a verification note.
- **AI must:** check that the Info.plist camera usage text and the export settings are in place, then test the permission prompt on a device.

### 2.12 Player Setup page (the "Submit Answer" button)
- **Wants:** the button should not say "Submit Answer" (user doesn't remember the old label).
- **Unknown:** which script builds this screen. It's not in `whack_screen.gd`. Likely `select_player_screen.gd`, `profiles_screen.gd` or `create_profile_screen.gd`.
- **AI must:** grep the project for `SUBMIT ANSWER` and `ADD USER`; ask the user what the label should be; do not guess.

### 2.13 Candy Crusade (`candy_crusade/scripts/hud.gd`, `ammo_crate.gd`, `minion.gd`)
- **Wants:** remove the target image in the middle; chest item closer to the camera; minion spawn rush; halved knockback.
- **History:**
  - Chat 1 commented out the HUD crosshair in `hud.gd`. **The AI assumed that was the image and never confirmed it.**
  - Chat 3 edited `ammo_crate.gd` (chest closer) and `minion.gd` (spawn rush and halved knockback) **only in its own copy. None of this is on the PC.**
- **AI must:** confirm with the user that the crosshair is the "target image"; re-apply the three changes to the PC files.

### 2.14 Notifications (`scripts/local_notifications.gd`, `project.godot`, `addons/`, `ios/plugins/`)
- **Wants:** local reminders at **7 AM and 7 PM**, and **7:30** for the daily reward. The badge and reward-chest notifications were dropped.
- **History:** Chat 1 created `local_notifications.gd`, added hooks in `main.gd`, `project.godot` and `settings_screen.gd`, and unpacked the plugin zip into `addons/` and `ios/plugins/` (17 files). It also fixed a signal name. Summer Engine could not load the plugin, and the user was told to restart it. The plugin warning screenshot was sent; the answer isn't visible.
- **AI must:** ask for the current plugin warning text; verify the plugin files and the 3 schedule times; confirm the settings toggles. Untested.

### 2.15 Privacy policy, parental gate, modals (`privacy_policy_modal.gd`, `privacy_policy_screen.gd`, `parental_gate_modal.gd`, `modal_manager.gd`)
- **Wants:** the "got it" popup shows once, not twice; camera permission follows the privacy policy.
- **History:** Chat 2 wrote notes on the double-tap, popup and modal fixes (`DOUBLE_TAP_FIX_SUMMARY.md`, `POPUP_FIX_COMPREHENSIVE.md`, `MODAL_INTEGRATION_QUICK_START.md`). It is unclear which of those code changes landed on the PC.
- **AI must:** read the current files and check the "got it" popup is created only once.

### 2.16 Other pages with earlier requests (only known from summaries)
- **Flossing** ("every time you brush"): likely `floss_screen.gd` and the brushing flow.
- **7 questions on day 28:** likely `quiz_screen.gd` and `game_state.gd`.
- **Move points and streak:** likely `top_bar.gd`.
- **Shop purchase popup:** likely `shop_screen.gd`.
- **AI must:** ask the user for each requirement in their words, then check the files. Chat 3 says it cannot confirm these survived the overwrites.

### 2.17 GLB compression (optional, abandoned)
- 25 GLB files, about 212 MB; largest are `blue_candor.glb` (21.2 MB), `BlueCandorHit.glb` (17.1), `EnamelBorder-Region4.glb` (14.4), `AmmoChestOpen.glb` (12.4), `AmmoChestClosed.glb` (11.0).
- Scripts exist (`compress_glb_v2.js`, `compress_glb_local.js`, `setup_compression.bat`, `compress_glb_models_local.bat`); the user chose to leave it and it must not be re-run without being asked. The first script failed and left files intact.

### 2.18 Git and build (Chat 3)
- Workflow file edited for the App Store build number. It did not show as changed in `git status`, so it may never have landed.
- Chat 3 created a **recovery snapshot branch**. Ask which name it used; do not delete or reset anything.

---

## 3. Known file sizes and times (device, local time)

| File | Size | Modified | Source |
|---|---|---|---|
| `map_screen-1.gd` | 35,693 | 11:01 | listing (a copy the user did not create) |
| `main-1.gd` | 16,777 | 11:01 | listing (same) |
| `map_screen.gd` | 32,567 | 11:41 | 12:15 listing |
| `map_screen.gd` | 33,981 | 13:31 | 13:58 listing |
| `map_screen.gd` | 36,533 | 14:43:36 | 14:58 listing |
| `map_screen.gd` | 36,601 | now | Chat 3 |
| `quiz_screen.gd` | 40,824 | 14:43:37 | 14:58 listing |
| `main.gd` | 19,742 | 14:51:22 | 14:58 listing |
| `start_screen.gd` | 4,116 | (old) | Chat 3 |
| `map_layout.json` | 834 | 12:31 | 13:58 listing |

Copies held by chat 2 (cloud only; not on the PC): `map_screen` 33,981 and `quiz_screen` 40,826, staged around 14:25.

---

## 4. Open questions to settle with the user first

1. What did the Player Setup button say before "Submit Answer"?
2. Is the Candy Crusade crosshair the "target image" they meant?
3. What exactly is wrong with the leave-early popup now (screenshot)?
4. Which image should the badges title use?
5. What is the current plugin warning text in Summer Engine?
6. Name of the recovery snapshot branch, and whether `map_screen_RECOVERED_1425.gd.txt` is the version they want.
7. Which tool wrote at 14:43 (Summer Engine's AI panel showed "Changes 39 files")? Check its change list.
8. Are Godot's 82 debugger errors the ones they wanted fixed? Ask for the list.

## 5. Suggested order of work

1. User closes Summer Engine; take a fresh backup.
2. Read-only audit: list `scripts/` and compare sizes and times with section 3.
3. `ui_helper.gd` (parser errors) so the debugger count is meaningful.
4. `map_screen.gd`, then `quiz_screen.gd`, then `main.gd`.
5. Candy Crusade re-apply (`hud.gd`, `ammo_crate.gd`, `minion.gd`).
6. `start_screen.gd` splash.
7. Audio (`audio_manager.gd`, `settings_screen.gd`, `brushing_screen.gd`).
8. Notifications and plugin.
9. Badges title, Player Setup button, leave-early popup.
10. Camera and privacy flow verification, then git commit on a new branch.

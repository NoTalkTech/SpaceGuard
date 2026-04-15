# Status Bar Regression

This script verifies the menu bar actions tied to `Analyze Disk` and `Quick Cleanup`.

## Preconditions

- Build succeeds: `swift build`
- Launch the app bundle: `open /Users/biyu.huang/code/SpaceGuard/SpaceGuard.app`
- Make sure the SpaceGuard status bar icon is visible
- If possible, use a test machine or disposable account with cache/log files available

## Analyze Disk

1. Click the SpaceGuard status bar icon.
2. Click `Analyze Disk`.
3. Confirm the status bar button immediately changes to a busy state such as `Scanning`.
4. Confirm the menu shows a foreground status line describing the current work.
5. Wait for completion.
6. Confirm the status line reaches a terminal state containing `Scan complete` or `Scan failed`.
7. Confirm the button briefly shows `Done` or `Failed` before returning to its idle appearance.

Expected result:
- The menu action gives immediate foreground feedback in the menu bar.
- The user can tell the app is working without opening the main window.

## Quick Cleanup

1. Click the SpaceGuard status bar icon.
2. Click `Quick Cleanup`.
3. Confirm the status bar button immediately changes to a busy state such as `Cleaning`.
4. Confirm the menu shows a foreground status line describing the current work.
5. Wait for the quick scan to finish.
6. If low-risk files are found, confirm the cleanup confirmation sheet opens.
7. Expand one risk group and verify representative directories and large files appear.
8. Click `Open` on a directory row and verify Finder opens that path.
9. Cancel the sheet.

Expected result:
- The menu action produces visible foreground UI in the menu bar.
- The confirmation sheet remains responsive with very large result sets.
- The sheet stays focused on review, not on full file browsing.

## Large Result Set Sanity Check

Use this when the quick cleanup result set is very large.

1. Open the confirmation sheet from `Quick Cleanup`.
2. Expand the largest visible risk group.
3. Confirm only a small set of representative directories and files is shown.
4. Click `Open` on one representative directory.
5. Dismiss Finder and return to the confirmation sheet.
6. Expand another risk group.

Expected result:
- No crash when expanding a large section.
- No freeze caused by rendering or sorting a full file tree.
- The review sheet remains usable even when the result set is very large.

## Regression Notes

If any step fails, capture:

- which menu item was used
- whether the status bar button changed state
- the menu activity text during the run
- the final terminal status text
- whether the confirmation sheet opened
- approximately how many files were in the result set

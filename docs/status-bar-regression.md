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
3. Confirm the Settings window opens and selects the `Cleanup` tab automatically.
4. Confirm the progress area appears in the `Quick Actions` section.
5. Wait for completion.
6. Confirm a top banner appears in the `Cleanup` page with a success or failure result.
7. Confirm the progress status text changes to a terminal state containing `Scan complete` or `Scan failed`.

Expected result:
- The menu action is visibly routed into the `Cleanup` page.
- The user sees progress without relying on system notifications.

## Quick Cleanup

1. Click the SpaceGuard status bar icon.
2. Click `Quick Cleanup`.
3. Confirm the Settings window opens and selects the `Cleanup` tab automatically.
4. Wait for the quick scan to finish.
5. If low-risk files are found, confirm the cleanup confirmation sheet opens.
6. In the sheet, confirm the default view is `Directories`.
7. Expand one directory and verify file rows appear inline.
8. Click `Open` on a directory row and verify Finder opens that path.
9. Click `Copy Path` and verify the pasted clipboard value matches the directory path.
10. Cancel the sheet.

Expected result:
- The menu action produces visible foreground UI.
- The confirmation sheet remains responsive with large result sets.
- Directory rows support inline inspection and utility actions.

## Large Result Set Sanity Check

Use this when the quick cleanup result set is very large.

1. Open the confirmation sheet from `Quick Cleanup`.
2. Keep the view in `Directories`.
3. Change sort order to `Largest First`, then `Most Files`.
4. Expand one large directory.
5. Click `Show More` multiple times in the directory list and in the inline file list if available.
6. Switch to `Files`.
7. Use the filter box with a directory name, extension, or app name.

Expected result:
- No crash when expanding a large section.
- No freeze when paging through more rows.
- Filtering and sorting stay responsive.

## Regression Notes

If any step fails, capture:

- which menu item was used
- whether the Settings window opened
- whether the `Cleanup` tab was selected
- the final `currentStatus` text shown in the progress area
- whether a banner appeared
- whether the confirmation sheet opened
- approximately how many files were in the result set

# Session Recovery Checklist

1. Read `doc/SuiSakhi_PROJECT_CONTEXT.md`.
2. Read `doc/SuiSakhi_CATALOGUE_CRITICAL_CONTEXT_18SEP2026.md`.
3. Confirm branch: `suisakhi-android-package-migration`.
4. Confirm commit `c9add10` exists.
5. Run `flutter analyze lib`; expected result is no issues.
6. Run `git status --short` and do not use `git add .`.
7. Verify Admin multi-view upload and gallery before changing correction logic.
8. Preserve legacy single-view fallback.
9. Preserve immutable original Storage assets and submitted Versions.
10. Update both context documents after the correction milestone and commit them.

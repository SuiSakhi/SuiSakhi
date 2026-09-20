# Common Partner Profile P1.1 Test Checklist

## Static validation
- [ ] `dart format` succeeds
- [ ] `flutter analyze lib` reports no issues
- [ ] `git diff --check` returns no output

## Designer validation
- [ ] Designer profile opens My Catalogue Designs by default
- [ ] Face icon opens Partner Workspace
- [ ] My Profile opens existing read-only profile
- [ ] Business Details opens approved common and Designer-specific data
- [ ] Addresses opens approved address/service-area data or a clear empty state
- [ ] Back returns to Partner Workspace
- [ ] My Catalogue Designs remains fully functional

## Tailor/common validation
- [ ] Approved generic Tailor profile can open Partner Workspace
- [ ] Header displays Tailor Partner
- [ ] My Profile, Business Details and Addresses use the same common screens
- [ ] Tailor-specific approved partnerData is displayed without a Tailor-only profile screen
- [ ] Tailor Operations remains Coming Soon

## Security and regression
- [ ] Screens are read-only
- [ ] Customer delivery addresses are not modified
- [ ] No Firestore or Storage deployment is required
- [ ] Admin Catalogue review remains working
- [ ] Designer upload, correction and resubmission remain working

# Partner Workspace Phase P1 Test Checklist

## Static validation
- [ ] `dart format` succeeds for all package Dart files
- [ ] `flutter analyze lib` reports no new issues
- [ ] `git diff --check` returns no output

## Designer pilot
- [ ] Select approved Designer profile
- [ ] Partner Workspace opens
- [ ] Header shows business name, Designer Partner, Approved, KYC Verified, Operationally Active
- [ ] My Profile opens read-only approved data
- [ ] My Catalogue Designs opens existing Catalogue screen
- [ ] Designer Catalogue Back returns to Partner Workspace
- [ ] Partner Account icon opens My Profile
- [ ] Upload, review, correction and resubmit remain working

## Account actions
- [ ] Change Profile loads live active profiles
- [ ] Customer profile returns to Customer Home
- [ ] Designer profile returns to Partner Workspace
- [ ] Logout returns to Login

## Admin regression
- [ ] Governed Catalogue opens
- [ ] Designer submission appears
- [ ] Request Changes, Approve and Reject remain working

## Negative tests
- [ ] Missing account/profile context shows a clear error
- [ ] Customer profile cannot open Partner Workspace
- [ ] Unapproved/KYC-unverified profile is denied
- [ ] No Firestore or Storage rule deployment is needed

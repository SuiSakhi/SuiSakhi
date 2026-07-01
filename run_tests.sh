#!/bin/bash
# ────────────────────────────────────────────────────────────────
# StitchSmart – Automated Test Runner
# Boots an iOS simulator, runs unit tests + integration tests,
# then prints a summary.
#
# Usage:
#   chmod +x run_tests.sh
#   ./run_tests.sh
#
# Optional: pass a simulator name as argument
#   ./run_tests.sh "iPhone 17 Pro"
# ────────────────────────────────────────────────────────────────

set -e  # stop on first error

# ── Config ──────────────────────────────────────────────────────
SIMULATOR_NAME="${1:-iPhone 17 Pro}"
PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
PASS=0
FAIL=0
RESULTS=()

# ── Colors ──────────────────────────────────────────────────────
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_step()  { echo -e "\n${BLUE}▶ $1${NC}"; }
print_ok()    { echo -e "${GREEN}✔ $1${NC}"; }
print_fail()  { echo -e "${RED}✘ $1${NC}"; }
print_warn()  { echo -e "${YELLOW}⚠ $1${NC}"; }

# ── Step 1: Boot simulator ───────────────────────────────────────
print_step "Finding simulator: $SIMULATOR_NAME"

DEVICE_ID=$(xcrun simctl list devices available | grep "$SIMULATOR_NAME" | head -1 | grep -oE '[A-F0-9-]{36}')

if [ -z "$DEVICE_ID" ]; then
  print_fail "Simulator '$SIMULATOR_NAME' not found."
  echo "Available simulators:"
  xcrun simctl list devices available | grep -E "iPhone|iPad"
  exit 1
fi

print_ok "Found: $DEVICE_ID"

DEVICE_STATE=$(xcrun simctl list devices | grep "$DEVICE_ID" | grep -oE 'Booted|Shutdown')

if [ "$DEVICE_STATE" = "Booted" ]; then
  print_ok "Simulator already booted."
else
  print_step "Booting simulator..."
  xcrun simctl boot "$DEVICE_ID"
  open -a Simulator --args -CurrentDeviceUDID "$DEVICE_ID"
  echo -n "Waiting for simulator to be ready"
  until xcrun simctl list devices | grep "$DEVICE_ID" | grep -q "Booted"; do
    echo -n "."
    sleep 1
  done
  sleep 3  # extra settling time
  echo ""
  print_ok "Simulator booted."
fi

cd "$PROJECT_DIR"

# ── Step 2: flutter pub get ──────────────────────────────────────
print_step "Installing dependencies (flutter pub get)..."
flutter pub get
print_ok "Dependencies ready."

# ── Step 3: Unit & widget tests (no device needed) ──────────────
print_step "Running unit tests..."

run_unit_test() {
  local label="$1"
  local file="$2"
  if flutter test "$file" --no-pub 2>&1 | tail -5 | grep -q "All tests passed"; then
    print_ok "$label"
    RESULTS+=("PASS: $label")
    ((PASS++)) || true
  else
    print_fail "$label"
    RESULTS+=("FAIL: $label")
    ((FAIL++)) || true
    flutter test "$file" --no-pub 2>&1 | tail -10
  fi
}

run_unit_test "Models: DressOrder & OrderStatus"     "test/models/dress_test.dart"
run_unit_test "Models: UserProfile & Gender"         "test/models/user_profile_test.dart"
run_unit_test "Models: BodyMeasurements"             "test/models/measurement_test.dart"
run_unit_test "Models: StitchingRate"                "test/models/stitching_rate_test.dart"
run_unit_test "Services: ClaudePricingService"       "test/services/claude_pricing_service_test.dart"
run_unit_test "Widget smoke test"                    "test/widget_test.dart"

# ── Step 4: Integration tests (requires simulator) ───────────────
print_step "Running integration tests on $SIMULATOR_NAME..."
print_warn "This launches the full app — Firebase must be reachable."

if flutter test integration_test/app_test.dart \
    --device-id "$DEVICE_ID" \
    --no-pub 2>&1 | tail -5 | grep -q "All tests passed"; then
  print_ok "Integration tests: PASSED"
  RESULTS+=("PASS: Integration tests (guest flow)")
  ((PASS++)) || true
else
  print_fail "Integration tests: FAILED"
  RESULTS+=("FAIL: Integration tests (guest flow)")
  ((FAIL++)) || true
  flutter test integration_test/app_test.dart \
    --device-id "$DEVICE_ID" \
    --no-pub 2>&1 | tail -20
fi

# ── Step 5: Summary ──────────────────────────────────────────────
echo ""
echo "══════════════════════════════════════════"
echo "  TEST SUMMARY"
echo "══════════════════════════════════════════"
for r in "${RESULTS[@]}"; do
  if [[ $r == PASS* ]]; then
    echo -e "  ${GREEN}✔${NC} ${r#PASS: }"
  else
    echo -e "  ${RED}✘${NC} ${r#FAIL: }"
  fi
done
echo "──────────────────────────────────────────"
echo -e "  ${GREEN}Passed: $PASS${NC}   ${RED}Failed: $FAIL${NC}"
echo "══════════════════════════════════════════"

if [ "$FAIL" -gt 0 ]; then
  exit 1
else
  print_ok "All tests passed!"
  exit 0
fi

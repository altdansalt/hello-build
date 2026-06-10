#!/bin/sh
# Polarity check (ADR 0015): run one real upstream .t through the cram
# runner with a deliberately wrong binary; the suite must fail. A harness
# that stays green with the wrong binary under test is vacuous.
set -eu

if "$CRAM_RUNNER" --binary /bin/true --setup "$SETUP" "$TEST_T" > polarity.log 2>&1; then
    echo "FAIL: cram suite passed with /bin/true as the binary under test" >&2
    cat polarity.log >&2
    exit 1
fi
echo "ok: suite fails with the wrong binary"

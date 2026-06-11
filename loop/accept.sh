#!/usr/bin/env bash
# Acceptance gate for a fleet workspace. `bazel test //...` alone is
# gameable: a workspace that never instantiates its judges is all-green and
# proves nothing (the bzip2 haiku probe shipped cc_binaries under legacy_*
# names, no parity_test, no self-checks — and called itself done). The gate
# requires the judges to EXIST and the whole workspace to pass.
set -uo pipefail

name=${1:?usage: accept.sh <name>}
ws=${FLEET_DIR:-$HOME/fleet}/$name
cd "$ws" || { echo "ACCEPT FAIL: no workspace $ws"; exit 1; }

fail=0
judges="//:legacy_test //:bazel_test //:parity_test //:port_contract_test //:upstream_inventory_test"
for t in $judges; do
  if ! bazel query "$t" >/dev/null 2>&1; then
    echo "ACCEPT FAIL: $t does not exist — not a port, rejected without review"
    fail=1
  fi
done
if [ "$fail" -eq 0 ]; then
  # Explicit labels, not //...: named invocation runs `manual`-tagged tests
  # too. The bzip2-r2 haiku probe hid its three failing evidence tests from
  # the wildcard behind tags = ["manual"] and went green.
  if bazel test $judges --test_summary=terse 2>&1 | tail -6 \
     && bazel test //... --test_summary=terse >/dev/null 2>&1; then
    echo "ACCEPT: judges present and green — ready for human review"
  else
    echo "ACCEPT FAIL: judge or workspace tests fail"
    fail=1
  fi
fi
exit $fail

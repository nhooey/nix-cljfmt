#!/usr/bin/env bash
# Smoke test for the packaged cljfmt and the dev shell's commands that wrap it.
#
# Usage: tests/smoke.sh CLJFMT_PACKAGE DEVSHELL VERSION
#   CLJFMT_PACKAGE  store path of the cljfmt package (has bin/cljfmt)
#   DEVSHELL        store path of the built dev shell (has bin/cljfmt, bin/fmt-check, bin/fmt-fix)
#   VERSION         the cljfmt version the package should report
#
# Runs in a scratch directory and exits non-zero on the first failed case.
set -euo pipefail

if [ "$#" -ne 3 ]; then
  echo "usage: $0 CLJFMT_PACKAGE DEVSHELL VERSION" >&2
  exit 2
fi
package=$1
devshell=$2
version=$3

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
cd "$work"

failures=0

fail() {
  echo "FAIL: $*" >&2
  failures=$((failures + 1))
}

# Runs a command, captures its output in $work/out, and records a failure
# unless it exits with the wanted status.
expect_status() {
  local want=$1
  shift
  local got=0
  "$@" >"$work/out" 2>&1 || got=$?
  if [ "$got" -ne "$want" ]; then
    fail "'$*' exited $got, want $want; output:"
    sed 's/^/  | /' "$work/out" >&2
  fi
}

# Runs a command with $1 as its working directory.
run_in() {
  local dir=$1
  shift
  (cd "$dir" && "$@")
}

# Writes a correctly formatted file to $1.
write_good() {
  cat >"$1" <<'CLJ'
(ns example.core)

(defn add-one [x]
  (+ x 1))
CLJ
}

# Writes the same code, misindented, to $1.
write_bad() {
  cat >"$1" <<'CLJ'
(ns example.core)

(defn add-one [x]
(+ x 1))
CLJ
}

# Each case runs cljfmt the way one entry point does: the package's binary
# directly, or a dev-shell command.
for cljfmt in "$package/bin/cljfmt" "$devshell/bin/cljfmt"; do
  echo "case: $cljfmt --version reports $version"
  expect_status 0 "$cljfmt" --version
  grep -qx "cljfmt $version" "$work/out" ||
    fail "'$cljfmt --version' printed '$(cat "$work/out")', want 'cljfmt $version'"

  echo "case: $cljfmt check passes a well-formatted file"
  write_good good.clj
  expect_status 0 "$cljfmt" check good.clj

  echo "case: $cljfmt check fails a misindented file and names it"
  write_bad bad.clj
  expect_status 1 "$cljfmt" check bad.clj
  grep -q 'bad.clj' "$work/out" ||
    fail "'$cljfmt check bad.clj' output does not name bad.clj"

  echo "case: $cljfmt fix reindents a misindented file"
  write_good want.clj
  expect_status 0 "$cljfmt" fix bad.clj
  cmp -s bad.clj want.clj || fail "'$cljfmt fix bad.clj' left: $(cat bad.clj)"

  rm -f good.clj bad.clj want.clj
done

# fmt-check and fmt-fix work on the current directory.
echo "case: fmt-check fails a project with a misindented file"
mkdir project
write_bad project/bad.clj
expect_status 1 run_in project "$devshell/bin/fmt-check"

echo "case: fmt-fix reindents the project, and fmt-check then passes"
expect_status 0 run_in project "$devshell/bin/fmt-fix"
write_good want.clj
cmp -s project/bad.clj want.clj || fail "fmt-fix left: $(cat project/bad.clj)"
expect_status 0 run_in project "$devshell/bin/fmt-check"

if [ "$failures" -ne 0 ]; then
  echo "$failures case(s) failed" >&2
  exit 1
fi
echo "all cases passed"

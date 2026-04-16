#!/usr/bin/env bats
# shellcheck shell=bash

@test "envfile-parse" {
  # shellcheck disable=SC1091
  source "${BATS_TEST_DIRNAME}/../../include/buildpack.bash"
  local fixture_filename
  local foo_expected='Hello'$'\n'' '\''world'\'' '
  local bar_expected='te'\''st'
  local nested_foo_expected=foo
  local nested_bar_expected=foo

  fixture_filename="${BATS_TEST_DIRNAME}/fixtures/complicated_envfile"
  eval "$(_envfile-parse <"$fixture_filename")"

  # shellcheck disable=2154
  if [[ ! "$foo_expected" == "$foo" ]]; then
    echo "Expected foo = $foo_expected got: $foo"
    return 1
  fi

  # shellcheck disable=2154
  if [[ ! "$bar_expected" == "$bar" ]]; then
    echo "Expected bar = $bar_expected got: $bar"
    return 2
  fi

  # shellcheck disable=2154
  if [[ ! "$nested_foo_expected" == "$nested_foo" ]]; then
    echo "Expected nested_foo = $nested_foo_expected got: $nested_foo"
    return 3
  fi

  # shellcheck disable=2154
  if [[ ! "$nested_bar_expected" == "$nested_bar" ]]; then
    echo "Expected nested_bar = $nested_bar_expected got: $nested_bar"
    return 4
  fi
}

@test "buildpack-install-invalid-url" {
  # Regression test for gliderlabs/herokuish#553: a non-URL input like "ruby"
  # must fail up-front with an actionable error instead of silently installing
  # an empty buildpack directory.
  # shellcheck disable=SC1091
  source "${BATS_TEST_DIRNAME}/../../include/buildpack.bash"

  # Stub out ensure-paths and scope buildpack_path to a temp dir so the test
  # does not touch /tmp/buildpacks or require the outer scope vars.
  local tmpdir
  tmpdir="$(mktemp -d)"
  # shellcheck disable=SC2317
  ensure-paths() { :; }
  # shellcheck disable=SC2034
  local buildpack_path="$tmpdir"

  run buildpack-install "ruby" "" "custom"
  rm -rf "$tmpdir"

  [[ "$status" -ne 0 ]] || {
    echo "Expected non-zero exit code for invalid URL, got 0"
    echo "output: $output"
    return 1
  }
  [[ "$output" == *"Invalid buildpack URL: 'ruby'"* ]] || {
    echo "Expected 'Invalid buildpack URL' message, got: $output"
    return 2
  }
}

@test "buildpack-install-unrecognised-archive" {
  # An http(s) URL that is not a known archive extension and is not a reachable
  # git remote should fail with an explicit "not a recognised archive" error
  # rather than silently running tar with empty args.
  # shellcheck disable=SC1091
  source "${BATS_TEST_DIRNAME}/../../include/buildpack.bash"

  local tmpdir
  tmpdir="$(mktemp -d)"
  # shellcheck disable=SC2317
  ensure-paths() { :; }
  # shellcheck disable=SC2034
  local buildpack_path="$tmpdir"

  # Use a reserved-for-documentation host so git ls-remote definitely fails
  # and the tarball branch is reached without network access attempting real
  # downloads.
  run buildpack-install "https://example.invalid/not-an-archive" "" "custom"
  rm -rf "$tmpdir"

  [[ "$status" -ne 0 ]] || {
    echo "Expected non-zero exit code for unrecognised archive URL, got 0"
    echo "output: $output"
    return 1
  }
  [[ "$output" == *"not a reachable git remote or a recognised archive"* ]] || {
    echo "Expected 'not a reachable git remote or a recognised archive' message, got: $output"
    return 2
  }
}

@test "procfile-parse-valid" {
  # shellcheck disable=SC1091
  source "${BATS_TEST_DIRNAME}/../../include/procfile.bash"
  local expected actual app_path
  app_path="${BATS_TEST_DIRNAME}/fixtures"
  for type in web worker; do
    case "$type" in
      web)
        expected="npm start"
        ;;
      worker)
        expected="npm worker"
        ;;
    esac
    actual=$(procfile-parse "$type" | xargs)
    if [[ "$actual" != "$expected" ]]; then
      echo "$actual != $expected"
      return 1
    fi
  done
}

@test "procfile-parse-merge-conflict" {
  # shellcheck disable=SC1091
  source "${BATS_TEST_DIRNAME}/../../include/procfile.bash"
  local expected actual app_path
  app_path="${BATS_TEST_DIRNAME}/fixtures-merge-conflict"
  for type in web worker; do
    case "$type" in
      web)
        expected="npm start"
        ;;
      worker)
        expected="npm worker"
        ;;
    esac
    actual=$(procfile-parse "$type" | xargs)
    if [[ "$actual" != "$expected" ]]; then
      echo "$actual != $expected"
      return 1
    fi
  done
}

@test "procfile-parse-invalid" {
  # shellcheck disable=SC1091
  source "${BATS_TEST_DIRNAME}/../../include/procfile.bash"
  local expected actual app_path
  app_path="${BATS_TEST_DIRNAME}/fixtures"

  expected="Proc entrypoint invalid-proc does not exist. Please check your Procfile"
  run procfile-start invalid-proc
  [[ "$status" -eq 1 ]]
  [[ "$output" == "$expected" ]] || {
    echo "procfile-start did not throw error for invalid procfile"
    echo "expected: $expected"
    echo "actual:   $output"
    return 1
  }
}

@test "procfile-types" {
  title() {
    # shellcheck disable=SC2317
    :
  }
  # shellcheck disable=SC1091
  source "${BATS_TEST_DIRNAME}/../../include/procfile.bash"
  local expected actual app_path
  app_path="${BATS_TEST_DIRNAME}/fixtures"

  expected="Procfile declares types -> web, worker"
  actual="$(procfile-types invalid-proc | tail -1)"

  if [[ "$actual" != "$expected" ]]; then
    echo "$actual != $expected"
    return 1
  fi
}

@test "procfile-types-merge-conflict" {
  title() {
    # shellcheck disable=SC2317
    :
  }
  # shellcheck disable=SC1091
  source "${BATS_TEST_DIRNAME}/../../include/procfile.bash"
  local expected actual app_path
  app_path="${BATS_TEST_DIRNAME}/fixtures-merge-conflict"

  expected="Procfile declares types -> web, worker"
  actual="$(procfile-types invalid-proc | tail -1)"

  if [[ "$actual" != "$expected" ]]; then
    echo "$actual != $expected"
    return 1
  fi
}

@test "procfile-load-env" {
  # shellcheck disable=SC1091
  source "${BATS_TEST_DIRNAME}/../../include/procfile.bash"
  local expected actual app_path env_path
  env_path="${BATS_TEST_DIRNAME}/fixtures/env"

  procfile-load-env
  actual="$TEST_BUILDPACK_URL"
  expected="$(cat "$env_path/TEST_BUILDPACK_URL")"

  if [[ "$actual" != "$expected" ]]; then
    echo "$actual != $expected"
    return 1
  fi
  unset TEST_BUILDPACK_URL
}

@test "procfile-load-profile" {
  # shellcheck disable=SC1091
  source "${BATS_TEST_DIRNAME}/../../include/procfile.bash"
  local expected actual app_path
  # shellcheck disable=SC2034
  app_path="${BATS_TEST_DIRNAME}/fixtures"

  procfile-load-profile
  actual="$TEST_APP_TYPE"
  expected="nodejs"

  if [[ "$actual" != "$expected" ]]; then
    echo "$actual != $expected"
    return 1
  fi
}

# The following two tests pass an invalid command so the underlying `exec`
# fails before it can hijack the test shell. We assert that procfile-exec
# actually reaches the exec step and that exec emits a "command not found"
# error, which proves the function executed end-to-end.
@test "procfile-exec" {
  # shellcheck disable=SC1091
  source "${BATS_TEST_DIRNAME}/../../include/procfile.bash"
  # shellcheck disable=SC2034
  app_path="${BATS_TEST_DIRNAME}/fixtures"
  # shellcheck disable=SC2034
  env_path="$app_path/env"
  export HEROKUISH_DISABLE_CHOWN=true

  run procfile-exec invalid
  # exec of an unknown command exits 127; older bats lacks `run -127`
  [[ "$status" -eq 127 ]] || {
    echo "expected procfile-exec to exit 127, got $status"
    echo "output: $output"
    return 1
  }
  # On systems with setuidgid the missing binary is `invalid`; without it
  # (e.g. local dev), bash reports `setuidgid: not found`. Either proves
  # the exec step was reached.
  [[ "$output" == *"not found"* ]] || {
    echo "expected 'not found' in output, got: $output"
    return 1
  }
}

@test "procfile-exec-setuidgid-optout" {
  # shellcheck disable=SC1091
  source "${BATS_TEST_DIRNAME}/../../include/procfile.bash"
  # shellcheck disable=SC2034
  app_path="${BATS_TEST_DIRNAME}/fixtures"
  # shellcheck disable=SC2034
  env_path="$app_path/env"
  export HEROKUISH_DISABLE_CHOWN=true
  export HEROKUISH_SETUIDGUID=false

  run procfile-exec invalid
  # exec of an unknown command exits 127; older bats lacks `run -127`
  [[ "$status" -eq 127 ]] || {
    echo "expected procfile-exec to exit 127, got $status"
    echo "output: $output"
    return 1
  }
  # With setuidgid bypassed, exec runs `invalid` directly so the missing
  # binary in the error message is `invalid`.
  [[ "$output" == *"invalid"*"not found"* ]] || {
    echo "expected 'invalid ... not found' in output, got: $output"
    return 1
  }
}

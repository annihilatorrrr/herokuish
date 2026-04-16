# shellcheck shell=bash

T_envfile-parse() {
  # shellcheck disable=SC1091
  source "$(dirname "${BASH_SOURCE[0]}")/../../include/buildpack.bash"
  local fixture_filename
  local foo_expected='Hello'$'\n'' '\''world'\'' '
  local bar_expected='te'\''st'
  local nested_foo_expected=foo
  local nested_bar_expected=foo

  fixture_filename="$(dirname "${BASH_SOURCE[0]}")/fixtures/complicated_envfile"
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

T_buildpack-install-invalid-url() {
  # Regression test for gliderlabs/herokuish#553: a non-URL input like "ruby"
  # must fail up-front with an actionable error instead of silently installing
  # an empty buildpack directory.
  # shellcheck disable=SC1091
  source "$(dirname "${BASH_SOURCE[0]}")/../../include/buildpack.bash"

  # Stub out ensure-paths and scope buildpack_path to a temp dir so the test
  # does not touch /tmp/buildpacks or require the outer scope vars.
  local tmpdir
  tmpdir="$(mktemp -d)"
  # shellcheck disable=SC2317
  ensure-paths() { :; }
  local buildpack_path="$tmpdir"
  local output rc

  output="$(buildpack-install "ruby" "" "custom" 2>&1)"
  rc=$?
  rm -rf "$tmpdir"

  if [[ "$rc" -eq 0 ]]; then
    echo "Expected non-zero exit code for invalid URL, got 0"
    echo "output: $output"
    return 1
  fi

  if [[ "$output" != *"Invalid buildpack URL: 'ruby'"* ]]; then
    echo "Expected 'Invalid buildpack URL' message, got: $output"
    return 2
  fi
}

T_buildpack-install-unrecognised-archive() {
  # An http(s) URL that is not a known archive extension and is not a reachable
  # git remote should fail with an explicit "not a recognised archive" error
  # rather than silently running tar with empty args.
  # shellcheck disable=SC1091
  source "$(dirname "${BASH_SOURCE[0]}")/../../include/buildpack.bash"

  local tmpdir
  tmpdir="$(mktemp -d)"
  # shellcheck disable=SC2317
  ensure-paths() { :; }
  local buildpack_path="$tmpdir"
  local output rc

  # Use a reserved-for-documentation host so git ls-remote definitely fails
  # and the tarball branch is reached without network access attempting real
  # downloads.
  output="$(buildpack-install "https://example.invalid/not-an-archive" "" "custom" 2>&1)"
  rc=$?
  rm -rf "$tmpdir"

  if [[ "$rc" -eq 0 ]]; then
    echo "Expected non-zero exit code for unrecognised archive URL, got 0"
    echo "output: $output"
    return 1
  fi

  if [[ "$output" != *"not a reachable git remote or a recognised archive"* ]]; then
    echo "Expected 'not a reachable git remote or a recognised archive' message, got: $output"
    return 2
  fi
}

T_procfile-parse-valid() {
  # shellcheck disable=SC1091
  source "$(dirname "${BASH_SOURCE[0]}")/../../include/procfile.bash"
  local expected actual app_path
  app_path="$(dirname "${BASH_SOURCE[0]}")/fixtures"
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

T_procfile-parse-merge-conflict() {
  # shellcheck disable=SC1091
  source "$(dirname "${BASH_SOURCE[0]}")/../../include/procfile.bash"
  local expected actual app_path
  app_path="$(dirname "${BASH_SOURCE[0]}")/fixtures-merge-conflict"
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

T_procfile-parse-invalid() {
  # shellcheck disable=SC1091
  source "$(dirname "${BASH_SOURCE[0]}")/../../include/procfile.bash"
  local expected actual app_path
  app_path="$(dirname "${BASH_SOURCE[0]}")/fixtures"

  expected="Proc entrypoint invalid-proc does not exist. Please check your Procfile"
  actual="$(procfile-start invalid-proc)"

  if [[ "$actual" != "$expected" ]]; then
    echo "procfile-start did not throw error for invalid procfile"
    return 1
  fi
}

T_procfile-types() {
  title() {
    # shellcheck disable=SC2317
    :
  }
  # shellcheck disable=SC1091
  source "$(dirname "${BASH_SOURCE[0]}")/../../include/procfile.bash"
  local expected actual app_path
  app_path="$(dirname "${BASH_SOURCE[0]}")/fixtures"

  expected="Procfile declares types -> web, worker"
  actual="$(procfile-types invalid-proc | tail -1)"

  if [[ "$actual" != "$expected" ]]; then
    echo "$actual != $expected"
    return 1
  fi
}

T_procfile-types-merge-conflict() {
  title() {
    # shellcheck disable=SC2317
    :
  }
  # shellcheck disable=SC1091
  source "$(dirname "${BASH_SOURCE[0]}")/../../include/procfile.bash"
  local expected actual app_path
  app_path="$(dirname "${BASH_SOURCE[0]}")/fixtures-merge-conflict"

  expected="Procfile declares types -> web, worker"
  actual="$(procfile-types invalid-proc | tail -1)"

  if [[ "$actual" != "$expected" ]]; then
    echo "$actual != $expected"
    return 1
  fi
}

T_procfile-load-env() {
  # shellcheck disable=SC1091
  source "$(dirname "${BASH_SOURCE[0]}")/../../include/procfile.bash"
  local expected actual app_path env_path
  env_path="$(dirname "${BASH_SOURCE[0]}")/fixtures/env"

  procfile-load-env
  actual="$TEST_BUILDPACK_URL"
  expected="$(cat "$env_path/TEST_BUILDPACK_URL")"

  if [[ "$actual" != "$expected" ]]; then
    echo "$actual != $expected"
    return 1
  fi
  unset TEST_BUILDPACK_URL
}

T_procfile-load-profile() {
  # shellcheck disable=SC1091
  source "$(dirname "${BASH_SOURCE[0]}")/../../include/procfile.bash"
  local expected actual app_path
  # shellcheck disable=SC2034
  app_path="$(dirname "${BASH_SOURCE[0]}")/fixtures"

  procfile-load-profile
  actual="$TEST_APP_TYPE"
  expected="nodejs"

  if [[ "$actual" != "$expected" ]]; then
    echo "$actual != $expected"
    return 1
  fi
}

#the following two tests needs to launch an invalid command,
#or else shell is hijacked by suceeding exec, so rather than no test
#it is better to pass a failing cmd, so that we can check we pass exec step
T_procfile-exec() {
  # shellcheck disable=SC1091
  source "$(dirname "${BASH_SOURCE[0]}")/../../include/procfile.bash"
  local expected actual

  actual=procfile-exec invalid
  expected=".*invalid: command not found.*"

  if [[ "$actual" =~ $expected ]]; then
    echo "$actual =~ $expected"
    return 1
  fi
}

T_procfile-exec-setuidgid-optout() {
  # shellcheck disable=SC1091
  source "$(dirname "${BASH_SOURCE[0]}")/../../include/procfile.bash"
  local expected actual

  export HEROKUISH_SETUIDGUID=false
  actual=procfile-exec invalid
  expected=".*invalid: command not found.*"

  if [[ "$actual" =~ $expected ]]; then
    echo "$actual =~ $expected"
    return 1
  fi
}

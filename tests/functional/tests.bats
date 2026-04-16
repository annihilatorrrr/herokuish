#!/usr/bin/env bats
# shellcheck shell=bash

herokuish-test() {
  declare name="$1" script="$2"
  # shellcheck disable=SC2046,SC2154
  docker run $([[ "$CI" ]] || echo "--rm") -v "$PWD:/mnt" \
    "herokuish:dev" bash -c "set -e; $script"
}

fn-source() {
  # use this if you want to write tests
  # in functions instead of strings.
  # see test-binary for trivial example
  # shellcheck disable=SC2086
  declare -f $1 | tail -n +2
}

teardown_file() {
  echo "Tests cleanup"
  local procfile
  procfile="${BATS_TEST_DIRNAME}/Procfile"
  if [[ -f "$procfile" ]]; then
    rm -f "$procfile"
  fi
}

@test "binary" {
  _test-binary() {
    # shellcheck disable=SC2317
    herokuish
  }
  herokuish-test "test-binary" "$(fn-source _test-binary)"
}

@test "default-user" {
  _test-user() {
    # shellcheck disable=SC2317
    id herokuishuser
  }
  herokuish-test "test-user" "$(fn-source _test-user)"
}

@test "generate-slug" {
  herokuish-test "test-slug-generate" "
		herokuish slug generate
		tar tzf /tmp/slug.tgz"
}

@test "buildpack-detect-default" {
  herokuish-test "buildpack-detect-default" "
    set -e
    unset BUILDPACK_URL
    export buildpack_path=/tmp/buildpacks
    export build_path=/tmp/app
    export unprivileged_user=\$(whoami)
    export unprivileged_group=\$(id -gn)

    rm -rf \$buildpack_path && mkdir -p \$buildpack_path

    mkdir -p \$buildpack_path/00_buildpack-ruby/bin
    {
      echo '#!/usr/bin/env bash'
      echo 'echo Ruby'
      echo 'exit 0'
    } > \$buildpack_path/00_buildpack-ruby/bin/detect
    chmod +x \$buildpack_path/00_buildpack-ruby/bin/detect

    herokuish buildpack detect | grep 'Ruby app detected'
  "
}

@test "buildpack-detect-fail" {
  herokuish-test "buildpack-detect-fail" "
    set -e
    unset BUILDPACK_URL
    export buildpack_path=/tmp/buildpacks
    export build_path=/tmp/app
    export unprivileged_user=\$(whoami)
    export unprivileged_group=\$(id -gn)

    rm -rf \$buildpack_path && mkdir -p \$buildpack_path

    mkdir -p \$buildpack_path/00_buildpack-fail/bin
    {
      echo '#!/usr/bin/env bash'
      echo 'exit 1'
    } > \$buildpack_path/00_buildpack-fail/bin/detect
    chmod +x \$buildpack_path/00_buildpack-fail/bin/detect

    herokuish buildpack detect 2>&1 | grep 'Unable to select a buildpack'
  "
}

# Regression tests for gliderlabs/herokuish#553: a failing custom buildpack
# download must exit non-zero with an actionable error instead of stopping
# silently. Each case points BUILDPACK_URL at a different class of bad input.

@test "buildpack-install-invalid-url" {
  herokuish-test "buildpack-install-invalid-url" "
    set +e
    export BUILDPACK_URL=ruby
    output=\$(herokuish buildpack install \"\$BUILDPACK_URL\" 2>&1)
    rc=\$?
    set -e
    if [[ \"\$rc\" -eq 0 ]]; then
      echo 'expected non-zero exit, got 0'
      echo \"\$output\"
      exit 1
    fi
    echo \"\$output\" | grep -q \"Invalid buildpack URL: 'ruby'\"
  "
}

@test "buildpack-install-bad-tarball-url" {
  herokuish-test "buildpack-install-bad-tarball-url" "
    set +e
    export BUILDPACK_URL=https://example.invalid/does-not-exist.tar.gz
    output=\$(herokuish buildpack install \"\$BUILDPACK_URL\" 2>&1)
    rc=\$?
    set -e
    if [[ \"\$rc\" -eq 0 ]]; then
      echo 'expected non-zero exit, got 0'
      echo \"\$output\"
      exit 1
    fi
    echo \"\$output\" | grep -q 'Failed to download buildpack'
  "
}

@test "buildpack-detect-bad-buildpack-url" {
  herokuish-test "buildpack-detect-bad-buildpack-url" "
    set +e
    export buildpack_path=/tmp/buildpacks
    export build_path=/tmp/app
    export unprivileged_user=\$(whoami)
    export unprivileged_group=\$(id -gn)
    export BUILDPACK_URL=ruby

    rm -rf \$buildpack_path && mkdir -p \$buildpack_path
    mkdir -p \$build_path

    output=\$(herokuish buildpack detect 2>&1)
    rc=\$?
    set -e
    if [[ \"\$rc\" -eq 0 ]]; then
      echo 'expected non-zero exit, got 0'
      echo \"\$output\"
      exit 1
    fi
    echo \"\$output\" | grep -q \"Invalid buildpack URL: 'ruby'\"
    echo \"\$output\" | grep -q 'Unable to fetch custom buildpack from ruby'
  "
}

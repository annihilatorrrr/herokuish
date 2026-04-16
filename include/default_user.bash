#!/usr/bin/env bash

addgroup --quiet --gid "32767" "herokuishuser" \
  && adduser \
    --shell /bin/bash \
    --disabled-password \
    --force-badname \
    --no-create-home \
    --uid "32767" \
    --gid "32767" \
    --gecos '' \
    --quiet \
    --home "/app" \
    "herokuishuser"

# tty group is needed when herokuish is run with `docker run -t`, so the
# unprivileged user can open /dev/pts/N (root:tty, mode 220). Harmless on
# runs without a tty.
usermod -aG tty herokuishuser

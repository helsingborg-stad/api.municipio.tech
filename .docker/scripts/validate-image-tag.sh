#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 1 ] || [[ ! "$1" =~ ^[A-Za-z0-9_][A-Za-z0-9_.-]{0,127}$ ]]; then
  echo 'Image tag must be 1-128 characters, start with a letter, digit or underscore, and contain only letters, digits, underscores, periods or hyphens.' >&2
  exit 1
fi

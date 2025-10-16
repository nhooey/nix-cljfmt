#!/usr/bin/env bash

set -xeu -o pipefail

export CLJNIX_ADD_NIX_STORE='true'
nix run github:jlesquembre/clj-nix#deps-lock

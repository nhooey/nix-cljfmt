# nix-cljfmt

[![built with garnix](https://img.shields.io/endpoint.svg?url=https%3A%2F%2Fgarnix.io%2Fapi%2Fbadges%2Fnhooey%2Fnix-cljfmt)](https://garnix.io/repo/nhooey/nix-cljfmt)

A Nix Flake package for [`weavejester/cljfmt`](https://github.com/weavejester/cljfmt).

## Version

This package is currently pegged to [`weavejester/cljfmt 0.15.2`](https://github.com/weavejester/cljfmt/releases/tag/0.15.2).

## Building

1. Lock the Clojure Nix build with `clj-nix` by running this script in a terminal (outside of any Nix shell):
```bash
bin/nix-deps-lock.sh
```

2. Enter the Nix shell:
```bash
nix develop
# The `numtide/devshell` menu will be displayed, showing the available commands
```

3. Build
```bash
nix build
```

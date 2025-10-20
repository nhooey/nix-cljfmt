# nix-cljfmt

A Nix Flake package for [`weavejester/cljfmt`](https://github.com/weavejester/cljfmt).

## Version

This package is currently pegged to [`weavejester/cljfmt 0.14.0`](https://github.com/weavejester/cljfmt/releases/tag/0.14.0).

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

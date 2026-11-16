# nix-cljfmt

A Nix Flake package for [`weavejester/cljfmt`](https://github.com/weavejester/cljfmt).

## Version

This package builds [`weavejester/cljfmt 0.15.2`](https://github.com/weavejester/cljfmt/releases/tag/0.15.2).

## Building

1. Enter the Nix shell with `nix develop`. Run `menu` to list its commands.
2. Build with `nix build`, and check with `nix flake check`.

## Updating cljfmt

`nix-cljfmt bump VERSION` points `deps.edn`, `flake.nix` and this README at another upstream tag, then regenerates `deps-lock.json` with `nix-cljfmt lock`. `nix-cljfmt version --check` says whether they all agree. Run `nix-cljfmt --help` for the options.

The dev shell can't build while `deps.edn` and `deps-lock.json` disagree. When that happens, run the same tool from the checkout as `bin/nix-cljfmt lock`, with `python3`, `git` and `nix` on `PATH`.

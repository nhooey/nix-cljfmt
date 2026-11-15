# nix-cljfmt

A Nix flake that packages [weavejester/cljfmt](https://github.com/weavejester/cljfmt) with clj-nix, pinned in `deps.edn` to one cljfmt release. `src/cljfmt/wrapper.clj` is a `:gen-class` namespace that delegates to `cljfmt.main`, since `mkCljApp` needs one for AOT compilation, and `deps-lock.json` pins the Clojure dependencies.

## Build and test

- `bin/nix-deps-lock.sh`: regenerates `deps-lock.json` after `deps.edn` changes; run it outside any Nix shell.
- `nix build`: builds the `cljfmt` package; `nix run` runs it.
- `nix flake check`: evaluates the package, the app and the dev shell.
- `nix develop`: the dev shell, with `cljfmt`, `fmt-check`, `fmt-fix`, `repl` and `deps-tree`, and the project's skills installed into `.agents/skills/` from the `skills-devshell/` sub-flake.

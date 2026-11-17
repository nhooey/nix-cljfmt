# nix-cljfmt

A Nix flake that packages [weavejester/cljfmt](https://github.com/weavejester/cljfmt) with clj-nix, pinned in `deps.edn` to one cljfmt release. `src/cljfmt/wrapper.clj` is a `:gen-class` namespace that delegates to `cljfmt.main`, since `mkCljApp` needs one for AOT compilation, and `deps-lock.json` pins the Clojure dependencies.

## Build and test

- `nix-cljfmt`: the dev shell's maintenance tool. `nix-cljfmt bump VERSION` moves `deps.edn`, `flake.nix` and the README to another cljfmt tag and relocks. `nix-cljfmt lock` regenerates `deps-lock.json` from `deps.edn`. `nix-cljfmt version --check` fails unless all four files state one version. Use `--dry-run` to preview a bump or lock. When the lock is stale the dev shell won't build, so run it as `bin/nix-cljfmt` from the checkout.
- `nix build`: builds the `cljfmt` package; `nix run` runs it.
- `nix flake check`: builds the package and the dev shell, runs `nix-cljfmt`'s tests and `version --check`, runs `tests/smoke.sh` (cljfmt `check` and `fix` on good and misindented code, through the package binary and the dev shell's `cljfmt`, `fmt-check` and `fmt-fix`), and checks formatting.
- `nix develop`: the dev shell, with `cljfmt`, `fmt-check`, `fmt-fix`, `repl`, `deps-tree` and `nix-cljfmt`, and the project's skills installed into `.agents/skills/` from the `skills-devshell/` sub-flake: skillspkgs' `nix-tooling` combination, plus `nix-clojure` for packaging cljfmt with clj-nix.

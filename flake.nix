{
  description = "Build cljfmt (weavejester/cljfmt) using clj-nix, with a runnable package and dev shell";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";
    flake-utils.url = "github:numtide/flake-utils";
    clj-nix.url = "github:jlesquembre/clj-nix";
    devshell.url = "github:numtide/devshell";
    # The builder library, not a skill: its `lib.devshellSkillsHook` wires the
    # `skills-devshell/` sub-flake into the dev shell. The skill sources live
    # only in that sub-flake's lock, invoked at runtime, so this flake carries
    # no skill inputs.
    agent-skill-flake = {
      url = "github:nhooey/agent-skill-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    { self
    , nixpkgs
    , flake-utils
    , clj-nix
    , devshell
    , agent-skill-flake
    , ...
    }@inputs:

    flake-utils.lib.eachDefaultSystem (system:
    let
      pkgs = nixpkgs.legacyPackages.${system};

      # Installs the `skills-devshell/` sub-flake's skills into `.agents/skills/`
      # on entering the dev shell, and adds the `skills` commands.
      devshellSkills = agent-skill-flake.lib.devshellSkillsHook { };

      # Build the Clojure app using clj-nix, sourcing deps from the local deps.edn.
      # The clj-nix overlay exposes the `clj-nix` namespace on pkgs.
      cljfmt-app = clj-nix.lib.mkCljApp {
        pkgs = pkgs;
        modules = [
          {
            # Use this repository (contains deps.edn with cljfmt dependency)
            projectSrc = ./.;
            name = "cljfmt";
            version = "0.15.2";
            # Use wrapper namespace with :gen-class that delegates to cljfmt.main
            # This is required because mkCljApp needs :gen-class for AOT compilation
            main-ns = "cljfmt.wrapper";
            # Use the locally generated deps-lock.json for reproducible builds
            lockfile = ./deps-lock.json;
          }
        ];
      };

    in
    {
      # Expose the cljfmt app as our default package
      packages.default = cljfmt-app;
      packages.cljfmt = cljfmt-app;

      # Expose a flake app for `nix run` convenience
      apps.default = {
        type = "app";
        program = "${cljfmt-app}/bin/cljfmt";
      };

      # Developer shell with categorized commands using numtide/devshell
      devShells.default = devshell.legacyPackages.${system}.mkShell {
        name = "nix-cljfmt-dev";
        devshell.startup.install-skills.text = devshellSkills.startup;
        packages = [
          pkgs.git
          pkgs.jq
          pkgs.curl
          pkgs.clojure
          pkgs.openjdk
        ];
        commands = [
          {
            name = "cljfmt";
            category = "clojure";
            help = "Run cljfmt (built via clj-nix)";
            command = "${cljfmt-app}/bin/cljfmt";
          }
          {
            name = "repl";
            category = "clojure";
            help = "Start a Clojure REPL with clojure CLI";
            command = "clj";
          }
          {
            name = "fmt-check";
            category = "quality";
            help = "Check formatting of current project (reads from stdin / files)";
            command = "${cljfmt-app}/bin/cljfmt check .";
          }
          {
            name = "fmt-fix";
            category = "quality";
            help = "Fix formatting of current project";
            command = "${cljfmt-app}/bin/cljfmt fix .";
          }
          {
            name = "deps-tree";
            category = "diagnostics";
            help = "Show tools.deps dependency tree (if tools/alias present)";
            command = "clj -Stree || true";
          }
        ] ++ devshellSkills.commands;
      };
    }
    );
}

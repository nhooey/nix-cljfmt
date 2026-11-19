{
  description = "nix-cljfmt dev-shell skill set — an isolated sub-flake invoked at RUNTIME by the root devShell, never a root input, so the skill sources live only in THIS flake's lock.";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    systems.url = "github:nix-systems/default";

    # The builder lib; it carries no skill inputs.
    agent-skill-flake = {
      url = "github:nhooey/agent-skill-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Skill sources. They follow `nixpkgs` but not `agent-skill-flake`, so
    # each keeps its own compatible builder.

    # The `nix-tooling` family's combination from skillspkgs: this
    # repository's one shared skill source.
    skillspkgs-combinations = {
      url = "github:nhooey/skillspkgs?dir=sources/combinations";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.nix-skills.follows = "nix-skills";
    };

    # For the Clojure addition below. The combination's nix-skills follows
    # it, so one revision lands in the shell.
    nix-skills = {
      url = "github:nhooey/nix-skills";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      nixpkgs,
      agent-skill-flake,
      ...
    }@inputs:
    agent-skill-flake.lib.mkDevshellSkillsFlake {
      inherit nixpkgs;
      systems = import inputs.systems;
      name = "nix-cljfmt-devshell";
      sources = [
        { source = inputs.skillspkgs-combinations.combinations.nix-tooling; }
        # Addition: this repository packages cljfmt with clj-nix, and no other
        # nix-tooling repository builds Clojure.
        {
          source = inputs.nix-skills;
          skills = [ "nix-clojure" ];
        }
      ];
    };
}

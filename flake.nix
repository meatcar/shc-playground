{
  description = "SMART Healthcard Playground";

  inputs = {
    flake-utils.url = "github:numtide/flake-utils";
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
  };

  outputs = { self, ... }@inputs:
    (inputs.flake-utils.lib.eachDefaultSystem
      (system:
        let
          pkgs = import inputs.nixpkgs { inherit system; };
          erlangVersion = "24";
          erlang = pkgs.beam.interpreters."erlangR${erlangVersion}";
          erlangPackages = pkgs.beam.packages."erlangR${erlangVersion}";
        in
        {
          devShell = pkgs.mkShell rec {
            name = "shc-playground";
            buildInputs = [
              pkgs.nixFlakes
              erlang
              erlangPackages.elixir_1_12
              erlangPackages.elixir_ls
            ];
            _PATH = "${erlangPackages.elixir_ls}/lib";
          };
        }));
}

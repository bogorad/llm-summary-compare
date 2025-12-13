{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

  outputs = { nixpkgs, ... }:
    let
      systems = [ "x86_64-linux" "aarch64-linux" ];
      forAllSystems = f: builtins.listToAttrs (map (system: {
        name = system;
        value = f nixpkgs.legacyPackages.${system};
      }) systems);
    in
    {
      devShells = forAllSystems (pkgs: {
        default = pkgs.mkShell {
          packages = [ pkgs.jq pkgs.curl pkgs.fzf pkgs.bc pkgs.zsh ];
          shell = "${pkgs.zsh}/bin/zsh";
        };
      });
    };
}

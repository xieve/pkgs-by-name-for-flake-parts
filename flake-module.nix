toplevel@{
  lib,
  flake-parts-lib,
  inputs,
  ...
}:
let
  inherit (flake-parts-lib)
    mkPerSystemOption
    ;
  inherit (lib)
    mkOption
    types
    ;
in
{
  options = {
    perSystem = mkPerSystemOption (
      { ... }:
      {
        options = {
          pkgsDirectory = mkOption {
            type = types.nullOr types.path;
            default = null;
            description = ''
              If set, the flake will import packages from the specified directory.
            '';
          };

          pkgsNameSeparator = mkOption {
            type = types.str;
            default = "/";
            description = ''
              The separator to use when flattening package names.
            '';
          };
        };
      }
    );
  };

  config = {
    perSystem =
      { config, pkgs, ... }:
      let
        flattenPkgs =
          path: value:
          if lib.isDerivation value then
            {
              "${lib.concatStringsSep config.pkgsNameSeparator path}" = value;
            }
          else
            lib.concatMapAttrs (name: flattenPkgs (path ++ [ name ])) value;

        # makeScope returns some non-derivation values, which we have to filter
        # out to conform to the flake spec. Assuming that `lib` is from `nixpkgs`,
        # `callPackage` will only ever return derivations, so this should be fine.
        legacyPackages = lib.filterAttrs (_: value: builtins.isAttrs value) (
          lib.makeScope pkgs.newScope (
            self:
            lib.filesystem.packagesFromDirectoryRecursive {
              callPackage = self.newScope { inherit inputs; };
              directory = config.pkgsDirectory;
            }
          )
        );
      in
      lib.mkIf (config.pkgsDirectory != null) {
        inherit legacyPackages;
        packages = flattenPkgs [ ] legacyPackages;
      };
  };
}

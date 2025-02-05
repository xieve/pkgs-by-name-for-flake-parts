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
        scope = lib.makeScope pkgs.newScope (self: {
          inherit inputs;
        });

        flattenAttrs =
          path: value:
          if builtins.isAttrs value then
            lib.concatMapAttrs (name: flattenAttrs (path ++ [ name ])) value
          else
            {
              "${lib.concatStringsSep config.pkgsNameSeparator path}" = value;
            };

        legacyPackages = lib.filesystem.packagesFromDirectoryRecursive {
          directory = config.pkgsDirectory;
          inherit (scope) callPackage;
        };
      in
      lib.mkIf (config.pkgsDirectory != null) {
        inherit legacyPackages;
        packages = flattenAttrs [] legacyPackages;
      };
  };
}

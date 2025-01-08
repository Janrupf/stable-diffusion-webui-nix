# A listing of stable diffusion packages that are to
# be made available
{ pkgs,
...
}:
let
  mkWebuiDistrib = {
      source
    , python
    , createPackage
    , additionalRequirements ? []
    , additionalPipArgs ? []
    , installInstructions
    , requirementsFileName ? "requirements_versions.txt"
  }@args: {
    type = "stable-diffusion-webui-derivation";

    # So the defaults propagate...
    inherit additionalPipArgs;
    inherit additionalRequirements;
    inherit requirementsFileName;
  } // args;
in
{
  forge = pkgs.callPackage ./forge { inherit mkWebuiDistrib; };
  comfy = pkgs.callPackage ./comfy { inherit mkWebuiDistrib; };
}

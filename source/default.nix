# A listing of stable diffusion packages that are to
# be made available
{ pkgs,
...
}:
let
  mkWebuiDistrib = {
      source
    , python
    , additionalRequirements ? []
    , additionalPipArgs ? []
    , installInstructions
  }@args: {
    type = "stable-diffusion-webui-derivation";

    # So the defaults propagate...
    inherit additionalPipArgs;
    inherit additionalRequirements;
  } // args;
in
{
  forge = pkgs.callPackage ./forge { inherit mkWebuiDistrib; };
}

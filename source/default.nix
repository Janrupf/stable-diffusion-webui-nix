# A listing of stable diffusion packages that are to
# be made available
{ pkgs,
...
}:
let
  mkWebuiDistrib = {
      source
    , python
    , additionalRequirements
    , installInstructions
  }@args: {
    type = "stable-diffusion-webui-derivation";
  } // args;
in
{
  forge = pkgs.callPackage ./forge { inherit mkWebuiDistrib; };
}

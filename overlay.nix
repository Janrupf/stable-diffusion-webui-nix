final: prev: 
let
  lib = final.lib;

  # These are packages we don't want in the final overlay, so we temporarily
  # keep them in this let block

  sources = (final.callPackage ./source {});

  # Take a source set of webui pkgs and get the final packages from it
  constructPackage = webuiPkgs:
  let
    requirements = final.callPackage ./requirements { inherit webuiPkgs; };
    runner = final.callPackage webuiPkgs.createPackage {
      inherit webuiPkgs;
      inherit requirements;
    };
  in
    runner // {
      update-helper = requirements.update-helper;
      inherit requirements;
    };

  # Convert the source definitions to the final packages
  mappedPackages = lib.attrsets.mapAttrsRecursiveCond
    (as: !(as ? "type" && as.type == "stable-diffusion-webui-derivation"))
    (path: x: constructPackage x)
    sources;

  fhs = final.callPackage ./fhs {};
in
{
  # Final packages
  stable-diffusion-webui = mappedPackages // { inherit fhs; } // (let
    error = throw "stable-diffusion-webui has been split into multiple packages! Use stable-diffusion-webui.forge.cuda or similar.";
  in {
    type = "derivation";
    drvPath = error;
    name = error;
    outputs = error;
    meta = error;
    system = error;
  });
}

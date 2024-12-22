final: prev: 
let
  # These are packages we don't want in the final overlay, so we temporarily
  # keep them in this let block

  webuiPkgs = {
    source = final.callPackage ./source {};
    python = final.python310;
  };

  # Import the requirements
  requirements = prev.callPackage ./requirements {
    inherit webuiPkgs;
  };
in
{
  # Final package
  stable-diffusion-webui = prev.callPackage ./package.nix {
    inherit webuiPkgs;
    inherit requirements;
  };

  # Requirements update helper
  stable-diffusion-webui-update-requirements = requirements.update-helper;

  # Python environment for development purpose
  stable-diffusion-webui-python = requirements.requirementPkgs.webui-python-raw;

  stable-diffusion-requirements = requirements;
}
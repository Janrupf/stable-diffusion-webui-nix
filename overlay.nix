final: prev: 
let
  # These are packages we don't want in the final overlay, so we temporarily
  # keep them in this let block

  # Source repo
  stable-diffusion-webui-git = prev.callPackage ./source {};

  # Import the requirements
  stable-diffusion-requirements = prev.callPackage ./requirements {
    inherit stable-diffusion-webui-git;
  };
in
{
  # Final package
  stable-diffusion-webui = prev.callPackage ./package.nix {
    inherit stable-diffusion-webui-git;
    inherit (stable-diffusion-requirements) stable-diffusion-webui-python;
  };

  # Requirements update helper
  inherit (stable-diffusion-requirements) stable-diffusion-webui-update-requirements;
}
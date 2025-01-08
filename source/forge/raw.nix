{ stdenv
, fetchFromGitHub
, dos2unix
, findutils
}:
let
  # The UI requires a bunch of extra repositories,
  # see modules/launch_utils.py
  extraRepos = {
    assets = fetchFromGitHub {
      owner = "AUTOMATIC1111";
      repo = "stable-diffusion-webui-assets";
      rev = "6f7db241d2f8ba7457bac5ca9753331f0c266917";
      hash = "sha256-gos24/VHz+Es834ZfMVdu3L9m04CR0cLi54bgTlWLJk=";
    };

    huggingfaceGuess = fetchFromGitHub {
      owner = "lllyasviel";
      repo = "huggingface_guess";
      rev = "84826248b49bb7ca754c73293299c4d4e23a548d";
      hash = "sha256-kL430JmKSriqYJgdhPdquf2qu4Qkb9riGeJLMor4XxA=";
    };

    googleBlockly = fetchFromGitHub {
      owner = "lllyasviel";
      repo = "google_blockly_prototypes";
      rev = "1e98997c7fedaf5106af9849b6f50ebe5c4408f1";
      hash = "sha256-e2T1NH+gyt0K1Vx+i8vU5xxiZEC2BC4t7didU3juRRg=";
    };

    blip = fetchFromGitHub {
      owner = "salesforce";
      repo = "BLIP";
      rev = "48211a1594f1321b00f14c9f7a5b4813144b2fb9";
      hash = "sha256-0IO+3M/Gy4VrNBFYYgZB2CzWhT3PTGBXNKPad61px5k=";
    };
  };
  
  additionalRequirements = [
    # Usually installed when launching the WebUI
    { name = "clip"; spec = "https://github.com/openai/CLIP/archive/d50d76daa670286dd6cacf3bcd80b5e4823fc8e1.zip"; }

    # Required by the stable diffusion model, no idea where it comes from usually
    { name = "timm"; spec = "0.9.16"; }

    # Installed from modules_forge/bnb_installer.py
    { name = "bitsandbytes"; spec = "0.43.3"; }
  ];
in
stdenv.mkDerivation {
  name = "stable-diffusion-webui-forge";

  # Main source
  src = fetchFromGitHub {
    owner = "lllyasviel";
    repo = "stable-diffusion-webui-forge";
    rev = "f53307881bfd824dbdce6ac0d4bba04d9a74ab36";
    hash = "sha256-51ZQwiRrduRDKQgymlOh41L4ia8aS1GhSUL1Z3LSxrs=";
  };

  patches = [
    ./0003-Move-config-states-to-data-path.patch
  ];

  unpackPhase = ''
    runHook preUnpack

    unpackFile $src
    sourceRoot="source"

    # Make sources writeable so we can copy in the other repositories
    chmod -R u+w -- "$sourceRoot"

    mkdir -p $sourceRoot/repositories
    cp -r ${extraRepos.assets} $sourceRoot/repositories/stable-diffusion-webui-assets
    cp -r ${extraRepos.huggingfaceGuess} $sourceRoot/repositories/huggingface_guess
    cp -r ${extraRepos.googleBlockly} $sourceRoot/repositories/google_blockly_prototypes
    cp -r ${extraRepos.blip} $sourceRoot/repositories/BLIP

    chmod -R u+w -- "$sourceRoot"

    # Convert all files to LF line endings so patches apply properly
    for f in $(${findutils}/bin/find "$sourceRoot" -name '*.py'); do
      if [[ -f "$f" ]]; then
        ${dos2unix}/bin/dos2unix "$f"
      fi
    done

    runHook postUnpack
  '';

  installPhase = ''
    cp -r . "$out"
  '';

  passthru = {
    inherit additionalRequirements;
  };
}

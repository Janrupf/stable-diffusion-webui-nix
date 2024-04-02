{ stdenv
, fetchFromGitHub
, dos2unix
, findutils
}:
let
  # The UI requires a bunch of extra repositories
  extraRepos = {
    assets = fetchFromGitHub {
      owner = "AUTOMATIC1111";
      repo = "stable-diffusion-webui-assets";
      rev = "6f7db241d2f8ba7457bac5ca9753331f0c266917";
      hash = "sha256-gos24/VHz+Es834ZfMVdu3L9m04CR0cLi54bgTlWLJk=";
    };

    stableDiffusion = fetchFromGitHub {
      owner = "Stability-AI";
      repo = "stablediffusion";
      rev = "cf1d67a6fd5ea1aa600c4df58e5b47da45f6bdbf";
      hash = "sha256-yEtrz/JTq53JDI4NZI26KsD8LAgiViwiNaB2i1CBs/I=";
    };

    stableDiffusionXL = fetchFromGitHub {
      owner = "Stability-AI";
      repo = "generative-models";
      rev = "45c443b316737a4ab6e40413d7794a7f5657c19f";
      hash = "sha256-qaZeaCfOO4vWFZZAyqNpJbTttJy17GQ5+DM05yTLktA=";
    };

    kDiffusion = fetchFromGitHub {
      owner = "crowsonkb";
      repo = "k-diffusion";
      rev = "ab527a9a6d347f364e3d185ba6d714e22d80cb3c";
      hash = "sha256-tOWDFt0/hGZF5HENiHPb9a2pBlXdSvDvCNTsCMZljC4=";
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
    { name = "xformers"; spec = "0.0.23.post1"; }
    { name = "clip"; spec = "https://github.com/openai/CLIP/archive/d50d76daa670286dd6cacf3bcd80b5e4823fc8e1.zip"; }
    # { name = "open-clip-torch"; spec = "https://github.com/mlfoundations/open_clip/archive/bb6e834e9c70d9c27d0dc3ecedeebeaeb1ffad6b.zip"; }

    # Required by the stable diffusion model, no idea where it comes from usually
    { name = "timm"; spec = "0.9.16"; }
  ];
in
stdenv.mkDerivation rec {
  name = "stable-diffusion-webui-git";

  # Main source
  src = fetchFromGitHub {
    owner = "AUTOMATIC1111";
    repo = "stable-diffusion-webui";
    rev = "aa4a45187eda51fe564139e0087d119b981ca66d";
    hash = "sha256-T5i1VOCFVNj6Mv9cF1Dkqajz/VBnmq7t1nqphtxZSt8=";
  };

  patches = [
    # Fixes an invalid import which references an old pytorch_lightning version
    ./fix-import.patch

    # Web UI feature patches
    ./0001-Add-uvicorn-option.patch
    ./0002-Add-idle-exit-option.patch
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
    cp -r ${extraRepos.stableDiffusion} $sourceRoot/repositories/stable-diffusion-stability-ai
    cp -r ${extraRepos.stableDiffusionXL} $sourceRoot/repositories/generative-models
    cp -r ${extraRepos.kDiffusion} $sourceRoot/repositories/k-diffusion
    cp -r ${extraRepos.blip} $sourceRoot/repositories/BLIP

    echo '${builtins.toJSON additionalRequirements}' > $sourceRoot/additional-requirements.json

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
}
# Pinned release wheel for headroom-ai. Underscore prefix keeps this out of
# import-tree; imported directly by headroom.nix.
#
# The upstream wheel, not a source build: the sdist builds a PyO3 Rust core
# through maturin, and its ort-sys dependency downloads ONNX Runtime from
# cdn.pyke.io at build time. The wheel's core links only system libraries and
# loads ONNX Runtime at runtime from ORT_DYLIB_PATH.
{ fetchurl }:
{
  headroom-ai = rec {
    version = "0.44.0";
    src = fetchurl {
      url = "https://files.pythonhosted.org/packages/42/b7/1ab4da6f7a091fd1a102b5194828f9a588b6b4f11b522f38b86b125770a3/headroom_ai-${version}-cp310-abi3-macosx_11_0_arm64.whl";
      hash = "sha256-mwhPTNmRivLQlwRQ/z6ZD//CmoIg3F4k+g8zpN0DWcw=";
    };
  };
}

{
  flake.modules.homeManager.flywheel =
    { pkgs, lib, ... }:
    let
      sources = import ./_sources.nix { inherit (pkgs) fetchFromGitHub; };

      # rust-toolchain.toml pins nightly for the whole workspace, but the
      # only load-bearing reason is the transitive `asupersync` dependency
      # defaulting on its "nightly-outcome-try" feature (a `?`-operator
      # sugar via #![feature(try_trait_v2)]); cass's own code has no
      # #![feature(...)] usage. That default is turned off below so the
      # build runs on nixpkgs stable rustc instead of needing a nightly
      # toolchain input.
      cass = pkgs.rustPlatform.buildRustPackage {
        pname = "cass";
        inherit (sources.cass) version src;

        cargoHash = "sha256-G36K9Oer3e9jPiDRYH8mcseB8P45Kswky+QjUwMnOrc=";

        # Two upstream git/registry dependencies need post-fetch patching,
        # done here since neither lives in cass's own source tree:
        #   - frankensearch (git dep) ships a non-default workspace member,
        #     tools/optimize_params, whose path dependency on a sibling
        #     `fast_cmaes` checkout only exists in upstream's own monorepo
        #     layout. That breaks `cargo metadata` for the whole
        #     frankensearch workspace during vendoring, even though cass
        #     only needs the unrelated `frankensearch` library crate.
        #     Stub the missing crate so metadata resolves.
        #   - asupersync (registry dep) defaults on "nightly-outcome-try",
        #     requiring nightly rustc; drop it from its default feature
        #     list so the crate builds on stable.
        #   - ft-kernel-cpu (git dep, part of frankentorch) unconditionally
        #     opts the whole crate into `feature(stdarch_neon_dotprod)` on
        #     aarch64 for a NEON dot-product int8 GEMM fast path. Upstream's
        #     own code already carries a portable fallback for "non-aarch64,
        #     no dotprod, or k<16" that it calls "bit-identical" to the SIMD
        #     path; disabling the aarch64-only cfg blocks (call sites and
        #     kernel fns alike) just forces that existing fallback instead
        #     of requiring nightly.
        #   - fsqlite-pager and fsqlite-btree (registry deps) each carry an
        #     unconditional `#![feature(core_intrinsics)]`, but the only use
        #     (an L1 cache-prefetch hint) is already `#[cfg(target_arch =
        #     "x86_64")]`-gated with a no-op fallback for every other arch.
        #     The crate-level attribute itself isn't cfg-gated, so it still
        #     trips the stable-channel check on aarch64 even though the code
        #     it guards never gets compiled there. Drop the attribute line.
        depsExtraArgs.postBuild = ''
          mkdir -p $out/git/fast_cmaes/src
          cat > $out/git/fast_cmaes/Cargo.toml <<'EOF'
          [package]
          name = "fastcma"
          version = "0.1.0"
          edition = "2024"

          [features]
          test_utils = []
          EOF
          touch $out/git/fast_cmaes/src/lib.rs

          asupersyncTarball="$out/tarballs/asupersync-0.3.5.tar.gz"
          patchDir="$(mktemp -d)"
          tar xzf "$asupersyncTarball" -C "$patchDir"
          sed -i '/^\s*"nightly-outcome-try",$/d' "$patchDir"/asupersync-0.3.5/Cargo.toml
          tar --sort=name --mtime='@0' --owner=0 --group=0 --numeric-owner \
            -czf "$asupersyncTarball" -C "$patchDir" asupersync-0.3.5

          ftKernelCpuLib="$out/git/c305306b251753099620ad5fe02e78c07c167cf6/crates/ft-kernel-cpu/src/lib.rs"
          sed -i \
            -e '/feature(stdarch_neon_dotprod)/d' \
            -e 's/cfg(target_arch = "aarch64")/cfg(all(target_arch = "aarch64", nix_never_enable))/g' \
            "$ftKernelCpuLib"

          for crate in fsqlite-pager fsqlite-btree; do
            tarball="$out/tarballs/$crate-0.1.13.tar.gz"
            patchDir="$(mktemp -d)"
            tar xzf "$tarball" -C "$patchDir"
            sed -i '/^#!\[feature(core_intrinsics)\]$/d' "$patchDir/$crate-0.1.13/src/lib.rs"
            tar --sort=name --mtime='@0' --owner=0 --group=0 --numeric-owner \
              -czf "$tarball" -C "$patchDir" "$crate-0.1.13"
          done
        '';

        # Only the cass binary is wanted; the perf-bundle and e2e-run-bundle
        # bins are dev/CI tooling.
        cargoBuildFlags = [
          "--bin"
          "cass"
        ];

        # openssl crate is pulled in with the "vendored" feature, which
        # compiles OpenSSL from source and needs perl for its Configure step.
        nativeBuildInputs = [ pkgs.perl ];

        buildInputs = lib.optionals pkgs.stdenv.hostPlatform.isDarwin [
          pkgs.libiconv
        ];

        doCheck = false;

        meta = {
          description = "Unified TUI and CLI to index and search local coding agent session history";
          homepage = "https://github.com/Dicklesworthstone/coding_agent_session_search";
          # Rider-carrying license (see the ADR closed as nyx-o2a): never
          # lib.licenses.mit, always this unfree custom shape.
          license = lib.licenses.unfree // {
            fullName = "MIT License (with OpenAI/Anthropic Rider)";
            url = "https://github.com/Dicklesworthstone/coding_agent_session_search/blob/v${sources.cass.version}/LICENSE";
          };
          mainProgram = "cass";
        };
      };
    in
    {
      # Binary only: semantic search's optional embedding model (~90MB) is
      # never fetched by this package. Install it explicitly per-user with
      # `cass models install`; lexical search works without it
      # (fallback_mode=lexical reported until then).
      home.packages = [ cass ];
    };
}

{
  description = "CLI tools installed by install.sh";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { nixpkgs, ... }:
    let
      systems = [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ];
      forAllSystems = f: nixpkgs.lib.genAttrs systems (s: f s nixpkgs.legacyPackages.${s});

      # CUDA llama.cpp. Not in any binary cache, so it compiles on first install;
      # aarch64 targets only the GB10 (sm_121) to keep that build short.
      cudaPkgsFor = system: import nixpkgs {
        inherit system;
        config = {
          allowUnfree = true;
          cudaSupport = true;
        } // nixpkgs.lib.optionalAttrs (system == "aarch64-linux") {
          cudaCapabilities = [ "12.1" ];
        };
      };

      # Nix CUDA binaries look for libcuda in /run/opengl-driver/lib (NixOS only).
      # Elsewhere, expose just the host's NVIDIA libs via a private symlink dir;
      # putting the whole system lib dir on LD_LIBRARY_PATH would shadow Nix's glibc/libstdc++.
      nvidiaDriverHook = pkgs: pkgs.writeText "nvidia-driver-hook.sh" ''
        if [ ! -e /run/opengl-driver/lib/libcuda.so.1 ]; then
          for d in /usr/lib/aarch64-linux-gnu /usr/lib/x86_64-linux-gnu /usr/lib64 \
                   /usr/local/nvidia/lib64 /usr/local/nvidia/lib /usr/lib/wsl/lib; do
            if [ -e "$d/libcuda.so.1" ]; then
              shim="''${XDG_CACHE_HOME:-$HOME/.cache}/dotfiles/nvidia-libs"
              mkdir -p "$shim"
              for l in "$d"/libcuda.so* "$d"/libnvidia-*.so*; do
                [ -e "$l" ] && ln -sf "$l" "$shim/"
              done
              export LD_LIBRARY_PATH="$shim''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
              break
            fi
          done
        fi
      '';

      # DGX Spark tuning (aarch64 only). nixpkgs already gives sm_121a (native FP4)
      # and runtime-dispatched CPU variants up to armv9.2, so only these differ:
      #  - FA_QUANTS=all: GPU flash-attention for every K/V cache quant pair
      #    (e.g. -ctk q8_0 -ctv q4_0), not just the four matching defaults.
      #  - rpcSupport: split a model across two linked Sparks with --rpc.
      #  - no test binaries: they aren't installed; trims the from-source build.
      llamaCudaFor = system:
        let llama = (cudaPkgsFor system).llama-cpp;
        in if system == "aarch64-linux" then
          (llama.override { rpcSupport = true; }).overrideAttrs (old: {
            cmakeFlags = old.cmakeFlags ++ [
              (nixpkgs.lib.cmakeFeature "GGML_CUDA_FA_QUANTS" "all")
              (nixpkgs.lib.cmakeBool "LLAMA_BUILD_TESTS" false)
            ];
            doCheck = false;
          })
        else llama;

      llamaCppFor = system: pkgs:
        if pkgs.stdenv.isLinux then
          pkgs.runCommand "llama-cpp-cuda" { nativeBuildInputs = [ pkgs.makeWrapper ]; } ''
            mkdir -p $out/bin
            for f in ${llamaCudaFor system}/bin/*; do
              makeWrapper "$f" "$out/bin/$(basename "$f")" --run '. ${nvidiaDriverHook pkgs}'
            done
          ''
        else
          # macOS (MacBook Air): stock nixpkgs is already Metal + embedded shaders +
          # runtime M1/M2-M3/M4 CPU dispatch, and it's in cache.nixos.org; any
          # override would force a slow local compile on a fanless laptop.
          pkgs.llama-cpp;
    in
    {
      packages = forAllSystems (system: pkgs: {
        default = pkgs.buildEnv {
          name = "dotfiles-tools";
          paths = with pkgs; [
            neovim
            dust
            tldr
            gh
            ddgr
            uv
            (llamaCppFor system pkgs)
            # LazyVim dependencies
            ripgrep
            fd
            fzf
            lazygit
            tree-sitter
          ] ++ lib.optionals stdenv.hostPlatform.isLinux [
            xdg-utils # xdg-open; macOS has `open`
          ];
        };
      });
    };
}

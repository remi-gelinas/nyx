{
  flake.modules.homeManager.headroom =
    {
      config,
      pkgs,
      lib,
      ...
    }:
    let
      sources = import ./_sources.nix { inherit (pkgs) fetchurl; };
      python3Packages = pkgs.unstable.python3Packages;

      port = 8787;
      proxyUrl = "http://127.0.0.1:${toString port}";

      headroom = python3Packages.buildPythonApplication rec {
        pname = "headroom-ai";
        inherit (sources.headroom-ai) version src;
        format = "wheel";

        # Upstream floors that sit one patch or minor release ahead of
        # nixpkgs-unstable. checks.headroom exercises the relaxed versions.
        pythonRelaxDeps = [
          "click"
          "filelock"
          "opentelemetry-api"
          "tomlkit"
        ];

        # Core dependencies plus the `proxy` and `mcp` extras. The `code`
        # extra is left out: it needs tree-sitter-language-pack < 1.0 and
        # nixpkgs carries 1.x. The ML extras (`ml`, `memory`) pull PyTorch.
        dependencies = with python3Packages; [
          ast-grep-cli
          click
          filelock
          hf-xet
          litellm
          opentelemetry-api
          pydantic
          pyyaml
          rich
          tiktoken
          tomlkit
          truststore

          fastapi
          h2
          httpx
          magika
          mcp
          onnxruntime
          openai
          orjson
          python-socks
          sqlite-vec
          starlette
          transformers
          uvicorn
          watchdog
          websockets
          zstandard
        ];

        # Every default here points away from the network: no telemetry
        # beacon, update check, or model and pricing-table downloads, and
        # litellm reads its bundled cost map instead of fetching one at
        # import. The Rust core dlopens ONNX Runtime; it cannot find nixpkgs'
        # copy on its own, and content detection then stalls on a 5s
        # watchdog before falling back. Headroom shells out to these tools
        # and downloads its own copies into ~/Library/Caches when they are
        # missing from PATH.
        #
        # `headroom proxy` re-executes itself as `python -m headroom.cli`, but
        # the nixpkgs wrapper only adds site dirs inside the wrapped process,
        # so the child needs them on PYTHONPATH.
        makeWrapperArgs = [
          "--prefix"
          "PYTHONPATH"
          ":"
          "${placeholder "out"}/${python3Packages.python.sitePackages}:${python3Packages.makePythonPath dependencies}"
          "--prefix"
          "PATH"
          ":"
          (lib.makeBinPath (
            with pkgs.unstable;
            [
              ast-grep
              difftastic
              scc
            ]
          ))
          "--set-default"
          "HEADROOM_OFFLINE"
          "1"
          "--set-default"
          "LITELLM_LOCAL_MODEL_COST_MAP"
          "True"
          "--set-default"
          "ORT_DYLIB_PATH"
          "${pkgs.unstable.onnxruntime}/lib/libonnxruntime.dylib"
        ];

        pythonImportsCheck = [ "headroom" ];

        meta = {
          description = "Compresses tool outputs, logs, and history before they reach the LLM";
          homepage = "https://github.com/headroomlabs-ai/headroom";
          license = lib.licenses.asl20;
          sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
          platforms = [ "aarch64-darwin" ];
          mainProgram = "headroom";
        };
      };
    in
    lib.mkMerge [
      {
        home.packages = [ headroom ];

        # Both harnesses run every model through OpenRouter, so one proxy
        # with OpenRouter as its OpenAI-compatible upstream covers all of
        # them. The proxy holds no key: each client's Authorization header is
        # forwarded. Routing lives in config files rather than env, so swarm
        # panes and subagents pick it up without any launch wrapper.
        programs.opencode.settings = {
          providers.openrouter.settings.baseURL = "${proxyUrl}/v1";
          # Lets the model fetch the original of a compressed block. The
          # proxy recognizes OpenCode's `headroom_headroom_retrieve` as this
          # tool and skips injecting its own.
          mcp.servers.headroom = {
            type = "local";
            command = [
              (lib.getExe headroom)
              "mcp"
              "serve"
            ];
          };
        };

        programs.omp = {
          # Scoped to the chat API. Unscoped, the override is provider-wide
          # and OpenRouter's decision, embedding, and media routes would be
          # derived from the proxy URL too.
          models.providers.openrouter = {
            baseUrl = "${proxyUrl}/v1";
            api = "openrouter";
          };
          mcpServers.headroom = {
            type = "stdio";
            command = lib.getExe headroom;
            args = [
              "mcp"
              "serve"
            ];
          };
        };
      }
      (lib.mkIf pkgs.stdenv.isDarwin {
        # Every agent's LLM traffic goes through this process, so launchd
        # restarts it on exit. Loopback only: the proxy's per-request
        # upstream header would otherwise be an open relay.
        launchd.agents.headroom = {
          enable = true;
          config = {
            ProgramArguments = [
              (lib.getExe headroom)
              "proxy"
              "--host"
              "127.0.0.1"
              "--port"
              (toString port)
              "--openai-api-url"
              "https://openrouter.ai/api/v1"
              # The response cache would replay an earlier completion for a
              # repeated request, and the local rate limiter would throttle a
              # swarm that OpenRouter's own limits already govern.
              "--no-cache"
              "--no-rate-limit"
            ];
            EnvironmentVariables = {
              # The default today; pinned so an upstream change cannot switch
              # the proxy to a mode that rewrites prior turns and busts the
              # provider prefix cache.
              HEADROOM_SAVINGS_PROFILE = "coding";
              # Kompress needs a HuggingFace model the offline proxy never
              # downloads, so the proxy should not try to load it.
              HEADROOM_DISABLE_KOMPRESS = "1";
            };
            KeepAlive = true;
            RunAtLoad = true;
            StandardOutPath = "${config.home.homeDirectory}/Library/Logs/headroom.log";
            StandardErrorPath = "${config.home.homeDirectory}/Library/Logs/headroom.log";
          };
        };
      })
    ];
}

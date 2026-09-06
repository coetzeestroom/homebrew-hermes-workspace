class HermesWorkspace < Formula
  desc "Native web workspace for Hermes Agent: chat, terminal, memory, skills"
  homepage "https://github.com/outsourc-e/hermes-workspace"
  url "https://github.com/outsourc-e/hermes-workspace/archive/refs/tags/v2.3.0.tar.gz"
  sha256 "1b0f4478527af098b0cefe33c61ec7dee16e520a30ec195fa0919eba577ddbbc"
  license "MIT"
  head "https://github.com/outsourc-e/hermes-workspace.git", branch: "main"

  depends_on "node@22"
  depends_on "pnpm"

  def install
    # pnpm 11 moved all non-auth config into pnpm-workspace.yaml and changed
    # strictDepBuilds to true by default, blocking build scripts for packages
    # like electron, esbuild, and unrs-resolver (ERR_PNPM_IGNORED_BUILDS).
    # It also changed the lockfile format from v9 to v11, so --frozen-lockfile
    # aborts when the upstream lockfile was generated with pnpm 9/10.
    # Write pnpm-workspace.yaml explicitly to guarantee allowBuilds is present
    # regardless of what pnpm version is installed, then install without
    # --frozen-lockfile so pnpm 11 can migrate the lockfile format in place.
    (buildpath/"pnpm-workspace.yaml").write <<~YAML
      allowBuilds:
        electron: true
        electron-winstaller: true
        esbuild: true
        unrs-resolver: true
    YAML
    system "pnpm", "install", "--no-frozen-lockfile"
    system "pnpm", "build"

    # Install the built output and node_modules required at runtime.
    # dist/server/server.js is a TanStack Start SSR bundle that still contains
    # bare ESM imports (e.g. 'react') which Node resolves via node_modules —
    # it is not a fully self-contained bundle, so node_modules must ship too.
    libexec.install "dist", "electron", "node_modules", "server-entry.js", "package.json", "pnpm-lock.yaml"

    node = Formula["node@22"].opt_bin/"node"

    # Create a wrapper script for the workspace server.
    # Use the absolute path to node so the script works regardless of PATH
    # (e.g. when invoked by systemd which starts with a minimal environment).
    (bin/"hermes-workspace").write <<~EOS
      #!/bin/bash
      export HERMES_HOME="${HERMES_HOME:-#{var}/lib/hermes-workspace}"
      export HERMES_WORKSPACE_PORT="${HERMES_WORKSPACE_PORT:-3000}"
      cd "#{libexec}"
      exec "#{node}" server-entry.js "$@"
    EOS

    # Also provide the electron dev entry point
    (bin/"hermes-workspace-dev").write <<~EOS
      #!/bin/bash
      export HERMES_HOME="${HERMES_HOME:-#{var}/lib/hermes-workspace}"
      cd "#{libexec}/.."
      exec pnpm dev "$@"
    EOS

    (var/"lib/hermes-workspace").mkpath
    (var/"log/hermes-workspace").mkpath
  end

  def caveats
    <<~EOS
      Start the service (user-level deployment):

        brew services start #{name}

      On Linux, enable lingering so the service persists after logout and
      starts on boot:

        loginctl enable-linger $USER

      On Linux, you may also need to set XDG_RUNTIME_DIR and
      DBUS_SESSION_BUS_ADDRESS so the service can connect to the D-Bus
      session bus. Run this once to add them to your ~/.bashrc:

        { echo; echo "# hermes-workspace: D-Bus session bus"; echo 'export XDG_RUNTIME_DIR=/run/user/$(id -u)'; echo 'export DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$(id -u)/bus'; } >> ~/.bashrc

      Then reload your shell:

        source ~/.bashrc
    EOS
  end

  service do
    run [opt_bin/"hermes-workspace"]
    keep_alive true
    environment_variables PATH: std_service_path_env,
                          HERMES_HOME: var/"lib/hermes-workspace",
                          HERMES_WORKSPACE_PORT: "3000"
    working_dir var/"lib/hermes-workspace"
    log_path var/"log/hermes-workspace/hermes-workspace.log"
    error_log_path var/"log/hermes-workspace/hermes-workspace.log"
  end

  test do
    # Test that the wrapper script exists and runs
    assert_match "HERMES_HOME", shell_output("#{bin}/hermes-workspace --help 2>&1")
  end
end

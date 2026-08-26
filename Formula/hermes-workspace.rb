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
    system "pnpm", "install", "--frozen-lockfile"
    system "pnpm", "build"

    # Install the built output
    # The build outputs to dist/ and the electron bundle to electron/
    # We'll install the built artifacts and create a wrapper script
    libexec.install "dist", "electron", "server-entry.js", "package.json", "pnpm-lock.yaml"

    # Create a wrapper script for the workspace server
    (bin/"hermes-workspace").write <<~EOS
      #!/bin/bash
      export HERMES_HOME="${HERMES_HOME:-#{var}/lib/hermes-workspace}"
      export HERMES_WORKSPACE_PORT="${HERMES_WORKSPACE_PORT:-3000}"
      cd "#{libexec}"
      exec node server-entry.js "$@"
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

  service do
    run [opt_bin/"hermes-workspace"]
    keep_alive true
    log_path var/"log/hermes-workspace/hermes-workspace.log"
    error_log_path var/"log/hermes-workspace/hermes-workspace.log"
  end

  test do
    # Test that the wrapper script exists and runs
    assert_match "HERMES_HOME", shell_output("#{bin}/hermes-workspace --help 2>&1")
  end
end

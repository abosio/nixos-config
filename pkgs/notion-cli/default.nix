# notion-cli is not in nixpkgs, so it is packaged here from upstream source.
# Update instructions: docs/notion-cli.md
{ lib, buildGoModule, fetchFromGitHub, installShellFiles }:

buildGoModule (finalAttrs: {
  pname = "notion-cli";
  version = "0.7.0";

  src = fetchFromGitHub {
    owner = "4ier";
    repo = "notion-cli";
    tag = "v${finalAttrs.version}";
    hash = "sha256-Wy3Xi40dsmk0igxsGiX7fqvgMVnuIcdNkOefUBAgy/I=";
  };

  vendorHash = "sha256-l+js7rA49aDVu6sHcuNDSv8R8E/Fi1J7yE17uaKHhjQ=";

  nativeBuildInputs = [ installShellFiles ];

  # Matches upstream's goreleaser build: stripped, version stamped into cmd.
  ldflags = [
    "-s"
    "-w"
    "-X github.com/4ier/notion-cli/cmd.Version=${finalAttrs.version}"
  ];

  # Upstream's binary is `notion`; buildGoModule names it after the module.
  postInstall = ''
    mv $out/bin/notion-cli $out/bin/notion

    installShellCompletion --cmd notion \
      --bash <($out/bin/notion completion bash) \
      --zsh <($out/bin/notion completion zsh) \
      --fish <($out/bin/notion completion fish)
  '';

  meta = {
    description = "Full-featured CLI for Notion. Like gh for GitHub, but for Notion";
    homepage = "https://github.com/4ier/notion-cli";
    changelog = "https://github.com/4ier/notion-cli/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.mit;
    mainProgram = "notion";
    platforms = lib.platforms.unix;
  };
})

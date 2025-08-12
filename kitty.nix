{ ... }:

{
  # Setup kitty terminal
  programs.kitty = {
    enable = true;
    shellIntegration.enableZshIntegration = true;
    font = {
      name = "Fira Code";
      size = 14;
    };
    themeFile = "Nord";
  };
}
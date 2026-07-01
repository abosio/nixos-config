{ ... }:

{
  programs.vim = {
    enable = true;
    settings = {
      number         = true;
      ignorecase     = true;
      expandtab      = true;
      tabstop        = 2;
      shiftwidth     = 2;
    };
    extraConfig = ''
      set smartcase
      set hlsearch
      set incsearch
      set cursorline
      set showmatch
      set wildmenu
      syntax on
      filetype plugin indent on
      autocmd FileType python setlocal tabstop=4 shiftwidth=4
    '';
  };
}

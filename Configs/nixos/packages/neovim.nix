{
  lib,
  neovim,
  ripgrep,
  fd,
  lazygit,
  ghostscript,
  tectonic,
  mermaid-cli,
  tree-sitter,
  neovimUtils,
  symlinkJoin,
  sqlite,
}:
let
  parsers = symlinkJoin {
    name = "snacks-image-parsers";
    paths = map neovimUtils.grammarToPlugin (
      with tree-sitter.builtGrammars;
      [
        tree-sitter-css
        tree-sitter-latex
        tree-sitter-norg
        tree-sitter-scss
        tree-sitter-svelte
        tree-sitter-typst
        tree-sitter-vue
      ]
    );
  };
in
neovim.override {
  wrapperArgs = [
    "--prefix"
    "PATH"
    ":"
    (lib.makeBinPath [
      ripgrep
      fd
      lazygit
      ghostscript
      tectonic
      mermaid-cli
      tree-sitter
    ])
    "--suffix"
    "LD_LIBRARY_PATH"
    ":"
    (lib.makeLibraryPath [ sqlite ])
    "--set"
    "NVIM_TREESITTER_PARSERS"
    (toString parsers)
  ];
}

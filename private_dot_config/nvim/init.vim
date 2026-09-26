" Load the shared Vim config. Neovim does not read ~/.vimrc on its own.
execute "set runtimepath^=" . fnameescape(expand("~/.vim"))
execute "set runtimepath+=" . fnameescape(expand("~/.vim/after"))
let &packpath = &runtimepath
execute "source" fnameescape(expand("~/.vimrc"))

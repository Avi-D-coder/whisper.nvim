" whisper.nvim - Speech-to-text for Neovim using whisper.cpp
" Maintainer: Avi D
" Version: 0.1.1

if exists('g:loaded_whisper_nvim')
  finish
endif
let g:loaded_whisper_nvim = 1

" Plugin is loaded via Lua
" Users should call require('whisper').setup() in their config

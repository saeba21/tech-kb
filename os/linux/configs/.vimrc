Vimrc Optimized Configuration
```

" =============================================================================

" 1. ENCODING & COMPATIBILITY

" =============================================================================

set encoding=utf-8

set fileencodings=utf-8,latin1,cp1252

set fileformats=unix,dos,mac

" =============================================================================

" 2. CLIPBOARD (Works if Vim has +clipboard support)

" =============================================================================

set clipboard=unnamedplus,unnamed

" =============================================================================

" 3. SELECT ALL (CTRL+A)

" =============================================================================

nnoremap <C-A> ggVG

vnoremap <C-A> ggVG

inoremap <C-A> ggVG

" =============================================================================

" 4. GENERAL OPTIMIZATIONS

" =============================================================================

syntax on

set number

set cursorline

set expandtab

set shiftwidth=4

set softtabstop=4

set smartindent

set ignorecase

set smartcase

set hlsearch

set incsearch

set backspace=indent,eol,start

set noswapfile

set undofile

```
if exists('g:fvim_loaded')
    " Ctrl-ScrollWheel for zooming in/out
    nnoremap <silent> <C-ScrollWheelUp> :set guifont=+<CR>
    nnoremap <silent> <C-ScrollWheelDown> :set guifont=-<CR>
    nnoremap <A-CR> :FVimToggleFullScreen<CR>

    set guifont=JuliaMono\ Medium:h12
    FVimCursorSmoothMove v:true
    FVimCursorSmoothBlink v:true

    FVimUIPopupMenu v:false
    FVimUIWildMenu v:false

    FVimFontAntialias v:true
    FVimFontAutohint v:true
    FVimFontHintLevel 'full'
    FVimFontLigature v:true
    FVimFontAutoSnap v:true
    FVimFontNoBuiltinSymbols v:false
    FVimFontAutoSnap v:true
endif


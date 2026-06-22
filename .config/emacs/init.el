;;; init.el --- Pure-Emacs config mirroring my Neovim setup -*- lexical-binding: t; -*-
;;
;; A 1:1 port of ~/.config/nvim, built on Emacs 30 built-ins wherever one
;; exists (eglot, flymake, treesit, project, dired/wdired, which-key, org) and
;; a small set of single-purpose packages everywhere else. No evil-mode: every
;; binding below is native Emacs.
;;
;; Keybinding scheme mirrors my Neovim leader groups, with `C-c` as the leader:
;;   C-c f …  find / pickers      (telescope)
;;   C-c l …  language server     (LSP keymaps)
;;   C-c g …  git                 (gitsigns)
;;   C-c i    format buffer       (conform)
;;   C-c t    toggle terminal     (toggleterm)
;;   C-c c    file browser        (oil)
;;   C-c s    surround            (nvim-surround)

;;;; ---------------------------------------------------------------------------
;;;; Paths: keep generated state out of the symlinked repo dir
;;;; ---------------------------------------------------------------------------

(defun dookie/cache (file)
  "Path to FILE under the XDG cache dir for Emacs."
  (expand-file-name (concat "emacs/" file)
                    (or (getenv "XDG_CACHE_HOME") (expand-file-name "~/.cache"))))

(defun dookie/data (file)
  "Path to FILE under the XDG data dir for Emacs."
  (expand-file-name (concat "emacs/" file)
                    (or (getenv "XDG_DATA_HOME") (expand-file-name "~/.local/share"))))

(dolist (dir (list (dookie/cache "") (dookie/data "")))
  (make-directory dir t))

(setq backup-directory-alist        `(("." . ,(dookie/cache "backups")))
      auto-save-file-name-transforms `((".*" ,(concat (dookie/cache "auto-save/")) t))
      auto-save-list-file-prefix     (dookie/cache "auto-save-list/.saves-")
      create-lockfiles               nil
      recentf-save-file              (dookie/data "recentf")
      savehist-file                  (dookie/data "history")
      save-place-file                (dookie/data "places")
      transient-history-file         (dookie/data "transient-history.el")
      transient-levels-file          (dookie/data "transient-levels.el")
      transient-values-file          (dookie/data "transient-values.el")
      project-list-file              (dookie/data "projects")
      bookmark-default-file          (dookie/data "bookmarks")
      eshell-directory-name          (dookie/data "eshell/")
      url-configuration-directory    (dookie/cache "url/")
      custom-file                    (dookie/data "custom.el"))
(make-directory (dookie/cache "auto-save/") t)
(load custom-file 'noerror 'nomessage)

;;;; ---------------------------------------------------------------------------
;;;; PATH: make GUI/daemon Emacs see your shell tools
;;;; ---------------------------------------------------------------------------
;; Launched from Sway/fuzzel or as a daemon, Emacs inherits a bare session
;; PATH (/usr/bin, ...) and never sources ~/.zshrc, so juliaup's `julia` and
;; npm-global binaries go missing and eglot/apheleia can't start them. Mirror
;; the user-bin dirs from ~/.zshrc onto exec-path and PATH.
(dolist (dir '("~/.juliaup/bin"   ; julia (juliaup) -> needed by eglot-jl
               "~/.julia/bin"     ; Julia-installed apps
               "~/.npm-global/bin"
               "~/.bun/bin"
               "~/.local/bin"))
  (let ((d (expand-file-name dir)))
    (when (file-directory-p d)
      (add-to-list 'exec-path d)
      (setenv "PATH" (concat d path-separator (getenv "PATH"))))))

;;;; ---------------------------------------------------------------------------
;;;; Package system: built-in package.el + use-package (Emacs 30)
;;;; ---------------------------------------------------------------------------

(require 'package)
(setq package-archives
      '(("gnu"    . "https://elpa.gnu.org/packages/")
        ("nongnu" . "https://elpa.nongnu.org/nongnu/")
        ("melpa"  . "https://melpa.org/packages/")))
(package-initialize)
(unless package-archive-contents
  (package-refresh-contents))

(require 'use-package)
(setq use-package-always-ensure t)

;;;; ---------------------------------------------------------------------------
;;;; Editor basics  (mirrors lua/config/options.lua)
;;;; ---------------------------------------------------------------------------

(setq-default indent-tabs-mode nil      ; expandtab
              tab-width 4               ; tabstop
              fill-column 92)           ; colorcolumn = "92"

(global-display-line-numbers-mode 1)              ; number
(global-hl-line-mode 1)                           ; cursorline
(global-display-fill-column-indicator-mode 1)     ; colorcolumn (always on)
(electric-pair-mode 1)                            ; nvim-autopairs
(electric-indent-mode 1)                          ; smartindent (on by default)
(delete-selection-mode 1)
(global-auto-revert-mode 1)                       ; autoread
(setq global-auto-revert-non-file-buffers t
      use-short-answers t                         ; y/n instead of yes/no
      sentence-end-double-space nil
      scroll-conservatively 101                   ; no recentering jumps
      tab-always-indent 'complete)                ; TAB indents, then completes

;; trim_whitespace / trim_newlines for every filetype (conform's ["*"]).
(add-hook 'before-save-hook #'delete-trailing-whitespace)

;; Small native niceties that the pickers below rely on.
(recentf-mode 1)
(savehist-mode 1)
(save-place-mode 1)

;;;; ---------------------------------------------------------------------------
;;;; Colorscheme  (dookie)
;;;; ---------------------------------------------------------------------------

(use-package dookie-theme
  :ensure nil
  :vc (:url "https://github.com/pebeto/dookie-emacs" :rev :newest)
  :config
  (load-theme 'dookie t))

;;;; ---------------------------------------------------------------------------
;;;; which-key  (built-in on Emacs 30)
;;;; ---------------------------------------------------------------------------

(use-package which-key
  :ensure nil
  :init
  (setq which-key-idle-delay 0.3)   ; nvim timeoutlen = 300
  (which-key-mode 1))

;;;; ---------------------------------------------------------------------------
;;;; Tree-sitter  (built into Emacs 30; treesit-auto just installs grammars
;;;; and remaps foo-mode -> foo-ts-mode automatically)  ── nvim-treesitter
;;;; ---------------------------------------------------------------------------

(use-package treesit-auto
  :custom (treesit-auto-install 'prompt)
  :config
  (treesit-auto-add-to-auto-mode-alist 'all)
  (global-treesit-auto-mode))

;;;; ---------------------------------------------------------------------------
;;;; Completion UI  (Vertico stack)  ── telescope.nvim
;;;; Vertico enhances Emacs's *native* completing-read; orderless gives the
;;;; fuzzy, space-separated matching that telescope-fzf-native provided.
;;;; ---------------------------------------------------------------------------

(use-package vertico
  :init (vertico-mode))

(use-package orderless
  :custom
  (completion-styles '(orderless basic))
  (completion-category-overrides '((file (styles partial-completion)))))

(use-package marginalia
  :init (marginalia-mode))

(use-package consult
  :bind (("C-x b" . consult-buffer)            ; nicer buffer switcher everywhere
         ;; <leader>f… pickers
         ("C-c f f" . project-find-file)       ; ff  find_files (project-scoped)
         ("C-c f g" . consult-ripgrep)         ; fg  live_grep
         ("C-c f b" . consult-buffer)          ; fb  buffers
         ("C-c f o" . consult-recent-file)     ; fo  oldfiles
         ("C-c f l" . consult-line)            ; (bonus) search current buffer
         ("C-c f h" . consult-info)            ; fh  help_tags  (search the manuals)
         ("C-c f r" . xref-find-references)    ; fr  lsp_references
         ("C-c f d" . xref-find-definitions)   ; fd  lsp_definitions
         ("C-c f a" . execute-extended-command) ; fa  commands  (M-x)
         ("C-c f n" . view-echo-area-messages))) ; fn  notifications (*Messages*)

;;;; ---------------------------------------------------------------------------
;;;; In-buffer completion  (Corfu + Cape)  ── blink.cmp
;;;; Built on Emacs's native completion-at-point. Sources mirror blink's
;;;; { lsp, buffer, snippets, path }.
;;;; ---------------------------------------------------------------------------

(use-package corfu
  :init (global-corfu-mode)
  :custom
  (corfu-auto t)                       ; popup as you type
  (corfu-auto-delay 0.2)               ; blink's auto_show_delay_ms = 200
  (corfu-auto-prefix 2)
  (corfu-popupinfo-delay '(0.2 . 0.1)) ; documentation.auto_show
  :config
  (corfu-popupinfo-mode))              ; floating docs next to the candidate

(use-package cape
  :init
  (add-hook 'completion-at-point-functions #'cape-dabbrev) ; buffer words
  (add-hook 'completion-at-point-functions #'cape-file))   ; path

(use-package yasnippet
  :init (yas-global-mode))
(use-package yasnippet-snippets        ; friendly-snippets
  :after yasnippet)
(use-package yasnippet-capf            ; snippets as a completion source (blink "snippets")
  :after (cape yasnippet)
  :init
  (add-hook 'completion-at-point-functions #'yasnippet-capf))

;;;; ---------------------------------------------------------------------------
;;;; LSP  (eglot, built-in)  ── nvim-lspconfig / mason
;;;; You install the servers yourself; eglot connects to them.
;;;; ---------------------------------------------------------------------------

(use-package eglot
  :ensure nil
  :hook ((python-ts-mode c-ts-mode c++-ts-mode
          js-ts-mode typescript-ts-mode tsx-ts-mode
          lua-ts-mode julia-mode latex-mode tex-mode)
         . eglot-ensure)
  :custom
  (eglot-autoshutdown t)
  :bind (:map eglot-mode-map
              ("C-c l r" . eglot-rename)               ; lr  rename
              ("C-c l a" . eglot-code-actions)         ; la  code action
              ("C-c l f" . xref-find-references)       ; lf  references
              ("C-c l d" . xref-find-definitions)      ; lgd go to definition
              ("C-c l h" . eldoc-doc-buffer)           ; lpd peek/hover in a buffer
              ("C-c l i" . eglot-inlay-hints-mode))    ; lh  toggle inlay hints
  :config
  ;; nvim used pyright, texlab and lua_ls; eglot's defaults differ, so override.
  (add-to-list 'eglot-server-programs
               '((python-mode python-ts-mode) . ("pyright-langserver" "--stdio")))
  (add-to-list 'eglot-server-programs
               '((lua-mode lua-ts-mode) . ("lua-language-server")))
  (add-to-list 'eglot-server-programs
               '((latex-mode tex-mode plain-tex-mode) . ("texlab"))))
;; clangd (c/c++) and typescript-language-server (js/ts) are eglot defaults.

;; Hover docs show in the echo area via eldoc (vim's `K`).
(setq eldoc-echo-area-use-multiline-p t)
(global-eldoc-mode 1)

;;;; ---------------------------------------------------------------------------
;;;; Diagnostics & linting  (flymake, built-in)  ── nvim-lint + diagnostics
;;;; eglot feeds flymake LSP diagnostics; flymake-collection adds external
;;;; linters (flake8, eslint, markdownlint, hadolint). Set
;;;; flymake-collection-config to pin an exact linter per language.
;;;; ---------------------------------------------------------------------------

(use-package flymake
  :ensure nil
  :hook (prog-mode . flymake-mode)
  :bind (:map flymake-mode-map
              ("C-c l l" . flymake-start)                  ; ll  run the linter
              ("C-c l e" . flymake-show-buffer-diagnostics) ; lbd buffer diagnostics
              ("C-c l n" . flymake-goto-next-error)         ; ]e  next diagnostic
              ("C-c l p" . flymake-goto-prev-error))        ; [e  prev diagnostic
  :custom
  (flymake-show-diagnostics-at-end-of-line 'short)) ; inline message ≈ virtual_text

;; lcd  show diagnostic at cursor; flymake stores it as help-echo at point.
(global-set-key (kbd "C-c l c") #'display-local-help)

(use-package flymake-collection
  :hook (after-init . flymake-collection-hook-setup))

;;;; ---------------------------------------------------------------------------
;;;; Formatting  (apheleia)  ── conform.nvim
;;;; ---------------------------------------------------------------------------

(use-package apheleia
  :bind ("C-c i" . apheleia-format-buffer)   ; <leader>i  format buffer
  :config
  ;; Pin each language to the same formatter conform used.
  (dolist (m '((python-mode . black)      (python-ts-mode . black)
               (lua-mode . stylua)        (lua-ts-mode . stylua)
               (c-mode . clang-format)    (c-ts-mode . clang-format)
               (c++-mode . clang-format)  (c++-ts-mode . clang-format)
               (latex-mode . latexindent) (tex-mode . latexindent)
               (js-mode . prettier)       (js-ts-mode . prettier)
               (typescript-ts-mode . prettier) (tsx-ts-mode . prettier)
               (css-mode . prettier)      (css-ts-mode . prettier)
               (html-mode . prettier)     (mhtml-mode . prettier)
               (json-ts-mode . prettier)  (yaml-ts-mode . prettier)
               (markdown-mode . prettier) (gfm-mode . prettier)))
    (setf (alist-get (car m) apheleia-mode-alist) (list (cdr m)))))

;;;; ---------------------------------------------------------------------------
;;;; Git  (magit + diff-hl)  ── gitsigns.nvim
;;;; diff-hl draws the fringe signs and stages/reverts hunks in the buffer;
;;;; magit is the full Git porcelain.
;;;; ---------------------------------------------------------------------------

(use-package magit
  :bind (("C-c g g" . magit-status)             ; the main entry point
         ("C-c g b" . magit-blame-addition)     ; gb  blame line
         ("C-c g d" . magit-diff-buffer-file))) ; gd  diff this
;; magit also binds C-x g -> magit-status globally by default; left as-is.

(use-package diff-hl
  :hook ((after-init . global-diff-hl-mode)
         (magit-pre-refresh  . diff-hl-magit-pre-refresh)
         (magit-post-refresh . diff-hl-magit-post-refresh))
  :bind (("C-c g n" . diff-hl-next-hunk)            ; ]c  next hunk
         ("C-c g N" . diff-hl-previous-hunk)        ; [c  prev hunk
         ("C-c g p" . diff-hl-show-hunk)            ; gp  preview hunk
         ("C-c g r" . diff-hl-revert-hunk)          ; gr  reset hunk
         ("C-c g s" . diff-hl-stage-current-hunk))  ; gs  stage hunk
  :config
  (diff-hl-flydiff-mode))   ; update signs live, without needing to save

;;;; ---------------------------------------------------------------------------
;;;; File browser  (dired + wdired, built-in)  ── oil.nvim
;;;; wdired (C-x C-q) makes the listing editable like oil: edit names as text,
;;;; C-c C-c to apply.
;;;; ---------------------------------------------------------------------------

(use-package dired
  :ensure nil
  :commands (dired dired-jump)
  :bind ("C-c c" . dired-jump)        ; <leader>c  open the browser at this file
  :custom
  (dired-listing-switches "-alh --group-directories-first") ; show hidden + sizes
  (dired-kill-when-opening-new-dired-buffer t)
  (dired-dwim-target t)
  (dired-auto-revert-buffer t))

;;;; ---------------------------------------------------------------------------
;;;; Terminal  (eshell popup)  ── toggleterm.nvim
;;;; eshell is the built-in Lisp shell. Swap the `(eshell)` call for `(eat)` or
;;;; `(vterm)` for a full TTY (TUI apps like btop).
;;;; ---------------------------------------------------------------------------

(add-to-list 'display-buffer-alist
             '("\\*eshell\\*"
               (display-buffer-in-side-window)
               (side . bottom)
               (window-height . 0.3)))

(defun dookie/toggle-eshell ()
  "Toggle an eshell popup along the bottom of the frame."
  (interactive)
  (let ((win (get-buffer-window "*eshell*")))
    (if win
        (delete-window win)
      (pop-to-buffer (save-window-excursion (eshell) (get-buffer "*eshell*"))))))

(global-set-key (kbd "C-c t") #'dookie/toggle-eshell)   ; <leader>t

;;;; ---------------------------------------------------------------------------
;;;; Surround  (embrace)  ── nvim-surround
;;;; C-c s, then an action: s)" wraps, c]} re-pairs, d( strips, etc.
;;;; ---------------------------------------------------------------------------

(use-package embrace
  :bind ("C-c s" . embrace-commander))

;;;; ---------------------------------------------------------------------------
;;;; Markdown  (markdown-mode)  ── render-markdown.nvim
;;;; ---------------------------------------------------------------------------

(use-package markdown-mode
  :mode ("\\.md\\'" . gfm-mode)
  :custom
  (markdown-hide-markup t)             ; conceal **/_/# like render-markdown
  (markdown-fontify-code-blocks-natively t))

;;;; ---------------------------------------------------------------------------
;;;; Org  (built-in; the real thing nvim-orgmode emulates)
;;;; org-modern replaces org-bullets with a cleaner look.
;;;; ---------------------------------------------------------------------------

(use-package org
  :ensure nil
  :bind (("C-c a"   . org-agenda)
         ("C-c o c" . org-capture))
  :custom
  (org-default-notes-file "~/Sync/orgfiles/refile.org")
  (org-hide-emphasis-markers t)        ; conceallevel = 2
  (org-startup-indented t)
  :config
  ;; org_agenda_files = "~/Sync/orgfiles/**/*"  (resolved recursively at startup)
  (when (file-directory-p "~/Sync/orgfiles/")
    (setq org-agenda-files
          (directory-files-recursively "~/Sync/orgfiles/" "\\.org\\'"))))

(use-package org-modern
  :hook (org-mode . org-modern-mode))

;;;; ---------------------------------------------------------------------------
;;;; Julia  (julia-mode + julia-repl + eglot-jl)  ── julia-vim + conjure
;;;; LaTeX-to-unicode (\alpha -> α) is built in: M-x set-input-method TeX,
;;;; or C-\ to toggle it. julia-repl gives conjure-style send-to-REPL eval.
;;;; ---------------------------------------------------------------------------

(use-package julia-mode)

(use-package julia-repl
  :hook ((julia-mode . julia-repl-mode)
         (julia-mode . (lambda () (set-input-method "TeX")))))

(use-package eglot-jl
  :after eglot
  :config (eglot-jl-init))

;;;; ---------------------------------------------------------------------------
;;;; AI  (copilot.el)  ── copilot.lua
;;;; First run: M-x copilot-install-server, then M-x copilot-login.
;;;; ---------------------------------------------------------------------------

(defun dookie/copilot-maybe ()
  "Enable `copilot-mode', but only once the language server is installed.
Before you run \\[copilot-install-server], copilot.el signals
\"@github/copilot-language-server is not installed\" on every window-focus
change. That spams *Messages* and can interrupt package installs, so this
stays off until the server exists."
  (require 'copilot)
  (when (ignore-errors (copilot-installed-version))
    (copilot-mode 1)))

(use-package copilot
  :ensure nil
  :vc (:url "https://github.com/copilot-emacs/copilot.el" :rev :newest)
  :hook ((prog-mode . dookie/copilot-maybe)
         (markdown-mode . dookie/copilot-maybe)) ; filetypes.markdown = true
  :bind (:map copilot-completion-map
              ("TAB"   . copilot-accept-completion)
              ("M-]"   . copilot-next-completion)     ; <M-]>
              ("M-["   . copilot-previous-completion) ; <M-[>
              ("M-RET" . copilot-accept-completion-by-word))
  :custom
  ;; Default is ~/.config/emacs/.cache/copilot, inside the symlinked repo.
  ;; Keep the server (node_modules) in the XDG cache instead.
  (copilot-install-dir (dookie/cache "copilot"))
  :config
  (setq copilot-indent-offset-warning-disable t))

;;;; ---------------------------------------------------------------------------
;;;; Icons  (nerd-icons)  ── mini.icons
;;;; OPTIONAL polish. Run `M-x nerd-icons-install-fonts` once; needs a Nerd Font
;;;; in your terminal/GUI. Delete this block if you don't want icons.
;;;; ---------------------------------------------------------------------------

(use-package nerd-icons)

(use-package nerd-icons-dired
  :hook (dired-mode . nerd-icons-dired-mode))

(use-package nerd-icons-completion
  :after marginalia
  :config
  (nerd-icons-completion-mode)
  :hook (marginalia-mode . nerd-icons-completion-marginalia-setup))

;;; init.el ends here

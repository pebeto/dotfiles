;;; early-init.el --- Loaded before the GUI and package system -*- lexical-binding: t; -*-

;; Raise the GC ceiling during startup, then drop it back so editing stays
;; responsive. Mirrors lazy.nvim's "do the expensive work up front" idea.
(setq gc-cons-threshold (* 64 1000 1000))
(add-hook 'emacs-startup-hook
          (lambda () (setq gc-cons-threshold (* 16 1000 1000))))

;; This directory is a symlink into the dotfiles repo, so every byte Emacs
;; writes here would show up in `git status`. Push the heavy generated state
;; (packages + native-comp cache) into XDG dirs instead. The rest is redirected
;; in init.el. Net effect: the repo only ever holds early-init.el and init.el.
(setq package-user-dir
      (expand-file-name "emacs/elpa"
                        (or (getenv "XDG_DATA_HOME")
                            (expand-file-name "~/.local/share"))))

(when (fboundp 'startup-redirect-eln-cache)
  (startup-redirect-eln-cache
   (expand-file-name "emacs/eln-cache"
                     (or (getenv "XDG_CACHE_HOME")
                         (expand-file-name "~/.cache")))))

;; Strip GUI chrome before the first frame is painted (no flicker).
(push '(menu-bar-lines . 0) default-frame-alist)
(push '(tool-bar-lines . 0) default-frame-alist)
(push '(vertical-scroll-bars) default-frame-alist)
(setq menu-bar-mode nil
      tool-bar-mode nil
      scroll-bar-mode nil)

(setq inhibit-startup-screen t
      initial-scratch-message nil
      frame-resize-pixelwise t
      ring-bell-function 'ignore)

;;; early-init.el ends here

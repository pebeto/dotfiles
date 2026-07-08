;;; early-init.el --- Loaded before the GUI and package system -*- lexical-binding: t; -*-

;; Raise the GC ceiling during startup, then drop it back so editing stays
;; responsive.
(setq gc-cons-threshold (* 64 1000 1000))
(add-hook 'emacs-startup-hook
          (lambda () (setq gc-cons-threshold (* 16 1000 1000))))

;; This directory symlinks into the dotfiles repo, so anything Emacs writes
;; here lands in `git status`. Put packages and the native-comp cache in XDG
;; dirs (init.el redirects the rest), leaving the repo with just these two files.
(setq package-user-dir
      (expand-file-name "emacs/elpa"
                        (or (getenv "XDG_DATA_HOME")
                            (expand-file-name "~/.local/share"))))

;; `startup-redirect-eln-cache' ships in startup.el on every Emacs 29+, but its body reads
;; `native-comp-eln-load-path', which only exists in a native-compilation build. Guarding on
;; `fboundp' alone lets a non-native-comp Emacs (some macOS builds) into the call, where the
;; void variable errors. Gate on the feature too.
(when (and (featurep 'native-compile)
           (fboundp 'startup-redirect-eln-cache))
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

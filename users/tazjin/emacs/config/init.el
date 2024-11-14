;;; init.el --- Package bootstrapping. -*- lexical-binding: t; -*-

;; Disable annoying warnings from native compilation.
(setq native-comp-async-report-warnings-errors nil
      warning-suppress-log-types '((comp)))

;; Packages are installed via Nix configuration, this file only
;; initialises the newly loaded packages.

(require 'use-package)
(require 'seq)

(package-initialize)

;; Initialise all packages installed via Nix.

(use-package ace-window
  :bind (("C-x o" . ace-window))
  :config
  (setq aw-keys '(?f ?j ?d ?k ?s ?l ?a)
        aw-scope 'frame))

(use-package auth-source-pass :config (auth-source-pass-enable))

(use-package avy
  :bind (("M-j" . avy-goto-char)
         ("M-p" . avy-pop-mark)
         ("M-g g" . avy-goto-line)))

(use-package browse-kill-ring)

(use-package company
  :config
  (global-company-mode))

(use-package consult
  :bind
  ("C-c r g" . consult-ripgrep)
  ("C-s" . consult-line))

(use-package dash)
(use-package gruber-darker-theme)

(use-package eglot
  :custom
  (eglot-autoshutdown t)
  (eglot-send-changes-idle-time 0.3))

(use-package ht)

(use-package hydra)
(use-package idle-highlight-mode :hook ((prog-mode . idle-highlight-mode)))

(use-package multiple-cursors)

(use-package notmuch
  :custom
  (notmuch-search-oldest-first nil)
  (notmuch-show-all-tags-list t)
  (notmuch-hello-tag-list-make-query "tag:unread"))

(use-package paredit :hook ((lisp-mode . paredit-mode)
                            (emacs-lisp-mode . paredit-mode)))

(use-package pinentry
  :config
  (setq epa-pinentry-mode 'loopback)
  (pinentry-start))

(use-package prescient
  :config
  (prescient-persist-mode)
  (setq completion-styles '(basic prescient)))

(use-package vertico-prescient
  :config
  (vertico-prescient-mode))

(use-package company-prescient
  :config
  (company-prescient-mode))

(use-package rainbow-delimiters :hook (prog-mode . rainbow-delimiters-mode))
(use-package rainbow-mode)
(use-package s)
(use-package string-edit-at-point)
(use-package term-switcher
  :bind (:map global-map ("C-c v" . #'ts/switch-to-terminal)))

(use-package undo-tree
  :config (global-undo-tree-mode)
  :custom (undo-tree-auto-save-history nil))

(use-package uuidgen)
(use-package which-key :config (which-key-mode t))

;;
;; Applications in emacs
;;

(use-package magit
  :bind ("C-c g" . magit-status)
  :config (setq magit-repository-directories '(("/home/tazjin/projects" . 2)
                                               ("/home/tazjin" . 1))))

(use-package password-store)
(use-package restclient)

(use-package vterm
  :custom
  (vterm-shell "fish")
  (vterm-kill-buffer-on-exit t))

;; vterm removed the ability to set a custom title generator function
;; via the public API, so this overrides its private title generation
;; function instead
(defun vterm--set-title (title)
  (rename-buffer
   (generate-new-buffer-name
    (format "vterm<%s>"
            (s-trim-left
             (s-chop-prefix "fish" title))))))

;;
;; Packages providing language-specific functionality
;;

(use-package cargo
  :hook ((rust-mode . cargo-minor-mode)
         (cargo-process-mode . visual-line-mode))
  :bind (:map cargo-mode-map ("C-c C-c C-l" . ignore)))

(use-package dockerfile-ts-mode)

(use-package erlang
  :hook ((erlang-mode . (lambda ()
                          ;; Don't indent after '>' while I'm writing
                          (local-set-key ">" 'self-insert-command)))))

(use-package f)

(use-package go-ts-mode
  :custom
  (go-ts-mode-indent-offset 4))

(use-package haskell-mode)

(use-package ielm
  :hook ((inferior-emacs-lisp-mode . (lambda ()
                                       (rainbow-delimiters-mode-enable)))))

(use-package jq-mode
  :config (add-to-list 'auto-mode-alist '("\\.jq\\'" . jq-mode)))

(use-package kotlin-mode
  :hook ((kotlin-mode . (lambda ()
                          (setq indent-line-function #'indent-relative)))))

(use-package markdown-mode
  :config
  (add-to-list 'auto-mode-alist '("\\.markdown\\'" . markdown-mode))
  (add-to-list 'auto-mode-alist '("\\.md\\'" . markdown-mode)))

(use-package markdown-toc)
(use-package niri)

(use-package nix-mode
  :hook ((nix-mode . (lambda ()
                       (setq indent-line-function #'nix-indent-line)))))

(use-package nix-util)
(use-package nginx-mode)
(use-package rust-mode)

(use-package sly
  :hook ((sly-mrepl-mode . (lambda ()
                             (paredit-mode)
                             (rainbow-delimiters-mode-enable))))
  :config
  (setq common-lisp-hyperspec-root "file:///home/tazjin/docs/lisp/"))

(use-package telega
  :bind (:map global-map ("C-x c" . (lambda (p) (interactive "P")
                                    (if p (call-interactively #'telega-chat-with)
                                      (telega))))
         :map telega-chat-button-map ("a" . ignore))
  :config (telega-mode-line-mode 1)
  :custom
  (telega-emoji-use-images nil)
  (telega-completing-read-function #'completing-read)
  (telega-video-player-command "vlc"))

(use-package terraform-mode)
(use-package toml-ts-mode)

(use-package treecrumbs
  :hook ((yaml-ts-mode . treecrumbs-mode)))

(use-package tvl)

(use-package vertico
  :config
  (vertico-mode))

(use-package web-mode)
(use-package yaml-ts-mode)
(use-package zoxide)

(use-package passively
  :custom
  (passively-store-state "/persist/tazjin/known-russian-words.el"))

;; Note taking configuration for deft.
(use-package deft
  :custom
  (deft-directory "/persist/tazjin/deft/")
  (deft-extensions '("md" "org" "txt"))
  (deft-default-extension "md"))

(use-package zetteldeft
  :custom
  ;; Configure for Markdown
  (zetteldeft-link-indicator "[[")
  (zetteldeft-link-suffix "]]")
  (zetteldeft-title-prefix "# ")
  (zetteldeft-list-prefix "* "))

;; Initialise midnight.el, which by default automatically cleans up
;; unused buffers at midnight.
(require 'midnight)

(defgroup tazjin nil
  "Settings related to my configuration")

(defcustom depot-path "/depot"
  "Local path to the depot checkout"
  :group 'tazjin)

;; Configuration changes in `customize` can not actually be persisted
;; to the customise file that Emacs is currently using (since it comes
;; from the Nix store).
;;
;; The way this will work for now is that Emacs will *write*
;; configuration to the file tracked in my repository, while not
;; actually *reading* it from there (unless Emacs is rebuilt).
(setq custom-file (f-join depot-path "users" "tazjin" "emacs" "config" "custom.el"))
(load-library "custom")

(defvar home-dir (expand-file-name "~"))

;; Seed RNG
(random t)

;; Load all other Emacs configuration. These configurations are
;; added to `load-path' by Nix.
(mapc 'require '(mail-setup
                 look-and-feel
                 functions
                 settings
                 bindings
                 eshell-setup))
(ace-window-display-mode)

;; If a local configuration library exists, it should be loaded.
;;
;; This can be provided by calling my Emacs derivation with
;; `withLocalConfig'.
(if-let (local-file (locate-library "local"))
    (load local-file))

(require 'dottime)

(provide 'init)

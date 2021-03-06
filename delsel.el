;;; delsel.el --- Delete the region (selection) upon char insertion or DEL.
;;
;; Filename: delsel.el
;; Description: Delete the region (selection) upon char insertion or DEL.
;; Author: Matthieu Devin <devin@lucid.com>, Drew Adams
;; Maintainer: D. ADAMS (concat "drew.adams" "@" "oracle" ".com")
;; Copyright (C) 1996-2015, Drew Adams, all rights reserved.
;; Copyright (C) 1992 Free Software Foundation, Inc.
;; Created: Fri Dec  1 13:51:31 1995
;; Version: 0
;; Package-Requires: ()
;; Last-Updated: Thu Jan  1 10:32:23 2015 (-0800)
;;           By: dradams
;;     Update #: 485
;; URL: http://www.emacswiki.org/delsel.el
;; Doc URL: http://emacswiki.org/DeleteSelectionMode
;; Keywords: abbrev, emulations, local, convenience
;; Compatibility: GNU Emacs: 20.x, 21.x, 22.x, 23.x, 24.x, 25.x
;;
;; Features that might be required by this library:
;;
;;   None
;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;;; Commentary:
;;
;;    Let DEL delete the region; let character insertion replace it.
;;
;;  This file makes the active region be pending a deletion, meaning
;;  that text inserted while the region is active will replace the
;;  region contents, and that operations like `delete-backward-char'
;;  will delete the region.
;;
;;  `C-g' is bound here to `minibuffer-keyboard-quit' in each of the
;;  minibuffer-local-*-map's.
;;
;;
;;  Property `delete-selection':
;;
;;  Commands that delete the selection need a `delete-selection'
;;  property on their symbols. Commands that insert text but do not
;;  have this property do not delete the selection.  The property can
;;  be one of these values:

;;  `yank' - For commands that do a yank.  Ensures that the region
;;           about to be deleted is not yanked.

;;  `supersede' - Delete the active region and ignore the current
;;           command: the command just deletes the region.
;;
;;  `kill' - `kill-region' is used on the selection, rather than
;;           `delete-region'.  (Text selected with the mouse is
;;           typically yankable anyway.)
;;
;;  anything else non-nil - Deletes the active region prior to
;;           executing the command, which inserts replacement
;;           text.  This is the usual case.
;;
;;
;; The original author is Matthieu Devin <devin@lucid.com>.
;; This version was modified by Drew Adams.
;;
;; Main changes here from the original:
;; -----------------------------------
;;
;; 1. Added function `delete-selection-pre-hook-1'.  In fact,
;;    `delete-selection-pre-hook' was renamed to
;;    `delete-selection-pre-hook-1', and a new version of
;;    `delete-selection-pre-hook' was defined in terms of it.
;;    This allowed change #2 (next).
;; 2. Fixed bug: `completion.el' was making things like SPC and `.'
;;    lose on self insert here.
;; 3. Will now work in tandem with `completion.el':
;;    a. `delete-active-region': Deletes latest completion only.
;;       During completion, don't delete region when self-insert.
;;    b. `delete-selection-pre-hook': In case of completion, makes
;;       mark active.
;; 4. `minibuffer-keyboard-quit':
;;    Removes any windows showing *Completions* buffer.
;; 5. `delete-selection-mode': Informs user of new state.
;;
;; You might want to do something like the following in your .emacs:
;;
;;       (make-variable-buffer-local 'transient-mark-mode)
;;       (put 'transient-mark-mode 'permanent-local t)
;;       (setq-default transient-mark-mode t)
;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;;; Change Log:
;;
;; 2014/07/23 dadams
;;     Added: delete-selection-helper.  Modify vanilla version per my
;;            previous delete-selection-pre-hook-1 definition, (1) updating that for types
;;            kill (handle overwrite mode), yank (yank from top of rectangle), and
;;            a function (Emacs 24.3+), and (2) handling text-read-only error.
;;     delete-active-region: Updated for Emacs 24.4:
;;       Bind this-command and use kill-region with 3rd arg REGION.
;;       Handle region-extract-function.
;;     delete-selection-pre-hook:
;;       Added doc string.  Modifed from vanilla delete-selection-helper doc string.
;;     delete-selection-pre-hook-1: Use delete-selection-helper.
;;     self-insert-command (put): Update for Emacs 24.4: self-insert-uses-region-functions.
;;     insert-char, quoted-insert: Put t as delete-selection prop (Emacs bug #13312).
;;     Rename delsel-unload-hook to delsel-unload-function, and create alias for Emacs 20.
;;     delsel-unload-function: Added dolist of functions to nil, per vanilla Emacs 24.4.
;; 2014/06/08 dadams
;;     Added electric-newline-and-maybe-indent and reindent-then-newline-and-indent
;;     for Emacs 24.4.  See Emacs bug #17737.
;; 2013/10/18 dadams
;;     Do not make insert-parentheses delete selection, for Emacs 22+.
;; 2012/08/12 dadams
;;     delete-selection-pre-hook-1: Updated for Emacs 24 bug #12161 fix.
;; 2012/06/02 dadams
;;     delete-selection-pre-hook-1: For yank, rotate kill-ring until get to diff one.
;; 2011/01/03 dadams
;;     Added autoload cookie for command.
;; 2009/10/02 dadams
;;     minibuffer-keyboard-quit:
;;       Don't call delete-windows-on if no buffer.  Thx to Tetzlaff.
;; 2008/05/03 dadams
;;     delete-selection-pre-hook: defun, not defsubst.
;; 2007/09/04 dadams
;;     minibuffer-keyboard-quit: remove-windows-on -> delete-windows-on.
;;     Removed require of frame-cmds.el.
;; 2006/03/31 dadams
;;     No longer use display-in-minibuffer.
;; 2005/12/18 dadams
;;     Use minibuffer-prompt face.  Removed require of def-face-const.el.
;; 2005/12/03 dadams
;;     Removed require (soft) of completion.el.
;; 2004/11/12 dadams
;;     Changed so will work with either byte-compiler: Emacs 20 or 21.
;; 2004/09/21 dadams
;;     Updated to work with Emacs 21 (as well as Emacs 20).
;;     Must byte-compile each version separately, however.
;; 2004/08/09 dadams
;;     Some cleanup to agree more with Emacs 20 standard version.
;; 2001/01/10 dadams
;;     Protected remove-windows-on via fboundp.
;; 1999/03/17 dadams
;;     1. Updated to incorporate Emacs 34.1 version.
;;     2. Protected calls with test fboundp.
;; 1996/02/15 dadams
;;     delete-active-region: During completion, don't delete region
;;       when self-insert.
;; 1995/12/28 dadams
;;     Will now work in tandem with completion.el:
;;       delete-active-region: Deletes latest completion only.
;;       delete-selection-pre-hook: In case of completion, makes mark active.
;;       Added delete-selection-pre-hook.
;; 1995/12/08 dadams
;;     completion.el was making things like SPC and `.' lose on self insert here.
;;     (put 'completion-separator-self-insert-command 'delete-selection t)
;;     (put 'completion-separator-self-insert-autofilling 'delete-selection t)
;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 2, or (at your option)
;; any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program; see the file COPYING.  If not, write to
;; the Free Software Foundation, Inc., 51 Franklin Street, Fifth
;; Floor, Boston, MA 02110-1301, USA.
;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;;; Code:

(and (< emacs-major-version 20) (eval-when-compile (require 'cl))) ;; when, unless


;;;;;;;;;;;;;;;;;;

;; Quiet the byte compiler:
(defvar cmpl-last-insert-location)
(defvar cmpl-original-string)
(defvar completion-to-accept)
(defvar region-extract-function)

;;;;;;;;;;;;;;;;;;

;; This is defined in `faces.el', Emacs 22.  This definition is adapted to Emacs 20.
(unless (facep 'minibuffer-prompt)
  (defface minibuffer-prompt '((((background dark)) (:foreground "cyan"))
                               (t (:foreground "dark blue")))
    "*Face for minibuffer prompts."
    :group 'basic-faces))


;;;###autoload
(defalias 'pending-delete-mode 'delete-selection-mode)

;; Macro `define-minor-mode' is not defined in Emacs 20, so in order
;; to be able to byte-compile this file in Emacs 20, prohibit
;; byte-compiling of the `define-minor-mode' call.
(if (fboundp 'define-minor-mode)

    ;; Emacs 21 ------------
    (eval '(define-minor-mode delete-selection-mode
            "Toggle Delete Selection mode.
With prefix ARG, turn Delete Selection mode on if and only if ARG is
positive.  If called from Lisp, enable the mode if ARG is omitted or
nil.

When Delete Selection mode is enabled, Transient Mark mode is also
enabled, typed text replaces the selection if the selection is active,
and DEL deletes the selection.  Otherwise, typed text is just inserted
at point, as usual."
            :global t :group 'editing-basics
            (if (not delete-selection-mode)
                (remove-hook 'pre-command-hook 'delete-selection-pre-hook)
              (add-hook 'pre-command-hook 'delete-selection-pre-hook)
              (transient-mark-mode t))
            (when (interactive-p)
              (message "Delete Selection mode is now %s."
                       (if delete-selection-mode "ON" "OFF")))))

  ;; Emacs 20 ---------------
  (defun delete-selection-mode (&optional arg)
    "Toggle Delete Selection mode.
With prefix ARG, turn Delete Selection mode on if and only if ARG is
positive.  If called from Lisp, enable the mode if ARG is omitted or
nil.

When Delete Selection mode is enabled, Transient Mark mode is also
enabled, typed text replaces the selection if the selection is active,
and DEL deletes the selection.  Otherwise, typed text is inserted at
point, as usual."
    (interactive "P")
    (setq delete-selection-mode  (if arg
                                     (> (prefix-numeric-value arg) 0)
                                   (not delete-selection-mode)))
    (force-mode-line-update)
    (if (not delete-selection-mode)
        (remove-hook 'pre-command-hook 'delete-selection-pre-hook)
      (add-hook 'pre-command-hook 'delete-selection-pre-hook)
      (transient-mark-mode t))
    (when (interactive-p)
      (message "Delete Selection mode is now %s."
               (if delete-selection-mode "ON" "OFF")))))

;;;###autoload
(defcustom delete-selection-mode nil
  "*Non-nil means Delete Selection mode is enabled.
In this mode, when a region is highlighted, insertion commands first
delete the region, then insert. See command `delete-selection-mode'.
Setting this variable directly does not change the mode; instead, use
either \\[customize] or function `delete-selection-mode'."
  :set (lambda (symbol value) (delete-selection-mode (or value 0)))
  :initialize 'custom-initialize-default
  :type 'boolean
  :group 'editing-basics
  :require 'delsel)


;; CMPL-LAST-INSERT-LOCATION, CMPL-ORIGINAL-STRING and COMPLETION-TO-ACCEPT
;; are free here.
(defun delete-active-region (&optional killp)
  (cond ((and (eq last-command 'complete) ; See `completion.el'.
              (boundp 'cmpl-last-insert-location))
         ;; Do not delete region if a `self-insert-command'.  Delete it only if a
         ;; supersede or a kill.
         (when (and (symbolp this-command)
                    (memq (get this-command 'delete-selection) '(supersede kill)))
           (delete-region (point) cmpl-last-insert-location) ; Free var here.
           (insert cmpl-original-string) ; Free var here.
           (setq completion-to-accept  nil))) ; Free var here.
        (killp
         (let (this-command)
           (if (or (> emacs-major-version 24)
                   (and (= emacs-major-version 24)  (< emacs-minor-version 4)))
               ;; Do not let `kill-region' change `this-command' - see Emacs bug #13312.
               (kill-region (point) (mark) 'REGION)
             (kill-region (point) (mark)))))
        ((boundp 'region-extract-function) ; Emacs 24.4+
         (funcall region-extract-function 'delete-only))
        (t (delete-region (point) (mark))))
  (deactivate-mark)
  t)

(defun delete-selection-pre-hook ()
  "Delete selection according to TYPE:
`yank'
    For commands that yank: Ensure that the region about to be
    deleted is not yanked.

`supersede'
    Delete the active region and ignore the current command.

`kill'
    Use `kill-region' on the selection, rather than `delete-region'.
    (Text selected with the mouse will typically be yankable anyway.)

FUNCTION (Emacs 24.4 or later, only)
    Invoke FUNCTION and then start over, using its return value as the
    new TYPE.  FUNCTION should not require an argument and should
    a value acceptable as TYPE.

other non-nil value
    Delete the active region prior to executing the command that
    inserts replacement text."
  (if (and (eq last-command 'complete)  ; See `completion.el'.
           (boundp 'cmpl-last-insert-location))
      (let ((mark-active  t))
        (delete-selection-pre-hook-1))
    (delete-selection-pre-hook-1)))

(if (< emacs-major-version 21)
    (defun delete-selection-pre-hook-1 ()
      "Helper for `delete-selection-pre-hook'."
      (when (and delete-selection-mode
                 (not buffer-read-only)
                 transient-mark-mode mark-active)
        (let ((type  (and (symbolp this-command)
                          (get this-command 'delete-selection))))
          (cond ((eq type 'kill)
                 (delete-active-region t))
                ((eq type 'yank)
                 ;; Before a yank command.  Make sure we do not yank the same region that
                 ;; we are going to delete.  That would make yank a no-op.
                 (let ((tail  kill-ring))
                   (while (and tail  (string= (buffer-substring-no-properties
                                               (point) (mark))
                                              (car tail)))
                     (current-kill 1)
                     (setq tail  (cdr tail))))
                 (delete-active-region))
                ((eq type 'supersede)
                 (delete-active-region)
                 (setq this-command  'ignore))
                (type (delete-active-region))))))
  (defun delete-selection-pre-hook-1 ()
    "Helper for `delete-selection-pre-hook'."
    (when (and delete-selection-mode
               (not buffer-read-only)
               (if (fboundp 'use-region-p)
                   (use-region-p)
                 (and transient-mark-mode  mark-active)))
      (delete-selection-helper (and (symbolp this-command)
                                    (get this-command 'delete-selection))))))

(defun delete-selection-helper (type)
  "Helper for `delete-selection-pre-hook-1'."
  (condition-case err
      (cond ((eq type 'kill)
             (delete-active-region t)
             ;; Fix `overwrite-mode' for `kill' - see Emacs bug #13312.
             (if (and overwrite-mode  (eq this-command 'self-insert-command))
                 (let ((overwrite-mode  nil))
                   (self-insert-command (prefix-numeric-value current-prefix-arg))
                   (setq this-command 'ignore))))
            ((eq type 'yank)
             ;; Before a yank command, make sure we don't yank the head of the kill-ring
             ;; that really comes from the currently active region we are going to delete.
             ;; That would make yank a no-op.
             (let ((tail  kill-ring))
               (while (and tail  (string= (buffer-substring-no-properties (point) (mark))
                                          (car tail))
                           ;; Vanilla Emacs has this, which seems very wrong.
                           ;; See Emacs bug #18090.
;;;                            (fboundp 'mouse-region-match) ; @@@@@@@@@@ ????
;;;                            (mouse-region-match) ; @@@@@@@@@@ ????
                           )
                 (current-kill 1)
                 (setq tail  (cdr tail))))
             (let ((pos  (copy-marker (region-beginning))))
               (delete-active-region)
               ;; If the region was, say, rectangular, make sure we yank from the top, to
               ;; "replace".
               (goto-char pos)))
            ((eq type 'supersede)
             (let ((empty-region  (= (point) (mark))))
               (delete-active-region)
               (unless empty-region (setq this-command  'ignore))))
            ((and (functionp type)
                  (or (> emacs-major-version 24)
                      (and (= emacs-major-version 24)  (> emacs-minor-version 2))))
             (delete-selection-helper (funcall type)))
            (type
             (delete-active-region)
             (if (and overwrite-mode  (eq this-command 'self-insert-command))
                 (let ((overwrite-mode  nil))
                   (self-insert-command (prefix-numeric-value current-prefix-arg))
                   (setq this-command  'ignore)))))

    ;; If `ask-user-about-supersession-threat' signals an error, stop safe_run_hooks from
    ;; clearing out `pre-command-hook'.
    (file-supersession (message "%s" (cadr err)) (ding))

    ;; This signal may come either from `delete-active-region' or `self-insert-command'
    ;; (when `overwrite-mode' is non-nil).  To avoid clearing out `pre-command-hook' we
    ;; handle this case by issuing a simple message.  Note, however, that we do not
    ;; handle all related problems: When read-only text ends before the end of the
    ;; region, the latter is not deleted but any subsequent insertion will succeed.  We
    ;; could avoid this case by doing a (setq this-command 'ignore) here.  This would,
    ;; however, still not handle the case where read-only text ends precisely where the
    ;; region starts: In that case the deletion would succeed but the subsequent
    ;; insertion would fail with a text-read-only error.  To handle that case we would
    ;; have to investigate text properties at both ends of the region and skip the
    ;; deletion when inserting text is forbidden there.
    (text-read-only (message "Text is read-only") (ding))))


(if (or (> emacs-major-version 24)
        (and (= emacs-major-version 24)  (> emacs-minor-version 2)))
    (put 'self-insert-command 'delete-selection
         (lambda ()
           (not (run-hook-with-args-until-success 'self-insert-uses-region-functions))))
  (put 'self-insert-command 'delete-selection t))

(put 'self-insert-iso 'delete-selection t)

;; These are defined in `completion.el'.
(put 'completion-separator-self-insert-command 'delete-selection t)
(put 'completion-separator-self-insert-autofilling 'delete-selection t)

(put 'insert-char 'delete-selection t)
(put 'quoted-insert 'delete-selection t)

(put 'yank 'delete-selection 'yank)
(put 'clipboard-yank 'delete-selection 'yank)
(put 'insert-register 'delete-selection t)

(put 'delete-backward-char 'delete-selection 'supersede)
(put 'backward-delete-char-untabify 'delete-selection 'supersede)
(put 'delete-char 'delete-selection 'supersede)

(put 'electric-newline-and-maybe-indent 'delete-selection t)
(put 'reindent-then-newline-and-indent 'delete-selection t)
(put 'newline-and-indent 'delete-selection t)
(put 'newline 'delete-selection t)
(put 'open-line 'delete-selection 'kill)

(when (< emacs-major-version 22)        ; New `insert-parentheses' behavior.
  (put 'insert-parentheses 'delete-selection t))

;; This can be used to cancel a selection in the minibuffer without
;; aborting the minibuffer.
;;;###autoload
(defun minibuffer-keyboard-quit ()
  "Abort recursive edit.
In Delete Selection mode, if the mark is active, just deactivate it;
then it takes a second \\[keyboard-quit] to abort the minibuffer."
  (interactive)
  (if (and delete-selection-mode transient-mark-mode mark-active)
      (setq deactivate-mark  t)
    (when (get-buffer "*Completions*") (delete-windows-on "*Completions*"))
    (abort-recursive-edit)))

(define-key minibuffer-local-map "\C-g" 'minibuffer-keyboard-quit)
(define-key minibuffer-local-ns-map "\C-g" 'minibuffer-keyboard-quit)
(define-key minibuffer-local-completion-map "\C-g" 'minibuffer-keyboard-quit)
(define-key minibuffer-local-must-match-map "\C-g" 'minibuffer-keyboard-quit)
(define-key minibuffer-local-isearch-map "\C-g" 'minibuffer-keyboard-quit)

(defun delsel-unload-function ()
  (define-key minibuffer-local-map "\C-g" 'abort-recursive-edit)
  (define-key minibuffer-local-ns-map "\C-g" 'abort-recursive-edit)
  (define-key minibuffer-local-completion-map "\C-g" 'abort-recursive-edit)
  (define-key minibuffer-local-must-match-map "\C-g" 'abort-recursive-edit)
  (define-key minibuffer-local-isearch-map "\C-g" 'abort-recursive-edit)
  (dolist (sym  '(self-insert-command  insert-char  quoted-insert yank
                  clipboard-yank  insert-register  newline-and-indent
                  reindent-then-newline-and-indent  newline  open-line))
    (put sym 'delete-selection nil)))

(when (< emacs-major-version 21)
  (defalias 'delsel-unload-hook 'delsel-unload-function))


;;;;;;;;;;;;;;;;;;;;;;;

;; Turn on Delete Selection mode if `delete-selection-mode' is non-nil
;; when this file is loaded.

(when delete-selection-mode (delete-selection-mode t))

(provide 'delsel)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; delsel.el ends here

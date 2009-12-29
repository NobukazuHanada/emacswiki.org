;;; sunrise-x-checkpoints.el ---  Checkpoint bookmarks for the Sunrise Commander
;;; File Manager

;; Copyright (C) 2009 José Alfredo Romero Latouche (j0s3l0)

;; Author: José Alfredo Romero L. <escherdragon@gmail.com>
;; Keywords: Sunrise Commander Emacs File Manager Checkpoints Bookmarks

;; This program is free software: you can redistribute it and/or modify it under
;; the terms of the GNU General Public License as published by the Free Software
;; Foundation,  either  version  3 of the License, or (at your option) any later
;; version.
;;
;; This  program  is distributed in the hope that it will be useful, but WITHOUT
;; ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
;; FOR  A  PARTICULAR  PURPOSE.  See the GNU General Public License for more de-
;; tails.

;; You  should have received a copy of the GNU General Public License along with
;; this program. If not, see <http://www.gnu.org/licenses/>.

;;; Commentary:

;; Beginning with version 4 of the Sunrise Commander, checkpoints were redefined
;; to be a special form of bookmarks. Unfortunately, the differences between the
;; bookmarks  frameworks in Emacs 22 and Emacs 23 are so big that including this
;; code directly in the sunrise-commander script would make it incompatible with
;; Emacs  22.  For  this reason both versions of checkpoints are now provided as
;; dynamically loaded extensions, so that you can decide which of them  to  use.
;; To  be  sure,  this  is  the version I intend to further develop, as it has a
;; richer set of functions and integrates more nicely to the rest of Emacs.  The
;; other  one is deprecated and will eventually disappear once Emacs 23+ becomes
;; the "stable" release.

;; This is version 1 $Rev: 246 $ of the Sunrise Commander Checkpoints Extension.

;; It  was  written and tested on GNU Emacs 23 on Linux.

;;; Installation and Usage:

;; 1) Put this file somewhere in your Emacs load-path. (Optionally) compile it.

;; 2)  Enjoy  ;-) -- Sunrise should pick the correct extension automatically. On
;; Emacs 23 it will look for sunrise-x-checkpoints, while on Emacs 22 it'll  try
;; to  load  sunrise-x-old-checkpoints. Only if you *really* want to use the old
;; extensions on Emacs 23 you may add a new (require 'sunrise-x-old-checkpoints)
;; expression to your .emacs file somewhere after (require 'sunrise-commander).

;;; Code:

(defalias 'sr-checkpoint-save    'sr-checkpoint-bookmark)

(defun sr-checkpoint-bookmark (arg)
  "Creates a new checkpoint bookmark to save the location of both panes."
  (interactive "p")
  (let ((bookmark-make-record-function 'sr-make-checkpoint-record))
    (sr-save-directories)
    (call-interactively 'bookmark-set)))

(defun sr-checkpoint-restore (arg)
  "Calls interactively bookmark-jump."
  (interactive "p")
  (call-interactively 'bookmark-jump))

(defun sr-make-checkpoint-record ()
  "Generates a the bookmark record for a new checkpoint."
  `((filename . ,(format "Sunrise Checkpoint: %s | %s"
                         sr-left-directory sr-right-directory))
    (sr-directories . (,sr-left-directory ,sr-right-directory))
    (handler . sr-checkpoint-handler)))

(defun sr-checkpoint-handler (bookmark)
  "Handler for checkpoint bookmarks."
  (print bookmark)
  (or sr-running (sunrise))
  (sr-select-window 'left)
  (let ((dirs (cdr (assq 'sr-directories (cdr bookmark)))) (missing))
    (mapc (lambda (x)
            (if (file-directory-p x)
                (progn (dired x) (sr-bookmark-jump))
              (setq missing (cons sr-selected-window missing)))
            (sr-change-window))
          dirs)
    (if missing (sr-checkpoint-relocate bookmark (reverse missing)))))

(defun sr-checkpoint-relocate (bookmark &optional sides)
  "Handles relocation of checkpoint bookmarks."
  (interactive (list (bookmark-completing-read "Bookmark to relocate")))
  (let* ((sides (or sides '(left right)))
         (name (car bookmark))
         (dirs (assq 'sr-directories (cdr bookmark)))
         (relocs (mapcar
                  (lambda (x)
                    (read-directory-name
                     (format "Relocate %s [%s] to: " name (symbol-name x))))
                  sides))
         (result (cond ((< 1 (length relocs)) relocs)
                       ((eq 'right (car sides)) (list (cadr dirs) (car relocs)))
                       (t (list (car relocs) (caddr dirs))))))
    (setcdr dirs result)
    (bookmark-set-filename
     bookmark (apply 'format "Sunrise Checkpoint: %s | %s" result)))
  (bookmark-save)
  (sr-checkpoint-handler bookmark))

(defadvice bookmark-relocate
  (around sr-advice-bookmark-relocate (bookmark))
  (let ((bmk (bookmark-get-bookmark bookmark)))
    (if (assq 'sr-directories bmk)
        (sr-checkpoint-relocate bmk)
      ad-do-it)))
(ad-activate 'bookmark-relocate)

(provide 'sunrise-x-checkpoints)

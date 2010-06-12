;;; notify.el --- notification front-end

;; Copyright (C) 2008  Mark A. Hershberger

;; Original Author: Mark A. Hershberger <mhersberger@intrahealth.org>
;; Modified by Andrey Kotlarski <m00naticus@gmail.com>
;; Keywords: extensions, convenience, lisp

;; This file is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 2, or (at your option)
;; any later version.

;; This file is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with GNU Emacs; see the file COPYING.  If not, write to
;; the Free Software Foundation, Inc., 59 Temple Place - Suite 330,
;; Boston, MA 02111-1307, USA.

;;; Commentary:

;; This provides a single function, `notify', that will produce a notify
;; pop-up via D-Bus, libnotify or simple message.
;; To use, just put (autoload 'notify "notify" "Notify TITLE, BODY.")
;;  in your init file.  You may override default chosen notification
;;  method by assigning `notify-method' to one of 'notify-via-dbus
;; 'notify-via-shell or 'notify-via-message
;;; Code:

(defvar notify-defaults (list :app "Emacs" :icon "emacs" :timeout 5000
			      :urgency "low"
			      :category "emacs.message")
  "Notification settings' defaults.
May be overridden with key-value additional arguments to `notify'.")
(defvar notify-delay '(0 5 0)
  "Minimum time allowed between notifications in time format.")
(defvar notify-last-notification '(0 0 0) "Time of last notification.")
(defvar notify-method nil "Notification method among
'notify-via-dbus, 'notify-via-shell or 'notify-via-message.")

;; determine notification method unless already set
;; prefer D-Bus > libnotify > message
(cond
 ((null notify-method)
  (setq notify-method
	(cond
	 ((and (require 'dbus nil t)
	       (dbus-ping :session "org.freedesktop.Notifications"))
	  (defvar notify-id 0 "Current D-Bus notification id.")
	  'notify-via-dbus)
	 ((executable-find "notify-send") 'notify-via-shell)
	 (t 'notify-via-message))))
 ((eq notify-method 'notify-via-dbus) ;housekeeping for pre-chosen DBus
  (if (and (require 'dbus nil t)
	   (dbus-ping :session "org.freedesktop.Notifications"))
      (defvar notify-id 0 "Current D-Bus notification id.")
    (setq notify-method (if (executable-find "notify-send")
			    'notify-via-shell
			  'notify-via-message))))
 ((and (eq notify-method 'notify-via-shell)
       (not (executable-find "notify-send"))) ;housekeeping for pre-chosen libnotify
  (setq notify-method
	(if (and (require 'dbus nil t)
		 (dbus-ping :session "org.freedesktop.Notifications"))
	    (progn
	      (defvar notify-id 0 "Current D-Bus notification id.")
	      'notify-via-dbus)
	  'notify-via-message))))

(defun notify-via-dbus (title body)
  "Send notification with TITLE, BODY `D-Bus'."
  (dbus-call-method :session "org.freedesktop.Notifications"
		    "/org/freedesktop/Notifications"
		    "org.freedesktop.Notifications" "Notify"
		    (get 'notify-defaults :app)
		    (setq notify-id (+ notify-id 1))
		    (get 'notify-defaults :icon) title body '(:array)
		    '(:array :signature "{sv}") ':int32
		    (get 'notify-defaults :timeout)))

(defun notify-via-shell-escape (str)
  "Escape special STR characters before passing to a shell command."
  (replace-regexp-in-string "['&]" (lambda (m)
				     (cond ((equal m "'") "`")
					   ((equal m "&") " and ")
					   ((equal m "<") "{")))
			    str))

(defun notify-via-shell (title body)
  "Notify with TITLE, BODY via `libnotify'."
  (shell-command
   (concat "notify-send '" (notify-via-shell-escape title) "' '"
	   (notify-via-shell-escape body)
	   "' -t " (number-to-string (get 'notify-defaults :timeout))
	   " -i '" (get 'notify-defaults :icon)
	   "' -u " (get 'notify-defaults :urgency)
	   " -c " (get 'notify-defaults :category))))

(defun notify-via-message (title body)
  "Notify TITLE, BODY with a simple message."
  (message "%s: %s" title body))

(defun keywords-to-properties (symbol args &optional defaults)
  "Add to SYMBOL's property list key-values from ARGS and DEFAULTS."
  (when (consp defaults)
    (keywords-to-properties symbol defaults))
  (while args
    (put symbol (car args) (cadr args))
    (setq args (cddr args))))

;;;###autoload
(defun notify (title body &rest args)
  "Notify TITLE, BODY via `notify-method'.
ARGS may be amongst :timeout, :icon, :urgency, :app and :category."
  (when (time-less-p notify-delay
		     (time-since notify-last-notification))
    (or (eq notify-method 'notify-via-message)
	(keywords-to-properties 'notify-defaults args
				notify-defaults))
    (setq notify-last-notification (current-time))
    (funcall notify-method title body)))

(provide 'notify)

;;; notify.el ends here

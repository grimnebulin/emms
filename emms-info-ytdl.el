;;; emms-info-ytdl.el --- info-method for EMMS using ytdl  -*- lexical-binding: t; -*-

;; Copyright (C) 2020  Free Software Foundation, Inc.

;; Author: Yuchen Pei (ycp@gnu.org)
;; Keywords: multimedia

;; EMMS is free software; you can redistribute it and/or modify it
;; under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; EMMS is distributed in the hope that it will be useful, but WITHOUT
;; ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
;; or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public
;; License for more details.

;; You should have received a copy of the GNU General Public License
;; along with EMMS; see the file COPYING..  If not, see
;; <https://www.gnu.org/licenses/>.

;;; Commentary:

;; (add-to-list emms-info-functions 'emms-info-ytdl)

;; To use this you would need to have `emms-info-ytdl-command`
;; (typically youtube-dl or yt-dlp) installed on your system.


;;; Code:

(require 'emms-info)
(require 'json)


(defgroup emms-info-ytdl nil
  "Options for EMMS."
  :group 'emms-info)

(defvar emms-info-ytdl-field-map
  '((info-title        . title)
    (info-artist       . artist)
    (info-playing-time . duration))
  "Mapping for ytdl output.")

(defvar emms-info-ytdl-regexp
  "^https?://"
  "Regexp to use ytdl to get info.")

(defvar emms-info-ytdl-exclude-regexp
  "\\(\\.\\w+$\\|/playlist\\|/channel\\)"
  "Regexp not to use ytdl to get info.")

(defvar emms-info-ytdl-command
  "youtube-dl"
  "Command to run for emms-info-ytdl.")

(defun emms-info-ytdl (track)
  "Set TRACK info using ytdl."
  (when (and (eq (emms-track-type track) 'url)
             (string-match emms-info-ytdl-regexp (emms-track-name track))
             (not
              (string-match emms-info-ytdl-exclude-regexp
                            (emms-track-name track))))
    (with-temp-buffer
      (when (zerop
             (let ((coding-system-for-read 'utf-8))
               (call-process emms-info-ytdl-command nil '(t nil) nil
                             "-j" (emms-track-name track))))
        (goto-char (point-min))
        (condition-case nil
            (let ((json-fields (json-read)))
              (mapc
               (lambda (field-map)
                 (let ((emms-field (car field-map))
                       (ytdl-field (cdr field-map)))
                   (let ((track-field (assoc ytdl-field json-fields)))
                     (when track-field
                       (emms-track-set
                        track
                        emms-field
                        (if (eq emms-field 'info-playing-time)
                            (truncate (cdr track-field))
                          (cdr track-field)))))))
               emms-info-ytdl-field-map))
          (error (message "error while reading track info")))
        track))))

(provide 'emms-info-ytdl)

;;; emms-info-ytdl.el ends here

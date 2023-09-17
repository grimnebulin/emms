;;; emms-info-vorbis.el --- EMMS Vorbis info support  -*- lexical-binding: t; -*-

;; Copyright (C) 2020-2023 Free Software Foundation, Inc.

;; Author: Petteri Hintsanen <petterih@iki.fi>

;; This file is part of EMMS.

;; EMMS is free software; you can redistribute it and/or modify it
;; under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 3, or (at your option)
;; any later version.

;; EMMS is distributed in the hope that it will be useful, but WITHOUT
;; ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
;; or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public
;; License for more details.

;; You should have received a copy of the GNU General Public License
;; along with EMMS; see the file COPYING. If not, write to the Free
;; Software Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston,
;; MA 02110-1301, USA.

;;; Commentary:

;; This file contains Vorbis-specific code for `emms-info-ogg'.

;;; Code:

(require 'bindat)

(defconst emms-info-vorbis--max-comments 1024
  "Maximum number of Vorbis comment fields in a stream.
Technically a single Vorbis stream may have up to 2^32 comments,
but in practice processing must be constrained to prevent memory
exhaustion in case of garbled or malicious inputs.

This limit is used with Opus and FLAC streams as well, since
their comments have almost the same format as Vorbis.")

(defconst emms-info-vorbis--max-comment-size (* 64 1024)
  "Maximum length for a single Vorbis comment field.
Technically a single Vorbis comment may have a length up to 2^32
bytes, but in practice processing must be constrained to prevent
memory exhaustion in case of garbled or malicious inputs.

This limit is used with Opus and FLAC streams as well, since
their comments have almost the same format as Vorbis.")

(defconst emms-info-vorbis--max-vendor-length 1024
  "Maximum length of Vorbis vendor string.
Technically a vendor string can be up to 2^32 bytes long, but in
practice processing must be constrained to prevent memory
exhaustion in case of garbled or malicious inputs.

This limit is used with Opus and FLAC streams as well, since
their comments have almost the same format as Vorbis.")

(defconst emms-info-vorbis--accepted-fields
  '("album"
    "albumartist"
    "albumartistsort"
    "albumsort"
    "artist"
    "artistsort"
    "composer"
    "composersort"
    "date"
    "discnumber"
    "genre"
    "label"
    "originaldate"
    "originalyear"
    "performer"
    "title"
    "titlesort"
    "tracknumber"
    "year")
  "EMMS info fields that are extracted from Vorbis comments.")

(defconst emms-info-vorbis--header-magic-pattern "vorbis"
  "Header packet magic pattern.")

(defconst emms-info-vorbis--id-header-bindat-spec
  (if (eval-when-compile (fboundp 'bindat-type))
      (bindat-type
        (packet-type u8)
        (_ unit (unless (= packet-type 1)
                  (error "Vorbis header type mismatch: expected 1, got %s"
                         packet-type)))
        (vorbis str 6)
        (_ unit (unless (equal vorbis emms-info-vorbis--header-magic-pattern)
                  (error "Vorbis framing mismatch: expected `%s', got `%s'"
                         emms-info-vorbis--header-magic-pattern
                         vorbis)))
        (vorbis-version uint 32 'le)
        (_ unit (unless (= vorbis-version 0)
                  (error "Vorbis version mismatch: expected 0, got %s"
                         vorbis-version)))
        (channel-count u8)
        (sample-rate uint 32 'le)
        (bitrate-maximum uint 32 'le)
        (bitrate-nominal uint 32 'le)
        (bitrate-minimum uint 32 'le)
        (blocksize u8)
        (framing-flag u8)
        (_ unit (unless (= framing-flag 1)
                  (error "Vorbis framing bit mismatch: expected 1, got %s"
                         framing-flag))))
    '((packet-type u8)
      (eval (unless (= last 1)
              (error "Vorbis header type mismatch: expected 1, got %s"
                     last)))
      (vorbis str 6)
      (eval (unless (equal last emms-info-vorbis--header-magic-pattern)
              (error "Vorbis framing mismatch: expected `%s', got `%s'"
                     emms-info-vorbis--header-magic-pattern
                     last)))
      (vorbis-version u32r)
      (eval (unless (= last 0)
              (error "Vorbis version mismatch: expected 0, got %s"
                     last)))
      (channel-count u8)
      (sample-rate u32r)
      (bitrate-maximum u32r)
      (bitrate-nominal u32r)
      (bitrate-minimum u32r)
      (blocksize u8)
      (framing-flag u8)
      (eval (unless (= last 1))
            (error "Vorbis framing bit mismatch: expected 1, got %s"
                   last))))
  "Vorbis identification header specification.")

(defconst emms-info-vorbis--comment-field-bindat-spec
  (if (eval-when-compile (fboundp 'bindat-type))
      (bindat-type
        (length uint 32 'le)
        (_ unit (when (> length emms-info-vorbis--max-comment-size)
                  (error "Vorbis comment length %s is too long"
                         length)))
        (user-comment str length))
    '((length u32r)
      (eval (when (> last emms-info-vorbis--max-comment-size)
              (error "Vorbis comment length %s is too long" last)))
      (user-comment str (length))))
  "Vorbis comment field specification.")

(defconst emms-info-vorbis--comment-header-bindat-spec
  (if (eval-when-compile (fboundp 'bindat-type))
      (bindat-type
        (packet-type u8)
        (_ unit (unless (= packet-type 3)
                  (error "Vorbis header type mismatch: expected 3, got %s"
                         packet-type)))
        (vorbis str 6)
        (_ unit (unless (equal vorbis emms-info-vorbis--header-magic-pattern)
                  (error "Vorbis framing mismatch: expected `%s', got `%s'"
                         emms-info-vorbis--header-magic-pattern
                         vorbis)))
        (vendor-length uint 32 'le)
        (_ unit (when (> vendor-length emms-info-vorbis--max-vendor-length)
                  (error "Vorbis vendor length %s is too long"
                         vendor-length)))
        (vendor-string str vendor-length)
        (user-comments-list-length uint 32 'le)
        (_ unit (when (> user-comments-list-length emms-info-vorbis--max-comments)
                  (error "Vorbis user comment list length %s is too long"
                         user-comments-list-length)))
        (user-comments repeat user-comments-list-length
                       type emms-info-vorbis--comment-field-bindat-spec)
        (framing-bit u8)
        (_ unit (unless (= framing-bit 1)
                  (error "Vorbis framing bit mismatch: expected 1, got %s"
                         framing-bit))))
    '((packet-type u8)
      (eval (unless (= last 3)
              (error "Vorbis header type mismatch: expected 3, got %s"
                     last)))
      (vorbis str 6)
      (eval (unless (equal last emms-info-vorbis--header-magic-pattern)
              (error "Vorbis framing mismatch: expected `%s', got `%s'"
                     emms-info-vorbis--header-magic-pattern
                     last)))
      (vendor-length u32r)
      (eval (when (> last emms-info-vorbis--max-vendor-length)
              (error "Vorbis vendor length %s is too long" last)))
      (vendor-string str (vendor-length))
      (user-comments-list-length u32r)
      (eval (when (> last emms-info-vorbis--max-comments)
              (error "Vorbis user comment list length %s is too long"
                     last)))
      (user-comments repeat
                     (user-comments-list-length)
                     (struct emms-info-vorbis--comment-field-bindat-spec))
      (framing-bit u8)
      (eval (unless (= last 1))
            (error "Vorbis framing bit mismatch: expected 1, got %s"
                   last))))
  "Vorbis comment header specification.")

(defconst emms-info-vorbis--headers-bindat-spec
  (if (eval-when-compile (fboundp 'bindat-type))
      (bindat-type
        (_ struct (identification-header type emms-info-vorbis--id-header-bindat-spec)
                  (comment-header type emms-info-vorbis--comment-header-bindat-spec)))
    '((identification-header struct emms-info-vorbis--id-header-bindat-spec)
      (comment-header struct emms-info-vorbis--comment-header-bindat-spec)))
  "Specification for first two Vorbis header packets.
They are always an identification header followed by a comment
header.")

(defun emms-info-vorbis-extract-comments (user-comments)
  "Return a decoded list of comments from USER-COMMENTS.
USER-COMMENTS should be a list of Vorbis comments according to
`user-comments' field in
`emms-info-vorbis--comment-header-bindat-spec'.

Return comments in a list of (FIELD . VALUE) cons cells.  Only
FIELDs that are listed in `emms-info-vorbis--accepted-fields' are
returned."
  (let (comments)
    (dolist (user-comment user-comments)
      (let* ((comment (alist-get 'user-comment user-comment))
             (pair (emms-info-vorbis--split-comment comment)))
        (when (member (car pair) emms-info-vorbis--accepted-fields)
          (push pair comments))))
    comments))

(defun emms-info-vorbis--split-comment (comment)
  "Split Vorbis COMMENT to a field-value pair.
Vorbis comments are of form `FIELD=VALUE'.  FIELD is a
case-insensitive field name with a restricted set of ASCII
characters.  VALUE is an arbitrary UTF-8 encoded octet stream.
Comments with empty FIELD or VALUE are ignored.

Return a cons cell (FIELD . VALUE), where FIELD is converted to
lower case and VALUE is the decoded value."
  (let ((comment-string (decode-coding-string comment 'utf-8)))
    (when (string-match "^\\(.+?\\)=\\(.+\\)$" comment-string)
      (cons (downcase (match-string 1 comment-string))
            (match-string 2 comment-string)))))

(provide 'emms-info-vorbis)

;;; emms-info-vorbis.el ends here

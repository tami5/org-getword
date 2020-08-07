;;; org-getword.el --- Get word information -*- lexical-binding: t; -*-
;;
;; Created: July 31, 2020
;; Modified: July 31, 2020
;; Version: 0.3
;; Keywords: dictionary lookup
;; Homepage: https://github.com/tami5/org-getword
;; Package-Requires: ((emacs 26.3) (jeison "1.0.0"))
;;
;; This file is not part of GNU Emacs.

;; getword.el is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; getword.el is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with getword.el.
;; If not, see <http://www.gnu.org/licenses/>.;;
;;
;;; Commentary:
;;  Check github readme.

;;; Code:
(require 'jeison)
(require 'url)
(require 'dash)
(require 's)
(require 'cl-seq)

(defgroup org-getword nil
  "Make it easy to deal with words and key terms."
  :prefix "org-getword-"
  :group 'tool
  :link '(url-link :tag "Repository" "https://github.com/tami5/org-getword"))

(defcustom org-getword-lingua-api-key nil
  "Api key for  to https://www.linguarobot.io/."
  :type 'string
  :group 'org-getword)

(defcustom org-getword-azure-translation-api-key nil
  "Api key for  to https://www.linguarobot.io/."
  :type 'string
  :group 'org-getword)

(defcustom org-getword-include-forms t
  "Whether to include word forms."
  :type 'boolean
  :group 'org-getword)

(defcustom org-getword-use-simple-entry t
  "Whether to use a simple structure or heading based structure."
  :type 'boolean
  :group 'org-getword)

(defcustom org-getword-include-usage-description t
  "Whether to include word usage description. Requires additional HTTP request."
  :type 'boolean
  :group 'org-getword)

(defcustom org-getword-capture-file-location
  "~/org/vocabulary.org"
  "The org file where to append org entries."
  :group 'org-getword
  :type 'string)

;; Jeison class for parsing json into objects
(jeison-defclass lingua-defs nil
  ((definition :initarg :definition )
   (usageExamples :initarg :usageExamples)
   (labels :initarg :labels)))

(jeison-defclass lingua-forms nil
  ((form :initarg :form )
   (grammar :initarg :grammar)
   (labels :initarg :labels)))

(jeison-defclass lingua-lexemes nil
  ((partOfSpeech :initarg :partOfSpeech)
    (senses :initarg :senses :type (list-of lingua-defs))
    (forms :initarg :forms :type (list-of lingua-forms))
    (synonymSets :initarg :synonymSets)))

(jeison-defclass lingua-pronu nil
  ((transcriptions :initarg :transcriptions)
   (audio :initarg :audio)
   (url :initarg :url :path (audio url))))

(jeison-defclass lingua-items nil
  ((entry :initarg :entry :type string :path (entries 0 entry))
    (pronu :initarg :pronu :type (list-of lingua-pronu) :path (entries 0 pronunciations))
    (lexem :initarg :lexem :type (list-of lingua-lexemes) :path (entries 0 lexemes))))

;;;###autoload
(defun org-getword-append-from-clipboard ()
  "From clipboard, silently append a formated org entry to 'org-getword-capture-file-location'."
  (interactive)
  (org-getword--append (org-getword--misc-get-clipboard-content))
  )

;;;###autoload
(defun org-getword-append-from-prompt ()
  "From prompt, append a formated org entry to 'org-getword-capture-file-location'."
  (interactive)
  (org-getword--append
   (read-string "Word: ") ;; TODO: add autocompletion
   ))

;;;###autoload
(defun org-getword-insert-from-clipboard ()
  "From clipboard, insert a formated org entry."
  ;;(interactive)
  (with-temp-buffer
    (insert (org-getword--format-org-entry (org-getword--fetch-from-lingua (org-getword--misc-get-clipboard-content))))
    (buffer-string)))

;;;###autoload
(defun org-getword-insert-from-prompt ()
  "From prompt, insert a formated org entry."
  (with-temp-buffer
    (insert (org-getword--format-org-entry (org-getword--fetch-from-lingua (read-string "Word: "))))
    (buffer-string)))


;;;###autoload
(defun org-getword-from-a-list ()
  "For each word in a list, insert a formated org entry."
)

;;;###autoload
(defun org-getword-set-apikey ()
  "Set api key from a file."
)

;;;###autoload
(defun org-getword-insert-usage-examples (word)
  "Insert after a elisp link a `WORD' usage example."
  ;; TODO: Focus on actual word usage, meaning just keep the first and last two words to `WORD'.
  ;; TODO: Get rid of echo message (org-getword-insert-usage-examples word) => nil after running the function
  ;;(interactive)
  (save-excursion
    (goto-char (re-search-forward "]]"))
    (set-mark (line-end-position))
    (let ((formatted-string (s-join "\n" (org-getword--fetch-examples-from-yourdictionary word))))
      (if (s-present? formatted-string)
          (insert (concat "\n" formatted-string))
        (insert (concat "\n Sorry no example has been found for ~" word "~."))
     ))))

;;;###autoload
(defun org-getword-insert-definitions (word)
  "Insert after a elisp link a `WORD' definitions."
  (save-excursion
    (goto-char (re-search-forward "]]"))
    (set-mark (line-end-position))
    (insert (concat "\n" (org-getword--fetch-definitions-from-wordnik word)))))

;;;###autoload
(defun org-getword-play-audio (url)
  "Play audio from a `URL'."
  ;; TODO: support other platfroms
  ;;(interactive)
  (start-process "mpv" nil "mpv" "" url))

;;;###autoload
(defun org-getword-define-at-point (word-point)
  "Find word at `WORD-POINT', look it up, and present a list of definitions for it."
  (interactive (list (point)))
  (save-mark-and-excursion
    (unless (org-getword--misc-is-at-the-beginning-of-word word-point)
      (backward-word))
    (set-mark (point))
    (forward-word)
    (activate-mark)
    (message (org-getword--fetch-definitions-from-wordnik (buffer-substring (region-beginning) (region-end)))))
  )

;;;###autoload
(defun org-getword-speak-content (start end)
  "Speak selected region. START END."
  (interactive "r")
  (save-excursion
    (let ((content
           (if (use-region-p)
               (buffer-substring start end)
             (thing-at-point 'line))))
      (org-getword-play-audio
       (org-getword--fetch-audio
        (s-replace-regexp
         (rx (or "*" "[" "]" "#" "/" "~" ":drill:")) ""
         content))))))

(defun org-getword--append (word)
  "Silently append a WORD formated org entry to 'org-getword-capture-file-location'."
   ;; (interactive)
  (with-temp-buffer
    (insert "\n* ")
    (insert (org-getword--format-org-entry (org-getword--fetch-from-lingua word)))
    (append-to-file (point-min) (point-max) org-getword-capture-file-location)
  ))

(defun org-getword--format-org-entry (lingua)
  "Format an org entry for a new WORD, from `LINGUA' Object."
  (with-temp-buffer
    (goto-char (point-min))
    (insert (concat "[[elisp:(org-getword-play-audio \"" (org-getword--parse-audio-url lingua) "\")][" (oref lingua entry) "]]" " :drill:\n"))
    (if org-getword-use-simple-entry
        (progn
          (insert (org-getword--simple-fetch-from-vocabulary (oref lingua entry)))
          (insert (org-getword--simple-parse-definitions lingua))
          (insert "\n")
          (insert (org-getword--simple-parse-forms lingua))
          (insert (concat "\n** [[elisp:(org-getword-insert-usage-examples \"" (oref lingua entry) "\")][Examples]]"))
          (insert (concat "\n** [[elisp:(org-getword-insert-definitions \"" (oref lingua entry) "\")][More Definitions]]"))
          )
      (progn
        (insert ":PROPERTIES:\n:DRILL_CARD_TYPE: twosided\n:END:")
        (insert (concat "\n** Word\n" (oref lingua entry)))
        (insert (concat "\n** Meaning\n" (org-getword--parse-definitions lingua) "\n"))
        (if org-getword-include-usage-description
            (insert (concat "\n** Description\n\n" (org-getword--fetch-from-vocabulary (oref lingua entry)) "\n")))
        (if org-getword-include-forms
            (insert (concat "** Forms\n" (org-getword--parse-forms lingua))))
        ))
    (buffer-string)))


(defun org-getword--parse-audio-url (lingua)
  "Parse a audio url from `LINGUA' Object."
  (format "%s" (car ;; get the first one
                (delete nil ;; delete nil
                        (mapcar
                         (lambda (pronunciation) (oref pronunciation url))
                         (oref lingua pronu)))))
  )

(defun org-getword--parse-definitions (lingua)
  "Parse and format `LINGUA' definitions with partOfSpeech as non-org-heading.
Definition as list. Examples wrapped in brackets"
  ;; TODO: Unclutter
  ;; TODO: Have figurative definitions in spreated list starting with /figurative/ as /noun/ ..
  (let ((parsed-definitions
         (s-join "\n"
                 (mapcar
                  (lambda (item)
                    (let ((speech (oref item partOfSpeech)))
                      (format
                       "%1$s\n- %2$s"
                       (format "\n/%s/" speech)
                       (s-join
                        "\n- "
                        (let ((definition
                                (lambda (subitem)
                                  (let* ((def (oref subitem definition))
                                         (labels (s-join ", " (append (oref subitem labels) nil)))
                                         (examples (s-join " | " (append (oref subitem usageExamples) nil))))
                                    (format "%1$s %2$s%3$s"
                                            (format "*%s*" def)
                                            (if (string= labels "")
                                                (format "%s" labels)
                                              (format "/%s/" labels))
                                            (if (string= examples "")
                                                (format "%s" examples)
                                              (format "\n  [%s]" examples)))))))
                          (mapcar definition (oref item senses)))))))(oref lingua lexem)))))
    (with-temp-buffer
      (insert parsed-definitions)
      (org-getword--misc-flush-lines ".*obsolete.*")
      (org-getword--misc-recode-region)
      (buffer-string)))
  )

(defun org-getword--simple-parse-definitions (lingua)
  "Parse and format `LINGUA' definitions with partOfSpeech as non-org-heading.
Definition as list. Examples wrapped in brackets"
 ;; [Word] in X form means ...
  (let ((parsed-definitions
         (s-join "\n"
                 (mapcar
                  (lambda (item)
                    (let ((speech (oref item partOfSpeech)))
                      (format
                       "%1$s %2$s"
                       (format "/As a %1$s, [%2$s] means:/" speech (oref lingua entry))
                       (car (let ((definition
                                             (lambda (subitem)
                                               (format "%1$s %2$s"
                                                       (format "%s" (oref subitem definition))
                                                       (format "%s" (s-join " " (append (oref subitem labels) nil)))
                                            ))))
                          (mapcar definition (oref item senses)))))))(oref lingua lexem)))))
    (with-temp-buffer
      (insert parsed-definitions)
      (org-getword--misc-flush-lines ".*obsolete.*")
      (org-getword--misc-replace-all-match "uncountable" "")
      (org-getword--misc-replace-all-match "countable" "")
      (org-getword--misc-replace-all-match "comparable" "")
      (org-getword--misc-replace-all-match "informal" "")
      (org-getword--misc-recode-region)
      (buffer-string)))

)


(defun org-getword--parse-forms (lingua)
  "Parse and format forms based on `LINGUA' object.
Each form shall be in a heading with elisp function to fetch usage examples."
  (with-temp-buffer
    (insert (concat "*** [[elisp:(org-getword-insert-usage-examples \"" (oref lingua entry) "\")][" (oref lingua entry) "]]"))
    (let ((forms
           (mapcar
            (lambda (item)
              (format "%s"
                      (mapcar
                       (lambda (form)
                         (format
                          (concat
                           "\n*** "
                           "[[elisp:(org-getword-insert-usage-examples "
                           "\"%2$s\")][%1$s]] %3$s")
                          (oref form form) ;; TODO: find better way, all the unnecessary
                          (oref form form) ;; the replace-regex down can be eliminated.
                          (oref form labels)))
                       (oref item forms))))
            (oref lingua lexem))))
      (insert (format "%s" forms))
      (let ((cleanup
             (concat (regexp-opt '( "\(" "\)" "/nil/" "nil")))))
        (org-getword--misc-replace-all-match cleanup ""))
      (org-getword--misc-replace-all-match ":" ":(")
      (org-getword--misc-replace-all-match "\"]" "\"\)]")
      (org-getword--misc-flush-lines ".*obsolete.*")
      (org-getword--misc-flush-lines ".*uncommon.*")
      (org-getword--misc-delete-duplicated-lines)
      )
    (buffer-string)
    ))

(defun org-getword--simple-parse-forms (lingua)
  "Parse and format forms based on `LINGUA' object.
Each form shall be in a heading with elisp function to fetch usage examples."
  (with-temp-buffer
    (insert "Other forms: ")
    (let ((forms (mapcar (lambda (item)
              (format "%s," (mapcar
                             (lambda (form)
                               (format "%1$s, %2$s" (oref form form) (delete nil (oref form labels))))
                             (oref item forms))))
                         (oref lingua lexem))))
      (insert (format "[%s]" forms)))
    (let ((cleanup (concat (regexp-opt '( "\(" "\)" "/nil/" "nil")))))
        (org-getword--misc-replace-all-match cleanup ""))
      (org-getword--misc-replace-all-match "\\[obsolete\\]" "")
      (org-getword--misc-replace-all-match ", ,\]" "\]")
      (org-getword--misc-replace-all-match " ," "")
      ;; (org-getword--misc-replace-all-match "\\[\\]" "")
    (buffer-string)
    ))


(defun org-getword--fetch-audio (content)
  "Fetch audio file for a word or phrase represented as CONTENT."
  (concat
        "https://microsoft-azure-translation-v1.p.rapidapi.com/Speak?text="
        (url-hexify-string content) "&language=en&"
        "&rapidapi-key=" org-getword-azure-translation-api-key
        "&rapidapi-host=microsoft-azure-translation-v1.p.rapidapi.com"))

(defun org-getword--fetch-definitions-from-wordnik (word)
  "Fetch definitions from wordnik.com, accepts WORD and return list of definitions."
  ;;(interactive)
  (let ((defs
          (with-current-buffer
              (url-retrieve-synchronously (concat "https://www.wordnik.com/words/" (downcase word)))
            (org-getword--misc-replace-all-match "<li><abbr[^>]*>" "\n- ")
            (org-getword--misc-replace-all-match "^.*ynonyms.*" "")
            (org-getword--misc-replace-all-match " </abbr> <i></i>  " " ")
            (org-getword--misc-replace-all-match "</abbr> " " ")
            (org-getword--misc-replace-all-match (concat "\"" (downcase word) "\">") "")
            (let ((cleanup (concat (regexp-opt '("</internalXref>" "<internalXref urlencoded="
                                         "verb " "transitive" "noun" "adverb"
                                         "adjective" "intransitive" "<xref>"
                                         "<strong>" "</strong>" "</xref>"
                                         "<i></i>" "</li>" "<em>" "</em>")))))
              (org-getword--misc-replace-all-match cleanup ""))
            (org-getword--misc-replace-all-match "</i>" "/") ;; Feild
            (org-getword--misc-replace-all-match "<i>" "/")  ;; Feild
            (org-getword--misc-replace-all-match "  " " ") ;; Fix the issue with dubble spaces
            (org-getword--misc-replace-all-match "  " " ") ;; Fix the issue with dubble spaces
            (org-getword--misc-replace-all-match "^.*obsolete.*" "")
            (org-getword--misc-replace-all-match "^.*archaic.*" "")
            (org-getword--misc-replace-all-match (concat "\\b" word) (concat "\[" (downcase word) "\]"))
            (keep-lines "^- " (point-min) (point-max))
            ;; (org-getword--misc-replace-all-match "-" "")
            (buffer-string))))
    ;; (split-string defs "\n")
    defs
  ))

(defun org-getword--fetch-from-lingua (word)
  "Make an api call to lingua with a `WORD' and get jeison format."
  ;; Check if the apikey is set, and if not notify the user.
  (if
      (not (and (boundp 'org-getword-lingua-api-key)
                (stringp org-getword-lingua-api-key)))
      (let ((error-msg
             (concat
              "Ops, It seems like Lingua apikey isn't defined."
              "Please visit linguarobot.io, then set your api lkie this:"
              "  (setq org-getword-lingua-api-key \"XXXXXXXXXXXX\") \n")))
        (message-box error-msg)
        nil)
    ;; Get an EIEIO object from the response.
    (jeison-read
     lingua-items ;; FIXME: reference to free variable
     (with-current-buffer
         (url-retrieve-synchronously
          (concat
           "https://lingua-robot.p.rapidapi.com/language/v1/entries/en/"
           (downcase word) "/?rapidapi-key=" org-getword-lingua-api-key
           "&rapidapi-host=lingua-robot.p.rapidapi.com"))
       (keep-lines "^\{" (point-min) (point-max)) ;; NOTE: There must be better way with url package.
       (buffer-string)))))


(defun org-getword--fetch-examples-from-yourdictionary (word)
    "Fetch a list of a `WORD' usage examples from yourdictonary.com."
    (let ((result
           (with-current-buffer
               (url-retrieve-synchronously
                (concat
                 "https://sentence.yourdictionary.com/" (downcase word)))
             (org-getword--misc-replace-all-match "</p></div> <div data-v.*\?class=\"sentence com" "")
             (org-getword--misc-replace-all-match "ponent\"><p>" "\n- ")
             (keep-lines "^- " (point-min) (point-max))
             (let ((cleanup
                    (concat (regexp-opt '( "</p></div>.*" "<span class=\"emphasis\">" "</span>")))))
               (org-getword--misc-replace-all-match cleanup ""))
             (org-getword--misc-replace-all-match "^.\\{140,\\}.*" "")
             (org-getword--misc-mark-keyword word)

             (buffer-string))))
      (-take 4 (delete "" (remove-duplicates (s-lines result))))))


(defun org-getword--fetch-from-vocabulary (word)
  "Fetch a `WORD' describtion from vocabulary.com."
  (with-current-buffer
      (url-retrieve-synchronously
       (concat
        "https://www.vocabulary.com/dictionary/"
        (downcase word)))

    (org-getword--misc-replace-all-match  "<meta name=\"description\" content=\"" "\n- ")
    (org-getword--misc-replace-all-match  "\" />" "")
    (keep-lines "^-" (point-min) (point-max))
    (org-getword--misc-mark-keyword word)
    (org-getword--misc-replace-all-match  "" "")
    (org-getword--misc-replace-all-match  "^- " "")
    (org-getword--misc-fix-formating-issues)
    (org-getword--misc-recode-region)
    (buffer-string)
    ))

(defun org-getword--simple-fetch-from-vocabulary (word)
  "Fetch a `WORD' describtion from vocabulary.com."
  (with-current-buffer
      (url-retrieve-synchronously
       (concat
        "https://www.vocabulary.com/dictionary/"
        (downcase word)))

    (org-getword--misc-replace-all-match  "<meta name=\"description\" content=\"" "\n- ")
    (org-getword--misc-replace-all-match  "\" />" "")
    (keep-lines "^-" (point-min) (point-max))
    ;;(org-getword--misc-mark-keyword word)
    (org-getword--misc-replace-all-match  word (concat "[" word "]"))
    (org-getword--misc-replace-all-match  "" "")
    (org-getword--misc-replace-all-match  "^- " "")
    (org-getword--misc-fix-formating-issues)
    (org-getword--misc-recode-region)
    (buffer-string)
    ))

(defun org-getword--misc-is-at-the-beginning-of-word (word-point)
  "Predicate to check whether `WORD-POINT' points to the beginning of the word."
  (save-excursion
    ;; If we are at the beginning of a word
    ;; this will take us to the beginning of the previous word.
    ;; Otherwise, this will take us to the beginning of the current word.
    (backward-word)
    ;; This will take us to the end of the previous word or to the end
    ;; of the current word depending on whether we were at the beginning
    ;; of a word.
    (forward-word)
    ;; Compare our original position with wherever we're now to
    ;; separate those two cases
    (< (point) word-point)))

(defun org-getword--misc-fix-formating-issues ()
  "A growing collection to fix stuff like &#39;."
  (org-getword--misc-replace-all-match "&#39;" "'")
  (org-getword--misc-replace-all-match "&#039;" "'")
  (org-getword--misc-replace-all-match "&#034;" "\""))


(defun org-getword--misc-mark-keyword (word)
  "Mark all occurance of a `WORD' so that its more visible in the buffer."
  (org-getword--misc-replace-all-match (concat word)
                                   (concat "~" word "~")))


(defun org-getword--misc-replace-all-match  (from to)
  "A simple wrapper that replace a match `FROM' a string `TO' a string."
    (goto-char (point-min))
    (while (re-search-forward from nil t)
        (replace-match to)))


(defun org-getword--misc-flush-lines (regex)
  "Unnecessary wrapper to delete a line with the matching `REGEX'."
  (flush-lines regex (point-min) (point-max))
  )


(defun org-getword--misc-recode-region (&optional coding-system)
    "Replace the region with a recoded text, args: `START' `END' and optionally: `CODING-SYSTEM'."
    ;; TODO: support other coding system such as for windows
    (setq coding-system (or coding-system 'utf-8))
    (let ((buffer-read-only nil)
    (text (buffer-substring (point-min) (point-max))))
    (delete-region (point-min) (point-max))
    (insert (decode-coding-string (string-make-unibyte text) coding-system))))


(defun org-getword--misc-delete-duplicated-lines ()
  "Find duplicate lines in region START to END keeping first occurrence."
    (let ((end (copy-marker (point-max))))
      (while
          (progn
            (goto-char (point-min))
            (re-search-forward "^\\(.*\\)\n\\(\\(.*\n\\)*\\)\\1\n" end t))
        (replace-match "\\1\n\\2"))))

(defun org-getword--misc-get-clipboard-content ()
    "Return the content of clipboard as string."
    (with-temp-buffer
      (clipboard-yank)
      (buffer-substring-no-properties (point-min) (point-max))))



(provide 'org-getword)
;;; org-getword.el ends here


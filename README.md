# org-getword

This package enable its users to append a nicely format description,
definitions, forms, and usage exmples of a word in a org file.

In order for this package to work properly, you must first go to
https://rapidapi.com/rokish/api/lingua-robot/pricing and register
to get an API key (additional costs after 2k+ lookup in a day) .
Then, set it like this:

```elisp
(setq org-getword-lingua-api-key "XXXXXXXXXXXX")
```

Additionally, you might want to change the following to fit your
preferences on what to include or exclude from your org vocabulary entry.

```elisp
(setq
  org-getword-include-forms t
  org-getword-include-usage-description t
  org-getword-capture-file-location "~/org/vocabulary.org")
```
Finally, you might be better off setting the following keyboard shortcuts:

```elsip
(define-key global-map (kbd "C-c g c") 'org-getword-append-from-clipboard)
(define-key global-map (kbd "C-c g p") 'org-getword-append-from-prompt)
```
-and/or-

```elisp
(setq org-capture-templates
      '(("g" "getword from clipboard" entry (file org-getword-capture-file-location)
         "* %?%(org-getword-insert-from-clipboard)")
        ("p" "getword from prompt" entry (file org-getword-capture-file-location)
         "* %?%(org-getword-insert-from-prompt)")
        ))
```


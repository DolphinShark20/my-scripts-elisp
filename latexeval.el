;;; latexeval.el --- script to (if possible) evaluate the LaTeX fragment under the mark

;;; Commentary:
;;; Found that occasionally, for examples in my notes, I would need to solve
;;; for whatever variable or concept is being made an example of.
;;; Doing these by hand, while not difficult, was simply tedious, and
;;; I thought it may be a fun way to improve my ability to write elisp
;;; *GOALS*:
;;; [O] Fix any and all potential errors
;;; [X] Have the evaluation be returned in the echo-area
;;; [O] Improve error catching system (E.G.: Catching LaTeX fragments that are unsolvable/not written properly)
;;; [X] Have the evaluation be added to the LaTeX fragment as the result.

;;; Code:

(require 'calc)
(require 'org)

(defun extract-fragment-plaintext-info ()
  "Extracts the plaintext of the LaTeX fragment that the mark is currently over, and returns relevant information."
  (if (and
       (string-match "\\$\\$" (current-word))
       (image-at-point-p)
       )

      (save-excursion
	(let (
	      (start-pos (re-search-forward "\\$\\$"))
	      )
	  (next-property-change start-pos)
	  (let* (
		 (end-pos (- (re-search-forward "\\$\\$") 2))
		 )
	    (list (buffer-substring start-pos end-pos) start-pos end-pos)
	    )
	  )
	)
        (message "LaTeX fragment not recognised! Make sure your mark is over the image fragment!")
    )
  )

(defun count-special-elements (latex-ptext)
  "Count the number of occurences of LaTeX-syntax within LATEX-PTEXT '\div', '\frac', etc."
  (with-temp-buffer
    (insert latex-ptext)
    (goto-char (point-min))
;;; List formatted with the occurences of things in equation form that are equivalent to basic maths operations
    ;;; Currently: [Multiplication] [Division]
    ;;; More can be added later.
    (list (+ (how-many "\\\\cdot") (how-many ")(")) (+ (how-many "\\\\div") (how-many "\\\\frac")))
    )
  )

(defun transform-latex-plaintext (plaintex)
  "Transform the latex plaintext, PLAINTEX, into a form that the calculator can recognise."
  (let* (
	 (ptext plaintex)
	 (occur-list (count-special-elements ptext))
	 (n-tex-multi (nth 0 occur-list))
	 (n-tex-div (nth 1 occur-list))
	 )
    ;;; Div and Frac are separated for now, as I'm uncertain on how I can use regex to more-or-less manipulate text /around/ subjects (IE transforming
    ;;; "\frac{text1}{text2}" into "(text1)/(text2)".
    ;;; ^ Above issue has been resolved. Using capture groups, I can very easily achieve this!
    (when (not (eq n-tex-multi 0))
	  (setq ptext (replace-regexp-in-string "\\\\cdot" "*" ptext))
	  (setq ptext (replace-regexp-in-string "(\\([^()]+\\))(\\([^()]+)\\)" "((\\1) * \\2))" ptext))
      )
    (when (not (eq n-tex-div 0))
	  (setq ptext (replace-regexp-in-string "\\\\div" "/" ptext))
	  (setq ptext (replace-regexp-in-string "\\\\frac{\\([^{}]+\\)}{\\([^{}]+\\)}" "((\\1)/(\\2))" ptext))
      )
    ;;; Finally, the formatting is done, and we can run it through the calculation function 'calc-eval'.
    ;;; Unfortunately, doesn't seem to be able to comprehend the format that I thought it could.
    ;;; Doesn't seem to know what to do with "(10)/(2)" which is odd.
    ;;; I'll have to check the documentation.
    ;;; ^ It seems the problem is not necessarily with the formatting, but rather the /type/.
    ;;; It may be that I need to manually convert ptext to an explicit string format (even though string-manipulation functions have worked)
    ;;; ^ This has now been fixed. It was as a result of me believing that 'replace-regexp-in-string' would place the results of the operation
    ;;; back Into the input string (an assumption spurred on from the use of 'replace-regexp' when modifying buffers), which caused the un-formatted string to
    ;;; be fed into 'calc-eval', prompting the error.
    ;;; It has now been fixed by simply ensuring that the correct values are applied to where they should be!

    ptext
    )
  )

(defun lateval ()
  "Evaluate the equation in latex fragment under point."
  (interactive)
  (let* (
	(plaintex (nth 0 (extract-fragment-plaintext-info)))
	(transformed-plaintex (transform-latex-plaintext plaintex))
	(result (calc-eval transformed-plaintex))
	)
    (message "The answer is: %s" result)
    )
  )

(defun lateval-ins ()
  "Insert result of equation into the latex fragment."
  (interactive)
  (let* (
	(latex-info (extract-fragment-plaintext-info))
	(plaintex (nth 0 latex-info))
	(equation-end-pos (nth 2 latex-info))
	(proper-plaintex (transform-latex-plaintext plaintex))
	(result (calc-eval proper-plaintex))
	)
    (goto-char equation-end-pos)
    (insert (concat "=" result))
    ;;; Extremely slow, freezes all of Emacs; maybe async could remedy this?
    (org-latex-preview)
    )
  (message "Finished result insertion!")
  )

(provide 'latexeval)
;;; latexeval.el ends here

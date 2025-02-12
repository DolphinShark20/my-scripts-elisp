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
;;; [O] Have the evaluation be added to the LaTeX fragment as the result.

;;; Code:

(require 'calc)

(defun find-plaintext-of-current-latex ()
  "Extracts the plaintext of the LaTeX image that the mark is currently over."
  (if (and
       (string-match "\\$\\$" (current-word))
       (image-at-point-p)
       )

      (save-excursion
	(backward-char)
	(let (
	      (start-pos (re-search-forward "\\$\\$"))
	      )
	  (next-property-change start-pos)
	  (let* (
		 (end-pos (- (re-search-forward "\\$\\$") 2))
		 (latex-plain (buffer-substring start-pos end-pos))
		 )
	    (with-temp-buffer
	      (insert latex-plain)
	      (goto-char (point-min))
	      	  ;;; Values that are returned in format "[PLAINTEXT] [NUM LaTeX multiplication (add more symbols if necessary)] [NUM LaTeX division] [NUM fractions]:
	      (list latex-plain (+ (how-many "\\\\cdot") (how-many ")(")) (+ (how-many "\\\\div") (how-many "\\\\frac")))
	      )
	    )
	  )
	)
    (message "LaTeX fragment not recognised! Make sure your mark is over the image fragment!")
    )
  )

(defun parse-plaintext-latex ()
  "Parse the plaintex into a form that the calculator can recognise."
  (let* (
	 (cap-out (find-plaintext-of-current-latex))
	 (ptext (car cap-out))
	 (n-tex-multi (nth 1 cap-out))
	 (n-tex-div (nth 2 cap-out))
	 )
    ;;; Div and Frac are separated for now, as I'm uncertain on how I can use regex to more-or-less manipulate text /around/ subjects (IE transforming
    ;;; "\frac{text1}{text2}" into "(text1)/(text2)".
    ;;; ^ Above issue has been resolved. Using capture groups, I can very easily achieve this!
    (if (not (eq n-tex-multi 0))
	(progn
	  (setq ptext (replace-regexp-in-string "\\\\cdot" "*" ptext))
	  (setq ptext (replace-regexp-in-string "(\\([^()]+\\))(\\([^()]+)\\)" "((\\1) * \\2))" ptext))
          )
      )
    (if (not (eq n-tex-div 0))
	(progn
	  (setq ptext (replace-regexp-in-string "\\\\div" "/" ptext))
	  (setq ptext (replace-regexp-in-string "\\\\frac{\\([^{}]+\\)}{\\([^{}]+\\)}" "((\\1)/(\\2))" ptext))
	  )
      )
    ;;; Finally, the formatting is done, and we can run it through the calculation function 'calc-eval'.
    ;;; Unfortunately, doesn't seem to be able to comprehend the format that I thought it could.
    ;;; Doesn't seem to know what to do with "(10)/(2)" which is odd.
    ;;; I'll have to check the documentation.
    ;;; ^ It seems the problem is not necessarily with the formatting, but rather the /type/.
    ;;; It may be that I need to manually convert ptext to an explicit string format (even though string-manipulation functions have worked)
    ;;; ^ This has now been fixed. It was as a result of me believing that 'replace-regexp-in-string' would place the results of the operation
    ;;; back Into the input string (an assumption spurred on from the use of 'replace-regexp' when modifying buffers), which caused the un-parsed string to
    ;;; be fed into 'calc-eval', prompting the error.
    ;;; It has now been fixed by simply ensuring that the correct values are applied to where they should be!

    (calc-eval ptext)
    )
  )

(defun lateval ()
  "User-facing function for the sake of implementing tweaks."
  (interactive)
  (message "The answer is: %s" (parse-plaintext-latex))
  )

(provide 'latexeval)
;;; latexeval.el ends here

;;; org-test.el --- script aiming to provide a way to simply set up tests through org files
;;; Commentary:
;;; I find, when working with my C code, there's always the risk of it having subtle bugs as a result of oversight.
;;; Standard input when testing such programs from the shell may /seem/ to get back an appropriate answer, but when faced with specific or extreme
;;; values, they break down.
;;; The issue is thus that it's repetitive and annoying to seek out these kinds of bugs after making a (seemingly) innocuous change, and so
;;; I thought it may be a good idea to put together a script that can do this repetitive testing for me, check the output from the program, and
;;; then inform me whether or not the program got the answer it was supposed to.
;;; In order to configure these tests, I settled on using a custom org-mode file that the script would find, interpret, and act on.
;;; Further explaination about how the config file should be formatted can be found at the bottom of the script.
;;; Code:
(require 'tramp)

(defun error-message-create (fail-list)
  "Create the error message shown when test(s) fail using info from FAIL-LIST."
  (with-temp-buffer
    (insert "%s tests have failed!\nHere's some additional information:\n\n")
    (let (
	  (counter 0)
	  (fail-num (length fail-list))
	  )
      (while (not (eq counter fail-num))
	(let* (
	      (cur-test-row-num (* counter 4))
	      (cur-alias (nth cur-test-row-num fail-list))
	      (cur-proc-out (nth (+ cur-alias 1) fail-list))
	      (cur-test-input (nth (+ cur-alias 2) fail-list))
	      (cur-test-output (nth (+ cur-alias 3) fail-list))
	      )
	  
	;;; There are 4 pieces of info for each failed test:
	;;; 1. 'T-ALIAS' - the name associated with the test
	;;; 2. 'OUT-PROC' - the actual output of the program
	;;; 3. 'T-INPUT' - the input argument
	;;; 4. 'T-OUTPUT' - the expected output
	  (insert (concat "Test: '" cur-alias "'\nInput: '" cur-test-input "'\nProduced output: '" cur-proc-out "'\nWhen the expected output was... '" cur-test-output "'\n\n"))
	  )
	(setq counter (+ counter 1))
	)
      (string (buffer-string))
      )
    )
  )

(defun index-found-otests (config-ptext)
  "Find any test from CONFIG-PTEXT and put their location in returned list."
  (with-temp-buffer
    (insert config-ptext)
    (goto-char (point-min))
    (let (
	  (test-search-end nil)
	  (test-locations ())
	  )
      (while (eq test-search-end nil)
	(let (
	      (test-search (re-search-forward "\\*\\*\\s-*" nil t))
	      )
	  
	  (if (not test-search)
	      (setq test-search-end t)
	    (progn
	      (setq test-locations (cons test-search test-locations))
	      )
	    )
	  )
	)
      ;;; Finally returns a list with elements 0 -> (num of locations - 1)
      (nreverse test-locations)
      )
    )
  )

;;; Extracts information from each test block
(defun extract-otest-info (config-ptext test-pos)
  "Find the input and expected output from CONFIG-PTEXT using TEST-POS."
  (with-temp-buffer
    (insert config-ptext)
    (goto-char test-pos)
    (let (
	  (ALIAS (buffer-substring (point) (- (re-search-forward "\\\n") 1)))
	  (CONFIG-BLOCK (buffer-substring (point) (- (re-search-forward ".*\\\n.*\\\n") 1)))
	  (INPUT-EXTRACT nil)
	  (OUTPUT-EXTRACT nil)
	  )
      (delete-region (point-min) (point-max))
      (insert CONFIG-BLOCK)
      (goto-char (point-min))
      (re-search-forward "INPUT\\s-*==\\s-*\\\[\\(.*\\)\\\]")
      (setq INPUT-EXTRACT (match-string-no-properties 1))
      (re-search-forward "EXP_OUTPUT\\s-*==\\s-*\\\[\\(.*\\)\\\]")
      (setq OUTPUT-EXTRACT (match-string-no-properties 1))
      (list INPUT-EXTRACT OUTPUT-EXTRACT ALIAS)
      )
    )
  )

;;; Does what it says on the tin: runs the executable using the input (as arguments) and then compares
;;; the executable's output to the expected output.
;;; Returns a list comprised of 1. The result (t for successful, nil for failed) 2. The alias associated with the test
;;; and 3. The actual output of the executable.
(defun run-tests-and-compare (IO EXEC-PATH)
  "Run EXEC-PATH with argument IO[0] and compare output to IO[1]."
  (with-temp-buffer
    (let* (
	   (T-INPUT (nth 0 IO))
	   (T-OUTPUT (nth 1 IO))
	   (T-ALIAS (nth 2 IO))
	   (T-PROCESS (start-process "TEST-PROCESS" (current-buffer) EXEC-PATH T-INPUT))
	   (T-RESULT nil)
	   (OUT-PROC nil)
	   )
      (set-process-filter T-PROCESS
			  (lambda (PROC OUT-STR)
			    (if (string-match T-OUTPUT OUT-STR)
				(setq T-RESULT t)
			      (setq T-RESULT nil)
			      )
			    (setq OUT-PROC OUT-STR)
			    )
			  )
      (list T-RESULT T-ALIAS OUT-PROC T-INPUT T-OUTPUT)
      )
    )
  )

;;; Despite the name, doesn't actually parse, but rather sort of processes the appropriate information.
;;; It calls for the locations of the tests within the test file using 'index-found-otests', then iterates
;;; through them to 1. find their test information (the input and expected output) 2. run the program and compare
;;; the output with the expected output 3. Sorts important test output into lists 'true-tests' and 'false-tests'.
;;; Returns a list combing the two lists.
(defun otest-config-parse (config-ptext exec-path)
  "Return list of test results, made by parsing CONFIG-PTEXT and EXEC-PATH."
  (with-temp-buffer
    (insert config-ptext)
    (goto-char (point-min))
    (let* (
	   (found-otest-list (index-found-otests config-ptext))
	   (num-otests (length found-otest-list))
	   (counter 0)
	   (true-tests '())
	   (false-tests '())
	   )
      (while (not (eq counter num-otests))
	(let* (
	       (InOutList (extract-otest-info config-ptext (nth counter found-otest-list)))
	       (ProgramOutList (run-tests-and-compare InOutList exec-path))
	       (TestResult (car ProgramOutList))
	       (TestRunInfo (cdr ProgramOutList))
	       
	       )
	  (if (nth 0 ProgramOutList)
	      (setq true-tests (append true-tests TestRunInfo))
	    (setq false-tests (append false-tests TestRunInfo))
	    )
	  )
	(setq counter (+ counter 1))
	)
      (list true-tests false-tests)
      )
    )
  )

(defun otest ()
  "Callable function of the org-test script."
  (interactive)
  (let* (
	 (usr-input (read-from-minibuffer "Name of C program: "))
	 (config-file-name (concat usr-input "-OCONFIG.org"))
	 (cur-dir (file-name-directory (buffer-file-name)))
	 (exec-path (concat cur-dir usr-input ".exe"))
	 (config-status (file-exists-p config-file-name))
	 )
    (if config-status
	(let* (
	       (config-ptext (tramp-get-buffer-string (find-file-noselect config-file-name)))
	       (result-lists (otest-config-parse config-ptext exec-path))
	       )
	  (if (eq (length (cdr result-lists)) 0)
	      (message "All tests have been completed successfully! No deviant output!")
	    (progn
	      (let (
		    (buf-name (get-buffer-create "*OTEST OUTPUT*"))
		    )
		(with-current-buffer buf-name
		  (erase-buffer)
		  (insert (error-message-string (cdr result-lists)))
		  (read-only-mode 1)
		  )
		(display-buffer buf-name '(display-buffer-pop-up-window buf-name nil))
		)
	      )
	    )
	  )
      (message (concat "Config file '" config-file-name "' cannot be found in the local directory!"))
      )
    )
  )

;;; In order to create an org-test config file, you must create an org-mode file with the name: "[Executable name in local dir]-OCONFIG.org".
;;; Then, for the inside of the file, an example may be more helpful than just outright explaining it:
;;; Org-Test config for testing a program that adds two arguments together then outputs the result:
;;;
;;; * TESTS
;;; ** Small number test
;;; INPUT == [3 5]
;;; EXP_OUTPUT == [8]
;;; ** Medium number test
;;; INPUT == [1000 630]
;;; EXP_OUTPUT == [1630]
;;; ** Large number test
;;; INPUT = [1000000 400000]
;;; EXP_OUTPUT = [1400000]
;;;
;;; You can add as many tests as you'd by adding more "** [Another tests' names]"
;;; and its appropriate input and output. It's important to note that the program
;;; must only output the result of whatever operation you're attempting to test,
;;; so org-test is honestly a very rudimentary script that I built with a specific program, with
;;; rather fickel output, in mind.

(provide 'org-test)
;;; org-test.el ends here.

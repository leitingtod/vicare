;;;Ikarus Scheme -- A compiler for R6RS Scheme.
;;;Copyright (C) 2006,2007,2008  Abdulaziz Ghuloum
;;;Modified by Marco Maggi <marco.maggi-ipsu@poste.it>
;;;
;;;This program is free software:  you can redistribute it and/or modify
;;;it under  the terms of  the GNU General  Public License version  3 as
;;;published by the Free Software Foundation.
;;;
;;;This program is  distributed in the hope that it  will be useful, but
;;;WITHOUT  ANY   WARRANTY;  without   even  the  implied   warranty  of
;;;MERCHANTABILITY  or FITNESS FOR  A PARTICULAR  PURPOSE.  See  the GNU
;;;General Public License for more details.
;;;
;;;You should  have received  a copy of  the GNU General  Public License
;;;along with this program.  If not, see <http://www.gnu.org/licenses/>.


(library (ikarus strings)
  (export
    make-string			string
    substring			string-length
    string-ref			string-set!
    string->list		list->string
    string-append		string-for-each
    string-copy			string-copy!
    string-fill!
    string=?
    string<?			string<=?
    string>?			string>=?
    uuid

    ;; Vicare specific
    string->latin1		latin1->string
    string->ascii		ascii->string
    string-hex->bytevector	bytevector->string-hex
    bytevector->hex		hex->bytevector

    ;; unsafe operations
    $string=)
  (import (except (ikarus)
		  make-string			string
		  substring			string-length
		  string-ref			string-set!
		  string->list			list->string
		  string-append			string-for-each
		  string-copy			string-copy!
		  string-fill!
		  string=?
		  string<?			string<=?
		  string>?			string>=?
		  uuid

		  ;; Vicare specific
		  string->latin1		latin1->string
		  string->ascii			ascii->string
		  bytevector->hex		hex->bytevector
		  string-hex->bytevector	bytevector->string-hex)
    (vicare syntactic-extensions)
    (prefix (except (vicare unsafe-operations)
		    string=)
	    $))


;;;; arguments validation

(define-argument-validation (string who obj)
  (string? obj)
  (assertion-violation who "expected string as argument" obj))

(define-argument-validation (char who obj)
  (char? obj)
  (assertion-violation who "expected character as argument" obj))

(define-argument-validation (bytevector who obj)
  (bytevector? obj)
  (assertion-violation who "expected bytevector as argument" obj))

(define-argument-validation (procedure who obj)
  (procedure? obj)
  (assertion-violation who "expected procedure as argument" obj))

;;; --------------------------------------------------------------------

(define-argument-validation (length who obj)
  (and (fixnum? obj) ($fx<= 0 obj))
  (assertion-violation who "expected non-negative fixnum as string length argument" obj))

(define-argument-validation (has-length who str len)
  ($fx= len ($string-length str))
  (assertion-violation who "length mismatch in argument strings" len str))

;;; --------------------------------------------------------------------

(define-argument-validation (index who obj)
  (and (fixnum? obj) ($fx<= 0 obj))
  (assertion-violation who "expected non-negative fixnum as string index argument" obj))

(define-argument-validation (index-for-string who idx str)
  ;;To be used after INDEX validation.
  ;;
  ($fx< idx ($string-length str))
  (assertion-violation who "index is out of range for string" idx str))

(define-argument-validation (start-index-and-length who start len)
  ;;To be used after INDEX validation.
  ;;
  ($fx<= start len)
  (assertion-violation who "start index argument out of range for string" start len))

(define-argument-validation (end-index-and-length who end len)
  ;;To be used after INDEX validation.
  ;;
  ($fx<= end len)
  (assertion-violation who "end index argument out of range for string" end len))

(define-argument-validation (start-and-end-indices who start end)
  ;;To be used after INDEX validation.
  ;;
  ($fx<= start end)
  (assertion-violation who "start and end index arguments are in decreasing order" start end))

;;; --------------------------------------------------------------------

(define-argument-validation (count who obj)
  (and (fixnum? obj) ($fx<= 0 obj))
  (assertion-violation who "expected non-negative fixnum as characters count argument" obj))

(define-argument-validation (start-index-and-count-and-length who start count len)
  ($fx<= ($fx+ start count) len)
  (assertion-violation who
    (string-append "count argument out of range for string of length " (number->string len)
		   " and start index " (number->string start))
    count))

;;; --------------------------------------------------------------------

(define-argument-validation (latin1 who code-point str)
  (and ($fx>= code-point 0)
       ($fx< code-point 256))
  (assertion-violation who
    "expected only Latin-1 characters in string argument"
    ($fixnum->char code-point) str))

(define-argument-validation (ascii who code-point str)
  (and ($fx>= code-point 0)
       ($fx<  code-point 128))
  (assertion-violation who
    "expected only ASCII characters in string argument"
    ($fixnum->char code-point) str))


;;;; constants

(define EXPECTED_PROPER_LIST_AS_ARGUMENT
  "expected proper list as argument")


;;;; helpers

(define (%unsafe.string-copy! src.str src.start
			      dst.str dst.start
			      src.end)
  ($string-copy! src.str src.start
		 dst.str dst.start
		 src.end))


(define (string-length str)
  ;;Defined by R6RS.   Return the number of characters  in the given STR
  ;;as an exact integer object.
  ;;
  (define who 'string-length)
  (with-arguments-validation (who)
      ((string str))
    ($string-length str)))

(define (string-ref str idx)
  ;;Defined by  R6RS.  IDX  must be  a valid index  of STR.   Return the
  ;;character at offset IDX of STR using zero-origin indexing.
  ;;
  ;;NOTE Implementors should make STRING-REF run in constant time.
  ;;
  (define who 'string-ref)
  (with-arguments-validation (who)
      ((string			str)
       (index			idx)
       (index-for-string	idx str))
    ($string-ref str idx)))

(define (string-set! str idx ch)
  ;;Defined by  R6RS.  IDX must  be a valid  index of STR.  Store  CH in
  ;;element IDX of STR and return unspecified values.
  ;;
  ;;Passing an immutable string to STRING-SET! should cause an exception
  ;;with condition type @condition{assertion} to be raised.
  ;;
  ;;NOTE Implementors should make STRING-SET!  run in constant time.
  ;;
  (define who 'string-set!)
  (with-arguments-validation (who)
      ((string			str)
       (index			idx)
       (index-for-string	idx str)
       (char			ch))
    ($string-set! str idx ch)))


(define make-string
  ;;Defined by R6RS.  Return a newly allocated string of length LEN.  If
  ;;FILL is  given, then all elements  of the string  are initialized to
  ;;FILL, otherwise the contents of the string are unspecified.
  ;;
  (case-lambda
   ((len)
    (make-string len #\x0))
   ((len fill)
    (define who 'make-string)
    (with-arguments-validation (who)
	((length len)
	 (char   fill))
      (let loop ((str ($make-string len))
		 (idx 0)
		 (len len))
	(if ($fx= idx len)
	    str
	  (begin
	    ($string-set! str idx fill)
	    (loop str ($fxadd1 idx) len))))))))

(define string
  ;;Defined by  R6RS.  Return a  newly allocated string composed  of the
  ;;arguments.
  ;;
  (case-lambda
   (()
    ($make-string 0))
   ((one)
    (define who 'string)
    (with-arguments-validation (who)
	((char one))
      (let ((str ($make-string 1)))
	($string-set! str 0 one)
	str)))

   ((one two)
    (define who 'string)
    (with-arguments-validation (who)
	((char one)
	 (char two))
      (let ((str ($make-string 2)))
	($string-set! str 0 one)
	($string-set! str 1 two)
	str)))

   ((one two three)
    (define who 'string)
    (with-arguments-validation (who)
	((char one)
	 (char two)
	 (char three))
      (let ((str ($make-string 3)))
	($string-set! str 0 one)
	($string-set! str 1 two)
	($string-set! str 2 three)
	str)))

   ((one two three four)
    (define who 'string)
    (with-arguments-validation (who)
	((char one)
	 (char two)
	 (char three)
	 (char four))
      (let ((str ($make-string 4)))
	($string-set! str 0 one)
	($string-set! str 1 two)
	($string-set! str 2 three)
	($string-set! str 3 four)
	str)))

   ((one . chars)
    (define who 'string)
    (define (%length-and-validation chars len)
      (if (null? chars)
	  len
	(let ((ch ($car chars)))
	  (with-arguments-validation (who)
	      ((char ch))
	    (%length-and-validation ($cdr chars) ($fxadd1 len))))))
    (let* ((chars (cons one chars))
	   (len   (%length-and-validation chars 0)))
      (with-arguments-validation (who)
	  ((length len))
	(let loop ((str   ($make-string len))
		   (idx   0)
		   (chars chars))
	  (if (null? chars)
	      str
	    (begin
	      ($string-set! str idx ($car chars))
	      (loop str ($fxadd1 idx) ($cdr chars))))))))))


(define (substring str start end)
  ;;Defined by  R6RS.  STR must be a  string, and START and  END must be
  ;;exact integer objects satisfying:
  ;;
  ;; 0 <= START <= END <= (string-length STR)
  ;;
  ;;Return a  newly allocated string  formed from the characters  of STR
  ;;beginning  with index START  (inclusive) and  ending with  index END
  ;;(exclusive).
  ;;
  (define who 'substring)
  (with-arguments-validation (who)
      ((string	str)
       (index	start)
       (index	end))
    (let ((len ($string-length str)))
      (with-arguments-validation (who)
	  ((start-index-and-length	start len)
	   (end-index-and-length	end   len)
	   (start-and-end-indices	start end))
	($substring str start end)))))

(define (string-copy str)
  ;;Defined  by  R6RS.  Return  a  newly  allocated  copy of  the  given
  ;;STR.
  ;;
  (define who 'string-copy)
  (with-arguments-validation (who)
      ((string str))
    (let ((end ($string-length str)))
      ($substring str 0 end))))


(define string=?
  ;;Defined by R6RS.   Return #t if the strings are  the same length and
  ;;contain the same characters in the same positions.  Otherwise return
  ;;#f.
  ;;
  (case-lambda
   ((str1 str2)
    (define who 'string=?)
    (with-arguments-validation (who)
	((string  str1)
	 (string  str2))
      (or (eq? str1 str2)
	  (let ((len ($string-length str1)))
	    (and ($fx= len ($string-length str2))
		 (%unsafe.two-strings=? str1 str2 0 len))))))
   ((str1 str2 . strs)
    (define who 'string=?)
    (with-arguments-validation (who)
	((string  str1)
	 (string  str2))
      (or (eq? str1 str2)
	  (let ((str1.len ($string-length str1)))
	    (and ($fx= str1.len ($string-length str2))
		 (%unsafe.two-strings=? str1 str2 0 str1.len)
		 (let next-string ((str1 str1)
				   (strs strs)
				   (len  str1.len))
		   (or (null? strs)
		       (let ((strN ($car strs)))
			 (with-arguments-validation (who)
			     ((string strN))
			   (if ($fx= len ($string-length strN))
			       (and (next-string str1 ($cdr strs) len)
				    (%unsafe.two-strings=? str1 strN 0 len))
			     (%check-strings-and-return-false who ($cdr strs))))))))))))
   ))

(define (%unsafe.two-strings=? str1 str2 index end)
  ;;Unsafely compare  two strings from  INDEX included to  END excluded;
  ;;return #t or #f.
  ;;
  (or ($fx= index end)
      (and ($char= ($string-ref str1 index)
			 ($string-ref str2 index))
	   (%unsafe.two-strings=? str1 str2 ($fxadd1 index) end))))

(define (%check-strings-and-return-false who strs)
  ;;Verify that the list (already validated) STRS contains only strings;
  ;;if successful return #f, else raise an assertion violation.
  ;;
  (if (null? strs)
      #f
    (let ((str ($car strs)))
      (with-arguments-validation (who)
	  ((string str))
	(%check-strings-and-return-false who ($cdr strs))))))

;;; --------------------------------------------------------------------

(define ($string= str1 str2)
  (or (eq? str1 str2)
      (let ((len ($string-length str1)))
	(and ($fx= len ($string-length str2))
	     (%unsafe.two-strings=? str1 str2 0 len)))))


;;;; string comparison
;;
;;Defined by R6RS.  These procedures are the lexicographic extensions to
;;strings of  the corresponding  orderings on characters.   For example,
;;STRING<?   is the  lexicographic ordering  on strings  induced  by the
;;ordering CHAR<?  on characters.  If  two strings differ in  length but
;;are  the same  up to  the length  of the  shorter string,  the shorter
;;string  is considered  to be  lexicographically less  than  the longer
;;string.
;;

(define (%string-cmp who cmp str1 strs)
  ;;Subroutine of the comparison functions.
  ;;
  (with-arguments-validation (who)
      ((string	str1))
    (let next-string ((str1 str1)
		      (strs strs))
      (or (null? strs)
	  (let ((str2 ($car strs)))
	    (with-arguments-validation (who)
		((string str2))
	      (if (cmp str1 str2)
		  (next-string str2 ($cdr strs))
		(%check-strings-and-return-false who strs))))))))

(define string<?
  (case-lambda
   ((str1 s2)
    (define who 'string<?)
    (with-arguments-validation (who)
	((string str1)
	 (string s2))
      (%unsafe.string<? str1 s2)))
   ((str . strs)
    (%string-cmp 'string<? %unsafe.string<? str strs))))

(define string<=?
  (case-lambda
   ((str1 s2)
    (define who 'string<=?)
    (with-arguments-validation (who)
	((string str1)
	 (string s2))
      (%unsafe.string<=? str1 s2)))
   ((str . strs)
    (%string-cmp 'string<=? %unsafe.string<=? str strs))))

(define string>?
  (case-lambda
   ((str1 s2)
    (define who 'string>?)
    (with-arguments-validation (who)
	((string str1)
	 (string s2))
      (%unsafe.string>? str1 s2)))
   ((str . strs)
    (%string-cmp 'string>? %unsafe.string>? str strs))))

(define string>=?
  (case-lambda
   ((str1 s2)
    (define who 'string>=?)
    (with-arguments-validation (who)
	((string str1)
	 (string s2))
      (%unsafe.string>=? str1 s2)))
   ((str . strs)
    (%string-cmp 'string>=? %unsafe.string>=? str strs))))


(define (%unsafe.string<? str1 str2)
  (let ((len1 ($string-length str1))
	(len2 ($string-length str2)))
    (if ($fx< len1 len2)
	(let next-char ((idx  0)
			(len1 len1)
			(str1 str1)
			(str2 str2))
	  (or ($fx= idx len1)
	      (let ((ch1 ($string-ref str1 idx))
		    (ch2 ($string-ref str2 idx)))
		(or ($char< ch1 ch2)
		    (if ($char= ch1 ch2)
			(next-char ($fxadd1 idx) len1 str1 str2)
		      #f)))))
      (let next-char ((idx  0)
		      (len2 len2)
		      (str1 str1)
		      (str2 str2))
	(if ($fx= idx len2)
	    #f
	  (let ((ch1 ($string-ref str1 idx))
		(ch2 ($string-ref str2 idx)))
	    (or ($char< ch1 ch2)
		(if ($char= ch1 ch2)
		    (next-char ($fxadd1 idx) len2 str1 str2)
		  #f))))))))

(define (%unsafe.string<=? str1 str2)
  (let ((len1 ($string-length str1))
	(len2 ($string-length str2)))
    (if ($fx<= len1 len2)
	(let next-char ((idx  0)
			(len1 len1)
			(str1 str1)
			(str2 str2))
	  (or ($fx= idx len1)
	      (let ((ch1 ($string-ref str1 idx))
		    (ch2 ($string-ref str2 idx)))
		(or ($char< ch1 ch2)
		    (if ($char= ch1 ch2)
			(next-char ($fxadd1 idx) len1 str1 str2)
		      #f)))))
      (let next-char ((idx  0)
		      (len2 len2)
		      (str1 str1)
		      (str2 str2))
	(if ($fx= idx len2)
	    #f
	  (let ((ch1 ($string-ref str1 idx))
		(ch2 ($string-ref str2 idx)))
	    (or ($char< ch1 ch2)
		(if ($char= ch1 ch2)
		    (next-char ($fxadd1 idx) len2 str1 str2)
		  #f))))))))

(define (%unsafe.string>? str1 str2)
  (%unsafe.string<? str2 str1))

(define (%unsafe.string>=? str1 str2)
  (%unsafe.string<=? str2 str1))


(define (string->list str)
  ;;Defined by  R6RS.  Return a  newly allocated list of  the characters
  ;;that make up the given string.
  ;;
  (define who 'string->list)
  (with-arguments-validation (who)
      ((string str))
    (let next-char ((str   str)
		    (i   ($string-length str))
		    (ac  '()))
      (if ($fxzero? i)
	  ac
	(let ((i ($fxsub1 i)))
	  (next-char str i (cons ($string-ref str i) ac)))))))


(define (list->string ls)
  ;;Defined by  R6RS.  Return a  newly allocated string formed  from the
  ;;characters in LS.
  ;;
  (define who 'list->string)
  (define (race h t ls n)
    (cond ((pair? h)
	   (let ((h ($cdr h)))
	     (if (pair? h)
		 (if (not (eq? h t))
		     (race ($cdr h) ($cdr t) ls ($fx+ n 2))
		   (assertion-violation who "circular list is invalid as argument" ls))
	       (if (null? h)
		   ($fx+ n 1)
		 (assertion-violation who EXPECTED_PROPER_LIST_AS_ARGUMENT ls)))))
	  ((null? h)
	   n)
	  (else
	   (assertion-violation who EXPECTED_PROPER_LIST_AS_ARGUMENT ls))))

  (define (fill s i ls)
    (if (null? ls)
	s
      (let ((c ($car ls)))
	(with-arguments-validation (who)
	    ((char c))
	  ($string-set! s i c)
	  (fill s ($fxadd1 i) ($cdr ls))))))

  (let ((len (race ls ls ls 0)))
    (with-arguments-validation (who)
	((length len))
      (fill ($make-string len) 0 ls))))


(define string-append
  ;;Defined by  R6RS.  Return a newly allocated  string whose characters
  ;;form the concatenation of the given strings.
  ;;
  (case-lambda
   (() "")

   ((str)
    (define who 'string-append)
    (with-arguments-validation (who)
	((string str))
      str))

   ((str1 str2)
    (define who 'string-append)
    (with-arguments-validation (who)
	((string str1)
	 (string str2))
      (let* ((len1	($string-length str1))
	     (len2	($string-length str2))
	     (dst.len	(+ len1 len2)))
	(with-arguments-validation (who)
	    ((length dst.len))
	  (let ((dst.str ($make-string dst.len)))
	    (%unsafe.string-copy! str1 0 dst.str 0    len1)
	    (%unsafe.string-copy! str2 0 dst.str len1 len2)
	    dst.str)))))

   ((str1 str2 str3)
    (define who 'string-append)
    (with-arguments-validation (who)
	((string str1)
	 (string str2)
	 (string str3))
      (let* ((len1	($string-length str1))
	     (len2	($string-length str2))
	     (len3	($string-length str3))
	     (dst.len	(+ len1 len2 len3)))
	(with-arguments-validation (who)
	    ((length  dst.len))
	  (let ((dst.str ($make-string dst.len)))
	    (%unsafe.string-copy! str1 0 dst.str 0    len1)
	    (%unsafe.string-copy! str2 0 dst.str len1 len2)
	    (%unsafe.string-copy! str3 0 dst.str ($fx+ len1 len2) len3)
	    dst.str)))))

   ((str1 str2 str3 str4)
    (define who 'string-append)
    (with-arguments-validation (who)
	((string  str1)
	 (string  str2)
	 (string  str3)
	 (string  str4))
      (let* ((len1	($string-length str1))
	     (len2	($string-length str2))
	     (len3	($string-length str3))
	     (len4	($string-length str4))
	     (dst.len	(+ len1 len2 len3 len4)))
	(with-arguments-validation (who)
	    ((length  dst.len))
	  (let ((dst.str ($make-string dst.len)))
	    (%unsafe.string-copy! str1 0 dst.str 0    len1)
	    (%unsafe.string-copy! str2 0 dst.str len1 len2)
	    (let ((dst.start ($fx+ len1 len2)))
	      (%unsafe.string-copy! str3 0 dst.str dst.start len3)
	      (let ((dst.start ($fx+ dst.start len3)))
		(%unsafe.string-copy! str4 0 dst.str dst.start len4)))
	    dst.str)))))

   ((str1 . strs)
    (define who 'string-append)
    (define (%length-and-validation strs len)
      (if (null? strs)
	  len
	(let ((str ($car strs)))
	  (with-arguments-validation (who)
	      ((string str))
	    (%length-and-validation ($cdr strs) (+ len ($string-length str)))))))

    (define (%fill-strings dst.str strs dst.start)
      (if (null? strs)
	  dst.str
	(let* ((src.str ($car strs))
	       (src.len ($string-length src.str)))
	  (begin
	    ($string-copy! src.str 0 dst.str dst.start src.len)
	    (%fill-strings dst.str ($cdr strs) ($fx+ dst.start src.len))))))

    (let* ((strs    (cons str1 strs))
           (dst.len (%length-and-validation strs 0)))
      (with-arguments-validation (who)
	  ((length dst.len))
	(%fill-strings ($make-string dst.len) strs 0))))))


(define string-for-each
  ;;Defined  by R6RS.  The  STRS must  all have  the same  length.  PROC
  ;;should accept as many arguments as there are STRS.
  ;;
  ;;The  STRING-FOR-EACH  procedure  applies  PROC element-wise  to  the
  ;;characters of the STRS for its side effects, in order from the first
  ;;characters to the  last.  PROC is always called  in the same dynamic
  ;;environment  as  STRING-FOR-EACH  itself.   The  return  values  are
  ;;unspecified.
  ;;
  ;;Analogous to FOR-EACH.
  ;;
  ;;Implementation responsibilities:  the implementation must  check the
  ;;restrictions on @var{proc} to the extent performed by applying it as
  ;;described.   An   implementation  may  check  whether   PROC  is  an
  ;;appropriate argument before applying it.
  ;;
  (case-lambda
   ((proc str)
    (define who 'string-for-each)
    (with-arguments-validation (who)
	((procedure	proc)
	 (string	str))
      (let next-char ((proc		proc)
		      (str		str)
		      (str.index	0)
		      (str.len		($string-length str)))
	(unless ($fx= str.index str.len)
	  (proc ($string-ref str str.index))
	  (next-char proc str ($fxadd1 str.index) str.len)))))

   ((proc str0 str1)
    (define who 'string-for-each)
    (with-arguments-validation (who)
	((procedure	proc)
	 (string	str0)
	 (string	str1))
      (let ((str.len ($string-length str0)))
	(with-arguments-validation (who)
	    ((has-length str1 str.len))
	  (let next-char ((proc		proc)
			  (str0		str0)
			  (str1		str1)
			  (str.index	0)
			  (str.len	str.len))
	    (unless ($fx= str.index str.len)
	      (proc ($string-ref str0 str.index)
		    ($string-ref str1 str.index))
	      (next-char proc str0 str1 ($fxadd1 str.index) str.len)))))))

   ((proc str0 str1 . strs)
    (define who 'string-for-each)
    (with-arguments-validation (who)
	((procedure	proc)
	 (string	str0)
	 (string	str1))
      (let ((str.len ($string-length str0)))
	(with-arguments-validation (who)
	    ((has-length str1 str.len))

	  ;; validate the rest strings
	  (let next-string ((strs	strs)
			    (str.len	str.len))
	    (unless (null? strs)
	      (let ((str ($car strs)))
		(with-arguments-validation (who)
		    ((string      str)
		     (has-length  str str.len))
		  (next-string ($cdr strs) str.len)))))

	  ;; do the application
	  (let next-char ((proc		proc)
			  (str0		str0)
			  (str1		str1)
			  (strs		strs)
			  (str.index	0)
			  (str.len	str.len))
	    (unless ($fx= str.index str.len)
	      (apply proc
		     ($string-ref str0 str.index)
		     ($string-ref str1 str.index)
		     (let next-string ((str.index str.index)
				       (strs      strs))
		       (if (null? strs)
			   '()
			 (cons ($string-ref ($car strs) str.index)
			       (next-string str.index ($cdr strs))))))
	      (next-char proc str0 str1 strs ($fxadd1 str.index) str.len)))
	  ))))
   ))


(define (string-fill! str fill)
  ;;Defined by R6RS.   Store FILL in every element of  the given STR and
  ;;return unspecified values.
  ;;
  (define who 'string-fill!)
  (with-arguments-validation (who)
      ((string	str)
       (char	fill))
    (let ((len ($string-length str)))
      ($string-fill! str 0 len fill))))


(define (string-copy! src.str src.start dst.str dst.start count)
  ;;Defined by  Ikarus.  Copy COUNT characters from  SRC.STR starting at
  ;;SRC.START  (inclusive)  to DST.STR  starting  at DST.START.   Return
  ;;unspecified values.
  ;;
  (define who 'string-copy!)
  (with-arguments-validation (who)
      ((string		src.str)
       (string		dst.str)
       (index		src.start)
       (index		dst.start)
       (count		count))
    (let ((src.len ($string-length src.str))
	  (dst.len ($string-length dst.str)))
      (with-arguments-validation (who)
	  ((start-index-and-length		src.start src.len)
	   (start-index-and-length		dst.start dst.len)
	   (start-index-and-count-and-length	src.start count src.len)
	   (start-index-and-count-and-length	dst.start count dst.len))
	(cond (($fxzero? count)
	       (void))
	      ((eq? src.str dst.str)
	       (cond (($fx< dst.start src.start)
		      ($string-self-copy-forwards!  src.str src.start dst.start count))
		     (($fx> dst.start src.start)
		      ($string-self-copy-backwards! src.str src.start dst.start count))
		     (else (void))))
	      (else
	       (let ((src.end ($fx+ src.start count)))
		 ($string-copy! src.str src.start dst.str dst.start src.end))))))))


(define (uuid)
  ;;Defined by Ikarus.  Attempt the generation of a unique string.
  ;;
  (define who 'uuid)
  (let* ((s ($make-bytevector 16))
	 (r (foreign-call "ik_uuid" s)))
    (if (bytevector? r)
	(utf8->string r)
      (error who "cannot obtain unique id"))))


;;;; Latin-1 bytevectors to/from strings

(define (string->latin1 str)
  ;;Defined by Vicare.  Convert the string STR into a bytevector holding
  ;;octects representing the character's Latin-1 code points.
  ;;
  (define who 'latin1->string)
  (with-arguments-validation (who)
      ((string str))
    ;;Both strings and bytevectors have length representable as fixnum.
    (let* ((bv.len ($string-length str))
	   (bv	 ($make-bytevector bv.len)))
      (do ((i 0 ($fxadd1 i)))
	  (($fx= i bv.len)
	   bv)
	(let ((code-point ($char->fixnum ($string-ref str i))))
	  (with-arguments-validation (who)
	      ((latin1 code-point str))
	    ($bytevector-u8-set! bv i code-point)))))))

(define (latin1->string bv)
  ;;Defined by Vicare.  Convert the  bytevector BV into a string holding
  ;;characters representing bytes interpreted as Latin-1 code points.
  ;;
  (define who 'latin1->string)
  (with-arguments-validation (who)
      ((bytevector bv))
    ;;Both strings and bytevectors have length representable as fixnum.
    (let* ((str.len ($bytevector-length bv))
	   (str     ($make-string str.len)))
      (do ((i 0 ($fxadd1 i)))
	  (($fx= i str.len)
	   str)
	(let ((code-point ($bytevector-u8-ref bv i)))
	  (with-arguments-validation (who)
	      ((latin1 code-point str))
	    ($string-set! str i ($fixnum->char code-point))))))))


;;;; ASCII bytevectors to/from strings

(define (string->ascii str)
  ;;Defined by Vicare.  Convert the string STR into a bytevector holding
  ;;octects representing the character's ASCII code points.
  ;;
  (define who 'ascii->string)
  (with-arguments-validation (who)
      ((string	str))
    ($string->ascii who str)))

(define ($string->ascii who str)
  ;;Both strings and bytevectors have length representable as fixnum.
  (let* ((bv.len	($string-length str))
	 (bv		($make-bytevector bv.len)))
    (do ((i 0 ($fxadd1 i)))
	(($fx= i bv.len)
	 bv)
      (let ((code-point ($char->fixnum ($string-ref str i))))
	(with-arguments-validation (who)
	    ((ascii	code-point str))
	  ($bytevector-u8-set! bv i code-point))))))

(define (ascii->string bv)
  ;;Defined by Vicare.  Convert the  bytevector BV into a string holding
  ;;characters representing bytes interpreted as ASCII code points.
  ;;
  (define who 'ascii->string)
  (with-arguments-validation (who)
      ((bytevector	bv))
    ($ascii->string who bv)))

(define ($ascii->string who bv)
  ;;Both strings and bytevectors have length representable as fixnum.
  (let* ((str.len	($bytevector-length bv))
	 (str		($make-string str.len)))
    (do ((i 0 ($fxadd1 i)))
	(($fx= i str.len)
	 str)
      (let ((code-point ($bytevector-u8-ref bv i)))
	(with-arguments-validation (who)
	    ((ascii	code-point bv))
	  ($string-set! str i ($fixnum->char code-point)))))))


;;;; bytevectors to/from HEX strings

(define (bytevector->hex bv)
  ;;Defined by Vicare.  Convert a bytevector of octets into a bytevector
  ;;representing the  ASCII HEX encoding  of the octets.   If successful
  ;;return the encoded bytevector, else return #f.
  ;;
  ;;The length of the output bytevector is twice the length of the input
  ;;bytevector.  An error  occurs if the output  bytevector length would
  ;;exceed the maximum bytevector length (which is the greatest fixnum).
  ;;
  (define who 'bytevector->hex)
  (with-arguments-validation (who)
      ((bytevector	bv))
    (foreign-call "ikrt_bytevector_to_hex" bv)))

(define (hex->bytevector bv)
  ;;Defined by Vicare.  Convert a  bytevector representing the ASCII HEX
  ;;encoding  of octets  into  a bytevector  of  octets.  If  successful
  ;;return the encoded bytevector, else return #f.
  ;;
  ;;The length of the output bytevector  is half the length of the input
  ;;bytevector.  An error  occurs if the input  bytevector holds invalid
  ;;data.
  ;;
  (define who 'hex->bytevector)
  (with-arguments-validation (who)
      ((bytevector	bv))
    (foreign-call "ikrt_bytevector_from_hex" bv)))

;;; --------------------------------------------------------------------

(define (bytevector->string-hex bv)
  ;;Defined by Vicare.  Convert the  bytevector BV into a string holding
  ;;the HEX representation of the bytes.
  ;;
  (define who 'bytevector->string-hex)
  (with-arguments-validation (who)
      ((bytevector	bv))
    (let ((rv (foreign-call "ikrt_bytevector_to_hex" bv)))
      (and rv ($ascii->string who rv)))))

(define (string-hex->bytevector S)
  ;;Defined by Vicare.   Convert the string S into  a bytevector holding
  ;;the byte representation of the HEX sequences.
  ;;
  (define who 'string-hex->bytevector)
  (with-arguments-validation (who)
      ((string	S))
    (foreign-call "ikrt_bytevector_from_hex" ($string->ascii who S))))


;;;; done

)


(library (ikarus system strings)
  (export $make-string
	  $string-length
	  $string-ref
	  $string-set!)
  (import (ikarus))
  (define $make-string		make-string)
  (define $string-length	string-length)
  (define $string-ref		string-ref)
  (define $string-set!		string-set!))

;;; end of file

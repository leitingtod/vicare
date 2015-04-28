;;;Copyright (c) 2006, 2007 Abdulaziz Ghuloum and Kent Dybvig
;;;Modified by Marco Maggi <marco.maggi-ipsu@poste.it>
;;;
;;;Permission is hereby granted, free of charge, to any person obtaining
;;;a  copy of  this  software and  associated  documentation files  (the
;;;"Software"), to  deal in the Software  without restriction, including
;;;without limitation  the rights to use, copy,  modify, merge, publish,
;;;distribute, sublicense,  and/or sell copies  of the Software,  and to
;;;permit persons to whom the Software is furnished to do so, subject to
;;;the following conditions:
;;;
;;;The  above  copyright notice  and  this  permission  notice shall  be
;;;included in all copies or substantial portions of the Software.
;;;
;;;THE  SOFTWARE IS  PROVIDED "AS  IS",  WITHOUT WARRANTY  OF ANY  KIND,
;;;EXPRESS OR  IMPLIED, INCLUDING BUT  NOT LIMITED TO THE  WARRANTIES OF
;;;MERCHANTABILITY,    FITNESS   FOR    A    PARTICULAR   PURPOSE    AND
;;;NONINFRINGEMENT.  IN NO EVENT  SHALL THE AUTHORS OR COPYRIGHT HOLDERS
;;;BE LIABLE  FOR ANY CLAIM, DAMAGES  OR OTHER LIABILITY,  WHETHER IN AN
;;;ACTION OF  CONTRACT, TORT  OR OTHERWISE, ARISING  FROM, OUT OF  OR IN
;;;CONNECTION  WITH THE SOFTWARE  OR THE  USE OR  OTHER DEALINGS  IN THE
;;;SOFTWARE.


(library (psyntax.config)
  (export
    if-wants-define-record	#;if-wants-define-struct
    if-wants-case-lambda
    if-wants-letrec*			if-wants-global-defines
    if-wants-library-letrec*
    if-wants-descriptive-gensyms	if-wants-descriptive-marks
    base-of-interaction-library)
  (import (rnrs)
    (psyntax.compat))


(define (base-of-interaction-library)
  '(vicare))

(define-syntax define-option
  (syntax-rules ()
    ((_ name #t)
     (define-syntax name
       (syntax-rules ()
	 ((_ ?success-kont ?failure-kont) ?success-kont))))
    ((_ name #f)
     (define-syntax name
       (syntax-rules ()
	 ((_ ?success-kont ?failure-kont) ?failure-kont))))))

;;DEFINE-RECORD is an Ikarus-specific extension.  It should be disabled for all other
;;implementations; the  source is included to  illustrate how implementation-specific
;;extensions can be added to the expander
;;
(define-option if-wants-define-record  #t)
(define-option if-wants-define-struct  #t)

;;If the implementation requires that all  global variables be defined before they're
;;SET!ed, then enabling this option causes the expander to produce:
;;
;;  (define <global> '#f)
;;
;;for  every exported  identifiers.   If  the option  is  disabled,  then the  global
;;definitions are suppressed.
;;
(define-option if-wants-global-defines #f)

;;Implementations that support CASE-LAMBDA natively  should have this option enabled.
;;Disabling WANTS-CASE-LAMBDA causes  the expander to produce  ugly, inefficient, but
;;correct code by expanding CASE-LAMBDA into explicit dispatch code.
;;
(define-option if-wants-case-lambda    #t)

;;If the implementation has built-in support  for efficient LETREC*, then this option
;;should be enabled.  Disabling the option expands:
;;
;;  (letrec* ((lhs* rhs*)  ...) body)
;;
;;into:
;;
;;  (let ((lhs*  #f) ...) (set!  lhs* rhs*) ... body)
;;
(define-option if-wants-letrec*        #t)

(define-option if-wants-library-letrec* #t)

;;If true:  generate gensyms  with descriptive  names, which is  slower but  helps in
;;debugging and understanding the code.
;;
(define-syntax if-wants-descriptive-gensyms
  (lambda (stx)
    (module (generate-descriptive-labels?)
      (include "ikarus.config.scm"))
    (syntax-case stx ()
      ((_ ?true ?false)
       (if generate-descriptive-labels? #'?true #'?false))
      )))

;;If  true: generate  descriptive strings  as  syntactic identifier  marks, which  is
;;slower but helps in debugging and understanding the code.
;;
(define-syntax if-wants-descriptive-marks
  (lambda (stx)
    (module (generate-descriptive-labels?)
      (include "ikarus.config.scm"))
    (syntax-case stx ()
      ((_ ?true ?false)
       (if generate-descriptive-labels? #'?true #'?false))
      )))


;;;; done

#| end of library |# )

;;; end of file

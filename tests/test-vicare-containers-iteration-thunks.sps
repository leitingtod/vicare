;;;
;;;Part of: Vicare Scheme
;;;Contents: tests for iterator thunks
;;;Date: Wed Aug 19, 2015
;;;
;;;Abstract
;;;
;;;
;;;
;;;Copyright (C) 2015 Marco Maggi <marco.maggi-ipsu@poste.it>
;;;
;;;This program is free software: you can  redistribute it and/or modify it under the
;;;terms  of  the GNU  General  Public  License as  published  by  the Free  Software
;;;Foundation,  either version  3  of the  License,  or (at  your  option) any  later
;;;version.
;;;
;;;This program is  distributed in the hope  that it will be useful,  but WITHOUT ANY
;;;WARRANTY; without  even the implied warranty  of MERCHANTABILITY or FITNESS  FOR A
;;;PARTICULAR PURPOSE.  See the GNU General Public License for more details.
;;;
;;;You should have received a copy of  the GNU General Public License along with this
;;;program.  If not, see <http://www.gnu.org/licenses/>.
;;;


#!vicare
(import (vicare)
  (vicare containers iteration-thunks)
  (vicare checks))

(check-set-mode! 'report-failed)
(check-display "*** testing Vicare libraries: iterator thunks\n")


;;;; helpers

(define (xcons a b)
  (cons b a))


(parametrise ((check-test-name	'list))

  (check
      (let ((iter (make-list-iteration-thunk '())))
        (iteration-thunk-fold xcons '() iter))
    => '())

  (check
      (let ((iter (make-list-iteration-thunk '(0))))
        (iteration-thunk-fold xcons '() iter))
    => '(0))

  (check
      (let ((iter (make-list-iteration-thunk '(0 1 2 3 4))))
        (iteration-thunk-fold xcons '() iter))
    => '(4 3 2 1 0))

  #t)


(parametrise ((check-test-name	'spine))

  (define (kons knil pair)
    (cons (car pair) knil))

  (check
      (let ((iter (make-spine-iteration-thunk '())))
        (iteration-thunk-fold kons '() iter))
    => '())

  (check
      (let ((iter (make-spine-iteration-thunk '(0))))
        (iteration-thunk-fold kons '() iter))
    => '(0))

  (check
      (let ((iter (make-spine-iteration-thunk '(0 1 2 3 4))))
        (iteration-thunk-fold kons '() iter))
    => '(4 3 2 1 0))

  #t)


(parametrise ((check-test-name	'vector))

  (check
      (let ((iter (make-vector-iteration-thunk '#())))
        (iteration-thunk-fold xcons '() iter))
    => '())

  (check
      (let ((iter (make-vector-iteration-thunk '#(0))))
        (iteration-thunk-fold xcons '() iter))
    => '(0))

  (check
      (let ((iter (make-vector-iteration-thunk '#(0 1 2 3 4))))
        (iteration-thunk-fold xcons '() iter))
    => '(4 3 2 1 0))

  #t)


(parametrise ((check-test-name	'string))

  (check
      (let ((iter (make-string-iteration-thunk "")))
        (iteration-thunk-fold xcons '() iter))
    => '())

  (check
      (let ((iter (make-string-iteration-thunk "0")))
        (iteration-thunk-fold xcons '() iter))
    => '(#\0))

  (check
      (let ((iter (make-string-iteration-thunk "01234")))
        (iteration-thunk-fold xcons '() iter))
    => '(#\4 #\3 #\2 #\1 #\0))

  #t)


(parametrise ((check-test-name	'bytevector))

  (check
      (let ((iter (make-bytevector-u8-iteration-thunk '#vu8())))
        (iteration-thunk-fold xcons '() iter))
    => '())

  (check
      (let ((iter (make-bytevector-u8-iteration-thunk '#vu8(0))))
        (iteration-thunk-fold xcons '() iter))
    => '(0))

  (check
      (let ((iter (make-bytevector-u8-iteration-thunk '#vu8(0 1 2 3 4))))
        (iteration-thunk-fold xcons '() iter))
    => '(4 3 2 1 0))

;;; --------------------------------------------------------------------

  (check
      (let ((iter (make-bytevector-s8-iteration-thunk '#vs8())))
        (iteration-thunk-fold xcons '() iter))
    => '())

  (check
      (let ((iter (make-bytevector-s8-iteration-thunk '#vs8(0))))
        (iteration-thunk-fold xcons '() iter))
    => '(0))

  (check
      (let ((iter (make-bytevector-s8-iteration-thunk '#vs8(0 -1 -2 -3 -4))))
        (iteration-thunk-fold xcons '() iter))
    => '(-4 -3 -2 -1 0))

  #t)


;;;; done

(check-report)

;;; end of file
;; Local Variables:
;; mode: vicare
;; coding: utf-8
;; End:
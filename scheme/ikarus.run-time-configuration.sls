;;;
;;;Part of: Vicare Scheme
;;;Contents: run-time configuration
;;;Date: Sun Jun 28, 2015
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
(library (ikarus run-time-configuration)
  (export
    scheme-heap-nursery-size)
  (import (vicare)
    (prefix (vicare platform words) words.))

  (case-define* scheme-heap-nursery-size
    (()
     (foreign-call "ikrt_scheme_heap_nursery_size_ref"))
    (({num-of-bytes words.unsigned-long?})
     (foreign-call "ikrt_scheme_heap_nursery_size_set" num-of-bytes)))

  #| end of library |# )

;;; end of file
;; Local Variables:
;; mode: vicare
;; coding: utf-8
;; End:
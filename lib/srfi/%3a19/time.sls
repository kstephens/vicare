;;;Copyright 2010 Derick Eddington.  My MIT-style license is in the file
;;;named LICENSE from  the original collection this  file is distributed
;;;with.

;;;Modified by Marco Maggi <marco.maggi-ipsu@poste.it>

;;SRFI-19: Time Data Types and Procedures.
;;
;;Copyright (C) I/NET, Inc. (2000, 2002, 2003). All Rights Reserved.
;;
;;This document  and translations of it  may be copied and  furnished to
;;others, and derivative  works that comment on or  otherwise explain it
;;or assist in its implementation may be prepared, copied, published and
;;distributed, in  whole or  in part, without  restriction of  any kind,
;;provided  that  the above  copyright  notice  and this  paragraph  are
;;included  on all  such  copies and  derivative  works.  However,  this
;;document itself  may not be modified  in any way, such  as by removing
;;the  copyright  notice  or  references   to  the  Scheme  Request  For
;;Implementation process or editors, except as needed for the purpose of
;;developing SRFIs in  which case the procedures  for copyrights defined
;;in the SRFI  process must be followed, or as  required to translate it
;;into languages other than English.
;;
;;The limited  permissions granted above  are perpetual and will  not be
;;revoked by the authors or their successors or assigns.
;;
;;This document and  the information contained herein is  provided on an
;;"AS  IS" basis  and  THE  AUTHOR AND  THE  SRFI  EDITORS DISCLAIM  ALL
;;WARRANTIES,  EXPRESS OR  IMPLIED,  INCLUDING BUT  NOT  LIMITED TO  ANY
;;WARRANTY THAT THE USE OF THE  INFORMATION HEREIN WILL NOT INFRINGE ANY
;;RIGHTS OR ANY  IMPLIED WARRANTIES OF MERCHANTABILITY OR  FITNESS FOR A
;;PARTICULAR PURPOSE.


;;;; Julian Date
;;
;;The Julian Date (JD, <http://en.wikipedia.org/wiki/Julian_day>) is the
;;interval   of  time   in   days   and  fractions   of   a  day   since
;;-4714-11-24T12:00:00Z  (November 24,  -4714 at  noon, UTC  scale, time
;;zone zero).
;;
;;The Julian Day  Number (JDN) is the integral part  of the Julian Date.
;;The day  commencing at  the above-mentioned  epoch is  zero.  Negative
;;values  can be  used  for  preceding dates,  though  they predate  all
;;recorded history.
;;
;;The Modified  Julian Day Number (MJDN)  represents a point in  time as
;;number  of  days  since  1858-11-17T00:00:00Z (November  17,  1858  at
;;midnight, UTC scale, time zone zero).
;;
;;The MDJN is 4800001/2 = 2400000.5 days less than the JDN:
;;
;;   JDN - MJDN = 4800001/2
;;
;;this brings the numbers into a more manageable numeric range and makes
;;the day numbers change at midnight UTC rather than noon.
;;
;;Julian Date  test values can be  computed with the calculator  at (URL
;;last verified Thu Jul 29, 2010):
;;
;;   <http://www.imcce.fr/en/grandpublic/temps/jour_julien.php>
;;   <http://www.imcce.fr/langues/en/grandpublic/temps/jour_julien.php>
;;
;;the number  computed by  that calculator is  the JD  at year/month/day
;;hour:minute:second.


#!r6rs
(library (srfi :19 time)
  (export
    time-duration		time-monotonic		time-process
    time-tai			time-thread		time-utc

    current-date		current-julian-day	current-modified-julian-day
    current-time		time-resolution

    (rename (true-make-time	make-time))
    copy-time			time?
    time-type			set-time-type!
    time-second			set-time-second!
    time-nanosecond		set-time-nanosecond!

    time=?
    time<=?			time<?
    time>=?			time>?
    time-difference		time-difference!
    add-duration		add-duration!
    subtract-duration		subtract-duration!

    make-date
    date?
    date-nanosecond		date-second
    date-minute			date-hour
    date-day			date-month
    date-year			date-zone-offset
    date-year-day		date-week-day
    date-week-number

    date->julian-day
    date->modified-julian-day
    date->time-monotonic
    date->time-tai
    date->time-utc

    julian-day->date
    julian-day->time-monotonic
    julian-day->time-tai
    julian-day->time-utc

    modified-julian-day->date
    modified-julian-day->time-monotonic
    modified-julian-day->time-tai
    modified-julian-day->time-utc

    time-monotonic->date
    time-monotonic->julian-day
    time-monotonic->modified-julian-day
    time-monotonic->time-tai
    time-monotonic->time-tai!
    time-monotonic->time-utc
    time-monotonic->time-utc!

    time-tai->date
    time-tai->julian-day
    time-tai->modified-julian-day
    time-tai->time-monotonic
    time-tai->time-monotonic!
    time-tai->time-utc
    time-tai->time-utc!

    time-utc->date
    time-utc->julian-day
    time-utc->modified-julian-day
    time-utc->time-monotonic
    time-utc->time-monotonic!
    time-utc->time-tai
    time-utc->time-tai!

    date->string			string->date)
  (import (except (vicare)
		  current-time
		  time-nanosecond
		  time-second
		  time-gmt-offset
		  time
		  time?)
    (prefix (only (vicare)
		  current-time
		  time-nanosecond
		  time-second
		  time-gmt-offset)
	    host.)
    (prefix (vicare unsafe-operations)
	    $)
    (vicare syntactic-extensions)
    (vicare arguments validation)
    (srfi :6 basic-string-ports))


;;;; common arguments validation

(define-argument-validation (seconds who obj)
  (or (and (fixnum? obj)
	   ($fx<= 0 obj))
      (and (bignum? obj)
	   ($bignum-positive? obj)))
  (assertion-violation who
    "expected non-negative exact integer as number of seconds argument" obj))

(define-argument-validation (nanoseconds who obj)
  (or (and (fixnum? obj)
	   ($fx<= 0 obj))
      (and (bignum? obj)
	   ($bignum-positive? obj)))
  (assertion-violation who
    "expected non-negative exact integer as number of nanoseconds argument" obj))

;;; --------------------------------------------------------------------

(define-argument-validation (julian-day-number who obj)
  (or (fixnum? obj)
      (bignum? obj))
  (assertion-violation who "expected julian day number as argument" obj))

(define-argument-validation (modified-julian-day-number who obj)
  (or (fixnum? obj)
      (bignum? obj))
  (assertion-violation who "expected modified julian day number as argument" obj))

;;; --------------------------------------------------------------------

(define-argument-validation (time-zone-offset who obj)
  (fixnum? obj)
  (assertion-violation who "expected time zone offset as argument" obj))


;;;; implementation specific stuff

(let-syntax
    ((define-not-implemented (syntax-rules ()
			       ((_ ?who)
				(define (?who . args)
				  (assertion-violation '?who "not implemented"))))))
  (define-not-implemented host.cumulative-thread-time)
  (define-not-implemented host.cumulative-process-time)
  (define-not-implemented host.cumulative-gc-time))

;;Vicare uses gettimeofday() which gives microseconds, so our resolution
;;is 1000 nanoseconds.
(define host.time-resolution 1000)

(define host.timezone-offset
  (host.time-gmt-offset (host.current-time)))

(define time-resolution
  (case-lambda
   (()
    host.time-resolution)
   ((clock-type)
    host.time-resolution)))

(define (%local-tz-offset)
  host.timezone-offset)


;;;; constants

;;These definitions are required by the SRFI specification.
;;
(let-syntax ((define-time-type (syntax-rules ()
				 ((_ ?type)
				  (define ?type (quote ?type))))))
  (define-time-type time-tai)
  (define-time-type time-utc)
  (define-time-type time-monotonic)
  (define-time-type time-thread)
  (define-time-type time-process)
  (define-time-type time-duration))

(define NUMBER-OF-NANOSECONDS-IN-A-SECOND	#e1e9)
(define NUMBER-OF-SECONDS-IN-A-DAY		86400)
(define NUMBER-OF-SECONDS-IN-HALF-A-DAY		43200)

(define TAI-EPOCH-IN-JULIAN-DAYS		4881175/2)

;; JDN - MJDN = 4800001/2
;; JDN  = MJDN + 4800001/2
;; MJDN = JDN  - 4800001/2
;;
(define JDN-MJDN 4800001/2)

;;; --------------------------------------------------------------------
;;; locale dependent constants

(define LOCALE-NUMBER-SEPARATOR
  ".")

(define LOCALE-ABBR-WEEKDAY-VECTOR
  #'("Sun" "Mon" "Tue" "Wed" "Thu" "Fri" "Sat"))

(define LOCALE-LONG-WEEKDAY-VECTOR
  '#("Sunday" "Monday" "Tuesday" "Wednesday" "Thursday" "Friday" "Saturday"))

(define LOCALE-ABBR-MONTH-VECTOR
  '#(""		;note empty string in 0th place
     "Jan" "Feb" "Mar" "Apr" "May" "Jun" "Jul" "Aug" "Sep" "Oct" "Nov" "Dec"))

(define LOCALE-LONG-MONTH-VECTOR
  '#(""		;note empty string in 0th place
     "January"		"February"	"March"
     "April"		"May"		"June"
     "July"		"August"	"September"
     "October"		"November"	"December"))

(define LOCALE-PM "PM")
(define LOCALE-AM "AM")

;;See DATE->STRING for the meaning of these.
(define LOCALE-DATE-TIME-FORMAT		"~a ~b ~d ~H:~M:~S~z ~Y")
(define LOCALE-SHORT-DATE-FORMAT	"~m/~d/~y")
(define LOCALE-TIME-FORMAT		"~H:~M:~S")
(define ISO-8601-DATE-TIME-FORMAT	"~Y-~m-~dT~H:~M:~S~z")


;;;;A table of leap seconds
;;
;;See   <ftp://maia.usno.navy.mil/ser7/tai-utc.dat>    and   update   as
;;necessary.   This procedure  reads the  file in  the above  format and
;;creates the leap second table.
;;
;;   (set! LEAP-SECOND-TABLE (%read-tai-utc-data "tai-utc.dat"))
;;

(define (%read-tai-utc-data filename)
  (define (convert-jd jd)
    (* (- (exact jd) TAI-EPOCH-IN-JULIAN-DAYS) NUMBER-OF-SECONDS-IN-A-DAY))
  (define (convert-sec sec)
    (exact sec))
  (let ( (port (open-input-file filename))
	 (table '()) )
    (let loop ((line (get-line port)))
      (if (not (eof-object? line))
	  (begin
	    (let* ( (data (read (open-input-string (string-append "(" line ")"))))
		    (year (car data))
		    (jd   (cadddr (cdr data)))
		    (secs (cadddr (cdddr data))) )
	      (if (>= year 1972)
		  (set! table (cons (cons (convert-jd jd) (convert-sec secs)) table)))
	      (loop (get-line port))))))
    table))

;;Each entry is:
;;
;;   (UTC-seconds-since-epoch . number-of-seconds-to-add-for-TAI)
;;
;;note they go higher to lower, and end in 1972.
;;
(define LEAP-SECOND-TABLE
  '((1230768000 . 34)
    (1136073600 . 33)
    (915148800 . 32)
    (867715200 . 31)
    (820454400 . 30)
    (773020800 . 29)
    (741484800 . 28)
    (709948800 . 27)
    (662688000 . 26)
    (631152000 . 25)
    (567993600 . 24)
    (489024000 . 23)
    (425865600 . 22)
    (394329600 . 21)
    (362793600 . 20)
    (315532800 . 19)
    (283996800 . 18)
    (252460800 . 17)
    (220924800 . 16)
    (189302400 . 15)
    (157766400 . 14)
    (126230400 . 13)
    (94694400 . 12)
    (78796800 . 11)
    (63072000 . 10)))

(define (read-leap-second-table filename)
  (set! LEAP-SECOND-TABLE (%read-tai-utc-data filename)))

(define (%leap-second-delta utc-seconds)
  (letrec ((lsd (lambda (table)
		  (cond ((>= utc-seconds (caar table))
			 (cdar table))
			(else
			 (lsd (cdr table)))))))
    (if (< utc-seconds (* (- 1972 1970) 365 NUMBER-OF-SECONDS-IN-A-DAY))
	0
      (lsd LEAP-SECOND-TABLE))))

(define (%leap-second-neg-delta tai-seconds)
  ;;Going from TAI seconds to UTC seconds ...
  (letrec ( (lsd (lambda (table)
		   (cond ((null? table)
			  0)
			 ((<= (cdar table) (- tai-seconds (caar table)))
			  (cdar table))
			 (else
			  (lsd (cdr table)))))))
    (if (< tai-seconds (* (- 1972 1970) 365 NUMBER-OF-SECONDS-IN-A-DAY))
	0
      (lsd LEAP-SECOND-TABLE))))


;;;; time structure

(define-struct time
  (type nanosecond second))

(define (true-make-time type nanoseconds seconds)
  (define who 'make-time)
  (with-arguments-validation (who)
      ((time-type	type)
       (seconds		nanoseconds)
       (nanoseconds	seconds))
    (receive (nanos secs)
	($nanoseconds->nanos+secs nanoseconds)
      (make-time type nanos (+ seconds secs)))))

(define (copy-time time)
  (define who 'copy-time)
  (with-arguments-validation (who)
      ((time	time))
    ($copy-time time)))

(define ($copy-time time)
  (make-time ($time-type	time)
	     ($time-nanosecond	time)
	     ($time-second	time)))

;;; --------------------------------------------------------------------

(define-argument-validation (time-type who obj)
  (memq obj '(time-tai
	      time-utc
	      time-monotonic
	      time-thread
	      time-process
	      time-duration))
  (assertion-violation who "expected time object as argument" obj))

(define-argument-validation (time who obj)
  (time? obj)
  (assertion-violation who "expected time object as argument" obj))

(define-argument-validation (same-time-type who time1 time2)
  (eq? ($time-type time1)
       ($time-type time2))
  (assertion-violation who "expected time objects with the same type" time1 time2))

(let-syntax
    ((define-time-type-validation
       (syntax-rules ()
	 ((_ ?type)
	  (define-argument-validation (?type who obj)
	    (and (time? obj)
		 (eq? '?type ($time-type obj)))
	    (assertion-violation who
	      (string-append "invalid time type, expected" (symbol->string '?type))
	      obj))))))
  (define-time-type-validation time-tai)
  (define-time-type-validation time-utc)
  (define-time-type-validation time-monotonic)
  (define-time-type-validation time-thread)
  (define-time-type-validation time-process)
  (define-time-type-validation time-duration))


;;;; current time

(module (current-time)

  (define current-time
    (case-lambda
     (()
      (current-time time-utc))
     ((clock-type)
      (case-symbols clock-type
	((time-tai)		(%current-time-tai))
	((time-utc)		(%current-time-utc))
	((time-monotonic)	(%current-time-monotonic))
	((time-thread)		(%current-time-thread))
	((time-process)		(%current-time-process))
	(else
	 (error 'current-time "invalid clock type" clock-type))))))

  (define (%current-time-utc)
    (%make-time-helper host.current-time time-utc values))

  (define (%current-time-tai)
    (%make-time-helper host.current-time time-tai my:leap-second-helper))

  (define (%current-time-ms-time time-type proc)
    (let ((current-ms (proc)))
      (make-time time-type
		 (* (remainder current-ms 1000) 1000)
		 (quotient current-ms 1000))))

  (define (%current-time-monotonic)
    (%make-time-helper host.current-time time-monotonic my:leap-second-helper))

  (define (%current-time-thread)
    (%make-time-helper host.cumulative-thread-time time-thread values))

  (define (%current-time-process)
    (%make-time-helper host.cumulative-process-time time-process values))

;;; --------------------------------------------------------------------

  (define (%make-time-helper current-time type proc)
    (let ((x (current-time)))
      (make-time type
		 (host.time-nanosecond x)
		 (proc (host.time-second x)))))

  (define (my:leap-second-helper s)
    (+ s (%leap-second-delta s)))

  #| end of module |# )


;;;; time comparisons

(define (time=? time1 time2)
  (define who 'time=?)
  (with-arguments-validation (who)
      ((time		time1)
       (time		time2)
       (same-time-type	time1 time2))
    ($time=? time1 time2)))

(define ($time=? time1 time2)
  (and (= ($time-second time1)
	  ($time-second time2))
       (= ($time-nanosecond time1)
	  ($time-nanosecond time2))))

;;; --------------------------------------------------------------------

(define (time>? time1 time2)
  (define who 'time>?)
  (with-arguments-validation (who)
      ((time		time1)
       (time		time2)
       (same-time-type	time1 time2))
    ($time>? time1 time2)))

(define ($time>? time1 time2)
  (or (> ($time-second time1)
	 ($time-second time2))
      (and (= ($time-second time1)
	      ($time-second time2))
	   (> ($time-nanosecond time1)
	      ($time-nanosecond time2)))))

;;; --------------------------------------------------------------------

(define (time<? time1 time2)
  (define who 'time<?)
  (with-arguments-validation (who)
      ((time		time1)
       (time		time2)
       (same-time-type	time1 time2))
    ($time<? time1 time2)))

(define ($time<? time1 time2)
  (or (< ($time-second time1)
	 ($time-second time2))
      (and (= ($time-second time1)
	      ($time-second time2))
	   (< ($time-nanosecond time1)
	      ($time-nanosecond time2)))))

;;; --------------------------------------------------------------------

(define (time>=? time1 time2)
  (define who 'time>=?)
  (with-arguments-validation (who)
      ((time		time1)
       (time		time2)
       (same-time-type	time1 time2))
    ($time>=? time1 time2)))

(define ($time>=? time1 time2)
  (or (> ($time-second time1)
	 ($time-second time2))
      (and (= ($time-second time1)
	      ($time-second time2))
	   (>= ($time-nanosecond time1)
	       ($time-nanosecond time2)))))

;;; --------------------------------------------------------------------

(define (time<=? time1 time2)
  (define who 'time<=?)
  (with-arguments-validation (who)
      ((time		time1)
       (time		time2)
       (same-time-type	time1 time2))
    ($time<=? time1 time2)))

(define ($time<=? time1 time2)
  (or (< ($time-second time1)
	 ($time-second time2))
      (and (= ($time-second time1)
	      ($time-second time2))
	   (<= ($time-nanosecond time1)
	       ($time-nanosecond time2)))))


;;;; time arithmetic

(module ($nanoseconds->nanos+secs
	 time-difference		$time-difference
	 time-difference!		$time-difference!
	 add-duration			$add-duration
	 add-duration!			$add-duration!
	 subtract-duration		$subtract-duration
	 subtract-duration!		$subtract-duration!)

  (define (time-difference time1 time2)
    (define who 'time-difference)
    (with-arguments-validation (who)
	((time			time1)
	 (time			time2)
	 (same-time-type	time1 time2))
      ($time-difference time1 time2)))

  (define (time-difference! time1 time2)
    (define who 'time-difference!)
    (with-arguments-validation (who)
	((time			time1)
	 (time			time2)
	 (same-time-type	time1 time2))
      ($time-difference! time1 time1 time2)))

  (define (add-duration time duration)
    (define who 'add-duration)
    (with-arguments-validation (who)
	((time		time)
	 (time-duration	duration))
      ($add-duration time duration)))

  (define (add-duration! time duration)
    (define who 'add-duration!)
    (with-arguments-validation (who)
	((time		time)
	 (time-duration	duration))
      ($add-duration! time time duration)))

  (define (subtract-duration time duration)
    (define who 'subtract-duration)
    (with-arguments-validation (who)
	((time		time)
	 (time-duration	duration))
      ($subtract-duration time duration)))

  (define (subtract-duration! time duration)
    (define who 'subtract-duration!)
    (with-arguments-validation (who)
	((time		time)
	 (time-duration	duration))
      ($subtract-duration! time time duration)))

;;; --------------------------------------------------------------------

  (define ($time-difference time1 time2)
    ($time-difference! (make-time #f #f #f) time1 time2))

  (define ($time-difference! retval time1 time2)
    ($set-time-type! retval time-duration)
    (if ($time=? time1 time2)
	(begin
	  ($set-time-second!     retval 0)
	  ($set-time-nanosecond! retval 0))
      (receive (nanos secs)
	  ($nanoseconds->nanos+secs (- ($time->nanoseconds time1)
				       ($time->nanoseconds time2)))
	($set-time-second!     retval secs)
	($set-time-nanosecond! retval nanos)))
    retval)

;;; --------------------------------------------------------------------

  (define ($add-duration time duration)
    ($add-duration! (make-time ($time-type time) #f #f) time duration))

  (define ($add-duration! retval time1 duration)
    (let ((sec-plus  (+ ($time-second     time1) ($time-second     duration)))
	  (nsec-plus (+ ($time-nanosecond time1) ($time-nanosecond duration))))
      (let ((r (remainder nsec-plus NUMBER-OF-NANOSECONDS-IN-A-SECOND))
	    (q (quotient  nsec-plus NUMBER-OF-NANOSECONDS-IN-A-SECOND)))
	(if (negative? r)
	    (begin
	      ($set-time-second!     retval (+ sec-plus q -1))
	      ($set-time-nanosecond! retval (+ NUMBER-OF-NANOSECONDS-IN-A-SECOND r)))
	  (begin
	    ($set-time-second!     retval (+ sec-plus q))
	    ($set-time-nanosecond! retval r)))
	retval)))

;;; --------------------------------------------------------------------

  (define ($subtract-duration time duration)
    ($subtract-duration! (make-time ($time-type time) #f #f) time duration))

  (define ($subtract-duration! retval time1 duration)
    (let ((sec-minus  (- ($time-second     time1) ($time-second     duration)))
	  (nsec-minus (- ($time-nanosecond time1) ($time-nanosecond duration))))
      (let ((r (remainder nsec-minus NUMBER-OF-NANOSECONDS-IN-A-SECOND))
	    (q (quotient  nsec-minus NUMBER-OF-NANOSECONDS-IN-A-SECOND)))
	(if (negative? r)
	    (begin
	      ($set-time-second!     retval (- sec-minus q 1))
	      ($set-time-nanosecond! retval (+ NUMBER-OF-NANOSECONDS-IN-A-SECOND r)))
	  (begin
	    ($set-time-second!     retval (- sec-minus q))
	    ($set-time-nanosecond! retval r)))
	retval)))

;;; --------------------------------------------------------------------

  (define ($time->nanoseconds time)
    (+ (* ($time-second time) NUMBER-OF-NANOSECONDS-IN-A-SECOND)
       ($time-nanosecond time)))

  (define ($nanoseconds->nanos+secs nanoseconds)
    (let ((q (quotient  nanoseconds NUMBER-OF-NANOSECONDS-IN-A-SECOND))
	  (r (remainder nanoseconds NUMBER-OF-NANOSECONDS-IN-A-SECOND)))
      (if (negative? r)
	  (values (+ NUMBER-OF-NANOSECONDS-IN-A-SECOND r) (- q 1))
	(values r q))))

  #| end of module |# )


;;;; converters between types

(define (time-tai->time-utc time-in)
  (define who 'time-tai->time-utc)
  (with-arguments-validation (who)
      ((time-tai	time-in))
    ($time-tai->time-utc time-in)))

(define (time-tai->time-utc! time-in)
  (define who 'time-tai->time-utc!)
  (with-arguments-validation (who)
      ((time-tai	time-in))
    ($time-tai->time-utc! time-in time-in)))

(define (time-utc->time-tai time-in)
  (define who 'time-utc->time-tai)
  (with-arguments-validation (who)
      ((time-utc	time-in))
    ($time-utc->time-tai time-in)))

(define (time-utc->time-tai! time-in)
  (define who 'time-utc->time-tai!)
  (with-arguments-validation (who)
      ((time-utc	time-in))
    ($time-utc->time-tai! time-in time-in)))

;;; --------------------------------------------------------------------

(define ($time-tai->time-utc time-in)
  ($time-tai->time-utc! time-in (make-time #f #f #f)))

(define ($time-utc->time-tai time-in)
  ($time-utc->time-tai! time-in (make-time #f #f #f)))

(define ($time-tai->time-utc! time-in time-out)
  ($set-time-type!       time-out time-utc)
  ($set-time-nanosecond! time-out ($time-nanosecond time-in))
  ($set-time-second!     time-out (- ($time-second time-in)
				     (%leap-second-neg-delta ($time-second time-in))))
  time-out)

(define ($time-utc->time-tai! time-in time-out caller)
  ($set-time-type!       time-out time-tai)
  ($set-time-nanosecond! time-out ($time-nanosecond time-in))
  ($set-time-second!     time-out (+ ($time-second time-in)
				     (%leap-second-delta ($time-second time-in))))
  time-out)

;;; --------------------------------------------------------------------

;;These depend on TIME-MONOTONIC having the same definition as TIME-TAI.

(define (time-monotonic->time-utc time-in)
  (define who 'time-monotonic->time-utc)
  (with-arguments-validation (who)
      ((time-monotonic	time-in))
    ($time-monotonic->time-utc time-in)))

(define ($time-monotonic->time-utc time-in)
  (let ((ntime ($copy-time time-in)))
    ($set-time-type! ntime time-tai)
    ($time-tai->time-utc! ntime ntime)))

(define (time-monotonic->time-utc! time-in)
  (define who 'time-monotonic->time-utc!)
  (with-arguments-validation (who)
      ((time-monotonic	time-in))
    ($time-monotonic->time-utc! time-in)))

(define ($time-monotonic->time-utc! time-in)
  ($set-time-type! time-in time-tai)
  ($time-tai->time-utc! time-in time-in))

;;; --------------------------------------------------------------------

(define (time-monotonic->time-tai time-in)
  (define who 'time-monotonic->time-tai)
  (with-arguments-validation (who)
      ((time-monotonic	time-in))
    ($time-monotonic->time-tai time-in)))

(define ($time-monotonic->time-tai time-in)
  (begin0-let ((ntime ($copy-time time-in)))
    ($set-time-type! ntime time-tai)))

(define (time-monotonic->time-tai! time-in)
  (define who 'time-monotonic->time-tai!)
  (with-arguments-validation (who)
      ((time-monotonic	time-in))
    ($time-monotonic->time-tai! time-in)))

(define ($time-monotonic->time-tai! time-in)
  ($set-time-type! time-in time-tai)
  time-in)

;;; --------------------------------------------------------------------

(define (time-utc->time-monotonic time-in)
  (define who 'time-utc->time-monotonic)
  (with-arguments-validation (who)
      ((time-utc	time-in))
    ($time-utc->time-monotonic time-in)))

(define ($time-utc->time-monotonic time-in)
  (begin0-let ((ntime ($time-utc->time-tai! time-in (make-time #f #f #f))))
    ($set-time-type! ntime time-monotonic)))

(define (time-utc->time-monotonic! time-in)
  (define who 'time-utc->time-monotonic!)
  (with-arguments-validation (who)
      ((time-utc	time-in))
    ($time-utc->time-monotonic! time-in)))

(define ($time-utc->time-monotonic! time-in)
  (begin0-let ((ntime ($time-utc->time-tai! time-in time-in)))
    (set-time-type! ntime time-monotonic)))

;;; --------------------------------------------------------------------

(define (time-tai->time-monotonic time-in)
  (define who 'time-tai->time-monotonic)
  (with-arguments-validation (who)
      ((time-tai	time-in))
    ($time-tai->time-monotonic time-in)))

(define ($time-tai->time-monotonic time-in)
  (begin0-let ((ntime ($copy-time time-in)))
    ($set-time-type! ntime time-monotonic)))

(define (time-tai->time-monotonic! time-in)
  (define who 'time-tai->time-monotonic!)
  (with-arguments-validation (who)
      ((time-tai	time-in))
    ($time-tai->time-monotonic! time-in)))

(define ($time-tai->time-monotonic! time-in)
  ($set-time-type! time-in time-monotonic)
  time-in)


;;;; date structure

(define-struct date
  (nanosecond second minute hour day month year zone-offset))

(define-argument-validation (date who obj)
  (date? obj)
  (assertion-violation who "expected date object as argument" obj))

(define current-date
  (case-lambda
   (()
    (current-date (%local-tz-offset)))
   ((tz-offset)
    (define who 'current-date)
    (with-arguments-validation (who)
	((time-zone-offset	tz-offset))
      ($time-utc->date (current-time time-utc) tz-offset)))))


;;;; time to date conversion

(define time-tai->date
  (case-lambda
   ((time)
    (time-tai->date time (%local-tz-offset)))
   ((time tz-offset)
    (define who 'time-tai->date)
    (with-arguments-validation (who)
	((time-tai		time)
	 (time-zone-offset	tz-offset))
      ($time-tai->date time tz-offset)))))

(define ($time-tai->date time tz-offset)
  (if (%tai-before-leap-second? ($time-second time))
      ;;If  it's *right*  before the  leap,  we need  to pretend  to
      ;;subtract a second ...
      (let* ((time^ (let ((T ($time-tai->time-utc time)))
		      ($subtract-duration! T (make-time time-duration 0 1))))
	     (date ($time-utc->date time^ tz-offset time-utc)))
	($set-date-second! date 60)
	date)
    ($time-utc->date ($time-tai->time-utc time) tz-offset)))

(module (%tai-before-leap-second?)

  (define (%tai-before-leap-second? second)
    (%find (lambda (x)
	     (= second (- (+ (car x) (cdr x)) 1)))
	   LEAP-SECOND-TABLE))

  (define (%find proc l)
    (cond ((null? l)
	   #f)
	  ((proc (car l))
	   #t)
	  (else
	   (%find proc (cdr l)))))

  #| end of module |# )

;;; --------------------------------------------------------------------

(define time-utc->date
  (case-lambda
   ((time)
    (time-utc->date time (%local-tz-offset)))
   ((time tz-offset)
    (define who 'time-utc->date)
    (with-arguments-validation (who)
	((time-utc		time)
	 (time-zone-offset	tz-offset))
      ($time-utc->date time tz-offset)))))

(define time-monotonic->date
  ;;Again, time-monotonic is the same as time tai.
  ;;
  (case-lambda
   ((time)
    (time-monotonic->date time (%local-tz-offset)))
   ((time tz-offset)
    (define who 'time-monotonic->date)
    (with-arguments-validation (who)
	((time-monotonic	time)
	 (time-zone-offset	tz-offset))
      ($time-utc->date time tz-offset)))))

(define ($time-utc->date time tz-offset)
  (receive (secs date month year)
      (%decode-julian-day-number
       (%time->julian-day-number ($time-second time) tz-offset))
    (let* ((hours    (quotient  secs (* 60 60)))
	   (rem      (remainder secs (* 60 60)))
	   (minutes  (quotient  rem 60))
	   (seconds  (remainder rem 60)))
      (make-date ($time-nanosecond time)
		 seconds
		 minutes
		 hours
		 date
		 month
		 year
		 tz-offset))))


;;;; date to time conversion

(define (date->time-utc date)
  (define who 'date->time-utc)
  (with-arguments-validation (who)
      ((date	date))
    ($date->time-utc date)))

(define ($date->time-utc date)
  (let ((nanosecond	($date-nanosecond  date))
	(second		($date-second      date))
	(minute		($date-minute      date))
	(hour		($date-hour        date))
	(day		($date-day         date))
	(month		($date-month       date))
	(year		($date-year        date))
	(offset		($date-zone-offset date)))
    (let ((jdays (- (%encode-julian-day-number day month year)
		    TAI-EPOCH-IN-JULIAN-DAYS)))
      (make-time time-utc nanosecond
		 (+ (* (- jdays 1/2) 24 60 60)
		    (* hour 60 60)
		    (* minute 60)
		    second
		    (- offset))))))

;;; --------------------------------------------------------------------

(define (date->time-tai date)
  (define who 'date->time-tai)
  (with-arguments-validation (who)
      ((date	date))
    ($date->time-tai date)))

(define ($date->time-tai date)
  (if (= (date-second date) 60)
      (let ((T (time-utc->time-tai! (date->time-utc date))))
	($subtract-duration! T (make-time time-duration 0 1)))
    ($time-utc->time-tai! ($date->time-utc date))))

;;; --------------------------------------------------------------------

(define (date->time-monotonic date)
  (define who 'date->time-monotonic)
  (with-arguments-validation (who)
      ((date	date))
    ($date->time-monotonic date)))

(define ($date->time-monotonic date)
  ($time-utc->time-monotonic! ($date->time-utc date)))


;;;; basic julian day functions

(define (current-julian-day)
  ($time-utc->julian-day (current-time time-utc)))

(define (current-modified-julian-day)
  ($time-utc->modified-julian-day (current-time time-utc)))

(define (%modified-julian-day->julian-day mjdn)
  (+ mjdn JDN-MJDN))

(define (%julian-day->modified-julian-day jdn)
  (- jdn JDN-MJDN))


;;;; misc routines

;; gives the julian day which starts at noon.
(define (%encode-julian-day-number day month year)
  (let* ((a (quotient (- 14 month) 12))
	 (y (- (- (+ year 4800) a) (if (negative? year) -1 0)))
	 (m (- (+ month (* 12 a)) 3)))
    (+ day
       (quotient (+ (* 153 m) 2) 5)
       (* 365 y)
       (quotient y 4)
       (- (quotient y 100))
       (quotient y 400)
       -32045)))

;; gives the seconds/date/month/year
(define (%decode-julian-day-number jdn)
  (let* ((days (truncate jdn))
	 (a (+ days 32044))
	 (b (quotient (+ (* 4 a) 3) 146097))
	 (c (- a (quotient (* 146097 b) 4)))
	 (d (quotient (+ (* 4 c) 3) 1461))
	 (e (- c (quotient (* 1461 d) 4)))
	 (m (quotient (+ (* 5 e) 2) 153))
	 (y (+ (* 100 b) d -4800 (quotient m 10))))
    (values ; seconds date month year
     (* (- jdn days) NUMBER-OF-SECONDS-IN-A-DAY)
     (+ e (- (quotient (+ (* 153 m) 2) 5)) 1)
     (+ m 3 (* -12 (quotient m 10)))
     (if (>= 0 y) (- y 1) y))
    ))

(define (%time->julian-day-number seconds tz-offset)
  ;;Special function: ignores nanoseconds.
  ;;
  (+ (/ (+ seconds tz-offset NUMBER-OF-SECONDS-IN-HALF-A-DAY)
	NUMBER-OF-SECONDS-IN-A-DAY)
     TAI-EPOCH-IN-JULIAN-DAYS))

(define (%leap-year? year)
  (or (= (modulo year 400) 0)
      (and (= (modulo year 4) 0)
	   (not (= (modulo year 100) 0)))))

(define (leap-year? date)
  (%leap-year? (date-year date)))

;;; --------------------------------------------------------------------

(define (date-year-day date)
  (define who 'date-year-day)
  (with-arguments-validation (who)
      ((date	date))
    (%year-day ($date-day date) ($date-month date) ($date-year date))))

(define (%year-day day month year)
  (define who 'date-year-day)
  (define MONTH-ASSOC
    '((0 . 0)		(1 . 31)	(2 . 59)
      (3 . 90)		(4 . 120)	(5 . 151)
      (6 . 181)		(7 . 212)	(8 . 243)
      (9 . 273)		(10 . 304)	(11 . 334)))
  (let ((days-pr (assoc (- month 1) MONTH-ASSOC)))
    (if (not days-pr)
	(error who "invalid month specification" month))
    (if (and (%leap-year? year) (> month 2))
	(+ day (cdr days-pr) 1)
      (+ day (cdr days-pr)))))

;;; --------------------------------------------------------------------

(define (date-week-day date)
  (define who 'date-week-day)
  (with-arguments-validation (who)
      ((date	date))
    (%week-day ($date-day date) ($date-month date) ($date-year date))))

(define (%week-day day month year)
  ;;From calendar FAQ.
  ;;
  (let* ((a (quotient (- 14 month) 12))
	 (y (- year a))
	 (m (+ month (* 12 a) -2)))
    (modulo (+ day y (quotient y 4) (- (quotient y 100))
	       (quotient y 400) (quotient (* 31 m) 12))
	    7)))

;;; --------------------------------------------------------------------

(define (date-week-number date day-of-week-starting-week)
  (define who 'date-week-number)
  (with-arguments-validation (who)
      ((date	date)
       (fixnum	day-of-week-starting-week))
    (quotient (- (date-year-day date)
		 (%days-before-first-week date day-of-week-starting-week))
	      7)))

(define (%days-before-first-week date day-of-week-starting-week)
  (let* ((first-day  (make-date 0 0 0 0
				1
				1
				(date-year date)
				#f))
	 (fdweek-day (date-week-day first-day)))
    (modulo (- day-of-week-starting-week fdweek-day)
            7)))

;;; --------------------------------------------------------------------

(define (%natural-year n)
  ;;Given a 'two digit' number, find the year within 50 years +/-.
  (let* ((current-year    ($date-year (current-date)))
	 (current-century (* (quotient current-year 100) 100)))
    (cond ((>= n 100)
	   n)
	  ((<  n 0)
	   n)
	  ((<= (- (+ current-century n) current-year) 50)
	   (+ current-century n))
	  (else
	   (+ (- current-century 100) n)))))


;;;; conversion from time objects to julian day numbers

(define (time-utc->julian-day time)
  (define who 'time-utc->julian-day)
  (with-arguments-validation (who)
      ((time-utc	time))
    ($time-utc->julian-day time)))

(define ($time-utc->julian-day time)
  (+ (/ (+ ($time-second time)
	   (/ ($time-nanosecond time)
	      NUMBER-OF-NANOSECONDS-IN-A-SECOND))
	NUMBER-OF-SECONDS-IN-A-DAY)
     TAI-EPOCH-IN-JULIAN-DAYS))

;;; --------------------------------------------------------------------

(define (time-utc->modified-julian-day time)
  (define who 'time-utc->modified-julian-day)
  (with-arguments-validation (who)
      ((time-utc	time))
    ($time-utc->modified-julian-day time)))

(define ($time-utc->modified-julian-day time)
  (%julian-day->modified-julian-day ($time-utc->julian-day time)))

;;; --------------------------------------------------------------------

(define (time-tai->julian-day time)
  (define who 'time-tai->julian-day)
  (with-arguments-validation (who)
      ((time-tai	time))
    ($time-tai->julian-day time)))

(define ($time-tai->julian-day time)
  (+ (/ (+ (- ($time-second time)
	      (%leap-second-delta ($time-second time)))
	   (/ ($time-nanosecond time)
	      NUMBER-OF-NANOSECONDS-IN-A-SECOND))
	NUMBER-OF-SECONDS-IN-A-DAY)
     TAI-EPOCH-IN-JULIAN-DAYS))

;;; --------------------------------------------------------------------

(define (time-tai->modified-julian-day time)
  (define who 'time-tai->modified-julian-day)
  (with-arguments-validation (who)
      ((time-tai	time))
    ($time-tai->modified-julian-day time)))

(define ($time-tai->modified-julian-day time)
  (%julian-day->modified-julian-day ($time-tai->julian-day time)))

;;; --------------------------------------------------------------------

(define (time-monotonic->julian-day time)
  ;;This is the same as TIME-TAI->JULIAN-DAY.
  ;;
  (define who 'time-monotonic->julian-day)
  (with-arguments-validation (who)
      ((time-monotonic	time))
    ($time-monotonic->julian-day time)))

(define ($time-monotonic->julian-day time)
  (+ (/ (+ (- ($time-second time)
	      (%leap-second-delta ($time-second time)))
	   (/ ($time-nanosecond time)
	      NUMBER-OF-NANOSECONDS-IN-A-SECOND))
	NUMBER-OF-SECONDS-IN-A-DAY)
     TAI-EPOCH-IN-JULIAN-DAYS))

;;; --------------------------------------------------------------------

(define (time-monotonic->modified-julian-day time)
  (define who 'time-monotonic->modified-julian-day)
  (with-arguments-validation (who)
      ((time-monotonic	time))
    ($time-monotonic->modified-julian-day time)))

(define ($time-monotonic->modified-julian-day time)
  (%julian-day->modified-julian-day ($time-monotonic->julian-day time)))


;;;; conversion from julian day numbers to time objects

(define (julian-day->time-utc jdn)
  (define who 'julian-day->time-utc)
  (with-arguments-validation (who)
      ((julian-day-number	jdn))
    ($julian-day->time-utc jdn)))

(define ($julian-day->time-utc jdn)
  (receive (nanos secs)
      ($nanoseconds->nanos+secs (* NUMBER-OF-NANOSECONDS-IN-A-SECOND
				   NUMBER-OF-SECONDS-IN-A-DAY
				   (- jdn TAI-EPOCH-IN-JULIAN-DAYS)))
    (make-time time-utc nanos secs)))

;;; --------------------------------------------------------------------

(define (julian-day->time-tai jdn)
  (define who 'julian-day->time-tai)
  (with-arguments-validation (who)
      ((julian-day-number	jdn))
    ($julian-day->time-tai jdn)))

(define ($julian-day->time-tai jdn)
  ($time-utc->time-tai! ($julian-day->time-utc jdn)))

;;; --------------------------------------------------------------------

(define (julian-day->time-monotonic jdn)
  (define who 'julian-day->time-monotonic)
  (with-arguments-validation (who)
      ((julian-day-number	jdn))
    ($julian-day->time-monotonic jdn)))

(define ($julian-day->time-monotonic jdn)
  ($time-utc->time-monotonic! ($julian-day->time-utc jdn)))

;;; --------------------------------------------------------------------

(define (modified-julian-day->time-utc mjdn)
  (define who 'modified-julian-day->time-utc)
  (with-arguments-validation (who)
      ((modified-julian-day-number	mjdn))
    ($modified-julian-day->time-utc mjdn)))

(define ($modified-julian-day->time-utc mjdn)
  ($julian-day->time-utc (%modified-julian-day->julian-day mjdn)))

;;; --------------------------------------------------------------------

(define (modified-julian-day->time-tai mjdn)
  (define who 'modified-julian-day->time-tai)
  (with-arguments-validation (who)
      ((modified-julian-day-number	mjdn))
    ($modified-julian-day->time-tai mjdn)))

(define ($modified-julian-day->time-tai mjdn)
  ($julian-day->time-tai (%modified-julian-day->julian-day mjdn)))

;;; --------------------------------------------------------------------

(define (modified-julian-day->time-monotonic mjdn)
  (define who 'modified-julian-day->time-monotonic)
  (with-arguments-validation (who)
      ((modified-julian-day-number	mjdn))
    ($modified-julian-day->time-monotonic mjdn)))

(define ($modified-julian-day->time-monotonic mjdn)
  ($julian-day->time-monotonic (%modified-julian-day->julian-day mjdn)))


;;;; conversion from julian day numbers to date objects

(define julian-day->date
  (case-lambda
   ((jdn)
    (julian-day->date jdn (%local-tz-offset)))
   ((jdn tz-offset)
    (define who 'julian-day->date)
    (with-arguments-validation (who)
	((julian-day-number	jdn)
	 (time-zone-offset	tz-offset))
      ($julian-day->date jdn tz-offset)))))

(define ($julian-day->date jdn tz-offset)
  ($time-utc->date ($julian-day->time-utc jdn) tz-offset))

;;; --------------------------------------------------------------------

(define modified-julian-day->date
  (case-lambda
   ((mjdn)
    (modified-julian-day->date mjdn (%local-tz-offset)))
   ((mjdn tz-offset)
    (define who 'modified-julian-day->date)
    (with-arguments-validation (who)
	((modified-julian-day-number	mjdn)
	 (time-zone-offset		tz-offset))
      ($modified-julian-day->date mjdn tz-offset)))))

(define ($modified-julian-day->date mjdn tz-offset)
  ($julian-day->date (%modified-julian-day->julian-day mjdn) tz-offset))


;;;; conversion from date objects to julian day numbers

(define (date->julian-day date)
  (define who 'date->julian-day)
  (with-arguments-validation (who)
      ((date	date))
    ($date->julian-day date)))

(define ($date->julian-day date)
  (let ((nanosecond	($date-nanosecond date))
	(second		($date-second		date))
	(minute		($date-minute		date))
	(hour		($date-hour		date))
	(day		($date-day		date))
	(month		($date-month		date))
	(year		($date-year		date))
	(offset		($date-zone-offset	date)))
    (+ (%encode-julian-day-number day month year)
       -1/2
       (+ (/ (+ (* hour 60 60)
                (* minute 60)
                second
                (/ nanosecond NUMBER-OF-NANOSECONDS-IN-A-SECOND)
                (- offset))
             NUMBER-OF-SECONDS-IN-A-DAY)))))

;;; --------------------------------------------------------------------

(define (date->modified-julian-day date)
  (define who 'date->modified-julian-day)
  (with-arguments-validation (who)
      ((date	date))
    ($date->modified-julian-day date)))

(define ($date->modified-julian-day date)
  (%julian-day->modified-julian-day ($date->julian-day date)))


(define (%locale-abbr-weekday n)
  ($vector-ref LOCALE-ABBR-WEEKDAY-VECTOR n))

(define (%locale-long-weekday n)
  ($vector-ref LOCALE-LONG-WEEKDAY-VECTOR n))

(define (%locale-abbr-month n)
  ($vector-ref LOCALE-ABBR-MONTH-VECTOR n))

(define (%locale-long-month n)
  ($vector-ref LOCALE-LONG-MONTH-VECTOR n))

(module (%locale-abbr-weekday->index
	 %locale-long-weekday->index
	 %locale-abbr-month->index
	 %locale-long-month->index)

  (define (%locale-abbr-weekday->index string)
    (%vector-find string LOCALE-ABBR-WEEKDAY-VECTOR string=?))

  (define (%locale-long-weekday->index string)
    (%vector-find string LOCALE-LONG-WEEKDAY-VECTOR string=?))

  (define (%locale-abbr-month->index string)
    (%vector-find string LOCALE-ABBR-MONTH-VECTOR string=?))

  (define (%locale-long-month->index string)
    (%vector-find string LOCALE-LONG-MONTH-VECTOR string=?))

  (define (%vector-find needle haystack comparator)
    (let ((len (vector-length haystack)))
      (define (%vector-find-int index)
	(cond ((>= index len)
	       #f)
	      ((comparator needle ($vector-ref haystack index))
	       index)
	      (else
	       (%vector-find-int (+ index 1)))))
      (%vector-find-int 0)))

  #| end of module |# )


;;;; string to date

(module (string->date)
  (define who 'string->date)

  (define (string->date input-string template-string)
    (with-arguments-validation (who)
	((string	input-string)
	 (string	template-string))
      (let ((newdate (make-date 0 0 0 0 #f #f #f (%local-tz-offset))))
	(%string->date newdate
		       0
		       template-string
		       ($string-length template-string)
		       (open-input-string input-string)
		       template-string)
	(if (%all-fields-set-in-date? newdate)
	    newdate
	  (error who "bad date format string, incomplete date read" newdate template-string)))))

  (define (%all-fields-set-in-date? date)
    ;;Return true if all the fields in DATE have been set.
    ;;
    (and ($date-nanosecond	date)
	 ($date-second		date)
	 ($date-minute		date)
	 ($date-hour		date)
	 ($date-day		date)
	 ($date-month		date)
	 ($date-year		date)
	 ($date-zone-offset	date)))

  (define (%string->date date index format-string str-len port template-string)
    (unless (>= index str-len)
      (let ((current-char (string-ref format-string index)))
	(if (not (char=? current-char #\~))
	    (let ((port-char (read-char port)))
	      (if (or (eof-object? port-char)
		      (not (char=? current-char port-char)))
		  (%error-bad-template template-string))
	      (%string->date date (+ index 1) format-string str-len port template-string))
	  ;;Otherwise, it's an escape, we hope.
	  (if (> (+ index 1) str-len)
	      (%error-bad-template template-string)
	    (let* ((format-char (string-ref format-string (+ index 1)))
		   (format-info (assoc format-char %READ-DIRECTIVES)))
	      (if (not format-info)
		  (%error-bad-template template-string)
		(begin
		  (let ((skipper (cadr format-info))
			(reader  (caddr format-info))
			(actor   (cadddr format-info)))
		    (%skip-until port skipper template-string)
		    (let ((val (reader port)))
		      (if (eof-object? val)
			  (%error-bad-template template-string)
			(actor val date)))
		    (%string->date date (+ index 2) format-string
				   str-len port template-string))))))))))

  (define (%skip-until port skipper template-string)
    (let ((ch (peek-char port)))
      (if (eof-object? ch)
	  (error who "bad date format string" template-string)
	(unless (skipper ch)
	  (read-char port)
	  (%skip-until port skipper template-string)))))

  (define (%make-integer-reader upto)
    (lambda (port)
      (%integer-reader upto port)))

  (define (%make-fractional-integer-reader upto)
    (lambda (port)
      (%fractional-integer-reader upto port)))

  (define (%make-locale-reader indexer)
    (lambda (port)
      (%locale-reader port indexer)))

  (define (%make-char-id-reader char)
    (lambda (port)
      (if (char=? char (read-char port))
	  char
	(error who "bad date template string, invalid character match"))))

  (define (%make-integer-exact-reader n)
    (lambda (port)
      (%integer-reader-exact n port)))

  (define (%char->int ch)
    (case-chars ch
      ((#\0) 0)
      ((#\1) 1)
      ((#\2) 2)
      ((#\3) 3)
      ((#\4) 4)
      ((#\5) 5)
      ((#\6) 6)
      ((#\7) 7)
      ((#\8) 8)
      ((#\9) 9)
      (else
       (error who "bad date template string, non-integer character" ch))))

  (define (%integer-reader upto port)
    ;;Read an integer upto n characters long  on port; upto -> #f if any
    ;;length.
    (define (accum-int port accum nchars)
      (let ((ch (peek-char port)))
	(if (or (eof-object? ch)
		(not (char-numeric? ch))
		(and upto (>= nchars upto)))
	    accum
          (accum-int port (+ (* accum 10) (%char->int (read-char port))) (+ nchars 1)))))
    (accum-int port 0 0))

  (define (%fractional-integer-reader upto port)
    ;;Read an fractional integer upto n characters long on port; upto ->
    ;;#f if any length.
    ;;
    ;;The  return  value  is  normalized to  upto  decimal  places.  For
    ;;example, if  upto is 9  and the string  read is "123",  the return
    ;;value is 123000000.
    ;;
    (define (accum-int port accum nchars)
      (let ((ch (peek-char port)))
	(if (or (eof-object? ch)
		(not (char-numeric? ch))
		(and upto (>= nchars  upto)))
	    (* accum (expt 10 (- upto nchars)))
	  (accum-int port (+ (* accum 10) (%char->int (read-char port))) (+ nchars 1)))))
    (accum-int port 0 0))

  (define (%integer-reader-exact n port)
    ;;Read exactly N characters and convert to integer; could be padded.
    ;;
    (let ((padding-ok #t))
      (define (accum-int port accum nchars)
	(let ((ch (peek-char port)))
	  (cond ((>= nchars n)
		 accum)
		((eof-object? ch)
		 (error who "bad date template string, premature ending to integer read"))
		((char-numeric? ch)
		 (set! padding-ok #f)
		 (accum-int port
			    (+ (* accum 10) (%char->int (read-char port)))
			    (+ nchars 1)))
		(padding-ok
		 (read-char port) ;consume padding
		 (accum-int port accum (+ nchars 1)))
		(else
		 ;;padding where it shouldn't be
		 (error who
		   "bad date template string, non-numeric characters in integer read.")))))
      (accum-int port 0 0)))

  (define (%zone-reader port)
    (let ((offset    0)
	  (positive? #f))
      (let ((ch (read-char port)))
	(when (eof-object? ch)
	  (%error-invalid-time-zone-pm ch))
	(if (or ($char= ch #\Z)
		($char= ch #\z))
	    0
	  (begin
	    (case-chars ch
	      ((#\+)
	       (set! positive? #t))
	      ((#\-)
	       (set! positive? #f))
	      (else
	       (%error-invalid-time-zone-pm ch)))
	    (let ((ch (read-char port)))
	      (if (eof-object? ch)
		  (%error-invalid-time-zone-number ch)
		(set! offset (* (%char->int ch) 10 60 60))))
	    (let ((ch (read-char port)))
	      (if (eof-object? ch)
		  (%error-invalid-time-zone-number ch)
		(set! offset (+ offset (* (%char->int ch) 60 60)))))
	    (let ((ch (read-char port)))
	      (if (eof-object? ch)
		  (%error-invalid-time-zone-number ch)
		(set! offset (+ offset (* (%char->int ch) 10 60)))))
	    (let ((ch (read-char port)))
	      (if (eof-object? ch)
		  (%error-invalid-time-zone-number ch)
		(set! offset (+ offset (* (%char->int ch) 60)))))
	    (if positive?
		offset
	      (- offset)))))))

  (define (%locale-reader port indexer)
    ;;Looking at a char, read the  char string, run thru indexer, return
    ;;index.
    ;;
    (let ((string-port (open-output-string)))
      (define (read-char-string)
	(let ((ch (peek-char port)))
	  (if (char-alphabetic? ch)
	      (begin
		(write-char (read-char port) string-port)
		(read-char-string))
	    (get-output-string string-port))))
      (let* ((str   (read-char-string))
	     (index (indexer str)))
	(or index
	    (error who "bad date template string")))))


  (define (%error-bad-template template-string)
    (error who "bad date format string" template-string))

  (define (%error-invalid-time-zone-number ch)
    (error who "bad date template string, invalid time zone number" ch))

  (define (%error-invalid-time-zone-pm ch)
    (error who "bad date template string, invalid time zone +/-" ch))

  (define %READ-DIRECTIVES
    ;;A List of formatted read directives.  Each entry is a list.
    ;;
    ;;1. The character  directive; a procedure, which  takes a character
    ;;   as input & returns.
    ;;
    ;;2. #t as soon  as a character on the input  port is acceptable for
    ;;   input.
    ;;
    ;;3. A port reader procedure that knows how to read the current port
    ;;   for a value. Its one parameter is the port.
    ;;
    ;;4. A  action procedure, that takes  the value (from 3.)   and some
    ;;   object (here, always the  date) and (probably) side-effects it.
    ;;   In some cases (e.g., ~A) the action is to do nothing.
    ;;
    (let ((ireader4		(%make-integer-reader 4))
	  (ireader2		(%make-integer-reader 2))
	  (fireader9		(%make-fractional-integer-reader 9))
	  (ireaderf		(%make-integer-reader #f))
	  (eireader2		(%make-integer-exact-reader 2))
	  (eireader4		(%make-integer-exact-reader 4))
	  (locale-reader-abbr-weekday (%make-locale-reader %locale-abbr-weekday->index))
	  (locale-reader-long-weekday (%make-locale-reader %locale-long-weekday->index))
	  (locale-reader-abbr-month   (%make-locale-reader %locale-abbr-month->index))
	  (locale-reader-long-month   (%make-locale-reader %locale-long-month->index))
	  (char-fail		(lambda (ch) #t))
	  (do-nothing		(lambda (val object) (values))))
      (list
       (list #\~ char-fail (%make-char-id-reader #\~) do-nothing)
       (list #\a char-alphabetic? locale-reader-abbr-weekday do-nothing)
       (list #\A char-alphabetic? locale-reader-long-weekday do-nothing)
       (list #\b char-alphabetic? locale-reader-abbr-month
	     (lambda (val object)
	       ($set-date-month! object val)))
       (list #\B char-alphabetic? locale-reader-long-month
	     (lambda (val object)
	       ($set-date-month! object val)))
       (list #\d char-numeric? ireader2 (lambda (val object)
					  ($set-date-day!
					   object val)))
       (list #\e char-fail eireader2 (lambda (val object)
				       ($set-date-day! object val)))
       (list #\h char-alphabetic? locale-reader-abbr-month
	     (lambda (val object)
	       ($set-date-month! object val)))
       (list #\H char-numeric? ireader2 (lambda (val object)
					  ($set-date-hour! object val)))
       (list #\k char-fail eireader2 (lambda (val object)
				       ($set-date-hour! object val)))
       (list #\m char-numeric? ireader2 (lambda (val object)
					  ($set-date-month! object val)))
       (list #\M char-numeric? ireader2 (lambda (val object)
					  ($set-date-minute!
					   object val)))
       (list #\N char-numeric? fireader9 (lambda (val object)
					   ($set-date-nanosecond! object val)))
       (list #\S char-numeric? ireader2 (lambda (val object)
					  ($set-date-second! object val)))
       (list #\y char-fail eireader2
	     (lambda (val object)
	       ($set-date-year! object (%natural-year val))))
       (list #\Y char-numeric? ireader4 (lambda (val object)
					  ($set-date-year! object val)))
       (list #\z (lambda (c)
		   (or (char=? c #\Z)
		       (char=? c #\z)
		       (char=? c #\+)
		       (char=? c #\-)))
	     %zone-reader (lambda (val object)
			      ($set-date-zone-offset! object val)))
       )))

  #| end of module |# )


;;;; date to string

(module (date->string)
  (define who 'date->string)

  (define date->string
    (case-lambda
     ((date)
      (date->string date "~c"))
     ((date format-string)
      (with-arguments-validation (who)
	  ((date	date)
	   (string	format-string))
	(receive (port getter)
	    (open-string-output-port)
	  (%date-printer date 0 format-string ($string-length format-string) port)
	  (getter))))))

  (define (%date-printer date index format-string str.len port)
    (unless (>= index str.len)
      (let ((current-char ($string-ref format-string index)))
	(if (not ($char= current-char #\~))
	    (begin
	      (display current-char port)
	      (%date-printer date (+ index 1) format-string str.len port))
	  (if (= (+ index 1) str.len)
	      (%error-bad-template format-string)
	    (let ((pad-char? (string-ref format-string (+ index 1))))
	      (case-chars pad-char?
		((#\-)
		 (if (= (+ index 2) str.len)
		     (%error-bad-template format-string)
		   (let ((formatter (%get-formatter (string-ref format-string (+ index 2)))))
		     (if (not formatter)
			 (%error-bad-template format-string)
		       (begin
			 (formatter date #f port)
			 (%date-printer date (+ index 3) format-string str.len port))))))

		((#\_)
		 (if (= (+ index 2) str.len)
		     (%error-bad-template format-string)
		   (let ((formatter (%get-formatter (string-ref format-string (+ index 2)))))
		     (if (not formatter)
			 (%error-bad-template format-string)
		       (begin
			 (formatter date #\space port)
			 (%date-printer date (+ index 3) format-string str.len port))))))

		(else
		 (let ((formatter (%get-formatter (string-ref format-string (+ index 1)))))
		   (if (not formatter)
		       (%error-bad-template format-string)
		     (begin
		       (formatter date #\0 port)
		       (%date-printer date (+ index 2) format-string str.len port))))))))))))

  (define (%get-formatter char)
    (let ((associated (assoc char %DIRECTIVES)))
      (if associated (cdr associated) #f)))

  (define %DIRECTIVES
    ;;A table  of output formatting  directives.  The first time  is the
    ;;format char.   The second is  a procedure  that takes the  date, a
    ;;padding character (which might be #f), and the output port.
    ;;
    (list
     (cons #\~ (lambda (date pad-with port) (display #\~ port)))

     (cons #\a (lambda (date pad-with port)
		 (display (%locale-abbr-weekday (date-week-day date))
			  port)))
     (cons #\A (lambda (date pad-with port)
		 (display (%locale-long-weekday (date-week-day date))
			  port)))
     (cons #\b (lambda (date pad-with port)
		 (display (%locale-abbr-month (date-month date))
			  port)))
     (cons #\B (lambda (date pad-with port)
		 (display (%locale-long-month (date-month date))
			  port)))
     (cons #\c (lambda (date pad-with port)
		 (display (date->string date LOCALE-DATE-TIME-FORMAT) port)))
     (cons #\d (lambda (date pad-with port)
		 (display (%padding (date-day date)
				    #\0 2)
			  port)))
     (cons #\D (lambda (date pad-with port)
		 (display (date->string date "~m/~d/~y") port)))
     (cons #\e (lambda (date pad-with port)
		 (display (%padding (date-day date)
				    #\space 2)
			  port)))
     (cons #\f (lambda (date pad-with port)
		 (if (> (date-nanosecond date)
			NUMBER-OF-NANOSECONDS-IN-A-SECOND)
		     (display (%padding (+ (date-second date) 1)
					pad-with 2)
			      port)
		   (display (%padding (date-second date)
				      pad-with 2)
			    port))
		 (display LOCALE-NUMBER-SEPARATOR port)
		 (display (%fractional-part (/ (date-nanosecond date)
						 NUMBER-OF-NANOSECONDS-IN-A-SECOND))
			  port)))
     (cons #\h (lambda (date pad-with port)
		 (display (date->string date "~b") port)))
     (cons #\H (lambda (date pad-with port)
		 (display (%padding (date-hour date)
				    pad-with 2)
			  port)))
     (cons #\I (lambda (date pad-with port)
		 (let ((hr (date-hour date)))
		   (if (> hr 12)
		       (display (%padding (- hr 12)
					  pad-with 2)
				port)
		     (display (%padding hr
					pad-with 2)
			      port)))))
     (cons #\j (lambda (date pad-with port)
		 (display (%padding (date-year-day date)
				    pad-with 3)
			  port)))
     (cons #\k (lambda (date pad-with port)
		 (display (%padding (date-hour date)
				    #\0 2)
			  port)))
     (cons #\l (lambda (date pad-with port)
		 (let ((hr (if (> (date-hour date) 12)
			       (- (date-hour date) 12) (date-hour date))))
		   (display (%padding hr  #\space 2)
			    port))))
     (cons #\m (lambda (date pad-with port)
		 (display (%padding (date-month date)
				    pad-with 2)
			  port)))
     (cons #\M (lambda (date pad-with port)
		 (display (%padding (date-minute date)
				    pad-with 2)
			  port)))
     (cons #\n (lambda (date pad-with port)
		 (newline port)))
     (cons #\N (lambda (date pad-with port)
		 (display (%padding (date-nanosecond date)
				    pad-with 9)
			  port)))
     (cons #\p (lambda (date pad-with port)
		 (display (%locale-am/pm (date-hour date)) port)))
     (cons #\r (lambda (date pad-with port)
		 (display (date->string date "~I:~M:~S ~p") port)))
     (cons #\s (lambda (date pad-with port)
		 (display (time-second (date->time-utc date)) port)))
     (cons #\S (lambda (date pad-with port)
		 (if (> (date-nanosecond date)
			NUMBER-OF-NANOSECONDS-IN-A-SECOND)
		     (display (%padding (+ (date-second date) 1)
					pad-with 2)
			      port)
                   (display (%padding (date-second date)
				      pad-with 2)
                            port))))
     (cons #\t (lambda (date pad-with port)
		 (display (integer->char 9) port)))
     (cons #\T (lambda (date pad-with port)
		 (display (date->string date "~H:~M:~S") port)))
     (cons #\U (lambda (date pad-with port)
		 (if (> (%days-before-first-week date 0) 0)
		     (display (%padding (+ (date-week-number date 0) 1)
					#\0 2) port)
		   (display (%padding (date-week-number date 0)
				      #\0 2) port))))
     (cons #\V (lambda (date pad-with port)
		 (display (%padding (date-week-number date 1)
				    #\0 2) port)))
     (cons #\w (lambda (date pad-with port)
		 (display (date-week-day date) port)))
     (cons #\x (lambda (date pad-with port)
		 (display (date->string date LOCALE-SHORT-DATE-FORMAT) port)))
     (cons #\X (lambda (date pad-with port)
		 (display (date->string date LOCALE-TIME-FORMAT) port)))
     (cons #\W (lambda (date pad-with port)
		 (if (> (%days-before-first-week date 1) 0)
		     (display (%padding (+ (date-week-number date 1) 1)
					#\0 2) port)
		   (display (%padding (date-week-number date 1)
				      #\0 2) port))))
     (cons #\y (lambda (date pad-with port)
		 (display (%padding (%last-n-digits (date-year date) 2)
				    pad-with 2)
			  port)))
     (cons #\Y (lambda (date pad-with port)
		 (display (%padding (date-year date) pad-with 4) port)))
     (cons #\z (lambda (date pad-with port)
		 (%tz-printer (date-zone-offset date) port)))
     (cons #\Z (lambda (date pad-with port)
		 (%locale-print-time-zone date port)))
     (cons #\1 (lambda (date pad-with port)
		 (display (date->string date "~Y-~m-~d") port)))
     (cons #\2 (lambda (date pad-with port)
		 (display (date->string date "~k:~M:~S~z") port)))
     (cons #\3 (lambda (date pad-with port)
		 (display (date->string date "~k:~M:~S") port)))
     (cons #\4 (lambda (date pad-with port)
		 (display (date->string date "~Y-~m-~dT~k:~M:~S~z") port)))
     (cons #\5 (lambda (date pad-with port)
		 (display (date->string date "~Y-~m-~dT~k:~M:~S") port)))
     ))

  (define (%padding n pad-with length)
    ;;Returns a string rep. of number  N, of minimum LENGTH, padded with
    ;;character PAD-WITH.  If PAD-WITH  if #f, no  padding is  done, and
    ;;it's  as if  number->string was  used.  if  string is  longer than
    ;;LENGTH, it's as if number->string was used.
    ;;
    (let* ((str     (number->string n))
	   (str-len (string-length str)))
      (if (or (> str-len length)
	      (not pad-with))
	  str
	(let* ((new-str        (make-string length pad-with))
	       (new-str-offset (- (string-length new-str) str-len)))
	  (do ((i 0 (+ i 1)))
	      ((>= i (string-length str)))
            (string-set! new-str (+ new-str-offset i) (string-ref str i)))
	  new-str))))

  (define (%fractional-part r)
    (if (integer? r)
	"0"
      (let* ((str  (number->string (exact->inexact r)))
	     (ppos (%char-pos #\. str 0 (string-length str))))
	(substring str (+ ppos 1) (string-length str)))))

  (define (%char-pos char str index len)
    (cond ((>= index len)
	   #f)
	  ((char=? (string-ref str index) char)
	   index)
	  (else
	   (%char-pos char str (+ index 1) len))))

  (define (%tz-printer offset port)
    (cond ((= offset 0)
	   (display "Z" port))
	  ((negative? offset)
	   (display "-" port))
	  (else
	   (display "+" port)))
    (unless (= offset 0)
      (let ((hours   (abs (quotient offset (* 60 60))))
	    (minutes (abs (quotient (remainder offset (* 60 60)) 60))))
	(display (%padding hours #\0 2)   port)
	(display (%padding minutes #\0 2) port))))

  (define (%locale-print-time-zone date port)
    ;;FIXME We should print something here.
    ;;
    (values))

  (define (%locale-am/pm hr)
    (if (> hr 11)
	LOCALE-PM
      LOCALE-AM))

  (define (%last-n-digits i n)
    (abs (remainder i (expt 10 n))))

  (define (%error-bad-template format-string)
    (error who "bad date format string" format-string))

  #| end of module |# )


;;;; done

)

;;; end of file

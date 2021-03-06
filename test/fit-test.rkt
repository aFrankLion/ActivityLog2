#lang racket/base

;; This file is part of ActivityLog2, an fitness activity tracker
;; Copyright (C) 2018, 2019, 2020 Alex Harsányi <AlexHarsanyi@gmail.com>
;;
;; This program is free software: you can redistribute it and/or modify it
;; under the terms of the GNU General Public License as published by the Free
;; Software Foundation, either version 3 of the License, or (at your option)
;; any later version.
;;
;; This program is distributed in the hope that it will be useful, but WITHOUT
;; ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
;; FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
;; more details.

;;;; Commentary

;; This code tests that the application can import correctly a variety of FIT
;; files and that session data frames can be created from them with the
;; correct data.  The FIT files are a collection of various "oddities" with
;; faulty data and unusual data plus files containing XDATA series.  It
;; requires fit files to be present in the `test-fit` folder, these are
;; downloaded by the `.travis/download-test-data.sh` script.

(require racket/format
         rackunit
         db
         "test-util.rkt"
         data-frame
         "../rkt/session-df/session-df.rkt"
         "../rkt/session-df/series-metadata.rkt"
         "../rkt/session-df/native-series.rkt"
         "../rkt/weather.rkt"
         "../rkt/database.rkt"
         "../rkt/utilities.rkt"
         "../rkt/fit-file/activity-util.rkt"
         "custom-test-runner.rkt")

(define (do-basic-checks file series-count row-count
                         #:expected-session-count (expected-session-count 1)
                         #:extra-db-checks (extra-db-checks #f)
                         #:extra-df-checks (extra-df-checks #f))

  (unless (file-exists? file)
    (skip-test))

  (dbglog "File ~a, ~a data-points ..." file row-count)
  ;; Simple consistency check: if we expect more than one session,
  ;; SERIES-COUNT and ROW-COUNT should be lists, one for each series.
  (check-true (if (number? series-count)
                  (= expected-session-count 1)
                  (= expected-session-count (length series-count))))
  (check-true (if (number? row-count)
                  (= expected-session-count 1)
                  (= expected-session-count (length row-count))))
  (with-fresh-database
    (lambda (db)
      (db-import-activity-from-file/check
       file db
       #:expected-session-count expected-session-count
       #:expected-row-count row-count
       #:expected-series-count series-count
       #:extra-db-checks extra-db-checks
       #:extra-df-checks extra-df-checks
       #:delete-sessions? #t))))

(define (do-multi-checks files
                         #:extra-db-checks (extra-db-checks #f))
  (unless (for/and ([f (in-list files)]) (file-exists? f))
    (skip-test))

  (dbglog "File multi-checks on ~a ..." files)
  (with-fresh-database
    (lambda (db)
      (for ([f (in-list files)])
        (db-import-activity-from-file f db))
      (when extra-db-checks
        (extra-db-checks db)))))

(define (check-run-power df)
  (when (equal? (df-get-property df 'sport #f) #(1 #f))
    (check-true (df-contains? df "pwr"))
    #;(df-describe df)
    ))

(define (check-xdata-app-count db n)
  (check = n (query-value db "select count(*) from XDATA_APP")
         "xdata app count"))

(define (check-xdata-app-present db app-guid)
  (check = 1 (query-value db "select count(*) from XDATA_APP where app_guid = ?" app-guid)
         (format "xdata app present: ~a" app-guid)))

(define (check-xdata-field-count db app-id n)
  (check = n (query-value db "select count(*) from XDATA_FIELD where app_id = (select id from XDATA_APP where app_guid = ?)" app-id)
         "xdata field count"))

(define (check-xdata-field-present db app-guid field-name)
  (check = 1 (query-value db "
select count(*)
from XDATA_FIELD XF, XDATA_APP XA
where XA.app_guid = ?
  and XF.app_id = XA.id
and XF.name = ?" app-guid field-name)
         (format "xdata field present, app ~a, field ~a" app-guid field-name)))

(define (check-xdata-trackpoint-values db app-guid field-name)
  (check < 0 (query-value db "
select count(*)
 from XDATA_VALUE XV, XDATA_FIELD XF, XDATA_APP XA
 where XV.field_id = XF.id and XF.app_id = XA.id
   and XA.app_guid = ?
   and XF.name = ?"
                          app-guid field-name)
         (format "xdata-has-trackpoint-values app ~a, field ~a" app-guid field-name)))

(define (check-xdata-summary-values db app-guid field-name)
  (check < 0 (query-value db "
select count(*)
 from XDATA_SUMMARY_VALUE XSV, XDATA_FIELD XF, XDATA_APP XA
 where XSV.field_id = XF.id and XF.app_id = XA.id
   and XA.app_guid = ?
   and XF.name = ?"
                          app-guid field-name)
         (format "xdata-has-summary-values app ~a, field ~a" app-guid field-name)))


(define (check-stryd-xdata db)
  (define app-id "660a581e5301460c8f2f034c8b6dc90f")
  ;; (check-xdata-app-count db 1)
  (check-xdata-app-present db app-id)
  (check-xdata-field-count db app-id 7)
  (for ([field '("Leg Spring Stiffness"
                 "Form Power" "Elevation" "Vertical Oscillation"
                 "Ground Time" "Cadence" "Power")])
    (check-xdata-field-present db app-id field))

  (for ([field '("Leg Spring Stiffness"
                 "Form Power" "Elevation" "Vertical Oscillation"
                 "Ground Time" "Cadence" "Power")])
    (check-xdata-trackpoint-values db app-id field)))

(define (check-garmin-run-power-data db)
  (define app-id "741afa11025048e286b514bd47e29391")
  (check-xdata-app-count db 1)
  (check-xdata-app-present db app-id)
  (check-xdata-field-count db app-id 5)
  ;; NOTE: the RP_SD field is an array of 5 values, see issue #42, we
  ;; currently discard this field, as it is unclear what to do with it.
  (for ([field '("RP_SD" "RP_WindEnabled" "RP_AvgPower" "RP_AvgLapPower" "RP_Power")])
    (check-xdata-field-present db app-id field))
  (check-xdata-trackpoint-values db app-id "RP_Power"))

(define (check-outdoorsports-xdata db)
  (check-xdata-app-count db 1)
  (check-xdata-app-present db "27dfb7e5900f4c2d80abc57015f42124")
  (check-xdata-field-count db "27dfb7e5900f4c2d80abc57015f42124" 9)
  (check-xdata-field-present db "27dfb7e5900f4c2d80abc57015f42124" "total_caloriesAV")
  (check-xdata-field-present db "27dfb7e5900f4c2d80abc57015f42124" "total_calories")
  (check-xdata-field-present db "27dfb7e5900f4c2d80abc57015f42124" "BatteryUsed")
  (check-xdata-field-present db "27dfb7e5900f4c2d80abc57015f42124" "avg_cadence")
  (check-xdata-field-present db "27dfb7e5900f4c2d80abc57015f42124" "Time")
  (check-xdata-field-present db "27dfb7e5900f4c2d80abc57015f42124" "Latitude")
  (check-xdata-field-present db "27dfb7e5900f4c2d80abc57015f42124" "Longitude")
  (check-xdata-field-present db "27dfb7e5900f4c2d80abc57015f42124" "eE")
  (check-xdata-field-present db "27dfb7e5900f4c2d80abc57015f42124" "StrideDistance")

  (check-xdata-trackpoint-values
   db "27dfb7e5900f4c2d80abc57015f42124" "eE")
  (check-xdata-trackpoint-values
   db "27dfb7e5900f4c2d80abc57015f42124" "StrideDistance")

  (check-xdata-summary-values
   db "27dfb7e5900f4c2d80abc57015f42124" "total_caloriesAV")
  (check-xdata-summary-values
   db "27dfb7e5900f4c2d80abc57015f42124" "total_calories")
  (check-xdata-summary-values
   db "27dfb7e5900f4c2d80abc57015f42124" "BatteryUsed")
  (check-xdata-summary-values
   db "27dfb7e5900f4c2d80abc57015f42124" "avg_cadence")
  (check-xdata-summary-values
   db "27dfb7e5900f4c2d80abc57015f42124" "Time")
  )

(define fit-files-test-suite
  (test-suite
   "FIT file reading"
   (test-case "f0001.fit"
     (do-basic-checks "./test-fit/f0001.fit" 18 14035))
   (test-case "f0002.fit"
     (do-basic-checks "./test-fit/f0002.fit" 17 500))
   (test-case "f0003.fit"
     (do-basic-checks "./test-fit/f0003.fit" 14 47))
   (test-case "f0004.fit"
     (do-basic-checks "./test-fit/f0004.fit" 18 138294))
   (test-case "f0005.fit"
     (do-basic-checks "./test-fit/f0005.fit" 13 227))
   (test-case "f0006.fit"
     (do-basic-checks "./test-fit/f0006.fit" 13 1297))
   (test-case "f0007.fit"
     (do-basic-checks "./test-fit/f0007.fit" 13 1452))
   (test-case "f0008.fit"
     (do-basic-checks "./test-fit/f0008.fit" 13 2331))
   (test-case "f0009.fit"
     (do-basic-checks "./test-fit/f0009.fit" 6 57))
   (test-case "f0010.fit"
     (do-basic-checks "./test-fit/f0010.fit" 19 8078))
   (test-case "f0011.fit"
     (do-basic-checks "./test-fit/f0011.fit" 12 39
                      #:extra-df-checks
                      (lambda (df)
                        (define stop-points (df-get-property df 'stop-points '()))
                        (check = (length stop-points) 2)
                        ;; Since this is a small data set, stop points are
                        ;; added to the data, instead of clearing existing
                        ;; points, we could also check that stop points are
                        ;; correctly added...
                        (define data (extract-data df axis-elapsed-time axis-speed 0 #f))
                        (check = (vector-length data) (+ (df-row-count df)
                                                         (* 2 (length stop-points))))
                        ;; The timer time axis does not mark stop points.
                        (define data2 (extract-data df axis-timer-time axis-speed 0 #f))
                        (check = (vector-length data2) (df-row-count df)))))
   (test-case "f0012.fit"
     (do-basic-checks "./test-fit/f0012.fit" 6 47))
   (test-case "f0013.fit"
     (do-basic-checks "./test-fit/f0013.fit" 18 8253))
   (test-case "f0014.fit"
     (do-basic-checks
      "./test-fit/f0014.fit" 20 155
      #:extra-db-checks
      (lambda (db)
        (check-xdata-app-count db 1)
        (check-xdata-app-present db "f848e2ecad564dbd8e36eaf0316d5ea3")
        (check-xdata-field-count db "f848e2ecad564dbd8e36eaf0316d5ea3" 1)
        (check-xdata-field-present db "f848e2ecad564dbd8e36eaf0316d5ea3" "current_wbal")
        )))
   (test-case "f0015.fit"
     (do-basic-checks
      "./test-fit/f0015.fit" 22 4057
      #:extra-db-checks
      (lambda (db)
        (check-xdata-app-count db 2)
        (check-xdata-app-present db "f848e2ecad564dbd8e36eaf0316d5ea3")
        (check-xdata-app-present db "a7e5e2534392495ba0728883c92d7211")
        (check-xdata-field-count db "f848e2ecad564dbd8e36eaf0316d5ea3" 2)
        (check-xdata-field-count db "a7e5e2534392495ba0728883c92d7211" 2)
        (check-xdata-field-present db "f848e2ecad564dbd8e36eaf0316d5ea3" "current_wbal")
        (check-xdata-field-present db "f848e2ecad564dbd8e36eaf0316d5ea3" "current_wbal_min")
        (check-xdata-field-present db "a7e5e2534392495ba0728883c92d7211" "THb Sensor 188.000000 on L. Quad")
        (check-xdata-field-present db "a7e5e2534392495ba0728883c92d7211" "SmO2 Sensor 188.000000 on L. Quad")

        (check-xdata-trackpoint-values
         db "f848e2ecad564dbd8e36eaf0316d5ea3" "current_wbal")
        (check-xdata-trackpoint-values
         db "a7e5e2534392495ba0728883c92d7211" "THb Sensor 188.000000 on L. Quad")
        (check-xdata-trackpoint-values
         db "a7e5e2534392495ba0728883c92d7211" "SmO2 Sensor 188.000000 on L. Quad")
        (check-xdata-summary-values
         db "f848e2ecad564dbd8e36eaf0316d5ea3" "current_wbal_min")

        )))
   (test-case "f0016.fit"
     (do-basic-checks
      "./test-fit/f0016.fit" 27 2119
      #:extra-db-checks
      (lambda (db)
        (check-xdata-app-count db 1)
        (check-xdata-app-present db "00000000000000000000000000000000")
        (check-xdata-field-count db "00000000000000000000000000000000" 4)
        (check-xdata-field-present db "00000000000000000000000000000000" "Distance")
        (check-xdata-field-present db "00000000000000000000000000000000" "Speed")
        (check-xdata-field-present db "00000000000000000000000000000000" "Leg Spring Stiffness")
        (check-xdata-field-present db "00000000000000000000000000000000" "Form Power")

        (check-xdata-trackpoint-values
         db "00000000000000000000000000000000" "Distance")
        (check-xdata-trackpoint-values
         db "00000000000000000000000000000000" "Speed")
        (check-xdata-trackpoint-values
         db "00000000000000000000000000000000" "Leg Spring Stiffness")
        (check-xdata-trackpoint-values
         db "00000000000000000000000000000000" "Form Power")
        )
      #:extra-df-checks check-run-power))
   (test-case "f0017.fit"
     (do-basic-checks
      "./test-fit/f0017.fit" 18 3211
      #:extra-db-checks check-outdoorsports-xdata))
   (test-case "f0018.fit"
     (do-basic-checks
      "./test-fit/f0018.fit" '(16 16 37 16 30) '(583 30 10217 10 8612)
      #:extra-db-checks check-stryd-xdata
      #:expected-session-count 5))
   (test-case "f0019.fit"
     (do-basic-checks
      "./test-fit/f0019.fit" 24 4081
      #:extra-db-checks check-stryd-xdata))
   (test-case "f0022.fit"
     (do-basic-checks "./test-fit/f0022.fit" 13 1868))
   (test-case "f0023.fit"
     (do-basic-checks
      "./test-fit/f0023.fit" 24 2138
      #:extra-db-checks check-garmin-run-power-data))
   (test-case "f0025.fit"
     (do-basic-checks
      "./test-fit/f0025.fit" 27 2148
      #:extra-db-checks
      (lambda (db)
        (void)
        (check-stryd-xdata db)
        ;; Stryd Pace Application
        (define app-id "8e471b4dddf4481a9861d80f22113f9a")
        ;; (check-xdata-app-count db 1)
        (check-xdata-app-present db app-id)
        (check-xdata-field-count db app-id 8)
        (for ([field '("Instantaneous Speed" "Instantaneous Pace")])
          (check-xdata-field-present db app-id field))
        (for ([field '("Instantaneous Speed" "Instantaneous Pace")])
          (check-xdata-trackpoint-values db app-id field)))))
   (test-case "f0026.fit"
     (do-basic-checks
      "./test-fit/f0026.fit" 20 6098))
   (test-case "f0027.fit"
     (do-basic-checks
      "./test-fit/f0027.fit" 30 4948
      #:extra-df-checks
      (lambda (df)
        ;; These series were missing from the activities as they are provided
        ;; by "enhanced fields".  Check that they are present.
        (check-true (df-contains? df "spd"))
        (check-true (df-contains? df "alt")))))
   (test-case "f0028.fit"
     (do-basic-checks
      "./test-fit/f0028.fit" 23 941
      #:extra-df-checks
      (lambda (df)
        ;; These series were missing from the activities as they are provided
        ;; by "enhanced fields".  Check that they are present.
        (check-true (df-contains? df "spd"))
        (check-true (df-contains? df "alt")))))
   (test-case "f0029.fit"
     (do-basic-checks
      "./test-fit/f0029.fit" '(15 18 31 16 30) '(943 814 24062 330 19656)
      #:expected-session-count 5
      #:extra-db-checks
      (lambda (db)
        (check-xdata-app-count db 2)
        (check-xdata-app-present db "660a581e5301460c8f2f034c8b6dc90f")
        (check-xdata-app-present db "6dcfffe5cd3d41f38ba313fa0647b003")
        (check-xdata-field-count db "660a581e5301460c8f2f034c8b6dc90f" 7)
        (check-xdata-field-count db "6dcfffe5cd3d41f38ba313fa0647b003" 1)
        (check-xdata-field-present db "660a581e5301460c8f2f034c8b6dc90f" "Leg Spring Stiffness")
        (check-xdata-field-present db "660a581e5301460c8f2f034c8b6dc90f" "Form Power")
        (check-xdata-field-present db "660a581e5301460c8f2f034c8b6dc90f" "Elevation")
        (check-xdata-field-present db "660a581e5301460c8f2f034c8b6dc90f" "Vertical Oscillation")
        (check-xdata-field-present db "660a581e5301460c8f2f034c8b6dc90f" "Ground Time")
        (check-xdata-field-present db "660a581e5301460c8f2f034c8b6dc90f" "Cadence")
        (check-xdata-field-present db "660a581e5301460c8f2f034c8b6dc90f" "Power")
        (check-xdata-field-present db "6dcfffe5cd3d41f38ba313fa0647b003" "wprime_bal"))))
   (test-case "f0031.fit"
     (do-basic-checks
      "./test-fit/f0031.fit" 8 1798
      #:extra-db-checks
      (lambda (db)
        ;; Importing this activity required building a lap and summary
        ;; information.  Check that it is present.
        (define s (db-fetch-session 1 db))
        (define laps (session-laps s))
        (check = 1 (length laps))
        (define lap0 (car laps))
        (check-true
         (let ((x (lap-avg-cadence lap0)))
           (and (number? x) (> x 0))))
        (check-true
         (let ((x (lap-max-cadence lap0)))
           (and (number? x) (> x 0))))
        (check-true
         (let ((x (lap-avg-power lap0)))
           (and (number? x) (> x 0))))
        (check-true
         (let ((x (lap-max-power lap0)))
           (and (number? x) (> x 0))))
        (check-true
         (let ((x (lap-avg-hr lap0)))
           (and (number? x) (> x 0))))
        (check-true
         (let ((x (lap-max-hr lap0)))
           (and (number? x) (> x 0)))))))
   (test-case "f0032.fit"
     (do-basic-checks
      "./test-fit/f0032.fit" 18 1473))
   (test-case "multi-checks"
     (do-multi-checks
      ;; These two files contain data from the same XDATA app, the application
      ;; should only be recorded once...
      '("./test-fit/f0014.fit" "./test-fit/f0015.fit")
      #:extra-db-checks
      (lambda (db)
        (check-xdata-app-count db 2)
        (check-xdata-app-present db "f848e2ecad564dbd8e36eaf0316d5ea3")
        (check-xdata-app-present db "a7e5e2534392495ba0728883c92d7211")
        (check-xdata-field-count db "f848e2ecad564dbd8e36eaf0316d5ea3" 2)
        (check-xdata-field-count db "a7e5e2534392495ba0728883c92d7211" 2)
        (check-xdata-field-present db "f848e2ecad564dbd8e36eaf0316d5ea3" "current_wbal")
        (check-xdata-field-present db "f848e2ecad564dbd8e36eaf0316d5ea3" "current_wbal_min")
        (check-xdata-field-present db "a7e5e2534392495ba0728883c92d7211" "THb Sensor 188.000000 on L. Quad")
        (check-xdata-field-present db "a7e5e2534392495ba0728883c92d7211" "SmO2 Sensor 188.000000 on L. Quad"))))
     ))

(module+ test
  (set-allow-weather-download #f)        ; don't download weather for unit tests

  ;; when set to #t, dbglog output is sent to stdout, useful for debugging
  ;; purposes.
  (set-dbglog-to-standard-output #f)

  (run-tests #:package "fit-test"
             #:results-file "test-results/fit-test.xml"
             ;; #:only '(("FIT file reading" "f0029.fit"))
             fit-files-test-suite))


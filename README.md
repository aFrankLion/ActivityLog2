![Logo](img/logo/ActivityLog2.png)

The bike-trainer prototype is on a separate
branch
[https://github.com/alex-hhh/ActivityLog2/tree/bike-trainer](https://github.com/alex-hhh/ActivityLog2/tree/bike-trainer)

# ActivityLog2 - analyze data from swim, bike and run activities

[![Build Status](https://travis-ci.org/alex-hhh/ActivityLog2.svg?branch=master)](https://travis-ci.org/alex-hhh/ActivityLog2)

Import swim, bike and run and other activities from .FIT files.  Display
plots, scatter plots, histograms, maps and other views for activities.  Show
reports and trends from activity data and track equipment usage.

Download pre-built releases from
the [releases](https://github.com/alex-hhh/ActivityLog2/releases) page, or
see [doc/building.md](doc/building.md) for how to build your own.

<p align="center">
<img align="center" width="800" 
     alt="session view" 
     src="https://drive.google.com/uc?export=download&id=0B5h4XOdkim72VmxOOWhYeVN5TGs" />
</p>

## Features

* Import Run, Bike and Swim activities from FIT files (as generated by Garmin
  devices, and others)
* Show data charts, histograms, scatter plots, best-average plots
* Show GPS track on a map, with several map tile styles
* Show hill climbs and best sections (e.g. best 5k, best 20 min power)
* Elevation correction (see [Notes](./doc/elevation-correction.md))
* Show weather information for sessions with GPS data
* Fix recording errors in swim activities (merge or split lengths, fix stroke
  type)
* Export data as CSV for analyzing it with other tools
* Export settings sport zones to the device
* Show trend plots and reports
* Track equipment usage and service reminders (e.g. replace running shoes or
  service the bike).
* Shows firmware version and battery voltage for all sensors (e.g HRM or Bike
  Cadence sensor), displays a warning on low battery.
* Track body weight, and other metrics
* Estimate [Critical Power](./doc/critical-power.md)
* Generate workout files for downloading to the Garmin device (requires Racket
  experience)


## License

This program is free software: you can redistribute it and/or modify it under
the terms of the GNU General Public License as published by the Free Software
Foundation, either version 3 of the License, or (at your option) any later
version.

This program is distributed in the hope that it will be useful, but WITHOUT
ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
details.

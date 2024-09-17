# Demo code for the wlBurst v2 library

## Overview

This is demo code intended to be used with the wlBurst v2 library.

The wlBurst_v2 library provides Matlab scripts for identifying and
characterizing transient oscillations ("oscillatory bursts") in local field
potential neural signals (the low-frequency aggregate activity of many
neurons).

This project includes the development tree for the demo; the demo itself
will eventually be migrated to a sample code folder within the wlBurst v2
project.

## Documentation

### Running The Demo

To use this demo:

* Make sure Field Trip is installed and in your Matlab search path.
* Make sure the wlBurst_v2 library is installed and in your Matlab search
path.
* If desired, edit the configuration variables at the top of the demo
script.
* Run the demo code (in the `demo` folder) to generate burst analysis plots
of the example data.
* If desired, modify the demo code to do additional analyses.

### What the Burst Library Does

The wlBurst_v2 library detects and analyses LFP oscillations by performing
the following steps:

* The data is band-pass filtered.
* The desired detection feature is extracted (magnitude, for the demo).
  When magnitude is above-threshold, a burst is detected.
* Two thresholds are tested: a high threshold (detecting whether an event
  is present) and a low threshold (detecting where the event starts and
  ends).
* A list of event locations is built using the threshold output.
* For each event, a curve fit is performed to get the amplitude envelope
  and frequency of the oscillatory burst.
* The event list is annotated with the curve fit information.
* The user defines time bins, and the number of events in each time bin in
  each trial is counted.
* The average across trials of these burst rates and the standard error are
  estimated, giving average burst rates as a function of time.
* The user can ask the library to generate phase-shuffled surrogate data and
  run the same analysis on that. This gives an estimate of the background
  detection rate (false positives).

For an overview of how to do these things using the wlBurst_v2 library, see
the sample code in the wlBurst_v2 project, and the demo code here.

For a detailed description of the functions offered by the library, and a
more detailed discussion of the detection algorithm, see the library
reference and user guide in the ``manual`` folder in the wlBurst_v2 project.

### What the Demo Does

The demo code performs the following steps:

* It picks a dataset. To choose a different dataset, set the appropriate
configuration variable
* It picks a starting threshold (2 sigma).
* It runs a detection for each band, plotting burst rate as a function of
band. This is intended to let you pick the band that has the most burst
activity (highest above the false positive background).
* Once a band is picked, it runs a detection for several different
threshold values. This is intended to let you adjust the threshold to
provide as many true detections and as few false detections as possible.
* Detection rate vs time in trial is plotted for the chosen band and
threshold.
* Optionally, detected events themselves are plotted, or are rendered using
Field Trip's data browser, or both.

## Folders

* `datasets-cooked` --
Field Trip data intended to be used by the demo script.
* `datasets-raw` --
Datasets from which the "cooked" datasets were derived.
* `demo` --
Scripts that are used for the demo.
* `development` --
Scripts that are not intended to be part of the demo.
* `slides` --
Slide deck for the 2024 demo presentation.

_(This is the end of the file.)_

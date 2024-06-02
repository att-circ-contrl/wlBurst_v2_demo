% wlBurst demo - Demo Script
% Written by Christopher Thomas.


%
% Library paths.
% You can set these manually here, or add them to your Matlab environment.

addpath('lib-fieldtrip');
addpath('lib-wlburst-v2');

wlAddPaths;




%
% Configuration that changes.


% Dataset to use.
% "wlburst" is short and has activity everywhere.
% "rfh" has strong alpha activity that ramps up after t=0.
% "nhp" is a single-channel non-human primate recording during a puzzle task.

dataset = 'wlburst';


% Band to use.
% The names are "Theta", "Alpha", "Beta", "Low Gamma", and "High Gamma".
% These are case-sensitive.

band = 'Beta';

% Whether or not to do a test sweep across all bands.
want_test_bands = true;


% Detection threshold to use.
% This is in standard deviations. The library natively uses dB, but there's
% a conversion function.
% Typical values are 2-3 sigma (6-10 dB).

threshold_sigma = 2.5;

% Whether or not to do a test sweep across all thresholds.
want_test_thresholds = true;

% Setting this "true" makes more informative plots but takes longer.
want_more_thresholds = false;


% This uses ft_databrowser to view events in trials with the artifact viewer.
want_browse_in_trials = false;


% This generates plots of events against the trial waveforms.
want_plot_trial_events = true;
want_plot_fewer_trials = true;

% This generates plots of detection thresholds within trials.
% It also plots individual events annotated with curve fits.
want_plot_threshold_debug = false;


% This uses bootstrapping instead of dev/sqrt(n) to estimate SEM.
want_bootstrap = false;

% This generates a larger number of surrogates for estimating background,
% instead of just generating one. This improves background accuracy.
want_surrogates = false;


% This emits progress messages while searching for bursts.
want_tattle_progress = false;

% Turn this off to force single-threaded operation. This can make debugging
% if it was stopping within a parallel function.
want_parallel = true;




%
% Configuration that usually doesn't change.


% Check to see if the Parallel Computing Toolbox is installed.
want_parallel = want_parallel & wlAux_checkParallelToolbox;


% Folders to read from and write to.

plotfolder = 'plots';
datafolder = [ '..' filesep 'datasets-cooked' ];


% The datasets, along with a bit of metadata.

datasetlist = struct( ...
  'fname', ...
    { 'ftdata_robinson.mat', 'ftdata_wlburst.mat', 'ftdata_york.mat' }, ...
  'varname', { 'ftdata_robinson', 'ftdata_wlburst', 'ftdata_york' }, ...
  'title', { 'RFH Synthetic', 'wlBurst Synthetic', 'York NHP' }, ...
  'label', { 'rfh', 'wlburst', 'nhp' } );

% Pick the dataset that was selected above.
scratch = { datasetlist.label };
if ~ismember( dataset, scratch )
  % Fall back to something valid.
  dataset = 'wlburst';
end
thisdataset = datasetlist( strcmp(dataset, scratch) );


% The bands, along with a bit of metadata.
% Alpha is normally 8-12 Hz, but we need it to be at least an octave wide
% for reasonable filter behavior.

bandlist = [ ...
  struct( 'band', [ 4 8 ],    'label', 'f1-th', 'name', 'Theta' ), ...
  struct( 'band', [ 7 14 ],   'label', 'f2-al', 'name', 'Alpha' ), ...
  struct( 'band', [ 12 30 ],  'label', 'f3-be', 'name', 'Beta' ), ...
  struct( 'band', [ 30 60 ],  'label', 'f4-gl', 'name', 'Low Gamma' ), ...
  struct( 'band', [ 60 120 ], 'label', 'f5-gh', 'name', 'High Gamma' ) ];

bandcount = length(bandlist);

% Pick the band that was selected above.
scratch = { bandlist.name };
if ~ismember( band, scratch )
  % Fall back to something valid.
  band = 'Beta';
end
thisband = bandlist( strcmp(band, scratch) );

% We want a Field Trip preprocessing config that isolates the chosen band.
% This is used for some of the plotting and visualization routines.
bandpassconfig = struct( 'bpfilter', 'yes', 'bpfreq', thisband.band, ...
  'bpinstabilityfix', 'split', 'feedback', 'no' );


% Threshold sweeping from 4 dB to 12 dB (1.5 to 4 sigma) worked well in tests.

% This is "1.5 to 4.0 in steps of 0.5".
threshold_sweep_sigma = 1.5:0.5:4;

if want_more_thresholds
  % Steps of 0.25 looks much nicer but takes twice as long.
  threshold_sweep_sigma = 1.5:0.25:4;
end

threshcount = length(threshold_sweep_sigma);


% Get native dB versions of the thresholds.

threshold_db = wlAux_sigmaTodB(threshold_sigma);
threshold_sweep_db = wlAux_sigmaTodB(threshold_sweep_sigma);


% Time bin size for time-varying rate analysis.
time_bin_ms = 100;


% Bootstrap count, for bootstrap statistics estimates.
% In my tests this had no advantage over dev/sqrt(n).
bootstrap_count = 1000;

% Override this if we don't want bootstrapping.
if ~want_bootstrap
  bootstrap_count = 'normal';
end


% Surrogate count. This is the number of phase-shuffled surrogates of the
% data to generate for background estimation.
% Setting this to 10 gives confidence intervals much tighter than the actual
% data based detection has, so there's not much advantage to going higher.
surrogate_count = 10;

% Override this if we don't want surrogates.
if ~want_surrogates
  surrogate_count = 1;
end


% Plotting decimation.

plot_max_per_band = inf;

plot_trial_stride = 1;
if want_plot_fewer_trials
  plot_trial_stride = 25;
end

plot_channel_stride = 1;

plot_event_stride = 1;


% Other plotting configuration.
% Mostly this is hints for rendering the power spectrum.
% See FIGCONFIG.txt in the burst library documentation for more information.

plotconfig = struct( 'fig', figure, 'outdir', plotfolder, ...
  'psfres', 5, 'psolap', 99, 'psleak', 0.75, 'psylim', 50 );


% Library-specific tuning parameters. The wlBurst documentation has more
% information about these.

% We're using two-threshold detection.
% We're using the DC average to get the baseline amplitude, rather than
% using a low-pass filter (the trials are too short; we get edge effects).
% We're ignoring any detection gaps one wavelength long or less.
% We're ignoring any detection _events_ one wavelength long or less.
% We're detecting the presence of an event based on our given threshold.
% We're detecting how far the event extends using a threshold of 2 dB
% (1.26 standard deviations).

segconfig = struct( 'type', 'magdual', ...
  'qlong', inf, 'qdrop', 1.0, 'qglitch', 1.0, ...
  'dbpeak', threshold_db, 'dbend', 2 );

% Event trimming at the ends of the detection range.
detecttrim_secs = 0.5;

% We're doing curve-fitting of the amplitude envelope using the "grid"
% algorithm. We're checking 5 points as starting/ending points.
paramconfig = struct( 'type', 'grid', 'gridsteps', 5 );


% Function handles for event pruning.
% These reject template fits that have an RMS error of 70% or more.

errorfunc = @(thisev, thiswave) ...
  wlProc_calcWaveErrorRelative( thiswave.bpfwave, thisev.sampstart, ...
    thisev.wave, thisev.s1 );

errorfield = 'fiterror';

prunepassfunc = @(thisev) (0.7 >= thisev.auxdata.(errorfield));


% Configuration for band-specific tuning parameters.
% We don't have any, so this is empty.

bandtuningsingle = struct( 'seg', struct(), 'param', struct() );

bandtuning = bandtuningsingle;
for bidx = 2:bandcount
  bandtuning(bidx) = bandtuningsingle;
end




%
% Setup.


evalc('ft_defaults');

ft_notice('off');
ft_info('off');
ft_warning('off');

if want_parallel
  % This takes about 30 seconds, so do it before we do timing measurements.
  parpool;
end




%
% Load the dataset.


disp([ '== Loading dataset "' thisdataset.title '".' ]);

load([ datafolder filesep thisdataset.fname ]);

% Copy the data to a consistently named variable.
ftdata = eval(thisdataset.varname);

chancount = length(ftdata.label);


% Build phase-shuffled surrogate data.

[ ftbackground trialmap ] = ...
  wlStats_makePhaseSurrogateFT( ftdata, surrogate_count );


% Build lists of time windows, now that we know how long the data trials are.

time_bins = wlFT_getTimeBinList( ftdata, time_bin_ms, 'edge' );
time_bins_single = wlFT_getTimeBinSingle;

wincount = length(time_bins);




%
% First pass: Plot activity vs band, to make sure we have in-band bursts.


if want_test_bands

disp('== Checking for burst activity by band.');



% Detection rate; this is true positives and false positives.

disp('.. Detecting bursts across all bands.');

tic;

% This gets the raw event lists, including poor fits.

if want_parallel
  thisdetect = wlFT_doFindEventsInTrials_MT( ...
    ftdata, bandlist, segconfig, paramconfig, ...
    bandtuning, want_tattle_progress );
else
  thisdetect = wlFT_doFindEventsInTrials( ...
    ftdata, bandlist, segconfig, paramconfig, ...
    bandtuning, want_tattle_progress );
end

% Drop events where the curve fit failed.
% This usually happens when it detected two bursts as one event.

thisdetect = wlFT_calcEventErrors( thisdetect, errorfunc, errorfield );
thisdetect = wlAux_pruneMatrix( thisdetect, prunepassfunc );

% Get burst rates.

[ rate_avg rate_dev rate_sem ] = wlStats_getMatrixBurstRates( ...
  thisdetect, time_bins_single, bootstrap_count );

durstring = helper_makePrettyTime(toc);
disp([ '.. Finished in ' durstring '.' ]);



% Background rate; this is just false positives.

disp('.. Evaluating background across all bands.');

tic;

% This gets the raw event lists, including poor fits.

if want_parallel
  thisbgdetect = wlFT_doFindEventsInTrials_MT( ...
    ftbackground, bandlist, segconfig, paramconfig, ...
    bandtuning, want_tattle_progress );
else
  thisbgdetect = wlFT_doFindEventsInTrials( ...
    ftbackground, bandlist, segconfig, paramconfig, ...
    bandtuning, want_tattle_progress );
end

% Drop events where the curve fit failed.
% This usually happens when it detected two bursts as one event.

thisbgdetect = wlFT_calcEventErrors( thisbgdetect, errorfunc, errorfield );
thisbgdetect = wlAux_pruneMatrix( thisbgdetect, prunepassfunc );

% Get burst rates.

[ bg_avg bg_dev bg_sem ] = wlStats_getMatrixBurstRates( ...
  thisbgdetect, time_bins_single, bootstrap_count );

durstring = helper_makePrettyTime(toc);
disp([ '.. Finished in ' durstring '.' ]);



% Generate plots of detection rates vs band.

wlPlot_plotMatrixBurstRates( plotconfig, ...
  rate_avg, rate_dev, rate_sem, bg_avg, bg_dev, bg_sem, ...
  time_bins_single, { bandlist.name }, { bandlist.label }, ftdata.label, ...
  sprintf( '%s Burst Rates By Band - %.1f sigma', ...
    thisdataset.title, threshold_sigma ), ...
  sprintf( '%s-vsband-%.1fsigma', thisdataset.label, threshold_sigma ) );


end  % if want_test_bands




%
% Second pass: In the chosen band, plot activity vs detection threshold.

% The goal is to find a threshold where we get many true positives and
% few false positives.


if want_test_thresholds

disp('== Checking different detection thresholds.');


% To aggregate the threshold sweep results, we're pretending that it's a
% sweep vs time. This lets us easily plot the results.


% Pre-allocate result variables so that they have the correct geometry.
% We're only using a single band for this.

scratch = nan([ 1 chancount threshcount ]);

rate_avg = scratch;
rate_dev = scratch;
rate_sem = scratch;

bg_avg = scratch;
bg_dev = scratch;
bg_sem = scratch;


% Detection rate; this is true positives and false positives.

disp('.. Detecting bursts using all thresholds.');

tic;

for thidx = 1:threshcount

  thisthresh = threshold_sweep_db(thidx);

  % Modify the detection parameters.
  segconfig.dbpeak = thisthresh;

  % This gets the raw event lists, including poor fits.
  if want_parallel
    thisdetect = wlFT_doFindEventsInTrials_MT( ...
      ftdata, thisband, segconfig, paramconfig, ...
      bandtuning, want_tattle_progress );
  else
    thisdetect = wlFT_doFindEventsInTrials( ...
      ftdata, thisband, segconfig, paramconfig, ...
      bandtuning, want_tattle_progress );
  end

  % Drop events where the curve fit failed.
  % This usually happens when it detected two bursts as one event.
  thisdetect = wlFT_calcEventErrors( thisdetect, errorfunc, errorfield );
  thisdetect = wlAux_pruneMatrix( thisdetect, prunepassfunc );

  % Get burst rates.
  [ scratch_avg scratch_dev scratch_sem ] = wlStats_getMatrixBurstRates( ...
    thisdetect, time_bins_single, bootstrap_count );

  % Add these to the aggregate.
  % We know that there was only one band and one time window.

  rate_avg(1,:,thidx) = scratch_avg(1,:,1);
  rate_dev(1,:,thidx) = scratch_dev(1,:,1);
  rate_sem(1,:,thidx) = scratch_sem(1,:,1);

end

% Restore the old detection threshold.
segconfig.dbpeak = threshold_db;

durstring = helper_makePrettyTime(toc);
disp([ '.. Finished in ' durstring '.' ]);



% Background rate; this is just false positives.

disp('.. Evaluating background using all thresholds.');

tic;

for thidx = 1:threshcount

  thisthresh = threshold_sweep_db(thidx);

  % Modify the detection parameters.
  segconfig.dbpeak = thisthresh;

  % This gets the raw event lists, including poor fits.
  if want_parallel
    thisbgdetect = wlFT_doFindEventsInTrials_MT( ...
      ftbackground, thisband, segconfig, paramconfig, ...
      bandtuning, want_tattle_progress );
  else
    thisbgdetect = wlFT_doFindEventsInTrials( ...
      ftbackground, thisband, segconfig, paramconfig, ...
      bandtuning, want_tattle_progress );
  end

  % Drop events where the curve fit failed.
  % This usually happens when it detected two bursts as one event.
  thisbgdetect = wlFT_calcEventErrors( thisbgdetect, errorfunc, errorfield );
  thisbgdetect = wlAux_pruneMatrix( thisbgdetect, prunepassfunc );

  % Get burst rates.
  [ scratch_avg scratch_dev scratch_sem ] = wlStats_getMatrixBurstRates( ...
    thisbgdetect, time_bins_single, bootstrap_count );

  % Add these to the aggregate.
  % We know that there was only one band and one time window.

  bg_avg(1,:,thidx) = scratch_avg(1,:,1);
  bg_dev(1,:,thidx) = scratch_dev(1,:,1);
  bg_sem(1,:,thidx) = scratch_sem(1,:,1);

end

% Restore the old detection threshold.
segconfig.dbpeak = threshold_db;

durstring = helper_makePrettyTime(toc);
disp([ '.. Finished in ' durstring '.' ]);



% Generate plots of detection rates vs threshold.

wlPlot_plotMatrixBurstRates( plotconfig, ...
  rate_avg, rate_dev, rate_sem, bg_avg, bg_dev, bg_sem, ...
  threshold_sweep_sigma, ...
  { thisband.name }, { thisband.label }, ftdata.label, ...
  sprintf( '%s Burst Rates By Threshold - %s', ...
    thisdataset.title, thisband.name ), ...
  sprintf( '%s-vsthresh-%s', thisdataset.label, thisband.label ), ...
  'Threshold (sigma)' );


end  % if want_test_thresholds




%
% Third pass: For the chosen band and threshold, plot activity vs time.

% For time-aligned trials, this should show changes in burst activity
% across different parts of the behavior task.


disp('== Measuring burst activity vs time.')



% Detection rate; this is true positives and false positives.

disp('.. Detecting bursts during all time windows.');

tic;

% This gets the raw event lists, including poor fits.

if want_parallel
  thisdetect = wlFT_doFindEventsInTrials_MT( ...
    ftdata, thisband, segconfig, paramconfig, ...
    bandtuning, want_tattle_progress );
else
  thisdetect = wlFT_doFindEventsInTrials( ...
    ftdata, thisband, segconfig, paramconfig, ...
    bandtuning, want_tattle_progress );
end

% Drop events where the curve fit failed.
% This usually happens when it detected two bursts as one event.

thisdetect = wlFT_calcEventErrors( thisdetect, errorfunc, errorfield );
thisdetect = wlAux_pruneMatrix( thisdetect, prunepassfunc );

% Get burst rates.

[ rate_avg rate_dev rate_sem ] = wlStats_getMatrixBurstRates( ...
  thisdetect, time_bins, bootstrap_count );

durstring = helper_makePrettyTime(toc);
disp([ '.. Finished in ' durstring '.' ]);



% Background rate; this is just false positives.

disp('.. Evaluating background during all time windows.');

tic;

% This gets the raw event lists, including poor fits.

if want_parallel
  thisbgdetect = wlFT_doFindEventsInTrials_MT( ...
    ftbackground, thisband, segconfig, paramconfig, ...
    bandtuning, want_tattle_progress );
else
  thisbgdetect = wlFT_doFindEventsInTrials( ...
    ftbackground, thisband, segconfig, paramconfig, ...
    bandtuning, want_tattle_progress );
end

% Drop events where the curve fit failed.
% This usually happens when it detected two bursts as one event.

thisbgdetect = wlFT_calcEventErrors( thisbgdetect, errorfunc, errorfield );
thisbgdetect = wlAux_pruneMatrix( thisbgdetect, prunepassfunc );

% Get burst rates.

[ bg_avg bg_dev bg_sem ] = wlStats_getMatrixBurstRates( ...
  thisbgdetect, time_bins, bootstrap_count );

durstring = helper_makePrettyTime(toc);
disp([ '.. Finished in ' durstring '.' ]);



% Generate plots of detection rates vs time.

wlPlot_plotMatrixBurstRates( plotconfig, ...
  rate_avg, rate_dev, rate_sem, bg_avg, bg_dev, bg_sem, ...
  time_bins, { thisband.name }, { thisband.label }, ftdata.label, ...
  sprintf( '%s Burst Rates vs Time - %s - %.1f sigma', ...
    thisdataset.title, thisband.name, threshold_sigma ), ...
  sprintf( '%s-vstime-%s-%.1fsigma', ...
    thisdataset.label, thisband.label, threshold_sigma ) );



% If we want to plot individual trials, or debugging info, do so.

if want_plot_trial_events || want_plot_threshold_debug

  disp('.. Plotting trials.');

  % We need a band-pass version of the trials for these plots.
  ftbandpass = ft_preprocessing( bandpassconfig, ftdata );

  if want_plot_trial_events
    wlPlot_plotAllMatrixEvents( plotconfig, thisdetect, ...
    sprintf( '%s Events - %s - %.1f sigma', ...
      thisdataset.title, thisband.name, threshold_sigma ), ...
    sprintf( '%s-events-%s-%.1fsigma', ...
      thisdataset.label, thisband.label, threshold_sigma ), ...
    plot_max_per_band, plot_trial_stride, plot_channel_stride );
  end

  if want_plot_threshold_debug
    wlPlot_plotAllMatrixEventsDebug( plotconfig, thisdetect, ...
    sprintf( '%s Events - %s - %.1f sigma', ...
      thisdataset.title, thisband.name, threshold_sigma ), ...
    sprintf( '%s-events-%s-%.1fsigma', ...
      thisdataset.label, thisband.label, threshold_sigma ), ...
    plot_max_per_band, plot_trial_stride, plot_channel_stride, ...
    plot_event_stride );
  end

  disp('.. Finished plotting trials.');
end


% If we want to browse the events visually, do so.

if want_browse_in_trials

  disp('.. Visualizing trials annotated with events.');

  % NOTE - Databrowser isn't auto-ranging reliably for some reason.
  thisyrange = helper_getTrialYrange( ftbandpass, {} );
  browserconfig = struct( 'ylim', thisyrange );

  % Use the event list to build a fake artifact annotation structure.
  artstruct = wlFT_getEventsAsArtifacts( thisdetect, ftdata.label );
  browserconfig.artfctdef = struct( 'wlburst', artstruct );

  % The browser can do band-pass filtering for us.
  browserconfig.preproc = bandpassconfig;

  % Call the browser.
  evalc( 'ft_databrowser( browserconfig, ftdata )' );

  disp('.. (press any key)');
  pause;

end




%
% Ending banner.

disp('== Done.');




%
% This is the end of the file.

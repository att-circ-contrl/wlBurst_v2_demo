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


% Detection threshold to use.
% This is in standard deviations. The library natively uses dB, but there's
% a conversion function.
% Typical values are 2-3 sigma (6-10 dB).

threshold_sigma = 2.5;


% This uses ft_databrowser to view events in trials with the artifact viewer.
want_browse_in_trials = true;


want_plot_trial_events = true;

want_plot_fewer_trials = true;

want_plot_threshold_debug = true;

want_plot_vs_band = true;

want_plot_vs_threshold = true;


% This uses bootstrapping instead of dev/sqrt(n) to estimate SEM.
want_bootstrap = false;

% This generates a larger number of surrogates for estimating background,
% instead of just generating one. This improves background accuracy.
want_surrogates = false;




%
% Configuration that usually doesn't change.


% Check to see if the Parallel Computing Toolbox is installed.
want_parallel = wlAux_checkParallelToolbox;


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
  struct( 'band', [ 4 8 ],    'label', '1-th', 'name', 'Theta' ), ...
  struct( 'band', [ 7 14 ],   'label', '2-al', 'name', 'Alpha' ), ...
  struct( 'band', [ 12 30 ],  'label', '3-be', 'name', 'Beta' ), ...
  struct( 'band', [ 30 60 ],  'label', '4-gl', 'name', 'Low Gamma' ), ...
  struct( 'band', [ 60 120 ], 'label', '5-gh', 'name', 'High Gamma' ) ];

% Pick the band that was selected above.
scratch = { bandlist.name };
if ~ismember( band, scratch )
  % Fall back to something valid.
  band = 'Beta';
end
thisband = bandlist( strcmp(band, scratch) );


% Threshold sweeping from 4 dB to 12 dB (1.5 to 4 sigma) worked well in tests.
% This is "1.5 to 4.0 in steps of 0.25".

threshold_sweep_sigma = 1.5:0.25:4;


% Get native dB versions of the thresholds.

threshold_db = wlAux_sigmaTodB(threshold_sigma);
threshold_sweep_db = wlAux_sigmaTodB(threshold_sweep_sigma);


% Time bin size for time-varying rate analysis.
rate_time_bin_ms = 100;


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


% Plotting decimation.

plot_trial_stride = 1;
if want_plot_fewer_trials
  plot_trial_stride = 25;
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
% This is the end of the file.

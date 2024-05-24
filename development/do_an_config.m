% wlBurst demo - Development scripts - Analysis - Configuration.
% Written by Christopher Thomas.


%
% Behavior switches.

want_sweep_thresh = false;
want_sweep_bands = false;
want_sweep_datasets = true;

want_bootstrap = false;
want_surrogates = false;

% This generates only one background surrogate and does bootstrapping,
% rather than generating many surrogates.
want_one_bg_surrogate = false;

want_tuned_thresholds = false;

want_parallel = true;

% This enables the wlBurst library's tattling.
want_tattle_progress = false;

% Indicate how, and if, to use ft_databrowser.
want_browse_bursts = false;
want_browse_in_trials = true;
want_browse_bandpass = false;


% Debugging switches.
debug_save_detected = true;


%
% General parameters.

% Using two different syntaxes for struct arrays, but this is the most
% readable way of doing each of these.

default_dataset = 'wlburst';

datasetpath = [ '..' filesep 'datasets-cooked' ];
datasetlist = struct( ...
  'fname', ...
    { 'ftdata_robinson.mat', 'ftdata_wlburst.mat', 'ftdata_york.mat' }, ...
  'vname', { 'ftdata_robinson', 'ftdata_wlburst', 'ftdata_york' }, ...
  'title', { 'RFH Synthetic', 'wlBurst Synthetic', 'York NHP' }, ...
  'label', { 'rfh', 'wlburst', 'york' } );

default_band = 'al';

bandlist = [ ...
  struct( 'band', [ 4 8 ],    'label', 'th', 'name', 'Theta' ), ...
  struct( 'band', [ 8 12 ],   'label', 'al', 'name', 'Alpha' ), ...
  struct( 'band', [ 12 30 ],  'label', 'be', 'name', 'Beta' ), ...
  struct( 'band', [ 30 60 ],  'label', 'gl', 'name', 'Low Gamma' ), ...
  struct( 'band', [ 60 120 ], 'label', 'gh', 'name', 'High Gamma' ) ];


%
% Tuning parameters.

% Giving this longer dropout paving (1.0) than in my other scripts (0.5).
segconfig = struct( 'type', 'magdual', ...
  'qlong', 10, 'qdrop', 1.0, 'qglitch', 1.0, ...
  'dbpeak', 10, 'dbend', 2 );

% Coarse grid envelope fitting is sufficient.
% FIXME - See if I can implement a "fast guess" method.
% Using a coarser grid (5) than in my other scripts (7).
paramconfig = struct( 'type', 'grid', 'gridsteps', 5 );

% Detection threshold tested for plots of detection vs threshold.
detsweepthresholds = 4:16;

% Selected thresholds per-band.
tunedthresholds = struct( 'th', 8, 'al', 12, 'be', 12, 'gl', 8, 'gh', 9 );

% Event trimming at the ends of the detection range.
detecttrimsecs = 0.5;


%
% Statistics evaluation.

bootstrap_count = 1000;
surrogate_count = 1000;


%
% This is the end of the file.

% wlBurst demo - Development scripts - Analysis - Configuration.
% Written by Christopher Thomas.


%
% Behavior switches.


want_sweep_thresh = true;
want_sweep_bands = true;
want_sweep_datasets = false;

% Bootstrapping doesn't seem to change SEM, vs dev/sqrt(n) estimation.
want_bootstrap = false;
want_surrogates = false;


% This generates only one background surrogate and does bootstrapping,
% rather than generating many surrogates.
want_one_bg_surrogate = false;

want_tuned_thresholds = false;
want_adaptive_threshold = false;


want_parallel = true;

% This enables the wlBurst library's tattling.
want_tattle_progress = false;


% Set up event plotting.

want_plot_trial_events = false;
want_plot_event_thresholds = false;

want_plot_trials_all = false;
want_plot_events_all = false;

want_plot_rates = true;


% Set up analysis plots.

want_plot_ratevstime = true;
want_plot_ratevsband = true;

% For evaluating rate vs band, this determines what time interval we use.
%plot_ratevsband_window = 'window';
%plot_ratevsband_window = 'positive';
plot_ratevsband_window = 'all';


% Indicate how, and if, to use ft_databrowser.
% Detected bursts as individual events with BPF and optional WB context.

want_browse_bursts = false;
want_browse_burst_wb = false;

% Original trials (WB or BPF) with bursts annotated as artifacts.
want_browse_in_trials = false;
want_browse_trial_bandpass = true;


% Debugging switches.

debug_save_detected = false;



%
% General parameters.

% Using two different syntaxes for struct arrays, but this is the most
% readable way of doing each of these.

%default_dataset = 'rfh';
default_dataset = 'wlburst';
%default_dataset = 'york';

%default_band = 'Alpha';
default_band = 'Beta';
%default_band = 'Low Gamma';


datasetpath = [ '..' filesep 'datasets-cooked' ];
datasetlist = struct( ...
  'fname', ...
    { 'ftdata_robinson.mat', 'ftdata_wlburst.mat', 'ftdata_york.mat' }, ...
  'vname', { 'ftdata_robinson', 'ftdata_wlburst', 'ftdata_york' }, ...
  'title', { 'RFH Synthetic', 'wlBurst Synthetic', 'York NHP' }, ...
  'label', { 'rfh', 'wlburst', 'york' } );


% NOTE - Alpha is normally 8-12 Hz, but we need it to be at least an
% octave wide for reasonable filter behavior.

% NOTE - Prepending digits to band labels, so that they're in order when
% sorted by filename.

bandlist = [ ...
  struct( 'band', [ 4 8 ],    'label', '1-th', 'name', 'Theta' ), ...
  struct( 'band', [ 7 14 ],   'label', '2-al', 'name', 'Alpha' ), ...
  struct( 'band', [ 12 30 ],  'label', '3-be', 'name', 'Beta' ), ...
  struct( 'band', [ 30 60 ],  'label', '4-gl', 'name', 'Low Gamma' ), ...
  struct( 'band', [ 60 120 ], 'label', '5-gh', 'name', 'High Gamma' ) ];

if ~want_sweep_bands
  scratch = { bandlist.name };
  bandlist = bandlist( strcmp(scratch, default_band) );
end


%
% Tuning parameters.

% Detection threshold tested for plots of detection vs threshold.
detsweepthresholds = 4:12;

% Default threshold.
% 4 sigma is 12.0 dB, 3 sigma is 9.5 dB, 2 sigma is 6.0 dB.
%fixedthreshold = 10.0;
fixedthreshold = 6.0;

% Selected thresholds per-band.
tunedthresholds = struct( 'th', 8, 'al', 12, 'be', 12, 'gl', 8, 'gh', 9 );

% Event trimming at the ends of the detection range.
detecttrimsecs = 0.5;

% Giving this longer dropout paving (1.0) than in my other scripts (0.5).
segconfig = struct( 'type', 'magdual', ...
  'qlong', 10, 'qdrop', 1.0, 'qglitch', 1.0, ...
  'dbpeak', fixedthreshold, 'dbend', 2 );

if ~want_adaptive_threshold
  % NOTE - Setting 'qlong' to inf works better for low frequencies.
  % Trying a very low but finite frequency can give artifacts.
  % At high frequencies, you do want an adaptive threshold (Q=10 works well).

  segconfig.qlong = inf;
end

if ~want_sweep_thresh
  detsweepthresholds = fixedthreshold;
end

% Coarse grid envelope fitting is sufficient.
% FIXME - See if I can implement a "fast guess" method.
% Using a coarser grid (5) than in my other scripts (7).
paramconfig = struct( 'type', 'grid', 'gridsteps', 5 );



%
% Burst rate analysis parameters.

rate_time_bin_ms = 100;

rate_band_time_bin_sec = [ 0.0 2.0 ];

bootstrap_count = 1000;

% Surrogate SEM starts as being comparable to non-surrogate SEM, and goes
% down as sqrt(count). So counts above 10 don't get you much (data error
% dominates).
%surrogate_count = 1000;
%surrogate_count = 100;
surrogate_count = 10;


% Adjust these settings if relevant flags were set.

if strcmp( 'positive', plot_ratevsband_window )
  rate_band_time_bin_sec = [ 0 inf ];
elseif strcmp( 'all', plot_ratevsband_window )
  rate_band_time_bin_sec = [ -inf inf ];
end


if ~want_bootstrap
  bootstrap_count = 'normal';
end

if ~want_surrogates
  surrogate_count = 1;
end


%
% Plotting.

% See lib-wl-plot/FIGCONFIG.txt for details.
% We also need to set 'fsamp' to each dataset's sampling rate.

plotconfig = struct( ...
  'fig', figure, 'outdir', 'plots', ...
  'psfres', 5, 'psolap', 99, 'psleak', 0.75, 'psylim', 50 );

plot_max_per_band = inf;

% "Stride" is "print every Nth item". Stride of 5 prints every 5th, etc.
plot_trial_stride = 25;
plot_channel_stride = 1;
plot_event_stride = 25;

if want_plot_trials_all
  plot_trial_stride = 1;
end

if want_plot_events_all
  plot_event_stride = 1;
end



%
% This is the end of the file.

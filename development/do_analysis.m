% wlBurst demo - Development scripts - Analysis.
% Written by Christopher Thomas.


%
% Setup.


% Configuration.

do_an_config;


% Paths.

addpath('lib-wlburst-v2');
addpath('lib-looputil');
addpath('lib-exputils');
addpath('lib-fieldtrip');

wlAddPaths;
addPathsLoopUtil;
addPathsExpUtilsCjt;


% Matlab warnings.

% NOTE - FT gives spurious warnings, but we may want to see legitimate ones.
%oldwarnstate = warning('off');


% Field Trip initialization and messages.

evalc('ft_defaults');

ft_notice('off');
ft_info('off');
ft_warning('off');


% Start the parallel pool early (it takes about 30 seconds).

if want_parallel
  parpool;
end



%
% Function handles for event pruning.

% Reject template fits that have relative RMS error of 0.7 or more.

fiterrfunc = @(thisev, thiswave) ...
  wlProc_calcWaveErrorRelative( thiswave.bpfwave, thisev.sampstart, ...
    thisev.wave, thisev.s1 );

% NOTE - Make sure to save calculated error in 'fiterror'.
prunepassfunc = @(thisev) (0.7 >= thisev.auxdata.fiterror);



%
% Iterate datasets, bands, and thresholds.

% FIXME - The library is set up to use multiple bands and split up the
% results after detection. We're ignoring that here.

bandoverridenone = struct( 'seg', struct(), 'param', struct() );

for sidx = 1:length(datasetlist)

  thissetdef = datasetlist(sidx);
  setfname = [ datasetpath filesep thissetdef.fname ];
  setvar = thissetdef.vname;
  settitle = thissetdef.title;
  setlabel = thissetdef.label;

  if (~want_sweep_datasets) && (~strcmp(setlabel, default_dataset))
    continue;
  end


  disp([ '== Loading dataset "' settitle '".' ]);

  tic;

  load(setfname);
  ftdata = eval(setvar);

  durstring = nlUtil_makePrettyTime(toc);
%  disp([ '.. Loaded in ' durstring '.' ]);


  % Get time bins.

  time_bins_sec = wlFT_getTimeBinList( ftdata, rate_time_bin_ms, 'edge' );
  time_bins_single = { rate_band_time_bin_sec };


  % Set up for aggregating burst rate information.

  threshcount = length(detsweepthresholds);

  bandcount = length(bandlist);
  chancount = length(ftdata.label);
  wincount = length(time_bins_sec);

  scratchband = nan([ bandcount chancount 1 ]);
  scratchtime = nan([ bandcount chancount wincount ]);

  rateband_avg = {};
  rateband_dev = {};
  rateband_sem = {};

  ratetime_avg = {};
  ratetime_dev = {};
  ratetime_sem = {};

  bgband_avg = {};
  bgband_dev = {};
  bgband_sem = {};

  bgtime_avg = {};
  bgtime_dev = {};
  bgtime_sem = {};

  for thidx = 1:threshcount
    % Pre-allocate, to force the correct geometry.

    rateband_avg{thidx} = scratchband;
    rateband_dev{thidx} = scratchband;
    rateband_sem{thidx} = scratchband;

    ratetime_avg{thidx} = scratchtime;
    ratetime_dev{thidx} = scratchtime;
    ratetime_sem{thidx} = scratchtime;

    bgband_avg{thidx} = scratchband;
    bgband_dev{thidx} = scratchband;
    bgband_sem{thidx} = scratchband;

    bgtime_avg{thidx} = scratchtime;
    bgtime_dev{thidx} = scratchtime;
    bgtime_sem{thidx} = scratchtime;
  end


  % Iterate bands.

  for bidx = 1:length(bandlist)

    thisbanddef = bandlist(bidx);
    bandspan = thisbanddef.band;
    bandtitle = thisbanddef.name;
    bandlabel = thisbanddef.label;

    disp(sprintf( '-- Processing %s band (%.1f - %.1f Hz).', ...
      bandtitle, min(bandspan), max(bandspan) ));

    basedetectconfig = segconfig;

    thisthreshlist = detsweepthresholds;
    if want_tuned_thresholds && isfield( tunedthresholds, bandlabel ) ...
      && (~want_sweep_thresh)
      thisthreshlist = tunedthresholds.(bandlabel);
    end

    % Get band-pass data, for plotting.
    bandpassconfig = struct( 'bpfilter', 'yes', 'bpfreq', sort(bandspan), ...
      'bpinstabilityfix', 'split', 'feedback', 'no' );
    ftbandpass = ft_preprocessing( bandpassconfig, ftdata );

    for thidx = 1:length(thisthreshlist)

      thisthresh = thisthreshlist(thidx);
      % FIXME - Assume integer dB values!
      threshlabel = sprintf( '%02ddb', round(thisthresh) );

      thisdetectconfig = basedetectconfig;
      thisdetectconfig.dbpeak = thisthresh;


      filebase = [ 'output' filesep setlabel '-' bandlabel '-' threshlabel ];


      disp(sprintf( '.. Testing with %.1f dB threshold.', thisthresh ));


      % Detect events in the baseline data.
      % Trim events near the ends to avoid roll-off artifacts.

      tic;

      if want_parallel
        thisdetect = wlFT_doFindEventsInTrials_MT( ...
          ftdata, thisbanddef, thisdetectconfig, paramconfig, ...
          bandoverridenone, want_tattle_progress );
      else
        thisdetect = wlFT_doFindEventsInTrials( ...
          ftdata, thisbanddef, thisdetectconfig, paramconfig, ...
          bandoverridenone, want_tattle_progress );
      end

      thisdetect = wlFT_pruneEventsByTime( ...
        thisdetect, detecttrimsecs, detecttrimsecs );

      durstring = nlUtil_makePrettyTime(toc);
      disp([ '.. Detection took ' durstring '.' ]);


      % Drop events where the curve fit failed.

      thisdetect = wlFT_calcEventErrors( thisdetect, fiterrfunc, 'fiterror' );
      thisdetect = wlAux_pruneMatrix( thisdetect, prunepassfunc );


      % Pick this apart into visualizable form even if we aren't going to
      % visualize it. It makes some of the diagnostics easier.

      ftevents = wlFT_getEventTrialsFromMatrix( thisdetect );
      artstruct = wlFT_getEventsAsArtifacts( thisdetect, ftdata.label );

      % Diagnostics.
      disp(sprintf( '.. Detected %d events.', size(artstruct.artifact,1) ));


      % Diagnostics.
      if debug_save_detected
        disp([ '.. Saving "' filebase '".' ]);

        events_matrix = thisdetect.events;
        save( [ filebase '-events_matrix.mat' ], 'events_matrix', '-v7.3' );

        events_ft = ftevents;
        save( [ filebase '-events_ft.mat' ], 'events_ft', '-v7.3' );

        events_art = artstruct;
        save( [ filebase '-events_art.mat' ], 'events_art', '-v7.3' );

        disp('.. Finished saving.');
      end


      % Get rates and rate statistics.
      % These get aggregted for later plotting.

      disp('.. Evaluating burst rates.');
      tic;

      [ thisrateband_avg thisrateband_dev thisrateband_sem ] = ...
        wlStats_getMatrixBurstRates( thisdetect, time_bins_single, ...
          bootstrap_count );

      rateband_avg{thidx}(bidx,:,:) = thisrateband_avg(1,:,:);
      rateband_dev{thidx}(bidx,:,:) = thisrateband_dev(1,:,:);
      rateband_sem{thidx}(bidx,:,:) = thisrateband_sem(1,:,:);

      [ thisratetime_avg thisratetime_dev thisratetime_sem ] = ...
        wlStats_getMatrixBurstRates( thisdetect, time_bins_sec, ...
          bootstrap_count );

      ratetime_avg{thidx}(bidx,:,:) = thisratetime_avg(1,:,:);
      ratetime_dev{thidx}(bidx,:,:) = thisratetime_dev(1,:,:);
      ratetime_sem{thidx}(bidx,:,:) = thisratetime_sem(1,:,:);

      durstring = nlUtil_makePrettyTime(toc);
      disp([ '.. Finished in ' durstring '.' ]);


      disp('.. Evaluating background rates.');


      [ ftphase trialmap ] = ...
        wlStats_makePhaseSurrogateFT( ftdata, surrogate_count );

      % FIXME - Duplicate code!

      % Detect events in the baseline data.
      % Trim events near the ends to avoid roll-off artifacts.

      disp('.. Detecting events in phase-shuffled surrogate data.');
      disp(sprintf( '.. Using %d surrogates.', surrogate_count ));
      tic;

      if want_parallel
        phasedetect = wlFT_doFindEventsInTrials_MT( ...
          ftphase, thisbanddef, thisdetectconfig, paramconfig, ...
          bandoverridenone, want_tattle_progress );
      else
        phasedetect = wlFT_doFindEventsInTrials( ...
          ftphase, thisbanddef, thisdetectconfig, paramconfig, ...
          bandoverridenone, want_tattle_progress );
      end

      phasedetect = wlFT_pruneEventsByTime( ...
        phasedetect, detecttrimsecs, detecttrimsecs );

      durstring = nlUtil_makePrettyTime(toc);
      disp([ '.. Detection took ' durstring '.' ]);

      % Drop events where the curve fit failed.

      phasedetect = ...
        wlFT_calcEventErrors( phasedetect, fiterrfunc, 'fiterror' );
      phasedetect = wlAux_pruneMatrix( phasedetect, prunepassfunc );


      disp('.. Computing event rates in surrogate data.')
      tic;

      [ thisbgband_avg thisbgband_dev thisbgband_sem ] = ...
        wlStats_getMatrixBurstRates( phasedetect, time_bins_single, ...
          bootstrap_count );

      bgband_avg{thidx}(bidx,:,:) = thisbgband_avg(1,:,:);
      bgband_dev{thidx}(bidx,:,:) = thisbgband_dev(1,:,:);
      bgband_sem{thidx}(bidx,:,:) = thisbgband_sem(1,:,:);

      [ thisbgtime_avg thisbgtime_dev thisbgtime_sem ] = ...
        wlStats_getMatrixBurstRates( phasedetect, time_bins_sec, ...
          bootstrap_count );

      bgtime_avg{thidx}(bidx,:,:) = thisbgtime_avg(1,:,:);
      bgtime_dev{thidx}(bidx,:,:) = thisbgtime_dev(1,:,:);
      bgtime_sem{thidx}(bidx,:,:) = thisbgtime_sem(1,:,:);

      durstring = nlUtil_makePrettyTime(toc);
      disp([ '.. Finished in ' durstring '.' ]);


      % Visualize the detected events using FT's functions, if desired.
      % FIXME - The 2023 version of FT emits a help screen to console with
      % no way to turn it off. Use "evalc" to get rid of it.

      if want_browse_bursts
        disp('.. Visualizing detected events.');

        burstchans = { 'wave', 'origbpf' };
        if want_browse_burst_wb
          burstchans = [ burstchans {'origwb'} ];
        end

        % FIXME - Databrowser isn't auto-ranging for some reason.
        thisyrange = helper_getTrialYrange( ftevents, burstchans );

% This would be great if we actually had a legend in ft_databrowser.
%          'viewmode', 'butterfly', ...

        browserconfig = struct( 'ylim', thisyrange );
        browserconfig.channel = burstchans;

        evalc( 'ft_databrowser( browserconfig, ftevents )' );

        disp('.. (press any key)');
        pause;
      end

      if want_browse_in_trials
        disp('.. Visualizing trials annotated with events.');

        % FIXME - Databrowser isn't auto-ranging for some reason.
        if want_browse_trial_bandpass
          thisyrange = helper_getTrialYrange( ftbandpass, {} );
        else
          thisyrange = helper_getTrialYrange( ftdata, {} );
        end

        browserconfig = struct( 'ylim', thisyrange );

        % Add Field Trip's nested artifact annotation structure.
        browserconfig.artfctdef = struct( 'wlburst', artstruct );

        if want_browse_trial_bandpass
          browserconfig.preproc = bandpassconfig;
        end

        evalc( 'ft_databrowser( browserconfig, ftdata )' );

        disp('.. (press any key)');
        pause;
      end


      if want_plot_trial_events
        disp('.. Plotting events in trials.');
        tic;

        wlPlot_plotAllMatrixEvents( plotconfig, thisdetect, ...
          sprintf( '%s Events - %s - %.1f dB', ...
            settitle, bandtitle, thisthresh ), ...
          [ 'events-' setlabel '-' bandlabel '-' threshlabel ], ...
          plot_max_per_band, plot_trial_stride, plot_channel_stride );

        durstring = nlUtil_makePrettyTime(toc);
        disp([ '.. Plotting took ' durstring '.' ]);
%        disp('.. Finished plotting.');
      end


      if want_plot_event_thresholds
        disp('.. Plotting individual events.');
        tic;

        wlPlot_plotAllMatrixEventsDebug( plotconfig, thisdetect, ...
          sprintf( '%s Events - %s - %.1f dB', ...
            settitle, bandtitle, thisthresh ), ...
          [ 'events-' setlabel '-' bandlabel '-' threshlabel ], ...
          plot_max_per_band, plot_trial_stride, plot_channel_stride, ...
          plot_event_stride );

        durstring = nlUtil_makePrettyTime(toc);
        disp([ '.. Plotting took ' durstring '.' ]);
%        disp('.. Finished plotting.');
      end


      % End of threshold iteration.
    end

    % End of band iteration.
  end


  % Iterate thresholds only, for rate plotting.

  if want_plot_rates
    disp('.. Plotting burst rates.');

    bandtitlelist = { bandlist.name };
    bandlabellist = { bandlist.label };

    for thidx = 1:threshcount
      thisthresh = detsweepthresholds(thidx);
      % FIXME - Assume integer dB values!
      threshlabel = sprintf( '%02ddb', round(thisthresh) );

      % FOOband has only one time window.
      wlPlot_plotMatrixBurstRates( plotconfig, ...
        rateband_avg{thidx}, rateband_dev{thidx}, rateband_sem{thidx}, ...
        bgband_avg{thidx}, bgband_dev{thidx}, bgband_sem{thidx}, ...
        time_bins_single, bandtitlelist, bandlabellist, ftdata.label, ...
        sprintf( '%s Burst Rates - %.1f dB', ...
          settitle, thisthresh ), ...
        [ 'byband-' setlabel '-' threshlabel ] );

      % FOOtime has lots of time windows.
      wlPlot_plotMatrixBurstRates( plotconfig, ...
        ratetime_avg{thidx}, ratetime_dev{thidx}, ratetime_sem{thidx}, ...
        bgtime_avg{thidx}, bgtime_dev{thidx}, bgtime_sem{thidx}, ...
        time_bins_sec, bandtitlelist, bandlabellist, ftdata.label, ...
        sprintf( '%s Burst Rates - %.1f dB', ...
          settitle, thisthresh ), ...
        [ 'bytime-' setlabel '-' threshlabel ] );
    end


    % This plot only looks good if it has more than one data point.
    if want_sweep_thresh
      % Re-aggregate the single-window case to have thresholds instead of
      % time as an axis.

      ratethresh_avg = helper_swapTimeAndThreshold( rateband_avg, 1 );
      ratethresh_dev = helper_swapTimeAndThreshold( rateband_dev, 1 );
      ratethresh_sem = helper_swapTimeAndThreshold( rateband_sem, 1 );

      bgthresh_avg = helper_swapTimeAndThreshold( bgband_avg, 1 );
      bgthresh_dev = helper_swapTimeAndThreshold( bgband_dev, 1 );
      bgthresh_sem = helper_swapTimeAndThreshold( bgband_sem, 1 );

      wlPlot_plotMatrixBurstRates( plotconfig, ...
        ratethresh_avg, ratethresh_dev, ratethresh_sem, ...
        bgthresh_avg, bgthresh_dev, bgthresh_sem, ...
        detsweepthresholds, bandtitlelist, bandlabellist, ftdata.label, ...
        sprintf( '%s Burst Rates vs Threshold', settitle ), ...
        [ 'bythresh-' setlabel ], 'Threshold (dB)' );
    end

    disp('.. Finished plotting.');
  end

  % End of dataset iteration.
end

disp('== Finished detection.');



%
% This is the end of the file.

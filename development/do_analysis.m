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


  for bidx = 1:length(bandlist)

    thisbanddef = bandlist(bidx);
    bandspan = thisbanddef.band;
    bandtitle = thisbanddef.name;
    bandlabel = thisbanddef.label;

    if (~want_sweep_bands) && (~strcmp(bandlabel, default_band))
      continue;
    end

    disp(sprintf( '-- Processing %s band (%.1f - %.1f Hz).', ...
      bandtitle, min(bandspan), max(bandspan) ));

    basedetectconfig = segconfig;
    if want_tuned_thresholds && isfield( tunedthresholds, bandlabel )
      basedetectconfig.dbpeak = tunedthresholds.(bandlabel);
    end

    thisthreshlist = basedetectconfig.dbpeak;
    if want_sweep_thresh
      thisthreshlist = detsweepthresholds;
    end

    % Get band-pass data, for plotting.
    bandpassconfig = struct( 'bpfilter', 'yes', 'bpfreq', sort(bandspan), ...
      'bpinstabilityfix', 'split', 'feedback', 'no' );
    ftbandpass = ft_preprocessing( bandpassconfig, ftdata );

    for threshidx = 1:length(thisthreshlist)

      thisthresh = thisthreshlist(threshidx);
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
        disp( '.. Plotting events in trials.');
        tic;

        wlPlot_plotAllMatrixEvents( plotconfig, thisdetect, ...
          sprintf( '%s Events - %s - %.1f db', ...
            settitle, bandtitle, thisthresh ), ...
          [ 'events-' setlabel '-' bandlabel '-' threshlabel ], ...
          plot_max_per_band, plot_trial_stride, plot_channel_stride );

        durstring = nlUtil_makePrettyTime(toc);
        disp([ '.. Plotting took ' durstring '.' ]);
%        disp('.. Finished plotting.');
      end


      if want_plot_event_thresholds
        disp( '.. Plotting individual events.');
        tic;

        wlPlot_plotAllMatrixEventsDebug( plotconfig, thisdetect, ...
          sprintf( '%s Events - %s - %.1f db', ...
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

  % End of dataset iteration.
end

disp('== Finished detection.');



%
% This is the end of the file.

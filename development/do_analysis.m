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
% Iterate datasets, bands, and thresholds.

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

    for tidx = 1:length(thisthreshlist)

      thisthresh = thisthreshlist(tidx);

      thisdetectconfig = basedetectconfig;
      thisdetectconfig.dbpeak = thisthresh;


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

% FIXME - NYI.
% FIXME - Pruning based on reconstruction error goes here.
% FIXME - Save relevant parts of the detection and discard the rest.

      % End of threshold iteration.
    end

    % End of band iteration.
  end

  % End of dataset iteration.
end

disp('== Finished detection.');



%
% This is the end of the file.

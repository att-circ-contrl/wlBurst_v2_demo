% wlBurst demo - Development scripts - Data processing for wlBurst synthetic.
% Written by Christopher Thomas.


% The dataset is already in FT format and small enough. Just copy it.

load([ '..' filesep 'datasets-raw' filesep 'minimal-synthevents.mat' ]);

ftdata_wlburst = synthdata;


% NOTE - Synthetic trials have continuous timestamps. Bring this back to
% per-trial timestamps.

trialcount = length(ftdata_wlburst.time);
trialstarttime = -2.0;

for tidx = 1:trialcount
  thistime = ftdata_wlburst.time{tidx};
  thistime = thistime + trialstarttime - thistime(1);
  ftdata_wlburst.time{tidx} = thistime;
end



% Save the edited dataset.
save( [ 'output' filesep 'ftdata_wlburst.mat' ], '-v7.3', 'ftdata_wlburst' );


%
% This is the end of the file.

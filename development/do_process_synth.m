% wlBurst demo - Development scripts - Data processing for wlBurst synthetic.
% Written by Christopher Thomas.


% The dataset is already in FT format and small enough. Just copy it.

load([ '..' filesep 'datasets-raw' filesep 'minimal-synthevents.mat' ]);

ftdata_wlburst = synthdata;

save( [ 'output' filesep 'ftdata_wlburst.mat' ], '-v7.3', 'ftdata_wlburst' );


%
% This is the end of the file.

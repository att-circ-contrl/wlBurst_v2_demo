% wlBurst demo - Development scripts - Data processing for R/F/H synthetic.
% Written by Christopher Thomas.


% The dataset is already in FT format and small enough. Just copy it.

load([ '..' filesep 'datasets-raw' filesep '202312-synth' filesep ...
  '20240117-100tr' filesep 'mua-loopbase-strong.mat' ]);

ftdata_robinson = ftdata_mua;



%
% FIXME - It's not small enough for GitHub. Use only the first two channels.

nchans = 2;

ftdata_robinson.label = ftdata_robinson.label(1:nchans,:);

ftdata_robinson.hdr.nChans = nchans;
ftdata_robinson.hdr.label = ftdata_robinson.hdr.label(1:nchans,:);

trialcount = length(ftdata_robinson.time);
for tidx = 1:trialcount
  thistrial = ftdata_robinson.trial{tidx};
  thistrial = thistrial(1:nchans,:);
  ftdata_robinson.trial{tidx} = thistrial;
end




% Save the dataset.

save( [ 'output' filesep 'ftdata_robinson.mat' ], '-v7.3', 'ftdata_robinson' );


%
% This is the end of the file.

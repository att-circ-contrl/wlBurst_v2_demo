function ylimits = helper_getTrialYrange( ftdata, chanlabels )

% function ylimits = helper_getTrialYrange( ftdata, chanlabels )
%
% This gets the minimum and maximum Y extents of trial data.
% This is massaged to have padding and to distinguish one-sided data.
%
% "ftdata" is a Field Trip datastructure.
% "chanlabels" is a cell array with channels to consider, or {} to consider
%   all channels.
%
% "ylimits" [ min max ] is a vector containing Y ranges to plot.


% Initialize output to sane values.
ylimits = [ -1 1 ];


% Magic values.

onesidedratio = 0.1;
padfrac = 0.2;


% Get metadata.

trialcount = length(ftdata.time);
chancount = length(ftdata.label);


% Figure out which channels we care about.

chanmask = true( size(ftdata.label) );

if ~isempty(chanlabels)
  for cidx = 1:chancount
    chanmask(cidx) = ismember( ftdata.label{cidx}, chanlabels );
  end
end


% Get the global maximum and minimum.

globalmax = [];
globalmin = [];

for tidx = 1:trialcount
  thisdata = ftdata.trial{tidx};
  thisdata = thisdata(chanmask,:);

  globalmax(tidx) = max(thisdata, [], 'all');
  globalmin(tidx) = min(thisdata, [], 'all');
end

globalmax = max(globalmax);
globalmin = min(globalmin);


% Figure out what the limits should be, based on this.

absmax = max(abs([ globalmax globalmin ]));
absmax = max( absmax, 1e-30 );

padsize = padfrac * absmax;

% FIXME - Kludge these to be pretty-looking values.
absmax = str2num( sprintf('%.1e', absmax) );
padsize = str2num( sprintf('%.1e', padsize) );

if abs(globalmax) < (onesidedratio * abs(globalmin))
  ylimits = [ -absmax, padsize ];
elseif abs(globalmin) < (onesidedratio * abs(globalmax))
  ylimits = [ -padsize, absmax ];
else
  ylimits = [ -absmax absmax ];
end


% Done.
end


%
% This is the end of the file.

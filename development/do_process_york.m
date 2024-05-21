% wlBurst demo - Development scripts - Data processing for York NHP data.
% Written by Christopher Thomas.


addpath('lib-wlburst-v2');
wlAddPaths;

% My experiment libraries, to make signal processing easier.
addpath('lib-looputil');
addpath('lib-exputils');
addPathsLoopUtil;
addPathsExpUtilsCjt;


% Blindly copy the preprocessing and trimming I'd used with the wlBurst
% test scripts.

% NOTE - That script says there are still artifact-bearing trials, so
% I'll still need to do my own processing to suppress those.



%
% Configuration.


want_plots = true;


targetchanlist = { 'CSC5LFP' };

% Notch filtering.
notchlist = [ 60 120 ];  % Omit 180; our sampling rate is 1 ksps.
notchbw = 3.0;

% Artifact rejection by amplitude.
% Hand-tuned based on plots.
% Anywhere from 150 (some false rejections) to 200 (no false rejections,
% but a few artifacts).

artifact_threshold = 150;
%artifact_threshold = 200;



%
% Load the FT data ("DATA") and Thilo's metadata ("tinfo").

disp('-- Loading York U dataset.');

load([ '..' filesep 'datasets-raw' filesep 'LFP_B_tmplate_01.mat' ]);

samprate = wlFT_getSamplingRate(DATA);



%
% Extract only the desired channel.
% NOTE - This doesn't change "hdr"! But "hdr" already isn't consistent with
% ftdata.label, so that's fine. It seems to be the before-processing header.

[ DATA chandefs ] = wlFT_getChanSubset( DATA, targetchanlist );



%
% Trim the trials.

disp('-- Trimming to exclude the reward period (licking artifacts).');


% Modified crop function.
% ROI is the time ahead of reward (where there are electrical artifacts).

% Get stop times (in samples), and augment "trialinfo" with them.

rewardsamps = [];
rewardtimes = tinfo.rewOnTimes;
for tidx = 1:length(rewardtimes);
  % Convert a negative timestamp in seconds into a positive sample offset.
  % Make sure this is a column vector.
  rewardsamps(tidx,1) = round( - samprate * rewardtimes{tidx}(1) );
end

% Trialinfo is Ntrials x 2; add an extra column.
DATA.trialinfo = [ DATA.trialinfo, rewardsamps ];
auxidx = size(DATA.trialinfo,2);


% Make a crop function that checks trialinfo for the end time.

cropfunc = @(thistrial, sampinforow, trialinforow) ...
  deal( 1, trialinforow(auxidx) );


% Do the cropping.

[ DATA cropdefs ] = wlFT_trimTrials(DATA, cropfunc);



%
% Do artifact rejection. Just throw out affected trials.

disp('-- Rejecting trials with artifacts.');

% Hand-tuned ad-hoc based on artifact amplitude.

trialcount = length(DATA.time);

trialmask = true([1 trialcount]);

for tidx = 1:trialcount
  thistrial = DATA.trial{tidx};
  thisart = ( abs(thistrial) >= artifact_threshold );

  if any(thisart,'all')
    trialmask(tidx) = false;
  end
end

DATA.time = DATA.time(trialmask);
DATA.trial = DATA.trial(trialmask);
trialmask = transpose(trialmask);
DATA.sampleinfo = DATA.sampleinfo(trialmask,:);
DATA.trialinfo = DATA.trialinfo(trialmask,:);

disp(sprintf( '.. Kept %d of %d trials.', sum(trialmask), trialcount ));
trialcount = sum(trialmask);



%
% Do notch filtering.

disp('-- Notch filtering.');

DATA = euFT_doBrickNotchRemoval( DATA, notchlist, notchbw );



%
% Diagnostic plots

if want_plots

  disp('-- Plotting wideband trials.');

  trialdefs = DATA.sampleinfo;

  % FIXME - Kludge start times.
  % I'll go out on a limb and say that the first column of "trialinfo" is
  % the cue time, since it's always 2000 samples.

  trialcount = size(trialdefs,1);
  trialdefs = [ trialdefs, - 2000 * ones([ trialcount 1 ]) ];


  euPlot_plotFTTrials( DATA, samprate, ...
    trialdefs, {}, samprate, struct(), samprate, ...
    { 'pertrial' }, { [] }, { 'full' }, inf, ...
    'Wideband Trial Data', [ 'plots' filesep 'trials-wb' ] );

end



%
% Save the curated data.

disp('-- Writing processed data to disk.');

ftdata_york = DATA;
save( [ 'output' filesep 'ftdata_york.mat' ], 'ftdata_york', '-v7.3' );

disp('-- Done.');


%
% This is the end of the file.

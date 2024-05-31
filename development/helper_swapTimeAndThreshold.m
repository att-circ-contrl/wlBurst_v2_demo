function newrates = helper_swapTimeAndThreshold( oldratelist, winidx )

% function newrates = helper_swapTimeAndThreshold( oldratelist, winidx )
%
% This takes a cell array of burst rate matrices, indexed by threshold, and
% reshuffles them into a rate matrix with threshold instead of time as the
% third index.
%
% This is intended to work with rate matrices returned by
% wlStats_getMatrixBurstRates.
%
% "oldratelist" is a cell array with one entry per threshold. Each cell
%   contains a rate matrix indexed by (bandidx, chanidx, windowidx).
% "winidx" is the time window index to read from in "oldratelist"'s matrices.
%
% "newrates" is a matrix indexed by (bandidx, chanidx, threshidx) containing
%   the selected data from "oldratelist".


newrates = [];

if ~isempty(oldratelist)

  threshcount = length(oldratelist);
  thisratematrix = oldratelist{1};
  [ bandcount, chancount, wincount ] = size(thisratematrix);

  newrates = nan([ bandcount, chancount, threshcount ]);

  for thidx = 1:threshcount
    thismatrix = oldratelist{thidx};

    % Don't take any chances with data ordering.
    % Only read a one-dimensional strip at a time.
    for bidx = 1:bandcount
      thisslice = thismatrix(bidx,:,winidx);
      newrates(bidx,:,thidx) = thisslice;
    end
  end

end


% Done.

end


%
% This is the end of the file.

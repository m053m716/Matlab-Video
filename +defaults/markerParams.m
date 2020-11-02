function out = markerParams(type)
%% LABELNAMES  Returns default label names
%
%  out = defaults.MARKERPARAMS;       % returns struct array
%  out = defaults.MARKERPARAMS(type); % returns specific field
%
% By: Max Murphy  v1.0  2019-05-14  Original version (R2017a)

%%
markerData = struct('name',{'dig1_d';
                            'dig1_p';
                            'dig2_d';
                            'dig2_p';
                            'dig3_d';
                            'dig3_p';
                            'dig4_d';
                            'dig4_p';
                            'hand'},...
                    'color',{[0.9 0.2 0.2];
                             [1.0 0.3 0.3];
                             [0.2 0.9 0.2];
                             [0.3 1.0 0.3];
                             [0.2 0.2 0.9];
                             [0.3 0.3 1.0];
                             [0.9 0.2 0.9];
                             [1.0 0.3 1.0];
                             [0.0 0.0 0.0]},...
                    'shape',{'none';
                             'h';
                             '+';
                             'o';
                             'd';
                             's';
                             'p';
                             'x';
                             '*'});
          
if nargin < 1
   out = markerData;
elseif ismember(type,fieldnames(markerData))
   out = {markerData.(type)};   
   out = reshape(out,numel(out),1); % make sure it is column vector
else
   warning('Invalid input. Should a char (either ''name'' or ''color'').');
   disp('Returning full defaults struct.');
   out = markerData;
end


end
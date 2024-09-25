function out = digitizePhase_PLM(phase,varargin)
%DIGITIZEPHASE_PLM function to digitized a phase matrix for the TI-PLM.
%   This function is used to convert the phase value [-pi pi] into a bit number
%   that is used as an index to create the PLM frame. The lookup table must
%   map phases from -pi:pi and bit value from 0 to 2^4 (16) 
%   [the last value is used to wrap the 2pi to index 0]
%   Made for the DLP6750Q1EVM PLM accorcing to the rev12 user guide
%
%   Input: - phase (MxN matrix) for TI-PLM (Model DLP6750Q1EVM) by default
%            the funcion expect a 800x2358 matrix. If a different size is
%            used you can pass the a 1x2 vector of [M N] after the phase
%          - lut (Name-Value optional 2xK vector) lookup table to digitized the phase
%            where the second line is the phase and the first line is the 
%            bit value. Must be from 0 to 15 (4bit) + 16 (one more value 
%            used to wrap around for 2pi)
%
%   Output: -out (NxM integer matrix)
%
% Nathan Vigne 2024

% Default value
lut_default(1,:) =  [0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16];
lut_default(2,:) = [0, 1.07, 2.19, 4.5, 5.98, 7.75, 12.06, 18.5, ...
                    35.55, 39.55, 45.1, 52.44, 63.93, 71.16, 85.02, ...
                    100, 100*16/15];
lut_default(2,:) = lut_default(2,:)./100 *15/16 * 2 *pi;
lut_default(2,:) = lut_default(2,:)-pi;
N = 1358; M = 800;

% Parse inputs
p = inputParser;
addRequired(p,'phase',@(x) isnumeric(x));
addOptional(p,'MatrixSize',[M N],@(x) size(x,1)==1 && size(x,2)==2 && isnumeric(x));
addParameter(p,'lut',lut_default,@(x) size(x,1)==2 && size(x,2)>2 && isnumeric(x));
parse(p,phase,varargin{:})
Size = p.Results.MatrixSize;
M = Size(1);
N = Size(2);
if size(phase,1) ~= M || size(phase,2) ~= N
    error('Phase matrix of wrong size expected a %dx%d matrix',M,N);
end
lut = p.Results.lut;

% if min(min(phase))<-pi || max(max(phase))>pi % unwrap phase
phase = mod(phase+pi,2*pi)-pi;
% end

out = interp1(lut(2,:),lut(1,:),phase,"nearest");
out = mod(out,16);
end
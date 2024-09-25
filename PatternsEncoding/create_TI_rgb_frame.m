function [frame] = create_TI_rgb_frame(phase,varargin)
%CREATE_TI_RGB_FRAME function to generate the frame expected by the TI PLM
%from a given phase matrix. 
%   This function can take from 1 to 24 patern (needs to be an integer 
%   divider of 24) and encode them into a single frame of 24bit
%   (8bit R, 8bit G, 8bit B). The first patern is encoded in the LSB of the
%   red channel and the rest follow from red LSB->MSB to blue. In the TI
%   software this correspond to R8->R15 then G0->G7 then B16->B23 
%   Made for the DLP6750Q1EVM PLM accorcing to the rev12 user guide
%
%   Inputs: -phase (MxNxP matrix) for TI-PLM (Model DLP6750Q1EVM) by default
%            the funcion expect a 800x1358xP matrix. If a different size is
%            used you can pass the a 1x2 vector of [M N] after the phase
%          - lut (Name-Value optional 2xK vector) lookup table to digitized the phase
%            where the second line is the phase and the first line is the 
%            bit value. Must be from 0 to 15 (4bit) + 16 (one more value 
%            used to wrap around for 2pi)
%          - verbose (Name-Value optional bool) By default Verbose is on
%            can turn it off by passing ('verbose',false)
%          - selectphase (Name-Value optional string 'phase' or 'direct') By default
%          selectphase is set to phase, meaning we use the digitized phase
%          function to convert from -pi/pi to 0-15 value. If direct is use
%          the phase matrix is consider to be already digitize to 0-15 any
%          value above or belove will be wrongly encoded
%
%
%   Output: -frame (2Mx2Nx3 uint8) digitized for working with the TI PLM
%
% Nathan Vigne 2024

% Defautl parameters
N = 1358; M = 800;

% Parse inputs
p = inputParser;
addRequired(p,'phase',@(x) isnumeric(x));
addOptional(p,'MatrixSize',[M N],@(x) size(x,1)==1 && size(x,2)==2 && isnumeric(x));
addParameter(p,'lut',nan,@(x) size(x,1)==2 && size(x,2)>2 && isnumeric(x));
addParameter(p,'verbose',true,@(x) islogical(x));
addParameter(p,'selectphase','phase',@(x) (isstring(x) || ischar(x)) && (strcmp(x,'phase') || strcmp(x,'direct')));

parse(p,phase,varargin{:})

% check if using custom LUT
useCustomLut=false;
if ~isnan(p.Results.lut)
    useCustomLut = true;
end

% check if using direct phase or not
useDigi = true;
if strcmp(p.Results.selectphase,'direct')
    useDigi = false;
end

% Load user size
M = p.Results.MatrixSize(1);
N = p.Results.MatrixSize(2);
if size(phase,1) ~= M || size(phase,2) ~= N
    error('Phase matrix of wrong size expected a %dx%d matrix',M,N);
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Some computation for handling different number of paterns

P = size(phase,3);
if mod(24,P)~=0 || P>24
    error('The thrid dimension of phase must be an integer diviser of 24. the max value being 24');
    % To create a video of more than 24 patern please make repeated call 
    % of this function passing 24 paterns each time
end

% Computing the number of bit to encode per patern
nbit_per_patern = floor(24/P);

% Creating bit mask LUT corresponding to the number of bit to encode per
% patern
bin_msk = [0x00000001;  %  1 bit/patern 
           0x00000003;  %  2 bit/patern 
           0x00000007;  %  3 bit/patern
           0x0000000F;  %  4 bit/patern
           0x0000003F;  %  6 bit/patern
           0x000000FF;  %  8 bit/patern
           0x00000FFF;  % 12 bit/patern
           0x00FFFFFF]; % 24 bit/patern

% Computing the index of bin_msk depending of the number of bit per patern
if nbit_per_patern<6
    msk_ind = nbit_per_patern;
elseif nbit_per_patern==6
    msk_ind = 5;
elseif nbit_per_patern==8
    msk_ind = 6;
elseif nbit_per_patern==12
    msk_ind = 7;
elseif nbit_per_patern==24
    msk_ind = 8;
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Start of frame creation
logging('Creating PLM RGB frame according to the user manual DLP6750Q1EVM rev12...\n',p.Results.verbose)
logging('Converting Phase value into 4bit phase level\n',p.Results.verbose);
% tic
% tranform the phase matrix in an index matrix used to generate the PLM frame
if useDigi
    if useCustomLut
        phaseBit = digitizePhase_PLM(phase,[M N],'lut',p.Results.lut);
    else
        phaseBit = digitizePhase_PLM(phase,[M N]);
    end
else
    phaseBit = phase;
end
% toc 


logging(sprintf('Generating the Memory frame of %dx%d pixels\n',2*N,2*M),p.Results.verbose);
% tic;
% Generate the frame
frame = uint8(zeros(2*M,2*N,3));
temp_rgb = uint8(zeros(2*M,2*N,4));

% temporary frame of uint32 to store the 24bit value before RGB separation
temp = uint32(zeros(2*M,2*N));

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Construction of the Frame is done using bit
% masking. We use a 32bit integer to have acces
% of the 24 RGB bits. Depending on the number
% of bit per patern use the corresponding bit mask.
% to encode the patern only on the specific bits
% for the next patern we just shift the mask and
% repeat. 
% 
% The formula to compute M3-M0 was taken from Suyeon Choi (suyeon@stanford.edu) python code
% each hologram pixel is transform to 2x2 memory matrix encoding the 4bit
% of the PLM piston. To gain speed we used slicing adressing to adress
% every odd or even row/col corresponding to memory cell M0->M3 (see TI
% user manual). The logical operation on the phase index allow us to
% encode a one or a zero depending on the bit value
%
% Once this step is complete we take the LSB 8bit and encode them into the
% RED channel then right shift the temp bits and encode the next 8bit to
% the GREEN channel then the next 8bit to the BLUE channel
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% tic
for i=0:P-1
    logging(sprintf('Computing patern %02d\n',i+1),p.Results.verbose);
    phaseBit_temp = phaseBit(:,:,i+1);
    % M3
    M3 = uint32(floor(phaseBit_temp./8).*(2^32-1));
    temp(1:2:end,2:2:end) = bitor(bitand(bitshift(bin_msk(msk_ind),i*nbit_per_patern),M3), ...
                            temp(1:2:end,2:2:end));
    % M2
    M2 = uint32((phaseBit_temp == 3) | ((phaseBit_temp ~= 4) ...
                                     & (mod(phaseBit_temp, 8) >= 4))).*(2^32-1);
    temp(2:2:end,2:2:end) = bitor(bitand(bitshift(bin_msk(msk_ind),i*nbit_per_patern),M2), ...
                            temp(2:2:end,2:2:end));
    % M1    
    M1 = uint32((phaseBit_temp == 3) | ((phaseBit_temp ~= 4) ...
                                     & (mod(phaseBit_temp, 4) < 2))).*(2^32-1);
    temp(1:2:end,1:2:end) = bitor(bitand(bitshift(bin_msk(msk_ind),i*nbit_per_patern),M1), ...
                            temp(1:2:end,1:2:end));
    % M0
    M0 = uint32((phaseBit_temp == 3) | ((phaseBit_temp ~= 4) ...
                                     & (mod(phaseBit_temp, 2) == 0))).*(2^32-1);
    temp(2:2:end,1:2:end) = bitor(bitand(bitshift(bin_msk(msk_ind),i*nbit_per_patern),M0), ...
                            temp(2:2:end,1:2:end));   
end
% toc

logging('Encoding to RGB channels\n',p.Results.verbose);
% tic
temp_rgb =  reshape( reshape(typecast(reshape(temp,1,2*2*M*N),'uint8'),4,[])' ,2*M,2*N,[]);
frame = temp_rgb(:,:,1:3);
% toc

logging('flipping Left-right image\n',p.Results.verbose);
% tic
frame = fliplr(frame);
% toc
end

function logging(msg,verbose)
%LOGGING function to display some text using fprintf
%   display the str msg if the verbose flag is true otherwise do nothing
%
%   msg: string
%   verbose: bool
%
% Nathan Vigne 2024
    if verbose
        fprintf(msg);
    end
end



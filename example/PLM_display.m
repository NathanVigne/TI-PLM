clear all;clc;clf;

%% Generate 24 phase patterns
N = 1358; M = 800;                  % PLM resolution
Phase = 2.*pi.*rand(M,N,24) - pi;   % rand phase patern -pi/pi

%% Encode all patern to a single frame
Frame = create_TI_rgb_frame(Phase,[M,N]);

%% Loading Psytoolbox
% Here we call some default settings for setting up Psychtoolbox
PsychDefaultSetup(1);
Screen('Preference', 'SkipSyncTests', 1);
Screen('Preference', 'VisualDebugLevel', 0);
Screen('Preference', 'Verbosity' , 1); % only show error (we can ignore synchro error)

% Get the screen numbers. This gives us a number for each of the screens
% attached to our computer.
screens = Screen('Screens'); 

%% Open window
Psy.openWindow(Psy.screens(3));

ID = screens(end); % get Last screen
white = WhiteIndex(ID);
black = BlackIndex(ID);

% set up gray color in window opening
col = white/2;

% Open an on screen window using PsychImaging and color it grey.
[w, wRect] = Screen('OpenWindow', ID, col);
 
% Get psytoolbox screen size (might give you issue if it doesnt detect the correct resolution)
[width, height] = Screen('WindowSize', obj.w);

% Wait for a keyboard press to continue
fprintf('Waiting for a keyboard press to continue!\n')
KbStrokeWait;
fprintf('Continuing!\n')


%% Test screen size
assert(width==N*2,'Screen width must be %d px',2*N);
assert(height==M*2,'Screen height must be %d px',2*M);


%% Load image into PLM
% Make the image into a texture (load to GPU)
Tex = Screen('MakeTexture',w,Frame,0);

%% Display image
Screen( 'DrawTexture',w,Tex,[],wRect,0 );
Screen( 'Flip',w,0 );

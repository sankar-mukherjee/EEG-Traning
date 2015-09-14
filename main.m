%%% This is the first matlab script for audio EEG experiment. Creates a beep sound for the subject and also send TTL signal to EEG
%%% system.
clear;close all;clc;

%% CC general notes
% you should have at least 60 trials for each condition you think to
% consider
% therefore sentences should be repeated a sufficient amount of times.
% to avoid habituation sentences should be randomized e.g. by the shuffle
% function of psychtoolbox

%% choose the screen to display
screen = 1;

%% CC set parallel port
% add path with the mex and the functions required to manage parallel port
addpath('C:\Toolbox\behaviourPlatform\CommonScript\io\lpt\Matlab32OS64')
%create an instance of the io32 object (object representing parallel port)
ioObj = io32;
%
%initialize the hwinterface.sys kernel-level I/O driver
status = io32(ioObj);

% give the address to the parallel port to handle outputs: triggers
lptport_output = (hex2dec('378'));

%% CC build the sound
%% send beep to microphone
Fs = 10000; % samples per second 1300
toneFreq = 500; % Tone Frequency, in Hertz
nSeconds = 0.075; %Duration of the sound
dt=1/Fs;
time = 0:dt:nSeconds;
bip = sin(2*pi*toneFreq*time);

%% CC set sound card
% call  data acquisition toolbox to identfy all devices
hwinfo = daqhwinfo;

% check that sound card is ok
FLAG_1 = 0;
for j = 1:length(hwinfo.InstalledAdaptors)
    if strcmp(hwinfo.InstalledAdaptors{j},'winsound')
        disp('sound card ok!');
        FLAG_1 = 1;
        id_sound = j;
    end
end

if FLAG_1 == 0
    disp('sound card not working!');
end

% create virtual object representing sound card
sound_card = analogoutput('winsound',1);
% add one virtual channel to the sound card to load the sound
chans = addchannel(sound_card,1);
% set the sampling rate of the sound card (must be the same of the sound)
sound_card.SampleRate = Fs;

%% CC set some trigger parameters
trigger.code.begin_recording = 1;
trigger.code.end_recording   = 2;
trigger.pause                = 0.02; % in seconds
trigger.code.begin_trial_recording = 3;
trigger.code.end_trial_recording   = 4;
trigger.code.word = 5:34;

%% prepare envioronment
prompt = 'Please insert the folder name\n';
name = input(prompt,'s');
if isempty(name)
    name = 'test';
end

folder = ['log_' name];
mkdir(folder);
filetid = fopen([folder '\timesteps.txt'],'w');

filename = './data/Sentence.txt';
fid = fopen(filename);
sentence = textscan(fid,'%s','delimiter','\n');
fclose(fid);
%% randomizing the words and triggers
randIdx = randperm(60);
a = repmat(sentence{1,1},2,1);
data.word = a(randIdx);
a = repmat(trigger.code.word',2,1);
data.trigger = a(randIdx);

%%  Screen
whichScreen=Screen('Screens');
window = Screen('OpenWindow',screen,0,[],32,2);
white = WhiteIndex(window); % pixel value for white
black = BlackIndex(window); % pixel value for black
gray = (white+black)/2;
inc = white-gray;

i = 1;
w(i) = window;
Screen(w(i), 'FillRect', gray);
Screen('TextFont', w(i), 'Arial');
Screen('TextSize', w(i),50);
DrawFormattedText(w(i),['Press Enter to Start'],'center','center',[255 255 255],50);
Screen('Flip',window);

fprintf('Press Enter to Start\n');
KbWait();
[keyIsDown, secs, keyCode] = KbCheck;
%% EEG TTL signal
% the same porcedure should be applied to all the sentences with specific
% triggers to be defined a the beginning of the script. triggers should be
% between 3 and 255.

% i would send a trigger
% 1. when each trail begin
% 2. immediately after the flip of each sentence

% send trigger
io32(ioObj,lptport_output,trigger.code.begin_recording);
% pause to avoid trigger overlap
WaitSecs(trigger.pause);
% reset parallel port
io32(ioObj,lptport_output,0);
% pause to avoid trigger overlap
WaitSecs(trigger.pause);

%% start timer
tStart = tic;
%% presetation of sentences
for i = 1:length(data.word)
    if i>1
        w(i) = window;
    end
        
    fprintf(filetid,'%s)\t',num2str(i));
    %% CC mark the begining of recording
    % send trigger
    io32(ioObj,lptport_output,trigger.code.begin_trial_recording);
    % pause to avoid trigger overlap
    WaitSecs(trigger.pause);
    % reset parallel port
    io32(ioObj,lptport_output,0);
    % pause to avoid trigger overlap
    WaitSecs(trigger.pause);
    fprintf(filetid,'%g\t',toc(tStart));
    
    
    %First instruction
    Screen(w(i), 'FillRect', gray);
    Screen('TextFont', w(i), 'Arial');
    Screen('TextSize', w(i),50);
    DrawFormattedText(w(i),['Wait....'],'center','center',[0 0 0],50,0,0,2);
    Screen('Flip',window);
    pause(1);
    
    %% CC manage the sound
    % load the sond to the sound card
    putdata(sound_card, bip');
    % start the sound
    start(sound_card);    
    
    fprintf('\n');
    fprintf('%g%s\n',i,[') ' data.word{i}]);
    
    pause(0.025); %25 ms for noise removing
    Screen(w(i), 'FillRect', gray);
    Screen('TextFont', w(i), 'Arial');
    Screen('TextSize', w(i),50);
    DrawFormattedText(w(i),[data.word{i}],'center','center',[255 255 255],50,0,0,2);
    Screen('Flip',window);
    
    % send trigger
    io32(ioObj,lptport_output,data.trigger(i));
    % pause to avoid trigger overlap
    WaitSecs(trigger.pause);
    % reset parallel port
    io32(ioObj,lptport_output,0);
    % pause to avoid trigger overlap
    WaitSecs(trigger.pause);
       
    fprintf('Press Enter to Start new Trial\n');
    KbWait();
    [keyIsDown, secs, keyCode] = KbCheck;
    
    %% CC mark the end of recording
    % send trigger
    io32(ioObj,lptport_output,trigger.code.end_trial_recording);
    % pause to avoid trigger overlap
    WaitSecs(trigger.pause);
    % reset parallel port
    io32(ioObj,lptport_output,0);
    % pause to avoid trigger overlap
    WaitSecs(trigger.pause);
    
    fprintf(filetid,'%g\t',toc(tStart));
    fprintf(filetid,'%s\t\n',data.word{i});
    pause(0.5); %50 ms pause
end

Screen('CloseAll');
fclose(filetid);
%% CC mark the end of recording
% send trigger
io32(ioObj,lptport_output,trigger.code.end_recording);
% pause to avoid trigger overlap
WaitSecs(trigger.pause);
% reset parallel port
io32(ioObj,lptport_output,0);
% pause to avoid trigger overlap
WaitSecs(trigger.pause);

% David Cade
% version 11.23.2020
% UC Santa Cruz
% Stanford University


% Before running through the steps in this file, run importCATSdata; (saves a *.mat file with data at 40 or 50 Hz, and Adata with raw accelerometer files)
% Run section 1 well before you want to start making the prh file as it takes a long time.
% Also prepare an xls file like spYYMMDD-tag#.xls with any observed tagslip times, GPS
% location of tagon, and, if there are not timestamps on the video surfacing times for each video 

dbstop if error;
disp('Section completed')
%% 1 Read time stamps on video files (can skip for data only)
% runs for a long time (like 2x as long as the amount of video you have)
% Saves output so can run this and come back to it later
% outputs: AudioData folder with audio info for each file
%          **movieTimes.mat file saved in the folder with the raw movies
%          (has the time of each frame in each movie)
%          A graph with all the video times graphed.  Look for obvious
%          errors in the order of the timestamps in the videos.
% Delete "movieTimesTEMP.mat" file AFTER this section finishes.

% Matlab packages required: Signal Processing Toolbox, Image Processing
% Toolbox, Statistics and Machine learning Toolbox


% It take some time but increases the ability to synch video and data.
% Just load the videos taken at least partly on whale.
% BEFORE RUNNING!: Create wav files from videos using ffmpeg (recommended),
% or VLC (also seems to work). For ffmpeg, in command prompt, change the
% directory to the directory with your movie files, create a "wavfiles"
% directory, then type: for %a in (*.mov) DO ffmpeg -i "%a" "wavfiles\%~na.wav"
% This script can also create wav files from the
% videos, but this seems to sometimes create an offset error, so check the
% results if you use this program to create wav files instead of the above recommendation.
% also: input whale ID or put files in a folder listed with the whale ID if
% you want to read in a TAG GUIDE for tag on and tag off times.

dur = 15; % break the video up into chunks of length dur seconds to ensure progress and avoid crashes.  Smaller numbers use less memory
folder = 'E:\CATS\tag_data_raw\'; % optional- just gives you a place to start looking for your data files
readaudiofiles = true;

% these will be less commonly adjusted
readtimestamps = true; % if there are embeded timestamps on the video.  If simpleread, only read timestamps at the end of a section and compare to the video time
simpleread = true; % newer videos with accurate initial timestamps (to the ms). If false, reads timestamps from every frame and tries to estimate the bad frame reads
timewarn = 0.1; % since typical data is downsampled to 10 Hz, use this as a threshold for accuracy of the video timestamps
redovids = []; % set this if you are trying to re-read specific video numbers
whaleID = []; 

makeMovieTimes(dur,readtimestamps,simpleread,folder,readaudiofiles,timewarn,whaleID,redovids); %workhorse script
disp('Section 1 completed');
%% 2. Select files (START HERE IF NO VIDEOS) 
% Always run this section
% 
% imports file names and reads the header file
% output: "headers" and "tagnum" variables in workspace
% set: "decfac" below.  Ending with 10 Hz files is probably a good goal.
% ensure that video files are in the same folder as the data file.

% Prerequisites:
% 1) run importCATSdata (or similar for other tag types) to convert raw tag
% outputted data into a .mat file with variables "data" (a table), "Adata" (a matrix) and
% "Atime" (a vector). See "importCATSdata" script for details
% 2) in the same folder as the *.mat file, there should be a header file
% "spYYMMDD-tag#.xls" with whale name & tag number & GPS location of tagon, as well as 
% times of tag slips (if they can be seen in the videos) and surfacing times 
% (necesary only if videos do not have time stamps embedded)
% 3) run "makeMovieTimes" script above if there are videos associated with
% the data

% variables to set
decfac = 5; %decimation factor (e.g. decimate 50 Hz data in "data" to 10 Hz data with a decfac of 5)

% Can set "drive" and "folder" below to start looking for files in a specific place on your computer

folder = 'e:/CATS/tag_data_raw/'; % folder in the drive where the cal files are located (and where you want to look for files) %'Users\Dave\Documents\Programs\MATLAB\Tagging\CATS cal';%
global fileloc filename
cf = pwd; try cd([vol ':\' folder]); catch; end
[filename,fileloc]=uigetfile('*.mat', 'select CATS data (imported mat file)'); 
cd(fileloc);

[headerfile,headerloc]=uigetfile('*xls*', 'select data file with surfacings and header info (i.e. spYYMMDD-tag#)');
cd(cf);

[~,~,headers]= xlsread([headerloc headerfile]);
tagnum = cell2mat(headers(4,2))

disp('Section 2 finished');
% look for progress Index in info file, tell you cell to continue on 
warning('off','MATLAB:load:variableNotFound');

if ~isempty(strfind(filename,'truncate'))
    disp('Using truncated file'); %load([fileloc filename]);
    filename = filename([1:end-12 end-3:end]); % filename without the truncate label
end

try load([fileloc filename(1:end-4) 'Info.mat'],'CellNum');
    disp(['Prhfile created through step number ' num2str(CellNum) ' (can start at subsequent step)']);
catch
    CellNum = 2;
      try save([fileloc filename(1:end-4) 'Info.mat'],'CellNum','-append');
      catch; save([fileloc filename(1:end-4) 'Info.mat'],'CellNum'); disp('Made new INFO file');
      end
end

clearvars -except fileloc filename decfac drive folder tagnum headers vol 
%% 3. Create a truncated file (or load it) and rename variables
% if you haven't run importCATSdata, this will run it.
% output: *truncate.mat files.  Truncate reduces file size by
% cutting out time not on the whale.
% asks for a cal file that matches the tagnumber of the deployment
% fills in gaps in the data with nans

% Matlab packages required: Statistics and Machine learning Toolbox
% dbstop if error;

df = decfac;
if exist([fileloc filename(1:end-4) 'truncate.mat'],'file') 
    disp('Using truncated file'); load([fileloc filename(1:end-4) 'truncate.mat']);
elseif ~isempty(strfind(filename,'truncate'))
    disp('Using truncated file'); load([fileloc filename]);
    filename = filename([1:end-12 end-3:end]); % filename without the truncate label
else
    load([fileloc filename]);
    disp('Data Loaded, making truncated file');
    if ~exist('Hzs','var'),[accHz,gyrHz,magHz,pHz,lHz,GPSHz,UTC,THz,T1Hz] = sampledRates(fileloc,filename);
        Hzs = struct('accHz',accHz,'gyrHz',gyrHz,'magHz',magHz,'pHz',pHz,'lHz',lHz,'GPSHz',GPSHz,'UTC',UTC,'THz',THz,'T1Hz',T1Hz);
    end
    [data,Adata,Atimem,datagaps,ODN,ofs,Afs] = truncatedata(data,Adata,Atime,Hzs,fileloc,filename); % workhorse script in this section
    disp('Check to ensure these times are before tag on and after tag off (or check plot)');
    figure; plot(data.Pressure); set(gca,'ydir','rev')
end
if ~exist('Hzs','var')
    [accHz,gyrHz,magHz,pHz,lHz,GPSHz,UTC,THz,T1Hz] = sampledRates(fileloc,filename);
    Hzs = struct('accHz',accHz,'gyrHz',gyrHz,'magHz',magHz,'pHz',pHz,'lHz',lHz,'GPSHz',GPSHz,'UTC',UTC,'THz',THz,'T1Hz',T1Hz);
end


%load cal file
cf = pwd; cd(fileloc);
% try load([vol ':\' folder '\Calibration\CATScal' num2str(tagnum) '.mat']);
rootDIR = strfind(fileloc,'CATS'); rootDIR = fileloc(1:rootDIR+4);
try CAL = load([rootDIR 'Calibrations' '\CATScal' num2str(tagnum) '.mat']);
    disp(['CATScal' num2str(tagnum) '.mat loaded']);
catch
    [calfile,calfileloc]=uigetfile('*.mat', 'select CATS cal file'); %look below to save time to make truncated files okay
    CAL = load([calfileloc calfile]);
    if isempty(regexp(calfile,num2str(tagnum))); error('Cal file does not match tag num, restart cell at next line to continue'); end
end
cd(cf);

disp('Section 3 finished');
   CellNum = 3;
      save([fileloc filename(1:end-4) 'Info.mat'],'CellNum','Hzs','CAL','df','ofs','Afs','-append');
%% 4. adjust video times to match data times 
% This is mostly for legacy data that does not have accurate start times(see below), but run it anyway as it sets up some variables.
% for pre-wireless data:
% Makes graphs where boxes should line up with surfacings and displays some values indicating how much each video needs to be adjusted.

synchusingvidtimestamps = true; % for newer videos where timestamp from data is imprinted on video
nocam = false; % set to true if this is a data only tag. If there is just audio, keep at true.  Will have to set audon independently

GPS = cell2mat(headers(2,2:3)); %from above file
whaleName = char(headers(1,2));
timedif = cell2mat(headers(3,2)); % The number of hours the tag time is behind (if it's in a time zone ahead, use -).  Also account for day differences here (as 24*# of days ahead)
load([fileloc filename(1:end-4) 'Info.mat'],'Afs','ofs','CAL','Hzs');
if ~exist('data','var'); load([fileloc filename(1:end-4) 'truncate.mat']); end
DNorig = data.Date+data.Time+timedif/24;

if nocam
    camon = false(size(DNorig)); audon = false(size(DNorig)); vidDN = []; tagslip = [];
else
   viddata = load([fileloc filename(1:end-4) 'movieTimes.mat']); %load frameTimes and videoDur from the movies, as well as any previously determined info from previous prh makings with different decimation factors
   % this script makes a few variables, but its main purpose is to
   % synchronize video and data using surfacings for videos that do not
   % have a record of their start times (i.e. collected independently of the diary data)
   [camon,audon,vidDN,vidDurs,nocam,tagslip] =  synchvidsanddata(data,headers,viddata,Hzs,DNorig,ODN,ofs,CAL,synchusingvidtimestamps);
end
   CellNum = 4;
     save([fileloc filename(1:end-4) 'Info.mat'],'camon','audon','tagslip','GPS','whaleName','tagnum','DNorig','vidDN','vidDurs','timedif','CellNum','nocam','-append');
disp('Section 4 done');
%% 5. get tagon and tagoff times 
% id tagon and tagoff times by zooming in and selecting the boundaries of
% time on the whale.
% output: tagon and tagoff variables in workspace
% After finishing this, update TAG GUIDE with the actual tag on and tag off
% times as well as the Video Time

load([fileloc filename(1:end-4) 'Info.mat'],'ofs','camon','audon','nopress');
if ~exist('data','var'); load([fileloc filename(1:end-4) 'truncate.mat']); end

% tests for existence of pressure data (since most scripts rely on having pressure data)
if ~exist('nopress','var') && sum(isnan(data.Pressure)) == length(data.Pressure) || sum(diff(data.Pressure) == 0) == length(data.Pressure) -1; nopress = true; else nopress = false; end

tagon = gettagon(data.Pressure,ofs,data.Date(1)+data.Time(1),[data.Acc1 data.Acc2 data.Acc3]); % final input could be anything you wish to use as confirmation (i.e. if you don't have Acc in your data, could use temperature etc.)
% inputs: Depth variable
%          fs (sampling rate)
%          starttime (matlab datenumber of the starttime- put 0 if unknown)
%          At (another comparable variable.  Set up to be Acceleration, but could use temperature or even depth again just to make the script work if no other data is available)
% output: tagon (an index of values for when the tag was on the whale

% 

disp(['Total Cam Time: ' datestr(sum(camon&tagon)/ofs/24/60/60,'HH:MM:SS')]);
disp(['Total Aud Time (in addition to cam time): ' datestr(sum(audon&tagon)/ofs/24/60/60,'HH:MM:SS')]);
disp(['Original data start time: ' datestr(ODN,'mm/dd/yy HH:MM:SS')]);
   CellNum = 5;
      save([fileloc filename(1:end-4) 'Info.mat'],'CellNum','tagon','nopress','-append');
disp('Section 5 done');
%% 6.
%Makes some variables(calibrated tag frame matrices Gt, At, Mt).  Also calibrates p by using the
%internal temperature applies a basic in situ calibration to Mt, but that will be fixed in the next step.

% Matlab packages required: Signal Processing Toolbox, Statistics and
% Machine Learning Toolbox

if ~exist('data','var'); load([fileloc filename(1:end-4) 'truncate.mat']); end
load([fileloc filename(1:end-4) 'Info.mat'],'ofs','DNorig','df','GPS','nopress','CAL','tagon','camon','audon','tagslip','Hzs');

disp(['New Sampling Rate: ' num2str(ofs/df);]);
if ofs/df ~= 10; warning('Final sampling rate does not equal 10 Hz'); end

%filterCATS needs improvement
DV = datevec(DNorig(1));
if DV(1,1)<2015; str = '2010'; elseif DV(1,1)<2020; str = '2015'; else str = '2020'; end
if isnan(GPS(1,1)) || isnan(GPS(1,2)); error('No GPS location (needed to calculate magnetic field'); end
try [~,~,dec,inc,b] = wrldmagm(0,GPS(1,1),GPS(1,2),decyear(DV(1,:)),str); % newest wrldmagm in subfunctions 
catch
   warning('''wrldmagm.m'' is not present or is throwing an error, input declination (deg), inclination (deg below horizon) and magnetic field strength (nanoTeslas)');
   disp('see, e.g.: https://www.ngdc.noaa.gov/geomag/calculators/magcalc.shtml#igrfwmm');
   dec = input('declination? ');
   inc = input('inclination? ');
   b = input('magnetic field strength? '); 
end
inc = -inc*pi/180; dec = dec*pi/180; b= b*10^-3; % inc is negative to match our axis system, b in microteslas
% the calibration files loaded above make the accelerations in g, the
% magnetometer readings in uTeslas, and the gyros in radians/sec.  The
% calibrations also orient the axes to be North-East-Down (right-hand
% rule), all angles counter clockwise rotations when looked at from the
% positive side of the third axis. decdc decimates the files by the
% decimation factor df.  filterCATS removes data spikes up to width 1/8 second in the original data bigger than 5% of
% the max-min difference of the smoothed data (window of 1 second to each
% side)

Depth = decdc(data.Pressure,df);
DN = DNorig(1:df:end,:); DN = DN(1:length(Depth));
[Depth,CAL] = pressurecal(data,DN,CAL,nopress,ofs,df,tagon,Hzs.pHz);
% get original cats cal values, but will likely be replaced in in situ
% cals.  Inspect for major errors but At and Mt will be recalibrated next.
% This uses bench cals (acal and aconst, not spherical cals)
[fs,Mt_bench,At_bench,Gt,DN,Temp,Light,LightIR,Temp1,tagondec,camondec,audondec,tagslipdec] = decimateandapplybenchcal(data,Depth,CAL,ofs,DN,df,Hzs,tagon,camon,audon,tagslip);
CellNum = 6;
save([fileloc filename(1:end-4) 'Info.mat'],'DN','fs','ofs','CAL','camondec','tagondec','audondec','tagslipdec','CellNum','Temp','Light','inc','dec','b','-append');
disp('Section 6 done');
%% 7a.  In situ cals
% Test an in situ calibration of acclerometer using spherical cal.
% you want the median value to be close to 1, but there should not be too
% much difference between the two of them.  Choose either the bench test or
% the in situ calibration.  If in situ doesn't converge (flat lines with 0
% residual), try limiting II.

% Matlab packages required: Signal Processing Toolbox

load([fileloc filename(1:end-4) 'Info.mat'],'tagondec','camondec','nocam','df','CAL','Hzs','b','ofs');
if ~exist('data','var'); load([fileloc filename(1:end-4) 'truncate.mat']); end
if ~exist('Depth','var')
    try pressTemp = data.TempDepthInternal; catch; try pressTemp = data.Temp1; catch; pressTemp = data.Temp; end; end
    Depth = decimateM((data.Pressure-CAL.pconst)*CAL.pcal+polyval([CAL.pc.tcomp,CAL.pc.poly(2)],pressTemp-CAL.pc.tref),ofs,Hzs.pHz,df,'pHz');
    try Temp = (data.Temp-CAL.Tconst)*CAL.Tcal; catch; Temp = data.Temp; end
    Temp = decimateM(Temp,ofs,Hzs.THz,df,'THz');
end

[At,Acal] = calA(data,tagondec,ofs,Hzs.accHz,df,CAL,Depth); % can input a sixth variable, I, that is the index of where to perform the calibration.  You would use this if there are bad parts of the data or really high acc somewhere that is throwing off the in situ cal.
At_mag = sqrt(sum(At.^2,2));
CAL.Acal = Acal;
save([fileloc filename(1:end-4) 'Info.mat'],'CAL','-append');
disp('Section 7a done');
%% 7b Calibrate Mag using spherical cal from animaltags.org 
% First tries spherical cal method using whole tag on time, then tries a
% temperature related calibration, then tries different cal on/ cal off
% periods.  Choose which one is best (flattest overall magnitude line closest to the magnetic
% field line).  If calibration does not converge (flat lines with 0
% residual), try restricting I or try using the pre-calibrated Mt to start.

% Matlab packages required: Signal Processing Toolbox
[Mt,Mcal] = calM(data,tagondec,camondec,camon,nocam,ofs,Hzs.magHz,df,CAL,Temp,b); % can input a twelfth variable, I, that is the index of where to perform the calibration.  You would use this if there are bad parts of the data somewhere that is throwing off the in situ cal.  A thirteenth variable, resThresh, could be set to lower or raise the threshold of what is acceptible before trying alternate calibration methods (e.g. cam on/camoff)

CAL.Mcal = Mcal;
Mt_mag = sqrt(sum(Mt.^2,2));
   CellNum = 7;
save([fileloc filename(1:end-4) 'Info.mat'],'CAL','CellNum','-append');
disp('Section 7b finished');


%% 8 Find orientation of tag on animal
% iteratively goes section by section, rotating tag frame to whale frame
% given user defined selection 

% Matlab packages required: Signal Processing Toolbox

load([fileloc filename(1:end-4) 'Info.mat'],'tagondec','tagslipdec','fs','ofs','camondec','nocam','nopress','df','CAL','Hzs','DN');
if ~exist('data','var'); load([fileloc filename(1:end-4) 'truncate.mat']); end
if ~exist('Depth','var')
    [Depth,At,Mt,Gt] = applyCal2(data,CAL,camondec,ofs,Hzs,df);
end
try load([fileloc filename(1:end-4) 'Info.mat'],'slips'); catch; end



% makes a graph
% 1. click where to break up the calibration periods (bottom graph is
% acceleration at each surfacing).  Use tag slips to help.  Each cal period must have a surfacing and a dive from the surface
% output: startsI and endsI (start and end indices of the calibration
% periods)

if exist('slips','var')
prelimslips = slips;
else prelimslips = tagslipdec;
end

slips = IDtagslips(DN,At,Depth,fs,tagondec,prelimslips,camondec);

save([fileloc filename(1:end-4) 'Info.mat'],'slips','-append');
disp('section 8.1 completed');

%% 8.2
% 2. left click on a few surfacings where accelerometers are stable, and right click on the boundaries of
% the first few seconds of a dive that looks like it has a smooth transition in the accelerometers.  Double check the
% boundaries before pressing enter.
% outputs: calperiodI which gives the indices of each surfacing/dive 
% W, the orietation matrix that converts tag frame to whale frame
% 
% To get the position of the tag on the whale, for as many surface
% intervals as possible, at least once per tag movement if possible,
% select >=1 surfacing where the accelerations are pretty consistent
% (because we are assuming the whale is not accelerating or changing
% orientation) and the first few seconds of a dive during which |acc| is approx 1

% Matlab packages required: Aerospace Toolbox

 load([fileloc filename(1:end-4) 'Info.mat'],'dec','slips');
 try  load([fileloc filename(1:end-4) 'Info.mat'],'W','calperiodI'); catch; end
 try  load([fileloc filename(1:end-4) 'Info.mat'],'tempslips'); catch; end
 if exist('W','var') && ~isempty(W) && ~all(cellfun(@isempty,W));
     W
     calperiodI
     s = input('start with previously saved W & calperiodI? 1 = yes, 2 = no ');
     if s ~=1; W = []; calperiodI = []; end
 else W = []; calperiodI = []; 
 end
 if exist('tempslips','var') && ~isempty(tempslips) 
      s = input('It appears that new tag slips were created in a previous running.  Do you want to use the new slips? 1 = yes, 2 = no ');
      if s == 1; slips = tempslips; end
 end 
  if length(W)~=length(calperiodI) || (~isempty(W) && length(W) ~= size(slips,1)-1); error('check input parameters'); end
 
[Aw,Mw,Gw,W,Wchange,Wchangeend,tagprh,pitch,roll,head,calperiodI,newslips,speedper] = estimatePRH(At,Mt,Gt,fs,DN,Depth,tagondec,dec,slips,calperiodI,W);
%
oldslips = slips; slips = newslips;
CellNum = 8;

plotprh;

disp('Press Enter to accept all calibrations (or ctrl-C to break and restart)');
pause
save([fileloc filename(1:end-4) 'Info.mat'],'slips','oldslips','CellNum','W','calperiodI','Wchange','Wchangeend','tagprh','speedper','-append');
disp('Section 8.2 done');


%% 9. (removed)- calibrate gyroscopes in situ.  Recalculate pitch, roll and heading using gyroscopes to be more accurate during times of high specific acceleration
% [GwUB, bias, pitchgy,rollgy,headgy] = unbiasgyro(Aw,fs,Gw,Mw,pitch,roll,head,tagondec,camondec)

%% 10a. Calculate flow noise from audio files 
% inputs audio file flow noise. 
% output: flownoise variable

% Matlab packages required: Signal Processing Toolbox

vars = load([fileloc filename(1:end-4) 'Info.mat'],'vidDN','vidDurs','vidNum','fs','ofs','camondec','tagondec','nocam','nopress','df','CAL','Hzs','DN');
if ~exist('data','var'); load([fileloc filename(1:end-4) 'truncate.mat']); end
if ~exist('Depth','var')
    Depth = applyCal2(data,vars.CAL,vars.camondec,vars.ofs,vars.Hzs,vars.df);   
end
vars.Depth = Depth;

audiodir = [fileloc 'AudioData\'];

load([fileloc filename(1:end-4) 'Info.mat'],'flownoise');
if exist('flownoise','var') && sum(isnan(flownoise))~=length(flownoise) 
    s = input('flownoise variable "DB" already exists and has data, overwrite?  (this will take some time) 1 = yes, 2= no ');
else s = 1;
end

if s == 1
    [flownoise,AUD] = getflownoise(audiodir,vars);
end

tag1 = find(vars.tagondec,1);
tag2 = find(vars.tagondec,1,'last');
    disp('Done importing, check out figure 300 to examine data for outliers');
% plot data.  Look for outliers, may have to remove data above a threshold
% if there are spikes
if sum(isnan(flownoise)) ~= length(flownoise)
    figure(300); clf; set(300,'windowstyle','docked');
    ax = plotyy(vars.DN(tag1:tag2),Depth(tag1:tag2),vars.DN(tag1:tag2),flownoise(tag1:tag2));
    set(ax(1),'ydir','rev');
    legend('Depth','Flow noise (dB)');
    ylabel('Depth (m)','parent',ax(1));
    ylabel('Flow noise (dB)','parent',ax(2));
    %         text(min(get(gca,'xlim')),max(get(gca,'ylim')),'Press Enter if okay, or click on the threshold above which points are considered outliers','verticalalignment','top','fontsize',16,'parent',ax300);
    %         [~,y,button] = ginput(1);
    
    %         if ~isempty(button)
    %             flownoise(flownoise>y) = nan;
    %             plot(tag1:tag2,DB(tag1:tag2),'s');
    %         end
end
clear vars
save([fileloc filename(1:end-4) 'Info.mat'],'flownoise','AUD','-append');
disp('Section 10a finished');

%% 10b calculates tag jiggle RMS across all three axes.  Makes a summary
% variable with three axes and the flownoise as the fourth (or the
% magnitude of the overall Jiggle if no flow noise) for comparison in the next step
% see Cade et al 2018 Determining forward speed from accelerometer jiggle in aquatic environments. Journal of Experimental Biology, 221, jeb170449.

% Matlab packages required: Signal Processing Toolbox

load([fileloc filename(1:end-4) 'Info.mat'],'Afs','CAL','fs','timedif','DN','flownoise','ofs');
if ~exist('data','var') || ~exist('Adata','var'); load([fileloc filename(1:end-4) 'truncate.mat']); end
names =fieldnames(CAL);
for ii = 1:length(names)
    eval([names{ii} ' = CAL.' names{ii} ';']);
end

% apply accelerometer calibrations to high-frequency sampled data.
if exist('Acal','var') && ~isempty(Acal)
    axA = (acal./abs(acal)); axA(isnan(axA)) = 0;
    A = Adata*axA;
    A = (A*diag(Acal.poly(:,1))+repmat(Acal.poly(:,2)',size(A,1),1))*Acal.cross;
else
    A = (Adata-repmat(aconst,size(Adata,1),1))*acal;
end

JX = TagJiggle(A(:,1),Afs,fs,[10 90],.5,Atime+timedif/24,DN); % 10 and 90 are the high-pass and low-pass filter frequencies. The higher number will have to be < .5* Afs.
JY = TagJiggle(A(:,2),Afs,fs,[10 90],.5,Atime+timedif/24,DN);
JZ = TagJiggle(A(:,3),Afs,fs,[10 90],.5,Atime+timedif/24,DN);
J = TagJiggle(A,Afs,fs,[10 90],.5,Atime+timedif/24,DN);

% speedP = Paddles; speedP(speedP == 0) = nan;
Jig = [JX JY JZ J];
CellNum = 10;
save([fileloc filename(1:end-4) 'Info.mat'],'CellNum','Jig','-append');
disp('Section 10b finished');
%
% use this to examine the two metrics of turbulent flow.  They should
% align, else you may have an offset issue between the data and the 
% acoustics (and likely video)
JJ = J; JJ(isnan(JJ)) = 0; JJ = runmean(JJ,fs);
D = flownoise; D(isnan(D)|isinf(D)) = min(D(~isinf(D)));  D = runmean(D,fs);
figure; plotyy(DN,JJ,DN,D);
legend('JiggleRMS','FlownoiseRMS')

% should not have to run this
% maxoffset = 2.5; % set with what you think the max offset would be
% AdjDataVidOffsets;
%% 11. SPEED. Calculate speed from jiggle and from flownoise using speed from RMS.  Adjust parameters below to adjust thresholds (or can adjust graphically within the program):
% outputs:
% speed (table with speed.FN, speed.JJ, speed.SP (OCDR from sine of pitch)
% speedstats (structure with thresholding and R2 information)
% JigRMS (jiggle for each axes used in the multivariate correlation)
% speedPlots folder with images of each plot

% Matlab packages required: Signal Processing Toolbox, Statistics and
% Machine Learning Toolbox, Curve Fitting Toolbox


load([fileloc filename(1:end-4) 'Info.mat'],'speedper','Jig','CAL','fs','timedif','DN','camondec','ofs','Hzs','df','W','slips','tagondec','flownoise');
if ~exist('data','var'); load([fileloc filename(1:end-4) 'truncate.mat']); end
if ~exist('At','var')
    [Depth,At,Mt,Gt] = applyCal2(data,CAL,camondec,ofs,Hzs,df);
end
if ~exist('pitch','var')
    [Aw,Mw,Gw] = applyW(W,slips(1:end-1,2),slips(2:end,1),At,Mt,Gt);
    [pitch,roll] = calcprh(Aw,Mw);
end


% set threshold parameters
minDepth = 5;
minPitch = 40;
% speedEnds = speedper(:,2);
minSpeed = 1;
% speedEnds([1 4 5 end-1:end]) = [];

if sum(isnan(flownoise)) == length(flownoise)
    RMS2 = []; lab = '';% could set RMS2 = Jig(:,4); lab = 'magJ'; if you want to compare the multiaxes model jig to the overall magnitude model
else
    RMS2 = flownoise; lab = 'FN';
end

[~,speed,speedstats] = SpeedFromRMS3(Jig(:,1:3),'JJ',RMS2,lab,fs,Depth,pitch,roll,DN,speedper,slips,tagondec,.5,0.5,minDepth,minPitch,minSpeed,.2);
X = Jig(:,1); Y = Jig(:,2); Z = Jig(:,3); Mag = Jig(:,4);
JigRMS = table(X, Y, Z, Mag);

if ~exist([fileloc 'SpeedPlots\'],'dir'); mkdir([fileloc 'SpeedPlots\']); end
for fig = [1 301:300+size(speedstats.r2used,1)]
    saveas(fig,[fileloc 'SpeedPlots\fig' num2str(fig) '.bmp']);
end


if sum(isnan(flownoise)) ~= length(flownoise)
    s = input('Would you like to recalibrate speed from flow noise using its own sections (1 = yes, 2 = no- click no if current calibration is good)? ');
    if s == 1
        disp('Can quit out of this and start cell again later if the results don''t seem to be improving');
        [~,speedFN,speedstatsFN] = SpeedFromRMS3(flownoise,'FN',[],'',fs,Depth,pitch,roll,DN,speedper,slips,tagondec,.5,0.5,minDepth,minPitch,minSpeed,.2);
        oi = speedFN.Properties.VariableNames;
        oi(cellfun(@(x) strcmp('section',x), oi)) = {'FNsection'};
        oi(cellfun(@(x) strcmp('sectionUsed',x), oi)) = {'FNsectionUsed'};
        speedFN.Properties.VariableNames = oi;
        for i = 1:length(oi); speed.(oi{i}) = speedFN.(oi{i}); end
        speedstats.FN.Models = speedstatsFN.Models;
        speedstats.FN.ModelFits = speedstatsFN.ModelFits;
        speedstats.FN.Thresh = speedstatsFN.Thresh;
        speedstats.FN.r2used = speedstatsFN.r2used;
        speedstats.FN.sections_end_index = speedstatsFN.sections_end_index;
    end
else
    speed.FN = nan(size(speed.JJ));
    try speed.FNP68 = []; speed.FNP95 = []; speed.FN95 = []; speed.FNr2 = [];catch; end
end


CellNum = 11;

disp('Section 11 (speed) finished');
save([fileloc filename(1:end-4) 'Info.mat'],'CellNum','JigRMS','speedstats','-append');




%% 12.
% save prh file.  At this point, basic orienation and motion data can be calculated, but after this step there are a few more steps
% to add GPS data and make the QuickLook file
% saves the variables listed below in **prh file.  Lists the frequency you
% used 
% Adjust "notes" below to add any notes about the prh file.

% Matlab packages required: Signal Processing Toolbox, Statistics and
% Machine Learning Toolbox, Mapping Toolbox

creator = 'DEC';
notes = '';

load([fileloc filename(1:end-4) 'Info.mat']);%,'nocam','speedstats','Temp','Light','JigRMS','CAL','fs','timedif','DN','flownoise','camondec','ofs','Hzs','df','dec','W','slips','tagondec','audondec');
if ~exist('data','var'); load([fileloc filename(1:end-4) 'truncate.mat']); end
% if ~exist('At','var');
    [p,At,Mt,Gt,T,TempI,Light] = applyCal2(data,CAL,camondec,ofs,Hzs,df);
% end
if ~exist('head','var')
    [Aw,Mw,Gw] = applyW(W,slips(1:end-1,2),slips(2:end,1),At,Mt,Gt);
    [pitch,roll,head] = calcprh(Aw,Mw,dec);
end
if ~exist('speed','var')
    speed = applySpeed(JigRMS,'JJ',flownoise,'FN',tagondec,p,pitch,roll,fs,speedstats);
end
CAL.info = 'Bench cals used for G, 3d in situ cal used for M, A and p. If A3d is empty, bench cal was used. If temp was used in Mag cal, there will be a "temp" variable in the structure; use appycalT to apply that structure to mag and temp data.  Axes must be corrected to NED before applying 3d cals, but not before applying original style bench cals since they take that into account';
tagon = tagondec; camon = camondec; tagslip = slips; 
%
if ~exist('frameTimes','var')
load([fileloc filename(1:end-4) 'movieTimes.mat'],'frameTimes','vidNam');
end
if ~nocam; viddeploy = find(vidDN<DN(find(tagon,1,'last')) & vidDN+vidDurs/24/60/60>DN(find(tagon,1))&~cellfun(@isempty,frameTimes)); end
if nocam; flownoise = nan(size(p)); vidDN = []; vidNam = []; vidDurs = []; viddeploy = [];  if ~exist('speed','var'); speed = table(nan(size(p)),nan(size(p)),nan(size(p)),'VariableNames',{'JJ' 'FN','SP'}); end; end
audon = audondec; 

INFO = struct;
INFO.whaleName = whaleName;
INFO.tagnum = tagnum;
INFO.notes = notes;
INFO.timedif = timedif; % time in hours that prh file differs from raw data (usually due to incorrect clock setting before deployment)
INFO.CAL = CAL;
INFO.W = W;
INFO.tagprh = tagprh;
INFO.calperiod = cellfun(@(x) DN(x),calperiodI,'uniformoutput',false);
INFO.calperiodI = calperiodI;
% INFO.tagslip.ObsonVid = tagslip; %tagslip indices from video observations
% INFO.tagslip.SpeedPeriods = speedstats.sections_end_index; %tagslip indices used for speed period calibrations
INFO.Wchange = Wchange; %tagslip indices used for tag rotation to animal frame (like Wcalperiods, but trying to find the actual slip)
INFO.tagslip = slips;
try INFO.TempInternal = TempI; catch; end
if nopress; INFO.NoPressure = true; end % if there's a tag with a messed up pressure sensor
a = [];
try 
    UTC = Hzs.UTC;
    a = ['(tag thinks it was ' num2str(UTC) ')'];
    INFO.UTC = getUTC(GPS(1),GPS(1,2),DN(1));
    if UTC~=INFO.UTC; a = [a(1:end-1) ', getUTC function calculated it as ' num2str(INFO.UTC) ')']; error(''); end
catch
    INFO.UTC = input(['UTC offset (hours from GMT at time of deployment)? ' a]);
end
disp(['UTC = ' num2str(INFO.UTC) ', if incorrect, set INFO.UTC and resave prhfile']); %save([fileloc prhfile],'INFO','-append');
INFO.prhcreated = date;
INFO.creator = creator;
try
    INFO.aud = AUD;
catch
    INFO.aud = nan; disp('No Audio Files');
end

CellNum = 12;
prhfile = [whaleName ' ' num2str(fs) 'Hzprh.mat'];
save([fileloc prhfile],'Aw','At','Gw','Gt','fs','pitch','roll','head','p','T','Light','Mt','Mw','GPS','DN','speed','speedstats','JigRMS','tagon','camon','vidDN','vidNam','vidDurs','viddeploy','flownoise','INFO','audon');
save([fileloc filename(1:end-4) 'Info.mat'],'prhfile','CellNum','INFO','-append');
disp('Section 12 finished, prh file and INFO saved');
%% 13. Import fastloc GPS data into file
% construct pos file from ubx file, then run this code (ENSURE prh and ALLDATA saved as this deletes all data)
% first graphs checks to make sure hits line up with deployment.  Usually just press enter if everything looks like it lines up
% bb190302-52 is a good one to figure out wtf is going on with the timestamps

clearvars -except prhfile fileloc filename
load([fileloc filename(1:end-4) 'Info.mat'],'prhfile','INFO');
close all
rootDIR = strfind(fileloc,'CATS'); rootDIR = fileloc(1:rootDIR+4); % rootDIR can be used to locate the TAG GUIDE for importing further data about the tag

addGPS(fileloc); %catch; disp('No GPS file found or error in adding tag GPS'); end
%% Make a "GPShits.xlsx" file with Time, Lat, Long from any other manual locations (like deployment or focal follows or Argos)
% If no manual hits exist, can press enter to just use tag on and recovery
% locations from tag guide
% This step also allows you to manually adjust auto GPS points, so worth
% running.

manualGPS2prh(fileloc,prhfile); %catch; disp('No GPS file found or error in adding manual GPS hits'); end
% Run this file to check georeferenced pseudotracks.  May have to go back a step to adjust points more once you see the track
load([fileloc prhfile]);
if DV(1,1)<2015; str = '2010'; elseif DV(1,1)<2020; str = '2015'; else str = '2020'; end
[~,~,dec,inc,b] = wrldmagm(0,GPS(1,1),GPS(1,2),decyear(DN(1)),str); % after 2015 or before 2010 use igrf11magm with the same parameters, or if you want to account for changes during deep dives
inc = -inc*pi/180; dec = dec*pi/180; b= b*10^-3; % i
AA = Aw;
for i = 1:3; AA(:,i) = fixgaps(Aw(:,i)); end
[fpk,q] = dsf(AA(tagon,:),fs,fs); % determine dominant stroke frequency;
disp(['dominant stroke frequency: ' num2str(fpk) ' quality: ' num2str(q)]);
[bodypitch,bodyroll] = a2pr([AA(:,1:2) -AA(:,3)],fs,fpk/2); bodyroll = -bodyroll; %uses Johnson method and then rotates back to normal axis orientation.
bodyhead = wrapToPi(m2h([Mw(:,1:2) -Mw(:,3)],[AA(:,1:2) -AA(:,3)],fs,fpk/2)+dec);

sp = speed.JJ;
% can use regular pitch or head if bodypitch or bodyhead have errors.
% Bodypitch and bodyhead are just smoothed versions of pitch and head
% uncomment this part if you may have sleeping whales
sp(isnan(sp)) = 0;
sp(p<1) = 0.1; sp = runmean(sp,fs);

[t,pt,newspeed,newhead] = gtrack(bodypitch,bodyhead,p,fs,sp,tagon,DN,[nan nan; GPS(2:end,:)],GPSerr,[3 3 3],0);


% make a ptrack if no geo information at all (come back with gps info later)
% nhead = fixgaps(bodyhead); nhead(isnan(nhead)) = 0;
% pthresh = 5; sp = speed.JJ; sp2 = sp; sp2(isnan(sp2)) = min(sp2); sp2 = runmean(sp2,2*fs); sp2(p<=pthresh) = nan; sp2 = fixgaps(sp2); sp(p<=pthresh) = sp2(p<=pthresh); sp = fixgaps(sp); sp(isnan(sp)) = min(sp); 
% PT = ptrack(bodypitch(tagon),nhead(tagon),p(tagon),fs,[],sp(tagon));
% pt = nan(size(Aw)); pt(tagon,:) = PT;
% t = pt(:,1);
% pt(:,1) = pt(:,2); pt(:,2) = t; clear t;
% CATS2TrackPlot(head,pitch,roll,tagondec,DN,fs,pt,false,INFO.whaleName,1.25,[rootDIR 'TrackPlot\']);

Gfig = gcf;

if ~exist([fileloc 'QL\'],'dir'); mkdir([fileloc 'QL\']); end
geoPtrack = t; Ptrack = pt; 

UTC = getUTC(GPS(1),GPS(1,2),DN(1));
t1 = find(tagon,1);
gI = find(~isnan(GPS(:,1)));
[~,b] = min(abs(gI-t1)); gI = gI(b);
gtrack2kml(geoPtrack,tagon,fs,DN,1/60,GPS(gI),GPS(gI,2),UTC,INFO.whaleName,fileloc)

%% Once you have a good track, run this file to save all the results, including trackplot and kml file
save([fileloc INFO.whaleName ' ' num2str(fs) 'Hzprh.mat'],'geoPtrack','Ptrack','head','-append');
saveas(Gfig,[fileloc 'QL\' INFO.whaleName 'ptrack.bmp']);
savefig(Gfig,[fileloc 'QL\' INFO.whaleName 'ptrack.fig']);
saveas(102,[fileloc INFO.whaleName 'geotrack.bmp']);
savefig(102,[fileloc 'QL\' INFO.whaleName 'geotrack.fig']);

prh2Acq(fileloc,[INFO.whaleName ' ' num2str(fs) 'Hzprh.mat']);

% first option makes just the DMA file, second option uses the pseudotrack,
% third option uses the geocorrected pseudotrack.
% CATS2TrackPlot_DMA(fileloc,[whaleName ' ' num2str(fs) 'Hzprh.mat']);
rootDIR = fileloc(1:strfind(fileloc,'CATS')+4);
copyfile([fileloc INFO.whaleName ' ' num2str(fs) 'Hzprh.mat'],[rootDIR 'tag_data\prh\' INFO.whaleName ' ' num2str(fs) 'Hzprh.mat']);


t1 = find(~isnan(Ptrack(:,1)),1)+1; t2 = find(~isnan(Ptrack(:,1)),1,'last')-1;
% uncomment line if you have nans before and after tag on;
% head(isnan(head)) = 0; pitch(isnan(pitch)) = 0; roll(isnan(roll)) = 0; Ptrack(1:t1,:) = repmat(Ptrack(t1,:),t1,1); Ptrack(t2:end,:) = repmat(Ptrack(t2,:),length(p)-t2+1,1); geoPtrack(1:t1,:) = repmat(geoPtrack(t1,:),t1,1); geoPtrack(t2:end,:) = repmat(geoPtrack(t2,:),length(p)-t2+1,1);

CATS2TrackPlot(head,pitch,roll,tagon,DN,fs,Ptrack,false,INFO.whaleName,1.25,[rootDIR 'tag_data\TrackPlot\']);
CATS2TrackPlot(newhead,pitch,roll,tagon,DN,fs,geoPtrack,true,[INFO.whaleName 'geo'],1.25,[rootDIR 'tag_data\TrackPlot\']);

CATSnc([fileloc INFO.whaleName ' ' num2str(fs) 'Hzprh.mat'],[rootDIR 'TAG GUIDE.xlsx']);
copyfile([fileloc INFO.whaleName '_prh' num2str(fs) '.nc'],[rootDIR 'tag_data\prh\nc\' INFO.whaleName '_prh' num2str(fs) '.nc']);
% to get lats and longs of geoPtrack, run:
% Gi = find(~isnan(GPS(:,1))); [~,G0] = min(abs(Gi-find(tagon,1))); G1 = GPS(Gi(G0),:);  [x1,y1,z1] = deg2utm(G1(1),G1(2)); [Lats,Longs] = utm2deg(geoPtrack(tagon,1)+x1,geoPtrack(tagon,2)+y1,repmat(z1,sum(tagon),1)); lats = nan(size(tagon)); longs = lats; lats(tagon) = Lats; longs(tagon) = Longs;

%% needs images generated from above script as well as:
% pics&vids folder with ID_... labeled and TAG_.... labeled. (and drone_... labeled if applicable) 
% Also needs  spyymmdd-tag#kml.jpg and spyymmdd-tag#map.jpg from google earth plot
% and tag video still jpg (spyymmdd-tag#cam.jpg) in the QL folder.  For single cams, best is to also have a second file (spyymmdd-tag#cam2.jpg) that will be displayed side by side.
% whaleID = 'be180424-41';
% fileloc = ['E:\CATS\tag_data\' whaleID ' (South Africa)\'];
% rootDIR = fileloc(1:strfind(fileloc,'CATS')+4);

makeQuickLook(fileloc);
whaleID = INFO.whaleName;
copyfile([fileloc '_' whaleID 'Quicklook.jpg'],[rootDIR 'tag_data\Quicklook\' whaleID 'Quicklook.jpg']);
function data = get_trapping_field(data,plottingOption)
% function data = get_trapping_field(path,plottingOption)
% generate the data structure 'data', which stores the information for trap operation.
% The electrodes are ordered as E(1), ..., E(NUM_ELECTRODES)=E(RF)
% i.e. the NUM_ELECTRODES-1 is the center electrode bias, and the NUM_ELECTRODES is the RF electrode bias
% (if center and RF are used)  
%
% path: path to the simulation text files
% position: trapping position along the trap axis. Millimeters or microns
% dataNames: the file name of the simulation data
% plottingOption: plotting option for sanity checks
% scale: scale of the simulated structure. 1 is mm, 1e-3 is micron
% zMin,zMax,zStep: range covered by all simulations, and range of each simulation
% NUM_ELECTRODES: number of used DC electrodes
%
% the consecutive data srtuctures must have overlapping
% first and last points, i.e. pt[I].Z(31) = pt[I+1].Z(1)
%
% Rules:
% *All the electrodes are assumed to be DC electrodes to begin with.
% *The sequence for counting DC electrodes runs through left side of the RF 
% (bottom to top), right side of the RF (bottom to top), center electrodes 
% inside of the RF (left center, then right center), and finalLy RF. 
% *To specify that an electrode is grounded, go to project_parameters and
% set the corresponding parameter in electrodeMapping to 0 
% 
% Base code by Mike, modified by Gebhard Oct 2010. The conventions where 
% redefined/cleaning up/combined with later developments by Nikos Jun 2013
%
% Nikos 2009. 
% Cleaned 26-05-2013, 10-23-2013

print_underlined_message('start','get_trapping_field');
path = data.systemInformation.matDataPath;
dataNames = data.systemInformation.dataNames;
position = data.trapConfiguration.trappingPosition;
zMin = data.trapConfiguration.zMin;                                         
zMax = data.trapConfiguration.zMax;                                        
zStep = data.trapConfiguration.zStep;
NUM_ELECTRODES = data.trapConfiguration.NUM_ELECTRODES;

nMatTot = round((zMax-zMin)/zStep);                  % nMatTot: the number of overlapping data structures?
if nMatTot ~= data.trapConfiguration.nMatTot
    fprintf('get_trapping_field: Check your defintion of zMin, zMax, nMatTot.\n');
end
zLim = zMin:zStep:zMax;                                     % define an array with the ranges of .mat-files
noStitch = false;

I = find(zLim>position,1,'first')-1;                        % find in which of the .mat-files the chosen position is centered

if (I<1)||(I>nMatTot),
    fprintf('Invalid ion position. Quitting.\n');
    print_underlined_message('stop_','get_trapping_field');
    return
end

% create a new grid by joining adjacent ones (current with either left or right one; that is
% determined by the sign of N). If position is in the first or last grid, just use those
N = sign(2*position-zLim(I)-zLim(I+1));
if (I==1)&&(N==-1),
    % If the ion is in the first half of the first grid, just use the first grid
    d = load([sprintf('%s',path),sprintf('%s',dataNames),'_1.mat']); 
    %fprintf('');% nd 04/30/2014
    data.Simulation = d.Simulation;
    noStitch = true;
elseif (I==nMatTot)&&(N==1),
    % If the ion is in the second half of the last grid, just use the last grid
    d = load([sprintf('%s',path),sprintf('%s',dataNames),sprintf('_%i.mat',nMatTot)]); 
    data.Simulation = d.Simulation;
    noStitch = true;
else
    % If the ion is somewhere in between
    d = load([sprintf('%s',path),sprintf('%s',dataNames),sprintf('_%i.mat',I)]); 
    Simulation0=d.Simulation;
    fieldnames(Simulation0);
    [dum K] = min(abs(Simulation0.Z-position));
    clear Simulation0;
    if N == 1,
        % pos lies closer to the next .mat-grid than the last grid 
        d = load([sprintf('%s',path),sprintf('%s',dataNames),sprintf('_%i.mat',I)]);
        Simulation1 = d.Simulation;
        d = load([sprintf('%s',path),sprintf('%s',dataNames),sprintf('_%i.mat',I+N)]); 
        Simulation2 = d.Simulation;
        [dum K] = min(abs(Simulation1.Z-position));
        K1 = K-floor(numel(Simulation1.Z)/2); % these are not the neatest definitions, but ok for now
        K2 = numel(Simulation1.Z);    
        K3 = 2; 
        K4 = K-floor(numel(Simulation1.Z)/2);
    elseif N  == -1,
        % pos lies closer to the last .mat-grid than the next grid 
        d = load([sprintf('%s',path),sprintf('%s',dataNames),sprintf('_%i.mat',I+N)]); 
        Simulation1 = d.Simulation;
        d = load([sprintf('%s',path),sprintf('%s',dataNames),sprintf('_%i.mat',I)]); 
        Simulation2 = d.Simulation;
        K1 = K+floor(numel(Simulation1.Z)/2);
        K2 = numel(Simulation1.Z)-1;
        K3 = 1; 
        K4 = K+floor(numel(Simulation1.Z)/2);
    else
        d = load([sprintf('%s',path),sprintf('%s',dataNames),sprintf('_%i.mat',I)]); 
        data.Simulation = d.Simulation;
        print_underlined_message('stop_','get_trapping_field');
        return
    end
end

if ~noStitch
    data.Simulation = Simulation1;
    for i=K1:K2         
        data.Simulation.Z(i-K1+1) = Simulation1.Z(i); 
        data.Simulation.EL_RF(:,:,i-K1+1) = Simulation1.EL_RF(:,:,i);
        for iii=1:(NUM_ELECTRODES)
            if isfield(Simulation1,['EL_DC' num2str(iii)]),
                data.Simulation.(['EL_DC' num2str(iii)])(:,:,i-K1+1) = Simulation1.(['EL_DC' num2str(iii)])(:,:,i);
            end
            if isfield(Simulation1,['mEL_DC' num2str(iii)]),        % logic error here: mEL_DC always exists, but it is zero if unused. if case is unnecessary. 12-10-2013
                data.Simulation.(['mEL_DC' num2str(iii)])(:,:,i-K1+1) = Simulation1.(['mEL_DC' num2str(iii)])(:,:,i);
            end
        end
    end

    for i=K3:K4        
        data.Simulation.Z(i-K3+max(K2-K1,-1)+2) = Simulation2.Z(i); 
        data.Simulation.EL_RF(:,:,i-K3+max(K2-K1,-1)+2) = Simulation2.EL_RF(:,:,i); 
        for iii=1:(NUM_ELECTRODES)
            if isfield(Simulation2,['EL_DC' num2str(iii)]),
                data.Simulation.(['EL_DC' num2str(iii)])(:,:,i-K3+max(K2-K1,-1)+2) = Simulation2.(['EL_DC' num2str(iii)])(:,:,i);
            end
            if isfield(Simulation2,['mEL_DC' num2str(iii)]),       % logic error here: mEL_DC always exists, but it is zero if unused. if case is unnecessary. 12-10-2013
                data.Simulation.(['mEL_DC' num2str(iii)])(:,:,i-K3+max(K2-K1,-1)+2) = Simulation2.(['mEL_DC' num2str(iii)])(:,:,i);
            end
        end 
    end
    data.Simulation.grid = [min(data.Simulation.X) min(data.Simulation.Y) min(data.Simulation.Z) ...
                            Simulation1.grid(4) Simulation1.grid(5) Simulation1.grid(6)];
end
    
if plottingOption,
    midIndex = round(numel(data.Simulation.Z)/2); 
    for el = 1:NUM_ELECTRODES
        plot_potential(data.Simulation.(['EL_DC' num2str(el)]),...
            midIndex,midIndex,midIndex,...
            data.Simulation.grid,'1d plots',sprintf('%i-th electrode potential',el),'Static potential (V)','','');
        pause;
    end
 	plot(data.Simulation.Z,'--*'); 
 	title('get_trapping_field.m check: you will see a straight line if the data was generated successfully.');
    pause
end
print_underlined_message('stop_','get_trapping_field');

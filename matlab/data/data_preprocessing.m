%% Download China 309 City-level MRIO Table  (from https://www.ceads.net/data/input_output_tables?#1282). It is an open economy.
% Rename 'China city MRIO_2017.mat' to 'CityLevelMRIO2017.mat'

%% Importing China Provincial-level MRIO 2017 (from https://www.ceads.net/data/input_output_tables?#1087). It is an open economy.

%Name the downloaded Excel file as 'MRIO2017.xlsx'.

R_MRIO2017  = 31; % Number of regions.
S_MRIO2017  = 42; % Number of sectors.

Z_MRIO2017 = readmatrix('MRIO2017.xlsx','Sheet','Table_2017_consistent','Range','D5:AXE1306'); % Intermediate flows.
VA_MRIO2017 = readmatrix('MRIO2017.xlsx','Sheet','Table_2017_consistent','Range','D1313:AXE1313'); % Value added.
C_MRIO2017 = readmatrix('MRIO2017.xlsx','Sheet','Table_2017_consistent','Range','AXG5:BDE1306'); % Consumptions.
C_MRIO2017 = C_MRIO2017 * kron(eye(R_MRIO2017),ones(5,1)); % Summing up 5 colunms of consumption in each region.
E_MRIO2017 = readmatrix('MRIO2017.xlsx','Sheet','Table_2017_consistent','Range','BDF5:BDF1306');  
IP_MRIO2017 = readmatrix('MRIO2017.xlsx','Sheet','Table_2017_consistent','Range','D1307:AXE1307'); % Imports by producing sectors.
IC_MRIO2017 = readmatrix('MRIO2017.xlsx','Sheet','Table_2017_consistent','Range','AXG1307:BDE1307'); % Imports by consumptions.
IC_MRIO2017 = IC_MRIO2017 * kron(eye(R_MRIO2017),ones(5,1)); % Summing up 5 colunms of imported consumption in each region.

% Save key variables.
save('ProvinceLevelMRIO2017.mat', 'R_MRIO2017', 'S_MRIO2017', ...
    'Z_MRIO2017', 'VA_MRIO2017', 'C_MRIO2017', 'E_MRIO2017', 'IP_MRIO2017', 'IC_MRIO2017');

%%  Importing Eora26 2016 (in basic prices) (from https://worldmrio.com/eora26/). 
% Eora26 includes 189 specific countries (regions) and Rest of the World (ROW), totaling 190 regions. It is a closed economy.
FD_Eora26 = load('Eora26_2016_bp_T.txt');   % Intermediate flows. 
VA_Eora26 =  load('Eora26_2016_bp_VA.txt'); % Value added.
VA_Eora26 = sum(VA_Eora26); % Summing up all types of value added into one row.
C_Eora26 =  load('Eora26_2016_bp_FD.txt'); % Consumptions.
C_Eora26 = C_Eora26* kron(eye(190),ones(6,1)); % Summing up 6 colunms of consumption in each region.

% For research convenience, we treat the 189 specific countries (regions) in Eora26 as an open economy (relative to Rest of the World, ROW).
R_EORA2016   = 189; % Number of regions.
S_EORA2016   = 26; % Number of sectors.
Z_EORA2016 = FD_Eora26(1:4914, 1:4914);   % Intermediate flows. 
VA_EORA2016 =  VA_Eora26(1,1:4914); % Value added.
C_EORA2016 =  C_Eora26(1:4914,1:189); % Consumptions.

IP_EORA2016 = FD_Eora26(4915, 1:4914);  %Imports by producing sectors.
E_EORA2016 = FD_Eora26(1:4914, 4915);  
IC_EORA2016 = C_Eora26(4915, 1:189);  % Imports by consumptions.
                                        

% Save key variables.
save('EORA2016.mat', 'R_EORA2016', 'S_EORA2016', ...
    'Z_EORA2016', 'VA_EORA2016', 'C_EORA2016',...
    "IP_EORA2016","E_EORA2016","IC_EORA2016");

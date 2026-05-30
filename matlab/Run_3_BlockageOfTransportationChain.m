%% Clear and load data.
% Clear memory.
clear; clc; close all

% Load file.
tic % Start timing.

% Load MRIO data.
load('EORA2016.mat'); % Unit: 1000 $.

% Load water intensity and water resource data.
% Please load data from the disk!

% Load periods for transportion between regions (integers, at least 1).
TransportationDays=readmatrix("TransportationDays_CountriesInWorld.xlsx","Sheet","TransportationDays");

% Load transportation line blockage data (optional).
TransportationLineBlockageData=readmatrix("TransportationLineBlockageData4.xlsx","Sheet","TransportationLineBlockageData");

% Load the conversion matrix from sectors to aggregate sectors.
... The rows represent products in MRIO table, and the columns are aggregate products 
... which are used as inputs to the Leontief production function.
... In the matrix, 1 means the row product belongs to the column aggregate proudct, and 0 otherwise.
... If it is an identity matrix, the original product classification 
... will be the same as the aggregate product classification, and
... WorldOfMatrix_GPU will be the same as WorldOfMatrix_Water, but the speed will be a little faster.
... Experiments show that when inventories are small, aggregation will reduce losses;
... otherwise using aggregation will slightly increase losses.
S2Sa = readmatrix('S2Sa.xlsx', 'Sheet', 'S2Sa_Identical_EORA');

MATLAB_RUNTIME_0_Load = toc; % End timing.

%% Setting the following variables for simulation:
% Length of each time step, as a fraction of input flows:
delta_t = 1/365;

% Total periods of simulation:
day_total = 20;

% Default targeted inventory periods:
% Note: This is (1 + the number of periods the remaining inputs would last after the current production ends).
... Therefore, it should be >= 1.
ndays_Target_Default = 3.5;

% Periods for transportion between regions (integers, at least 1):
%MRIO_Dist = ones(189, 189);
% In fact, trasportation line lengths in CLUES model are the lengths of
... lines that stays in transportation steps.
... Therefore, it is tranportation period - 1.
... For example, if the tranportation period is 1 (i.e., arriving next period),
... there will be no goods staying in the intermediate transportation steps,
... so, the trasportation line length is 1 - 1 = 0.
MRIO_Dist = TransportationDays - 1;

% Water required for unitary output of each production agent (i.e., region-sector):
% Note: At least 1 water intensity should be nonzero to avoid computational error.
AgentsP_WaterIntensity = ones(189*26, 1); % MRIO_R*MRIO_S column vector. 

%% Define China's economy and initialize the model.
GlobalEcon = WorldOfMatrix_GPU; % China's economy is our World.

% Basic Input-Output variables.
GlobalEcon.MRIO_R = R_EORA2016; % Number of regions.
GlobalEcon.MRIO_S = S_EORA2016; % Number of sectors in each region.
GlobalEcon.MRIO_Z = Z_EORA2016; % Intermediate flows (in a year) between region-sector pairs.
GlobalEcon.MRIO_C = C_EORA2016; % Consumption of each region.
GlobalEcon.MRIO_VA = VA_EORA2016; % Value added of each region-sector.

% Define open-economy variables.
% ONLY NEEDED FOR OPEN ECONOMIES.
GlobalEcon.OpenEcon = true; % EORA is an open economy.
GlobalEcon.MRIO_E = E_EORA2016; % Exports.
GlobalEcon.MRIO_IP = IP_EORA2016; % Imports by sectors.
GlobalEcon.MRIO_IC = IC_EORA2016; % Imports by consumption.

% Length of each time step, as a fraction of input flows.
GlobalEcon.delta_t = delta_t;
% Default targeted inventory days.
GlobalEcon.ndays_Target_Default = ndays_Target_Default;
% Distance (i.e., steps in the transportation line) between regions.
GlobalEcon.MRIO_Dist = MRIO_Dist;
% Water required for unitary output of each production agent.
GlobalEcon.AgentsP_WaterIntensity = AgentsP_WaterIntensity;
% A conversion matrix, each row is a product and each column is an aggregate product. 
% The value is 1 if the column is aggregate product for the row product, otherwise is 0.
GlobalEcon.S2Sa = S2Sa; % Use the imported conversion matrix.
% ChinaEcon.S2Sa = eye(ChinaEcon.MRIO_R*ChinaEcon.MRIO_S); % Use the indentity matrix, so aggregate sectors are the same as original sectors.

%% Initialize the World.
tic % Start timing.
GlobalEcon = GlobalEcon.InitializeBasicVariables_UsingMRIO;
MATLAB_RUNTIME_1_1_InitializeBasic = toc; % End timing.

tic % Start timing
GlobalEcon = GlobalEcon.InitializeProductionAgents_UsingMRIO;
MATLAB_RUNTIME_1_2_InitializeProduction = toc; % End timing.

tic % Start timing
GlobalEcon = GlobalEcon.InitializeConsumptionAgents_UsingMRIO;
MATLAB_RUNTIME_1_3_InitializeConsump = toc; % End timing.

tic % Start timing
GlobalEcon = GlobalEcon.InitializeTransportationAgents_UsingMRIO;
MATLAB_RUNTIME_1_4_InitializeTransport = toc; % End timing.

%% Define key variables to be recorded.
% Evolution of value-added of all Countries-sectors from day 1 to day_total.
... Each row represents a production agent (Country-sector in this case).
S0_Evolution_ValueAdded_ProductionAgents = zeros(GlobalEcon.N_P, day_total);
S0_Evolution_Invertory = zeros(4914*26, day_total);

% Steady-state value-added of Country-sectors (each simulation step).
SS_AgentsP_VA = GlobalEcon.AgentsP_VA;

% Matrix for converting Country-sector results to Country results.
RegionSectors2Regions = kron(eye(GlobalEcon.MRIO_R),ones(GlobalEcon.MRIO_S,1));

% Steady-state value-added of Country-sectors (each simulation step).
SS_Countries_VA = RegionSectors2Regions' * SS_AgentsP_VA;

% Evolution of the trade network between Countries (for products coming into the Countries).
... Eeah layer is a square matrix of product flows, where the row represent the sending Country, and the column represents the receiving Country.
S0_ProductInNetwork_Countries = zeros(GlobalEcon.MRIO_R, GlobalEcon.MRIO_R, day_total);
S0_ProductInNetwork_Countries_Change = zeros(GlobalEcon.MRIO_R, GlobalEcon.MRIO_R, day_total); % Change relative to the steady state.
% Steady state trade network.
SS_ProductInNetwork_Countries = RegionSectors2Regions' * GlobalEcon.AgentsP_ProductInP * RegionSectors2Regions;

% Evolution of Scarcity Indices for each product in each region.
... Eeah layer is a R * S matrix: rows are regions, and columns are sectors (i.e. products).
S0_Evolution_Scarcity_RegionsProducts =  zeros(GlobalEcon.MRIO_R,GlobalEcon.Sa,day_total);

%% SIMULATE NETWORK DYNAMICS AND RECORD KEY VARIABLES.
tic % Start timing

for day=1:day_total % Days for simulation. 
    disp(day);
    % To simulate the impact of losses in production capacity:
    % We can revise the property obj.AgentsP_Theta of the WorldOfMatrix_GPU object:
    % obj.N_P * 1: Reduction in production capacity relative to pre-event level, in [0,1].
%     if day==1 % For example, production capacity loss in the fist period:
%         ChinaEcon.AgentsP_Theta(1) = 0.4;
%     else % After that:
%         ChinaEcon.AgentsP_Theta(1) = 0;
%     end

    % To simulate the impact of resource constraints:
    % We can revise the property obj.WaterConstraints of the WorldOfMatrix_Water object:
    % obj.MRIO_R*1 vector: Water constraints for each MRIO region, FOR THE CURRENT SIMULATION PERIOD.
%     if day==1 % For example, in the first period, water availability is 90% of the steady state level.
%         ChinaEcon.WaterConstraints = ChinaEcon.WaterConstraints * 0.9;
%     else % Very abundant water. PLEASE USE THIS IN EACH SIMULATION PERIOD IS THERE IS NO WATER CONSTRAINT!
%         ChinaEcon.WaterConstraints = ones(size(ChinaEcon.WaterConstraints)) * (sum(ChinaEcon.AgentsP_SS_Xcap) * 10 + 1e10);
%     end

    %% This part calculates movements in transportation lines.
    % DON'T REVISE THIS SECTION IF THERE IS NO TRANSPORTATION LINE OBSTRUCTION.

    % Tranportation lines:
    % Load, move, and unload goods in the transportation chains.
    % Move one step forward (creating augumented transportation lines), for P2P.
    GlobalEcon.AgentsT_P2P = [ zeros(GlobalEcon.nl_NetPP,1), GlobalEcon.AgentsT_P2P ];
    % Calculate products loaded to each transportation lines.
    GlobalEcon.AgentsT_P2P(GlobalEcon.AgentsT_P2P_StartLinInd) = GlobalEcon.AgentsP_ProductOutP(GlobalEcon.k_NetPP);
    % Move one step forward (creating augumented transportation lines), for P2C.
    GlobalEcon.AgentsT_P2C = [ zeros(GlobalEcon.nl_NetPC,1), GlobalEcon.AgentsT_P2C ];
    % Calculate products loaded to each transportation lines.
    GlobalEcon.AgentsT_P2C(GlobalEcon.AgentsT_P2C_StartLinInd) = GlobalEcon.AgentsP_ProductOutC(GlobalEcon.k_NetPC);  

    % Transportation line obstruction.
    for  k=TransportationLineBlockageData
        if (day>=k(4))&& (day<=k(5))
        GlobalEcon = GlobalEcon.TransportObstruct_MRIO(k(1), k(2), 1, k(3), k(6));
        GlobalEcon = GlobalEcon.TransportObstruct_MRIO(k(1), k(2), 2, k(3), k(7));
        GlobalEcon = GlobalEcon.TransportObstruct_MRIO(k(1), k(2), 3, k(3), k(8));
        GlobalEcon = GlobalEcon.TransportObstruct_MRIO(k(1), k(2), 4, k(3), k(9));
        GlobalEcon = GlobalEcon.TransportObstruct_MRIO(k(1), k(2), 5, k(3), k(10));
        GlobalEcon = GlobalEcon.TransportObstruct_MRIO(k(1), k(2), 6, k(3), k(11));
        GlobalEcon = GlobalEcon.TransportObstruct_MRIO(k(1), k(2), 7, k(3), k(12));
        GlobalEcon = GlobalEcon.TransportObstruct_MRIO(k(1), k(2), 8, k(3), k(13));
        GlobalEcon = GlobalEcon.TransportObstruct_MRIO(k(1), k(2), 9, k(3), k(14));
        GlobalEcon = GlobalEcon.TransportObstruct_MRIO(k(1), k(2), 10, k(3), k(15));
        GlobalEcon = GlobalEcon.TransportObstruct_MRIO(k(1), k(2), 11, k(3), k(16));
        end
    end
    
    %i=10
    %day=18;
    %k=TransportationLineBlockageData(:,70);
    %r1 = k(1)
    %r2 = k(2)
    %s =  i+1
    %position_fraction = k(3)
    %product_blocked = k(6+i)  
    


    % Calculate products unloaded to each production agent from transportation lines.
    temp = GlobalEcon.AgentsP_ProductInP';
    temp(GlobalEcon.k_NetPP) =  GlobalEcon.AgentsT_P2P(:,end);
    GlobalEcon.AgentsP_ProductInP = temp';
    GlobalEcon.AgentsT_P2P(:,end) = [];
    % Calculate products unloaded to each consumption agent from transportation lines.
    temp = GlobalEcon.AgentsC_ProductInP';
    temp(GlobalEcon.k_NetPC) =  GlobalEcon.AgentsT_P2C(:,end);
    GlobalEcon.AgentsC_ProductInP = temp';
    GlobalEcon.AgentsT_P2C(:,end) = [];
    clear temp;
    
    %% Other actions of the agents, which are automatically computed.
    % Agents commuicate.
    GlobalEcon = GlobalEcon.AgentsCommunicate;    
    % Update inventories of production agents.
    GlobalEcon = GlobalEcon.UpdateInventories;   
    % Update export orders (only for open economy).
    GlobalEcon = GlobalEcon.UpdateExportOrders;
    % Update shares.
    GlobalEcon = GlobalEcon.UpdateShares;
    % Production agents produce.
    GlobalEcon = GlobalEcon.ProductionAgentsProduce;
    % Production agents prepare product outflows.
    GlobalEcon = GlobalEcon.ProductionAgentsPrepareProductOut;
    % Production agents prepare order outflows.
    GlobalEcon = GlobalEcon.ProductionAgentsPrepareOrderOut;
    % Production agents adpat to shocks.
    GlobalEcon = GlobalEcon.ProductionAgentsAdaptToShocks;
    % Production agents adpat production modes to shortages.
    GlobalEcon = GlobalEcon.ProductionAgentsAdaptToShortages;
    % Production agents remember key state variables.
    GlobalEcon = GlobalEcon.ProductionAgentsRemember;
    % Consumption agents consume.
    GlobalEcon = GlobalEcon.ConsumptionAgentsConsume;
    % Consumption agents prepare order outflows.
    GlobalEcon = GlobalEcon.ConsumptionAgentsPrepareOrderOut;
    % Consumption agents remember key state variables
    GlobalEcon = GlobalEcon.ConsumptionAgentsRemember;
    
    
    %% Record the evolution of key variables.
    S0_Evolution_ValueAdded_ProductionAgents(:,day) =  GlobalEcon.AgentsP_VA;
    S0_Evolution_Invertory(:,day) =  GlobalEcon.AgentsP_I(:);
    S0_ProductInNetwork_Countries(:,:,day) = RegionSectors2Regions' *  GlobalEcon.AgentsP_ProductInP * RegionSectors2Regions;
    S0_ProductInNetwork_Countries_Change(:,:,day) = S0_ProductInNetwork_Countries(:,:,day) - SS_ProductInNetwork_Countries;
    S0_Evolution_Scarcity_RegionsProducts(:,:,day) = GlobalEcon.Scarcity_RegionsProducts;

end
MATLAB_RUNTIME_2_Simulate = toc; % End timing.

%% Calculate other key variables, using the recorded.
% Evolution of value-added of all Countries.
S0_Evolution_ValueAdded_Countries = RegionSectors2Regions' * S0_Evolution_ValueAdded_ProductionAgents;

% Percentage of value-added reduction of each Country-sector.
S0_LossPerc_ProductionAgents = zeros(GlobalEcon.N_P,1);
ind = SS_AgentsP_VA > 10^(-4); % Select sectors with positive value-added in the beginning.
S0_LossPerc_ProductionAgents(ind) = 100 * (SS_AgentsP_VA(ind)-mean(S0_Evolution_ValueAdded_ProductionAgents(ind,:),2)) ./ SS_AgentsP_VA(ind);

% Percentage of value-added reduction of each region.
S0_LossPerc_Countries = zeros(GlobalEcon.MRIO_R,1);
ind = SS_Countries_VA > 10^(-4); % Select sectors with positive value-added in the beginning.
S0_LossPerc_Countries(ind) = 100 * (SS_Countries_VA(ind)-mean(S0_Evolution_ValueAdded_Countries(ind,:),2)) ./ SS_Countries_VA(ind);

% Average change of inter-region trade network each simulation step.
S0_ProductInNetwork_Countries_Change_Mean = mean(S0_ProductInNetwork_Countries_Change,3);

%% Saving.
%save('TestResults_TransportationLineBlockage3.mat','S0_Evolution_ValueAdded_ProductionAgents', 'S0_Evolution_ValueAdded_Countries', ...
%    'S0_ProductInNetwork_Countries', 'S0_ProductInNetwork_Countries_Change', 'S0_ProductInNetwork_Countries_Change_Mean', ...
%    'S0_LossPerc_ProductionAgents', 'S0_LossPerc_Countries', ...
%    'S0_Evolution_Scarcity_RegionsProducts', ...
%    'SS_AgentsP_VA', 'SS_Countries_VA', 'SS_ProductInNetwork_Countries', ...
%    'RegionSectors2Regions')

%% Plot the evoluton of values added of all production agents.
% figure
% plot(S0_Evolution_ValueAdded_ProductionAgents')
col_sum = sum(S0_Evolution_ValueAdded_ProductionAgents, 1);
%col_sum = col_sum - col_sum(1);
x = 1:length(col_sum);           % 横坐标：每列的索引
y = col_sum;                     % 纵坐标：每列的和
scatter(x, y, 'filled');        % 绘制散点图，'filled' 表示填充颜色
xlabel('Column Index');
ylabel('Sum of Each Column');
title('Scatter Plot of Column Sums');


%% Clear and load data.
% Clear memory.
clear; clc; close all

% Load file.
tic % Start timing.

% Load MRIO data.
load('data/CityLevelMRIO2017.mat');

% Load water intensity and water resource data.
% Please load data from the disk!
WaterConstraints_Ratio=readmatrix("data/WaterVariables.xlsx","Sheet","WaterConstraints_Ratio");
WaterIntensity=readmatrix("data/WaterVariables.xlsx","Sheet","WaterIntensity");

% Load periods for transportion between regions (integers, at least 1).
% NO NEED FOR WEEKLY SIMULATION FOR CHINA!

% Load transportation line blockage data (optional).
% NO NEED IN THIS CASE!

% Load the conversion matrix from sectors to aggregate sectors.
... The rows represent products in MRIO table, and the columns are aggregate products 
... which are used as inputs to the Leontief production function.
... In the matrix, 1 means the row product belongs to the column aggregate proudct, and 0 otherwise.
... If it is an identity matrix, the original product classification 
... will be the same as the aggregate product classification, and
... WorldOfMatrix_GPU will be the same as WorldOfMatrix_Water, but the speed will be a little faster.
... Experiments show that when inventories are small, aggregation will reduce losses;
... otherwise using aggregation will slightly increase losses.
S2Sa = readmatrix('data/S2Sa.xlsx', 'Sheet', 'S2Sa_Identical');

MATLAB_RUNTIME_0_Load = toc; % End timing.

%% Setting the following variables for simulation:
% Length of each time step, as a fraction of input flows:
delta_t = 1/52;

% Total periods of simulation:
day_total = 52;

% Default targeted inventory periods:
% Note: This is (1 + the number of periods the remaining inputs would last after the current production ends).
... Therefore, it should be >= 1.
ndays_Target_Default = 1+4.3/7;

% Periods for transportion between regions (integers, at least 1):
MRIO_Dist = ones(313, 313);
% In fact, trasportation line lengths in CLUES model are the lengths of
... lines that stays in transportation steps.
... Therefore, it is tranportation period - 1.
... For example, if the tranportation period is 1 (i.e., arriving next period),
... there will be no goods staying in the intermediate transportation steps,
... so, the trasportation line length is 1 - 1 = 0.
MRIO_Dist = MRIO_Dist - 1;

% Water required for unitary output of each production agent (i.e., region-sector):
% Note: At least 1 water intensity should be nonzero to avoid computational error.
AgentsP_ResourceIntensity = WaterIntensity;

%% Define China's economy and initialize the model.
ChinaEcon = clues_abm.WorldOfMatrix_GPU; % China's economy is our World.

% Basic Input-Output variables.
ChinaEcon.MRIO_R = 313; % Number of regions (cities).
ChinaEcon.MRIO_S = 42; % Number of sectors in each region.
ChinaEcon.MRIO_Z = MRIO.Z; % Intermediate flows (in a year) from each city-region to each city-region.
ChinaEcon.MRIO_C = MRIO.F * kron( eye(ChinaEcon.MRIO_R), ones(5,1) ) ; % Consumption. Each column is the consumption of a city from all city-sectors.
MRIO.VA(isnan(MRIO.VA)) = 0; % Converting NaN to 0.
ChinaEcon.MRIO_VA = MRIO.VA(5,1:(ChinaEcon.MRIO_R*ChinaEcon.MRIO_S) ) ; % Value added of each city-sector. Aggregation over the 5 items.

% Define open-economy variables.
% ONLY NEEDED FOR OPEN ECONOMIES.
ChinaEcon.OpenEcon = true; % China is an open economy.
ChinaEcon.MRIO_E = MRIO.Export; % Exports.
ChinaEcon.MRIO_IP = MRIO.IM( 1:(ChinaEcon.MRIO_R*ChinaEcon.MRIO_S) ); % Imports by city-sectors.
ChinaEcon.MRIO_IC = MRIO.IM( (ChinaEcon.MRIO_R*ChinaEcon.MRIO_S+1):(ChinaEcon.MRIO_R*ChinaEcon.MRIO_S+5*ChinaEcon.MRIO_R) ); % Imports by city consumptions.
ChinaEcon.MRIO_IC = ChinaEcon.MRIO_IC * kron( eye(ChinaEcon.MRIO_R), ones(5,1) ); % To get ChinaEcon.MRIO_R city consumption levels,
...we need to sum up every 5 columns of ChinaEcon.MRIO_IC, using kron( eye(ChinaEcon.MRIO_R), ones(5,1) ).

% Length of each time step, as a fraction of input flows.
ChinaEcon.delta_t = delta_t;
% Default targeted inventory days.
ChinaEcon.ndays_Target_Default = ndays_Target_Default;
% Distance (i.e., steps in the transportation line) between regions.
ChinaEcon.MRIO_Dist = MRIO_Dist;
% Water required for unitary output of each production agent.
ChinaEcon.AgentsP_ResourceIntensity = AgentsP_ResourceIntensity;
% A conversion matrix, each row is a product and each column is an aggregate product. 
% The value is 1 if the column is aggregate product for the row product, otherwise is 0.
ChinaEcon.S2Sa = S2Sa; % Use the imported conversion matrix.
% ChinaEcon.S2Sa = eye(ChinaEcon.MRIO_R*ChinaEcon.MRIO_S); % Use the indentity matrix, so aggregate sectors are the same as original sectors.

%% Initialize the World.
tic % Start timing.
ChinaEcon = ChinaEcon.InitializeBasicVariables_UsingMRIO;
MATLAB_RUNTIME_1_1_InitializeBasic = toc; % End timing.

tic % Start timing
ChinaEcon = ChinaEcon.InitializeProductionAgents_UsingMRIO;
MATLAB_RUNTIME_1_2_InitializeProduction = toc; % End timing.

tic % Start timing
ChinaEcon = ChinaEcon.InitializeConsumptionAgents_UsingMRIO;
MATLAB_RUNTIME_1_3_InitializeConsump = toc; % End timing.

tic % Start timing
ChinaEcon = ChinaEcon.InitializeTransportationAgents_UsingMRIO;
MATLAB_RUNTIME_1_4_InitializeTransport = toc; % End timing.

%% Define key variables to be recorded.
% Evolution of value-added of all cities-sectors from day 1 to day_total.
... Each row represents a production agent (City-sector in this case).
S0_Evolution_ValueAdded_ProductionAgents = zeros(ChinaEcon.N_P, day_total);

% Steady-state value-added of City-sectors (each simulation step).
SS_AgentsP_VA = ChinaEcon.AgentsP_VA;

% Matrix for converting City-sector results to City results.
RegionSectors2Regions = kron(eye(ChinaEcon.MRIO_R),ones(ChinaEcon.MRIO_S,1));

% Steady-state value-added of City-sectors (each simulation step).
SS_Cities_VA = RegionSectors2Regions' * SS_AgentsP_VA;

% Evolution of the trade network between Cities (for products coming into the Cities).
... Eeah layer is a square matrix of product flows, where the row represent the sending City, and the column represents the receiving City.
S0_ProductInNetwork_Cities = zeros(ChinaEcon.MRIO_R, ChinaEcon.MRIO_R, day_total);
S0_ProductInNetwork_Cities_Change = zeros(ChinaEcon.MRIO_R, ChinaEcon.MRIO_R, day_total); % Change relative to the steady state.
% Steady state trade network.
SS_ProductInNetwork_Cities = RegionSectors2Regions' * ChinaEcon.AgentsP_ProductInP * RegionSectors2Regions;

% Evolution of Scarcity Indices for each product in each region.
... Eeah layer is a R * S matrix: rows are regions, and columns are sectors (i.e. products).
S0_Evolution_Scarcity_RegionsProducts = zeros(ChinaEcon.MRIO_R,ChinaEcon.Sa,day_total);

%% SIMULATE NETWORK DYNAMICS AND RECORD KEY VARIABLES.
tic % Start timing

for day=1:day_total % Days for simulation. 
    % ----This part calculates the impact of resource constraints:----
    % We can revise the property obj.ResourceConstraints of the WorldOfMatrix_Water object:
    ...obj.MRIO_R*1 vector: Resource constraints for each MRIO region, FOR THE CURRENT SIMULATION PERIOD.
    % Setting up regions where resource scarcity occurs:
    ...In this example, only one region was set to have water resource restrictions; 
    ...Multiple regions can be simultaneously set to generate water resource restrictions, such as Regions_WaterScarcity=[2,3,4,6,7,8];
    
    Regions_WaterScarcity=2;
    if day==1 % For example, in the first period, water scarcity occurs:
        WaterConstraints_RatioInput=ones(313,1);
        WaterConstraints_RatioInput(Regions_WaterScarcity)=WaterConstraints_Ratio(Regions_WaterScarcity);
        ChinaEcon.ResourceConstraints = ChinaEcon.ResourceConstraints.* WaterConstraints_RatioInput;
    else % Very abundant water. PLEASE USE THIS IN EACH SIMULATION PERIOD IS THERE IS NO WATER CONSTRAINT!
        ChinaEcon.ResourceConstraints = ones(size(ChinaEcon.ResourceConstraints)) * (sum(ChinaEcon.AgentsP_SS_Xcap) * 10 + 1e10);
    end
    
    % ----This part calculates the impact of losses in production capacity:----
    % We can revise the property obj.AgentsP_Theta of the WorldOfMatrix_GPU object:
    ...obj.N_P * 1: Reduction in production capacity relative to pre-event level, in [0,1].
    
%     if (day>=1) && (day<=10) % For example, production capacity loss in the fist period:
%         ChinaEcon.AgentsP_Theta(1) = 0.4;  %The production capacity of the first sector in the first region decreased by 40%
%     end
    
    % ----This part calculates movements in transportation lines.----
    % DON'T REVISE THIS SECTION IF THERE IS NO TRANSPORTATION LINE OBSTRUCTION.

    % Tranportation lines:
    % Load, move, and unload goods in the transportation chains.
    % Move one step forward (creating augumented transportation lines), for P2P.
    ChinaEcon.AgentsT_P2P = [ zeros(ChinaEcon.nl_NetPP,1), ChinaEcon.AgentsT_P2P ];
    % Calculate products loaded to each transportation lines.
    ChinaEcon.AgentsT_P2P(ChinaEcon.AgentsT_P2P_StartLinInd) = ChinaEcon.AgentsP_ProductOutP(ChinaEcon.k_NetPP);
    % Move one step forward (creating augumented transportation lines), for P2C.
    ChinaEcon.AgentsT_P2C = [ zeros(ChinaEcon.nl_NetPC,1), ChinaEcon.AgentsT_P2C ];
    % Calculate products loaded to each transportation lines.
    ChinaEcon.AgentsT_P2C(ChinaEcon.AgentsT_P2C_StartLinInd) = ChinaEcon.AgentsP_ProductOutC(ChinaEcon.k_NetPC);  

    % Transportation line obstruction (optional).
    % HERE WE DO NOTHING SINCE THERE IS NO TRANSPORTATION LINE OBSTRUCTION.

    % Calculate products unloaded to each production agent from transportation lines.
    temp = ChinaEcon.AgentsP_ProductInP';
    temp(ChinaEcon.k_NetPP) =  ChinaEcon.AgentsT_P2P(:,end);
    ChinaEcon.AgentsP_ProductInP = temp';
    ChinaEcon.AgentsT_P2P(:,end) = [];
    % Calculate products unloaded to each consumption agent from transportation lines.
    temp = ChinaEcon.AgentsC_ProductInP';
    temp(ChinaEcon.k_NetPC) =  ChinaEcon.AgentsT_P2C(:,end);
    ChinaEcon.AgentsC_ProductInP = temp';
    ChinaEcon.AgentsT_P2C(:,end) = [];
    clear temp;
    
    %% Other actions of the agents, which are automatically computed.
    % Agents commuicate.
    ChinaEcon = ChinaEcon.AgentsCommunicate;    
    % Update inventories of production agents.
    ChinaEcon = ChinaEcon.UpdateInventories;   
    % Update export orders (only for open economy).
    ChinaEcon = ChinaEcon.UpdateExportOrders;
    % Update shares.
    ChinaEcon = ChinaEcon.UpdateShares;
    % Production agents produce.
    ChinaEcon = ChinaEcon.ProductionAgentsProduce;
    % Production agents prepare product outflows.
    ChinaEcon = ChinaEcon.ProductionAgentsPrepareProductOut;
    % Production agents prepare order outflows.
    ChinaEcon = ChinaEcon.ProductionAgentsPrepareOrderOut;
    % Production agents adpat to shocks.
    ChinaEcon = ChinaEcon.ProductionAgentsAdaptToShocks;
    % Production agents adpat production modes to shortages.
    ChinaEcon = ChinaEcon.ProductionAgentsAdaptToShortages;
    % Production agents remember key state variables.
    ChinaEcon = ChinaEcon.ProductionAgentsRemember;
    % Consumption agents consume.
    ChinaEcon = ChinaEcon.ConsumptionAgentsConsume;
    % Consumption agents prepare order outflows.
    ChinaEcon = ChinaEcon.ConsumptionAgentsPrepareOrderOut;
    % Consumption agents remember key state variables
    ChinaEcon = ChinaEcon.ConsumptionAgentsRemember;
    
    %% Record the evolution of key variables.
    S0_Evolution_ValueAdded_ProductionAgents(:,day) =  ChinaEcon.AgentsP_VA;
    S0_ProductInNetwork_Cities(:,:,day) = RegionSectors2Regions' *  ChinaEcon.AgentsP_ProductInP * RegionSectors2Regions;
    S0_ProductInNetwork_Cities_Change(:,:,day) = S0_ProductInNetwork_Cities(:,:,day) - SS_ProductInNetwork_Cities;
    S0_Evolution_Scarcity_RegionsProducts(:,:,day) = ChinaEcon.Scarcity_RegionsProducts;

end
MATLAB_RUNTIME_2_Simulate = toc; % End timing.

%% Calculate other key variables, using the recorded.
% Evolution of value-added of all Cities.
S0_Evolution_ValueAdded_Cities = RegionSectors2Regions' * S0_Evolution_ValueAdded_ProductionAgents;

% Percentage of value-added reduction of each City-sector.
S0_LossPerc_ProductionAgents = zeros(ChinaEcon.N_P,1);
ind = SS_AgentsP_VA > 10^(-4); % Select sectors with positive value-added in the beginning.
S0_LossPerc_ProductionAgents(ind) = 100 * (SS_AgentsP_VA(ind)-mean(S0_Evolution_ValueAdded_ProductionAgents(ind,:),2)) ./ SS_AgentsP_VA(ind);

% Percentage of value-added reduction of each region.
S0_LossPerc_Cities = zeros(ChinaEcon.MRIO_R,1);
ind = SS_Cities_VA > 10^(-4); % Select sectors with positive value-added in the beginning.
S0_LossPerc_Cities(ind) = 100 * (SS_Cities_VA(ind)-mean(S0_Evolution_ValueAdded_Cities(ind,:),2)) ./ SS_Cities_VA(ind);

% Average change of inter-region trade network each simulation step.
S0_ProductInNetwork_Cities_Change_Mean = mean(S0_ProductInNetwork_Cities_Change,3);

%% Saving.
save('TestResults_ResourceConstraintsExample1.mat','S0_Evolution_ValueAdded_ProductionAgents', 'S0_Evolution_ValueAdded_Cities', ...
   'S0_ProductInNetwork_Cities', 'S0_ProductInNetwork_Cities_Change', 'S0_ProductInNetwork_Cities_Change_Mean', ...
   'S0_LossPerc_ProductionAgents', 'S0_LossPerc_Cities', ...
   'S0_Evolution_Scarcity_RegionsProducts', ...
   'SS_AgentsP_VA', 'SS_Cities_VA', 'SS_ProductInNetwork_Cities', ...
   'RegionSectors2Regions')

%% Plot the evoluton of values added of all production agents.
% figure
col_sum = sum(S0_Evolution_ValueAdded_ProductionAgents, 1);
plot(col_sum);
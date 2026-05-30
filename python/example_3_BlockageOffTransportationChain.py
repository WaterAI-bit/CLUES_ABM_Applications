import numpy as np
import pandas as pd
from scipy.io import loadmat
import matplotlib.pyplot as plt
from clues_abm.WorldOfMatrix_GPU import WorldOfMatrixGPU

# ======================= Load and initialize model =======================
mat = loadmat("data/EORA2016.mat")
MRIOdata = {
    "MRIO_Z": mat["Z_EORA2016"],
    "MRIO_C": mat["C_EORA2016"],
    "MRIO_E": mat["E_EORA2016"],
    "MRIO_IC": mat["IC_EORA2016"].flatten().reshape(1, -1),
    "MRIO_IP": mat["IP_EORA2016"].flatten().reshape(1, -1),
    "MRIO_R": int(mat["R_EORA2016"].item()),
    "MRIO_S": int(mat["S_EORA2016"].item()),
    "MRIO_VA": mat["VA_EORA2016"].flatten().reshape(1, -1)
}


# Load the conversion matrix from sectors to aggregate sectors.
#  The rows represent products in MRIO table, and the columns are aggregate products 
#  which are used as inputs to the Leontief production function.
#  In the matrix, 1 means the row product belongs to the column aggregate proudct, and 0 otherwise.
#  If it is an identity matrix, the original product classification 
#  will be the same as the aggregate product classification, and
#  WorldOfMatrix_GPU will be the same as WorldOfMatrix_Water, but the speed will be a little faster.
#  Experiments show that when inventories are small, aggregation will reduce losses;
#  otherwise using aggregation will slightly increase losses.
S2Sa = pd.read_excel('data/S2Sa.xlsx', sheet_name='S2Sa_Identical_EORA', header=None)

# Set simulation parameters
# Length of each time step, as a fraction of input flows:
delta_t = 1 / 365

# Total periods of simulation:
day_total = 30

# Default targeted inventory periods:
# Note: This is (1 + the number of periods the remaining inputs would last after the current production ends). Therefore, it should be >= 1.
ndays_target_default = 3.5

# ==== Basic Input-Output variables ====
model = WorldOfMatrixGPU()

model.MRIO_R = int(MRIOdata["MRIO_R"]) # Number of regions (cities).
model.MRIO_S = int(MRIOdata["MRIO_S"]) # Number of sectors in each region.
model.MRIO_Z = MRIOdata["MRIO_Z"] # Intermediate flows (in a year) from each city-region to each city-region.
model.MRIO_C = MRIOdata["MRIO_C"] # Consumption. Each column is the consumption of a city from all city-sectors.
model.MRIO_VA = MRIOdata["MRIO_VA"] # Value added of each city-sector.

# Define open-economy variables.
model.OpenEcon = True # China is an open economy.
model.MRIO_E = MRIOdata["MRIO_E"] # Exports.
model.MRIO_IP = MRIOdata["MRIO_IP"] # Exports.
model.MRIO_IC = MRIOdata["MRIO_IC"] # Exports.

# Set MRIO_Dist: default 1
TransportationDays = pd.read_excel("TransportationDays_CountriesInWorld.xlsx",sheet_name="TransportationDays", header=None).values
model.MRIO_Dist = TransportationDays - 1
TransportationLineBlockageData = pd.read_excel("TransportationLineBlockageData.xlsx",sheet_name="TransportationLineBlockageData", header=None).values

# Length of each time step, as a fraction of input flows.
model.delta_t = delta_t

# Default targeted inventory days.
model.ndays_Target_Default = ndays_target_default

# Water intensity: placeholder
model.AgentsP_ResourceIntensity = np.ones((model.MRIO_R * model.MRIO_S, 1)).reshape(-1)

# A conversion matrix, each row is a product and each column is an aggregate product. 
# The value is 1 if the column is aggregate product for the row product, otherwise is 0.
model.S2Sa = S2Sa.values # Use the imported conversion matrix.

# Initialize
model.initialize_variables()
model.initialize_production_agents()
model.initialize_consumption_agents()
model.initialize_transportation_agents()

# ======================= Prepare recording arrays =======================
S0_Evolution_ValueAdded_ProductionAgents = np.zeros((model.N_P, day_total))
S0_Evolution_Inventory = np.zeros((4914*26, day_total))


RegionSectors2Regions = np.kron(np.eye(model.MRIO_R), np.ones((model.MRIO_S, 1)))
SS_AgentsP_VA = model.AgentsP_VA
SS_Region_VA = RegionSectors2Regions.T @ SS_AgentsP_VA
S0_ProductInNetwork_Region = np.zeros((model.MRIO_R, model.MRIO_R, day_total))
S0_ProductInNetwork_Region_Change = np.zeros_like(S0_ProductInNetwork_Region)
SS_ProductInNetwork_Region = RegionSectors2Regions.T @ model.AgentsP_ProductInP @ RegionSectors2Regions
S0_Evolution_Scarcity_RegionsProducts = np.zeros((model.MRIO_R, model.Sa, day_total))

# ======================= Run simulation =======================
for day in range(1,day_total+1):
    print(day)


    # This part calculates movements in transportation lines.
    # DON'T REVISE THIS SECTION IF THERE IS NO TRANSPORTATION LINE OBSTRUCTION.

    # Tranportation lines:
    # Load, move, and unload goods in the transportation chains.
    # Move one step forward (creating augumented transportation lines), for P2P.
    model.AgentsT_P2P = np.hstack([np.zeros((model.nl_NetPP, 1)), model.AgentsT_P2P])
    # Calculate products loaded to each transportation lines.
    flat_P2P = model.AgentsT_P2P.ravel(order='F').copy()
    flat_P2P[model.AgentsT_P2P_StartLinInd] = model.AgentsP_ProductOutP.ravel(order='F')[model.k_NetPP]
    model.AgentsT_P2P = flat_P2P.reshape(model.AgentsT_P2P.shape, order='F')
    
    
    # Move one step forward (creating augumented transportation lines), for P2C.
    model.AgentsT_P2C = np.hstack([np.zeros((model.nl_NetPC, 1)), model.AgentsT_P2C])
    # Calculate products loaded to each transportation lines.
    flat_P2C = model.AgentsT_P2C.ravel(order='F').copy()
    flat_P2C[model.AgentsT_P2C_StartLinInd] = model.AgentsP_ProductOutC.ravel(order='F')[model.k_NetPC]  
    model.AgentsT_P2C = flat_P2C.reshape(model.AgentsT_P2C.shape, order='F')
    
    
    # Transportation line obstruction
    # Interventions are loaded from 'TransportationLineBlockageData.xlsx'.
    # Columns: Represent different blocked ships/events.
    # Rows inside the matrix 'k' are mapped using Python's 0-based indexing:
    #   k[0]   : Origin region (Row 1: ranking order among 189 EORA countries)
    #   k[1]   : Destination region (Row 2: ranking order among 189 EORA countries)
    #   k[2]   : Position_fraction in (0, 1] marking where blockage occurs (Row 3)
    #   k[3]   : Start day of the blockage (Row 4)
    #   k[4]   : End day of the blockage (Row 5)
    #   k[5+i] : Value of delayed goods in the first 11 EORA cargo sectors (Rows 6-16, Unit: 1000 $)

    for k in TransportationLineBlockageData.T:
        if day >= k[3] and day <= k[4]:
            for i in range(11):
                model.transport_obstruct_mrio(
                    k[0]-1,
                    k[1]-1,
                    i,
                    k[2],
                    k[5 + i]
                )

    # Calculate products unloaded to each production agent from transportation lines.
    temp2 = model.AgentsP_ProductInP.T.copy()
    flat_temp = temp2.ravel(order='F').copy()
    flat_temp[model.k_NetPP] = model.AgentsT_P2P[:, -1]
    temp2 = flat_temp.reshape(temp2.shape, order='F')
    model.AgentsP_ProductInP = temp2.T.copy()
    model.AgentsT_P2P = model.AgentsT_P2P[:, :-1]
    
    
    # Calculate products unloaded to each consumption agent from transportation lines.
    temp2 = model.AgentsC_ProductInP.T.copy()
    flat_temp = temp2.ravel(order='F').copy()
    flat_temp[model.k_NetPC] =  model.AgentsT_P2C[:, -1]
    temp2 = flat_temp.reshape(temp2.shape, order='F')
    model.AgentsC_ProductInP = temp2.T.copy()
    model.AgentsT_P2C = model.AgentsT_P2C[:, :-1]
    del temp2, flat_temp

    # Other actions of the agents, which are automatically computed.
    model.agents_communicate()
    model.update_inventories()
    model.update_export_orders()
    model.update_shares()
    model.production_agents_produce()
    model.production_agents_prepare_product_out()
    model.production_agents_prepare_order_out()
    model.production_agents_adapt_to_shocks()
    model.production_agents_adapt_to_shortages()
    model.production_agents_remember()
    model.consumption_agents_consume()
    model.consumption_agents_prepare_order_out()
    model.consumption_agents_remember()

    # Record
    S0_Evolution_ValueAdded_ProductionAgents[:, day-1] = model.AgentsP_VA.flatten()
    flow = RegionSectors2Regions.T @ model.AgentsP_ProductInP @ RegionSectors2Regions
    S0_ProductInNetwork_Region[:, :, day-1] = flow
    S0_ProductInNetwork_Region_Change[:, :, day-1] = flow - SS_ProductInNetwork_Region
    S0_Evolution_Scarcity_RegionsProducts[:, :, day-1] = model.Scarcity_RegionsProducts


# ======================= Post-processing =======================
# Evolution of value-added of all Regions.
S0_Evolution_ValueAdded_Region = RegionSectors2Regions.T @ S0_Evolution_ValueAdded_ProductionAgents

# Percentage of value-added reduction of each Region-sector.
S0_LossPerc_ProductionAgents = np.zeros((model.N_P, 1))

# Select sectors with positive value-added in the beginning.
ind = (SS_AgentsP_VA > 1e-4).flatten().copy()

# Compute % loss for those with positive initial VA
S0_LossPerc_ProductionAgents[ind] = (
    100 * (SS_AgentsP_VA[ind] - np.mean(S0_Evolution_ValueAdded_ProductionAgents[ind, :], axis=1).reshape(-1,1))
    / SS_AgentsP_VA[ind]
)

# Percentage of value-added reduction of each region.
S0_LossPerc_Region = np.zeros((model.MRIO_R, 1))

# Select regions with positive value-added in the beginning.
ind = (SS_Region_VA > 1e-4).flatten().copy()

# Compute % loss for each region
S0_LossPerc_Region[ind] = (
    100 * (SS_Region_VA[ind] - np.mean(S0_Evolution_ValueAdded_Region[ind, :], axis=1).reshape(-1,1))
    / SS_Region_VA[ind]
)

# Average change of inter-region trade network each simulation step.
S0_ProductInNetwork_Region_Change_Mean = np.mean(S0_ProductInNetwork_Region_Change, axis=2)




# ======================= Save results =======================
np.savez("TestResults_BlockageOfTransportationChainExample3.npz",
    S0_Evolution_ValueAdded_ProductionAgents = S0_Evolution_ValueAdded_ProductionAgents,
    S0_Evolution_ValueAdded_Region = S0_Evolution_ValueAdded_Region,
    S0_ProductInNetwork_Region = S0_ProductInNetwork_Region,
    S0_ProductInNetwork_Region_Change = S0_ProductInNetwork_Region_Change,
    S0_ProductInNetwork_Region_Change_Mean = S0_ProductInNetwork_Region_Change_Mean,
    S0_LossPerc_ProductionAgents = S0_LossPerc_ProductionAgents,
    S0_LossPerc_Region = S0_LossPerc_Region,
    S0_Evolution_Scarcity_RegionsProducts = S0_Evolution_Scarcity_RegionsProducts,
    SS_AgentsP_VA = SS_AgentsP_VA,
    SS_Region_VA = SS_Region_VA,
    SS_ProductInNetwork_Region = SS_ProductInNetwork_Region,
    RegionSectors2Regions = RegionSectors2Regions
)
    
# ======================= Plot =======================
# Daily total ValueAdded: sum across the agent dimension (axis=0 indicates row-wise)
daily_total = np.sum(S0_Evolution_ValueAdded_ProductionAgents, axis=0)

# Plotting
plt.figure(figsize=(10, 5))
plt.plot(range(1, day_total+1), daily_total, marker='o')
plt.xlabel('Day')
plt.ylabel('Total Value Added')
plt.title('Daily Total Value Added of Production Agents')
plt.grid(True)
plt.tight_layout()
plt.show()

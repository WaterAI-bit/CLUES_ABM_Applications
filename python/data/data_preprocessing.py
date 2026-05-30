import numpy as np
import pandas as pd
import scipy.io as sio

# ==============================================================================
# %% Download China 309 City-level MRIO Table  (from https://www.ceads.net/data/input_output_tables?#1282). It is an open economy.
# Rename 'China city MRIO_2017.mat' to 'CityLevelMRIO2017.mat'
# ==============================================================================


# ==============================================================================
# %% Importing China Provincial-level MRIO 2017 (from https://www.ceads.net/data/input_output_tables?#1087). It is an open economy.
# Name the downloaded Excel file as 'MRIO2017.xlsx'.
# ==============================================================================

R_MRIO2017  = 31 # Number of regions.
S_MRIO2017  = 42 # Number of sectors.

def readmatrix_excel(filepath, sheet, start_col, end_col, start_row, end_row):
    """
    Equivalent to MATLAB's 'readmatrix' function, enabling precise extraction of the specified range.
    """
    df = pd.read_excel(filepath, sheet_name=sheet, header=None)
    def col_to_num(col_str):
        num = 0
        for c in col_str.upper():
            num = num * 26 + (ord(c) - ord('A') + 1)
        return num - 1
    s_col, e_col = col_to_num(start_col), col_to_num(end_col)
    s_row, e_row = start_row - 1, end_row
    return df.iloc[s_row:e_row, s_col:e_col + 1].values

print("Processing ProvinceLevelMRIO2017...")
excel_file = 'MRIO2017.xlsx'
sheet_name = 'Table_2017_consistent'

Z_MRIO2017 = readmatrix_excel(excel_file, sheet_name, 'D', 'AXE', 5, 1306) # Intermediate flows.
VA_MRIO2017 = readmatrix_excel(excel_file, sheet_name, 'D', 'AXE', 1313, 1313) # Value added.
C_MRIO2017 = readmatrix_excel(excel_file, sheet_name, 'AXG', 'BDE', 5, 1306) # Consumptions.
C_MRIO2017 = C_MRIO2017 @ np.kron(np.eye(R_MRIO2017), np.ones((5, 1))) # Summing up 5 colunms of consumption in each region.
E_MRIO2017 = readmatrix_excel(excel_file, sheet_name, 'BDF', 'BDF', 5, 1306)  
IP_MRIO2017 = readmatrix_excel(excel_file, sheet_name, 'D', 'AXE', 1307, 1307) # Imports by producing sectors.
IC_MRIO2017 = readmatrix_excel(excel_file, sheet_name, 'AXG', 'BDE', 1307, 1307) # Imports by consumptions.
IC_MRIO2017 = IC_MRIO2017 @ np.kron(np.eye(R_MRIO2017), np.ones((5, 1))) # Summing up 5 colunms of imported consumption in each region.

# Save key variables.
mat_province = {
    'R_MRIO2017': float(R_MRIO2017),
    'S_MRIO2017': float(S_MRIO2017),
    'Z_MRIO2017': Z_MRIO2017,
    'VA_MRIO2017': VA_MRIO2017,
    'C_MRIO2017': C_MRIO2017,
    'E_MRIO2017': E_MRIO2017,
    'IP_MRIO2017': IP_MRIO2017,
    'IC_MRIO2017': IC_MRIO2017
}
sio.savemat('ProvinceLevelMRIO2017.mat', mat_province)
print("Successfully saved to ProvinceLevelMRIO2017.mat")


# ==============================================================================
# %%  Importing Eora26 2016 (in basic prices) (from https://worldmrio.com/eora26/). 
# Eora26 includes 189 specific countries (regions) and Rest of the World (ROW), totaling 190 regions. It is a closed economy.
# ==============================================================================
print("\nProcessing EORA2016...")

FD_Eora26 = np.loadtxt('Eora26_2016_bp_T.txt')   # Intermediate flows. 
VA_Eora26 = np.loadtxt('Eora26_2016_bp_VA.txt') # Value added.
VA_Eora26 = np.sum(VA_Eora26, axis=0, keepdims=True) # Summing up all types of value added into one row.
C_Eora26 = np.loadtxt('Eora26_2016_bp_FD.txt') # Consumptions.
C_Eora26 = C_Eora26 @ np.kron(np.eye(190), np.ones((6, 1))) # Summing up 6 colunms of consumption in each region.

# For research convenience, we treat the 189 specific countries (regions) in Eora26 as an open economy (relative to Rest of the World, ROW).
R_EORA2016   = 189; # Number of regions.
S_EORA2016   = 26; # Number of sectors.
Z_EORA2016 = FD_Eora26[0:4914, 0:4914]   # Intermediate flows. 
VA_EORA2016 = VA_Eora26[0, 0:4914].reshape(1, -1) # Value added.
C_EORA2016 = C_Eora26[0:4914, 0:189] # Consumptions.

IP_EORA2016 = FD_Eora26[4914, 0:4914].reshape(1, -1)  #Imports by producing sectors.
E_EORA2016 = FD_Eora26[0:4914, 4914].reshape(-1, 1)  
IC_EORA2016 = C_Eora26[4914, 0:189].reshape(1, -1)  # Imports by consumptions.

# Save key variables.
mat_eora = {
    'R_EORA2016': float(R_EORA2016),
    'S_EORA2016': float(S_EORA2016),
    'Z_EORA2016': Z_EORA2016,
    'VA_EORA2016': VA_EORA2016,
    'C_EORA2016': C_EORA2016,
    'IP_EORA2016': IP_EORA2016,
    'E_EORA2016': E_EORA2016,
    'IC_EORA2016': IC_EORA2016
}
sio.savemat('EORA2016.mat', mat_eora)
print("Successfully saved to EORA2016.mat")
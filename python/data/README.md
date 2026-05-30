# 📊 Data Acquisition and Pre-processing Guide

Due to GitHub's file size limitations (`>100 MB`), this repository does not embed the massive, fully compiled raw Multi-Regional Input-Output (MRIO) datasets. 

Instead, we provide an automated, one-click preprocessing pipeline (`data_preprocessing.m`) that converts official source tables into the precise `.mat` tensor configurations required by the **CLUES-ABM** engine.

---

## 🛠️ Step-by-Step Data Retrieval Playbook

Please follow the manual links below to retrieve the source files, rename them exactly as requested, and place them into this `data/` directory.

### 🏢 Step 1: China 309 City-Level MRIO Table (2017)
* **Source Platform**: China Emission Accounts and Datasets (CEADs)
* **Download URL**: [CEADs Input-Output Tables](https://www.ceads.net/data/input_output_tables?#1282)
* **Post-Download Action**: Rename the downloaded file `China city MRIO_2017.mat` to **`CityLevelMRIO2017.mat`**.

### 🗺️ Step 2: China Provincial-Level MRIO Table (2017)
* **Source Platform**: China Emission Accounts and Datasets (CEADs)
* **Download URL**: [CEADs Input-Output Tables](https://www.ceads.net/data/input_output_tables?#1087)
* **Post-Download Action**: Save the downloaded Excel configuration sheet as **`MRIO2017.xlsx`**.

### 🌍 Step 3: Eora26 Global MRIO Table (2016)
* **Source Platform**: The Eora Global MRIO Database
* **Download URL**: [Eora26 Database](https://worldmrio.com/eora26/)
* **Post-Download Action**: Download the basic prices files and ensure `Eora26_2016_bp_T.txt`, `Eora26_2016_bp_VA.txt`, and `Eora26_2016_bp_FD.txt` are unpacked directly into this `data/` folder.

---

## 🚀 Compiling the Tensors

Once all requested raw tables are properly positioned in this directory, open Python and execute the tracking script:

```python
# Navigate to the data folder and execute the compilation pipeline
python data_preprocessing.py
```

This pipeline automatically extracts intermediate flows ($Z$), value-added vectors ($VA$), and multi-regional consumption matrices ($C$), outputting optimized ProvinceLevelMRIO2017.mat and EORA2016.mat matrices into this folder, making them instantly accessible to the main ABM simulation.
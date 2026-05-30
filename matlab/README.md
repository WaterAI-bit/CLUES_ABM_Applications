# CLUES-ABM Applications (Python/MATLAB)

## 1. Overview

**CLUES-ABM** is a high-performance computational framework designed to simulate the short-term cascading impacts of abrupt external shocks on socio-economic-environmental systems. Built upon high-frequency, multi-regional input-output (MRIO) tensor alignments, the model endogenously captures the spatial-temporal dynamic adaptation, inventory buffering, and market-share reallocation behaviors of heterogeneous production, consumption, and transportation agents.

This repository houses the standalone **MATLAB core engine**, optimized for discrete-event simulation, automated micro-behavioral feedback loops, and large-scale parallel tensor matrix operations.


---

## 2. Environment Prerequisites & Dataset Setup

### 2.1 Prerequisites
* **MATLAB** ($\ge$ R2020a recommended).
* **Parallel Computing Toolbox** (Required if deploying on GPU matrix layers for city-level or global scales).
* **No external software wrappers** (e.g., Python) are required for the main simulation pipeline.

### 2.2 Crucial: Dataset Preparation 🚨
Because the raw City-level and Global MRIO tables exceed GitHub's hosting size limits ($>500\text{ MB}$), users must download the raw source tables independently from official providers (such as CEADs and Eora) and execute our automated preprocessing compiler.

**Please pivot to the [data/ Subdirectory Guide](data/README.md) for step-by-step download instructions and to execute the `data_preprocessing.m` script.** Once compiled, the optimized `.mat` tensor configurations will be instantly ready for scenario testing.

---

## 3. Core Simulation Templates (Three Empirical Cases)

The CLUES-ABM architecture decouples the core macroeconomic engine from specific policy scenario modules, offering three standardized templates to evaluate distinct structural risk propagation pathways:

### 💧 Case 1: Multi-Element Resource Constraints (`example_1_ResourceConstraints.m`)
* **Mechanism**: Models localized resource supply bottlenecks (e.g., rigid water quotas or energy dual-control thresholds). It dynamically scales the `model.ResourceConstraints` vector for targeted regions at designated time steps. Downstream agents face input shocks when regional consumption hits resource intensity (`AgentsP_ResourceIntensity`) ceilings.
* **Configuration**: Leverages the City-Level MRIO 2017 dataset ($\delta_t = 1/52$, `day_total = 52` weeks).
* **Execution**: Injecting a water scarcity constraint into specific region nodes at Day 1 while keeping baseline periods abundant.

### ⚙️ Case 2: Industrial Capacity Reduction (`example_2_ReductionInProductionCapacity.m`)
* **Mechanism**: Simulates localized physical asset degradation or policy-driven enterprise temporary shutdowns. By altering the `model.AgentsP_Theta` property (bounded within $[0, 1]$), it restricts maximum production capabilities relative to pre-event benchmarks. Over-shocked agents trigger localized supply shortfalls that cascade through the spatial trade network.
* **Configuration**: Leverages the Provincial-Level MRIO 2017 dataset and explicit inter-provincial logistics tracking, evaluated across a daily resolution ($\delta_t = 1/365$, `day_total = 365`).
* **Execution**: Simulates a $40\%$ drop in production capacity (`model.AgentsP_Theta[0] = 0.4`) for the baseline index region from Day 1 to Day 10.

### 🚚 Case 3: Infrastructure & Logistics Blockage (`example_3_BlockageOffTransportationChain.m`)
* **Mechanism**: Evaluates the systemic exposure of international and domestic trade channels to critical transportation line interruptions (e.g., the Suez Canal obstruction or subnational maritime corridor friction). Rather than mutating input-output structural parameters, it invokes the `model.transport_obstruct_mrio()` routine to lock commodities inside the intermediate transportation lines (`AgentsT_P2P`, `AgentsT_P2C`). Downstream agents rapidly drain their localized safety buffers (`ndays_target_default = 3.5`), triggering massive cascading shortages.
* **Configuration**: Maps the global closed-economy Eora26 Global MRIO 2016 database ($189$ regions $\times$ $26$ sectors) into an open-economy framework coupled with cross-border logistics metrics (`TransportationDays_CountriesInWorld.xlsx`), simulated across a localized timeline (`day_total = 365`).
* **Execution**: Loops through a customized schedule matrix (`TransportationLineBlockageData.xlsx`) to programmatically lock trade lanes during specified intervals.

---

## 4. Quick Start & Execution Workflow

Once the benchmarking data matrices are ready in the `data/` folder, you can verify the execution pipeline by running our canonical multi-stage scenario script:

```matlab
% Open MATLAB and run the programmatic baseline script
run('example_1_ResourceConstraints.m')
run('example_2_ReductionInProductionCapacity.m')
run('example_3_BlockageOffTransportationChain.m')
```













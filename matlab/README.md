# CLUES-ABM Applications (MATLAB version)

## 1. Environment Prerequisites & Dataset Setup

### 1.1 Prerequisites
* **MATLAB** ($\ge$ R2020a recommended).
* **Parallel Computing Toolbox** (Required if deploying on GPU matrix layers for city-level or global scales).
* **No external software wrappers** (e.g., Python) are required for the main simulation pipeline.

### 1.2 Crucial: Dataset Preparation 🚨
Because the raw City-level and Global MRIO tables exceed GitHub's hosting size limits ($>500\text{ MB}$), users must download the raw source tables independently from official providers (such as CEADs and Eora) and execute our automated preprocessing compiler.

**Please pivot to the [data/ Subdirectory Guide](data/README.md) for step-by-step download instructions and to execute the `data_preprocessing.m` script.** Once compiled, the optimized `.mat` tensor configurations will be instantly ready for scenario testing.


### 1.3 Subdirectory Architecture

* **`+clues_abm/`**: The standard Matlab module library.
  * `WorldOfMatrix_GPU.m`: Core computational matrix model governing large-system agent communications.
* **`data/`**: Input file repository.
  * `S2Sa.xlsx`: Binary sector-to-aggregate mapping matrix ($1$ if a micro-sector belongs to an aggregate industry, $0$ otherwise) used to calibrate the Leontief production function. 
  * `TransportationDays_CountriesInWorld.xlsx`: Transportation days between countries in the world.
  * `TransportationDays_ProvincesInChina.xlsx`: Transportation days between provinces in China.
  * `TransportationLineBlockageData.xlsx`: Temporal event manifest driving global supply chain disruptions. Rows 1–5 parameterize the blockage vectors (origin/destination regions, spatial position fraction, and start/end day horizons), while rows 6–16 scale the delayed commodity valuations across sectors.
  * `WaterVariables.xlsx`: Multi-sheet environmental boundary registry for **Case 1**. The `WaterConstraints_Ratio` sheet defines regional water quota ceiling limits, while the `WaterIntensity` sheet stores sector-level consumption coefficients flattened to direct the micro-agent adaptive production functions.
* **`example_1_ResourceConstraints.m`**: Empirical validation workflow for **Case 1: Resource Constraints**.
* **`example_2_ReductionInProductionCapacity.m`**: Empirical validation workflow for **Case 2: Capacity Degradation**.
* **`example_3_BlockageOffTransportationChain.m`**: Empirical validation workflow for **Case 3: Logistics Chokepoint**.

---

## 2. Core Simulation Templates (Three Empirical Cases)

The CLUES-ABM architecture provides three standardized validation templates to evaluate distinct economic-environmental structural risk propagation channels. 

| Case & Scenario | Mechanism | Model Configuration | Execution |
| :--- | :--- | :--- | :--- |
| **💧 Case 1: Resource Constraints**<br>`example_1_ResourceConstraints.m` | Models localized resource supply bottlenecks (e.g., rigid water quotas). It dynamically scales the `model.ResourceConstraints` vector. Downstream agents face input shocks when regional consumption hits resource intensity (`AgentsP_ResourceIntensity`) ceilings. | **City-Level MRIO 2017**<br>• Temporal step: $\delta_t = 1/52$<br>• Timeline: `day_total = 52` (weeks) | Injecting a severe water scarcity constraint into target regional nodes at Day 1 while keeping baseline periods abundant. |
| **⚙️ Case 2: Capacity Degradation**<br>`example_2_ReductionInProductionCapacity.m` | Simulates localized physical asset degradation or policy-driven shutdowns. By altering `model.AgentsP_Theta` $\in [0, 1]$, it restricts maximum production capabilities. Over-shocked agents trigger localized supply shortfalls cascading through the trade network. | **Provincial-Level MRIO 2017**<br>• Temporal step: $\delta_t = 1/365$<br>• Timeline: `day_total = 365` (days) | Simulates a $40\%$ drop in production capacity (`model.AgentsP_Theta[0] = 0.4`) for the baseline index region from Day 1 to Day 10. |
| **🚚 Case 3: Logistics Chokepoint**<br>`example_3_BlockageOffTransportationChain.m` | Evaluates trade channels under infrastructure interruptions (e.g., canal obstructions). It invokes `model.transport_obstruct_mrio()` to lock commodities inside transit lines (`AgentsT_P2P`), draining downstream safety buffers (`ndays_target_default = 3.5`). | **Eora26 Global MRIO 2016**<br>• $189$ regions $\times$ $26$ sectors<br>• Open-economy framework<br>• Timeline: `day_total = 365` (days) | Loops through a cross-border logistics schedule (`TransportationLineBlockageData.xlsx`) to programmatically lock trade lanes during specified intervals. |

---

## 3. Quick Start & Execution Workflow

Once the benchmarking data matrices are ready in the `data/` folder, you can verify the execution pipeline by running our canonical multi-stage scenario script:

```matlab
% Open MATLAB and run the programmatic baseline script
run('example_1_ResourceConstraints.m')
run('example_2_ReductionInProductionCapacity.m')
run('example_3_BlockageOffTransportationChain.m')
```


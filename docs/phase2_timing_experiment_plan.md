# CS683 Phase 2: LLBP-X Timing Sensitivity Experiment Plan

**Date:** 2026-11-21
**Status:** Experiment plan finalized after preliminary pilot testing. This is not a preregistration made before observing pilot results.

## 1. Research question

How does approximate LLBP-X pattern-prefetch access delay affect branch prediction accuracy across different TAGE-SC-L capacity configurations and workloads?

The study investigates whether delayed availability of patterns in the Pattern Buffer reduces LLBP-X's ability to provide predictions, and whether the effect differs across capacity configurations and workloads.

## 2. Preliminary pilot and design provenance

A preliminary delay sweep was conducted on the `benchbase-tpcc` trace using:

- 10 million warm-up instructions
- 20 million measured instructions
- BTB enabled
- Timing-enabled LogG10 LLBP-X
- Access delays of 0, 2, 4, 8 and 16 simulator ticks

A non-timing LogG10 configuration was also tested.

The pilot showed increasing MPKI at larger delays for this workload. These preliminary results informed the delay values selected for the formal experiment.

Pilot runs are exploratory and will not be included in the formal 252-run dataset.

## 3. Hypotheses and investigation

**H1:** Increasing approximate prefetch access delay can reduce the availability of useful patterns when predictions are made, potentially increasing MPKI.

**H2:** The effect of access delay may differ across TAGE-SC-L capacity configurations and workloads.

The experiment will test these expectations. A monotonic increase in MPKI is not assumed for every individual workload.

## 4. Predictor configurations

Three capacity configurations will be evaluated.

| Capacity | Non-timing model | Timing-enabled model | TAGE LogG |
|---|---|---|---:|
| Full | `llbpx` | `llbpx-timing` | 10 |
| Reduced | `llbpx-reduced-tagged` | `llbpx-reduced-tagged-timing` | 9 |
| Smaller | `llbpx-logg8` | `llbpx-logg8-timing` | 8 |

The corresponding constructors use LogB=13 and enable the Statistical Corrector and Loop Predictor. The configurations use `optW=0`.

Within each capacity, the timing-enabled configuration enables the approximate timing model and accepts an explicit access delay. The non-timing configuration is the reference for that capacity.

**Important:** A timing-enabled configuration with delay 0 is not equivalent to the non-timing configuration. The timing-enabled execution still uses the prefetch queue and Pattern Buffer path.

## 5. Workloads

The experiment uses the same 14 workloads listed in `scripts/eval_all.sh`:

1. `mwnginxfpm-wiki`
2. `dacapo-kafka`
3. `dacapo-tomcat`
4. `dacapo-spring`
5. `renaissance-finagle-chirper`
6. `renaissance-finagle-http`
7. `benchbase-tpcc`
8. `benchbase-twitter`
9. `benchbase-wikipedia`
10. `nodeapp-nodeapp`
11. `charlie.1006518`
12. `delta.507252`
13. `merced.467915`
14. `whiskey.426708`

The corresponding compressed ChampSim traces are stored under `traces/`.

## 6. Experiment matrix

### 6.1 Timing-enabled runs

For every capacity and workload, run the timing-enabled predictor with these access delays:

- 0 ticks
- 2 ticks
- 4 ticks
- 8 ticks
- 16 ticks

Total:

3 capacities x 14 workloads x 5 delays = **210 runs**

### 6.2 Non-timing reference runs

For every capacity and workload, run the corresponding non-timing predictor.

Total:

3 capacities x 14 workloads = **42 runs**

### 6.3 Total

**252 formal simulations.**

Each timing-enabled result will be compared with the non-timing result for the same workload and capacity.

## 7. Controlled simulation settings

All formal runs use:

| Parameter | Setting |
|---|---:|
| Warm-up instructions | 100,000,000 |
| Measured instructions | 200,000,000 |
| BTB simulation | Enabled |
| Workloads | Same 14 traces |
| Timing delays | 0, 2, 4, 8, 16 simulator ticks |
| Concurrency | 4 simulation processes |

The requested measured instruction count is 200 million. The actual ROI instruction count printed by the simulator must be recorded for every run; it may differ slightly because of trace instruction granularity.

The same freshly built Release executable will be used for every formal run.

## 8. Primary metric and analysis

The primary metric is ROI MPKI:

MPKI = 1000 x ROI mispredictions / ROI instructions

Lower MPKI indicates better branch prediction accuracy.

For each capacity, workload and timing delay, calculate the paired difference:

Delta MPKI = Timing-enabled MPKI - Non-timing MPKI

A positive difference means the timing-enabled configuration has worse MPKI.

Also calculate the per-workload MPKI ratio:

Ratio = Timing-enabled MPKI / Non-timing MPKI

A ratio greater than 1 indicates worse MPKI with timing enabled.

Report all 14 workload results separately.

For aggregate comparisons, report:

1. The geometric mean of the 14 per-workload MPKI ratios.
2. The pooled MPKI, calculated from the sum of ROI mispredictions divided by the sum of ROI instructions across workloads.

These summaries answer different questions and should be reported separately. Do not silently replace missing or zero denominators with an arbitrary value. If a workload has zero baseline MPKI, explain how that affects the ratio summary.

## 9. Secondary diagnostic metrics

The following predictor statistics will be retained from the final statistics block of each run.

### Provider behaviour

- LLBP provider count and share of all predictions.
- LLBP provider accuracy.
- LLBP provider count divided by pattern-hit count.

These are distinct quantities. Provider share of all predictions must not be confused with the fraction of pattern hits that become LLBP providers.

### Reasons LLBP does not provide a prediction

- `Shorter`: a matching pattern has a shorter history than the selected TAGE history.
- `NoPrefetch`: a matching pattern is not available through the required prefetch path when timing is enabled.

These counters can overlap. They must not be presented as mutually exclusive categories or added as though they partition all pattern hits.

### Pattern Buffer and prefetch behaviour

Retain:

- Prefetch queue hits.
- Pattern Buffer hits.
- Context Index hits.
- Prefetch drops due to locked entries.
- Prefetch drops following mispredictions.
- Prefetch drops following BTB misses.

These are diagnostic counters used to help interpret changes in MPKI. They do not independently measure physical memory latency.

## 10. Statistics collection and warm-up

The simulator prints periodic predictor statistics during execution and prints a final statistics block after the ROI summary.

The formal analysis must use the final statistics block, not an intermediate progress report.

The warm-up phase trains the predictor tables and LLBP structures. At the warm-up boundary, the simulator resets aggregate measurement statistics and certain per-entry accounting counters. In TAGE, the replacement-usefulness field `u` must be distinguished from the separate accounting field `useful`: allocation decisions use `u`, and prediction updates modify `u`, whereas `resetStats()` clears `useful` but does not clear `u`. Thus, the trained predictor tables and TAGE replacement-usefulness metadata are carried into the ROI, while measurement counters are reset. The inspected reset functions do not reinitialize the predictor tables or LLBP storage.

The exact ROI instruction and misprediction counts must be retained from the final output.

## 11. Execution and output

The formal runner will be a separate script:

`scripts/run_phase2_timing.sh`

It will write one log per workload and predictor configuration under:

`results/phase2_timing/`

The output directory is separate from `results/checkpoint1/`.

The runner must not silently overwrite an existing Phase 2 output directory. It will record the run configuration and executable provenance, and it will report failed runs.

The normal simulation output is captured through standard-output and standard-error redirection. The `--output` option is not required for normal statistics collection; in `main.cc`, it is used to construct a table-dump filename when table dumping is enabled.


## 12. Interpretation limits

The access-delay parameter is documented by the simulator as an approximate pattern-prefetch delay in simulator ticks.

The simulator's tick counter advances according to its event/tick model. A tick is not directly equivalent to a CPU cycle.

Therefore, this experiment investigates sensitivity to the simulator's approximate prefetch timing model. It does not establish:

- Cycle-accurate memory or predictor latency.
- Full processor IPC or execution-time improvement.
- Energy consumption.
- Physical silicon area or measured hardware performance.

The results should be interpreted as simulator-level branch prediction accuracy and diagnostic-counter measurements under the specified configurations.

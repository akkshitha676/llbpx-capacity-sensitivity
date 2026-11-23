
# LLBP-X: Capacity and Timing Sensitivity Study

This project studies the capacity and timing sensitivity of LLBP-X, an enhanced version of LLBP built on top of TAGE-SC-L.

The project consists of two studies:

1. **Phase I: Capacity Sensitivity** — investigates whether reducing the storage capacity of TAGE-SC-L while retaining LLBP-X can recover prediction accuracy.
2. **Phase II: Timing Sensitivity** — investigates how approximate LLBP-X pattern-prefetch access delay affects branch prediction accuracy across different capacity configurations.

The implementation is based on the upstream [LLBP-X repository](https://github.com/dhschall/LLBP-X).

---

## Research Questions

### Phase I: Capacity Sensitivity

How much prediction accuracy can LLBP-X recover when the underlying TAGE-SC-L predictor is configured with reduced capacity?

The study compares three configurations:

- **LogG10:** Full-size TAGE-SC-L configuration.
- **LogG9:** Reduced tagged-table capacity.
- **LogG8:** Further reduced tagged-table capacity.

### Phase II: Timing Sensitivity

How does approximate LLBP-X pattern-prefetch access delay affect branch prediction accuracy across different TAGE-SC-L capacity configurations and workloads?

The timing experiment evaluates access delays of 0, 2, 4, 8, and 16 simulator ticks.

---

## Phase I: Capacity-Sensitivity Study

### Experimental Setup

The capacity-sensitivity experiment evaluates three TAGE-SC-L capacity configurations with and without LLBP-X.

The experiment uses:

- 14 workloads.
- 3 capacity configurations.
- 2 predictor configurations per capacity.
- 100 million warmup instructions.
- 200 million measured instructions.
- Branch Target Buffer (BTB) enabled.

This results in 84 simulation runs.

### Evaluation Metrics

MPKI represents the number of branch mispredictions per thousand instructions.

Two metrics are used to evaluate LLBP-X under capacity constraints. They use different baselines and therefore answer different questions.

**Metric A: Same-capacity comparison**

Metric A compares LLBP-X against standalone TAGE-SC-L at the same predictor capacity.

\[
\text{Metric A}_{s,t}
=
100 \times \frac{T_{s,t}-X_{s,t}}{T_{s,t}}
\]

Where:

- \(T_{s,t}\): Standalone TAGE-SC-L MPKI at capacity \(s\) for workload \(t\).
- \(X_{s,t}\): LLBP-X MPKI at capacity \(s\) for workload \(t\).

This metric measures the improvement provided by LLBP-X over a standalone predictor with the same capacity.

**Metric B: Full-size baseline comparison**

Metric B compares reduced-capacity LLBP-X against the full-size 64K standalone TAGE-SC-L baseline.

\[
\text{Metric B}_{s,t}
=
100 \times \frac{T_{64,t}-X_{s,t}}{T_{64,t}}
\]

Where:

- \(T_{64,t}\): Full-size 64K standalone TAGE-SC-L MPKI for workload \(t\).
- \(X_{s,t}\): LLBP-X MPKI at reduced capacity \(s\) for workload \(t\).

This metric evaluates whether reduced-capacity LLBP-X can retain an advantage over the full-size standalone baseline.

For both metrics:

- Positive values indicate lower MPKI and better prediction performance than the corresponding baseline.
- Negative values indicate higher MPKI and worse prediction performance.
- The geometric-mean improvement summarizes normalized per-workload MPKI ratios.
- Pooled improvement is calculated separately using total mispredictions and total instructions.

For a set of \(N\) workloads, the geometric-mean MPKI ratio is:

\[
GM(R) =
\exp\left(
\frac{1}{N}\sum_{t=1}^{N}\ln(R_t)
\right)
\]

where \(R_t\) is the LLBP-X-to-baseline MPKI ratio for workload \(t\).

The percentage improvement is:

\[
(1-GM(R))\times 100
\]

The pooled comparison aggregates mispredictions and instructions across workloads before calculating the ratio. It is therefore distinct from the geometric mean of per-workload ratios.

### Metric A: Same-Capacity Results

The following table reports the geometric-mean and pooled MPKI improvements of LLBP-X over the corresponding standalone TAGE-SC-L configuration.

| Configuration | Geometric-Mean Improvement | Pooled Improvement | Workloads Improved |
|---|---:|---:|---:|
| LogG10 | 12.92% | 13.41% | 14/14 |
| LogG9 | 21.37% | 19.98% | 14/14 |
| LogG8 | 32.34% | 27.82% | 14/14 |

The results indicate that LLBP-X continues to outperform its corresponding standalone baseline under reduced capacity in aggregate.

All 14 workloads improve over their corresponding same-capacity standalone TAGE-SC-L baselines at all three capacity configurations. However, this does not mean that LLBP-X consistently outperforms the full-size 64K baseline, as shown by Metric B.

### Absolute MPKI

The arithmetic mean MPKI values across the 14 workloads are:

| Configuration | Standalone TAGE-SC-L | LLBP-X |
|---|---:|---:|
| LogG10 | 2.916 | 2.525 |
| LogG9 | 3.345 | 2.677 |
| LogG8 | 3.925 | 2.833 |

Lower MPKI indicates fewer branch prediction misses.

### Metric B: Full-Size Baseline Comparison

The following table compares reduced-capacity LLBP-X against the full-size 64K standalone TAGE-SC-L baseline.

| Configuration | Geometric-Mean Improvement | Pooled Improvement |
|---|---:|---:|
| LogG10 | 12.92% | 13.41% |
| LogG9 | 7.22% | 8.22% |
| LogG8 | 1.09% | 2.85% |

Metric B shows a different trend from Metric A. The improvement over the full-size baseline decreases substantially as capacity is reduced.

This distinction is important: strong improvement over a same-capacity standalone predictor does not necessarily imply that a reduced-capacity LLBP-X configuration performs substantially better than the full-size standalone predictor.

### Storage Estimates

The estimated storage requirements are based on source-level accounting rather than physical hardware measurements.

Using the primary TAGE storage formula:

| Configuration | Estimated Combined Storage |
|---|---:|
| LogG10 | 574.5 KiB |
| LogG9 | 553.7 KiB |
| LogG8 | 543.3 KiB |

Relative to LogG10, the estimated reductions are:

- LogG9: approximately 3.6%.
- LogG8: approximately 5.4%.

An alternate TAGE accounting formula produces the following estimates:

| Configuration | Alternate Combined Estimate |
|---|---:|
| LogG10 | 588.3 KiB |
| LogG9 | 560.8 KiB |
| LogG8 | 547.0 KiB |

These estimates correspond to reductions of approximately 4.7% and 7.0% relative to LogG10.

These are implementation-level storage estimates, not measured silicon area or physical hardware results.

---

## Phase II: Timing-Sensitivity Study

### Motivation

LLBP-X uses pattern prefetching to make predictions using previously observed branch-history patterns.

Although pattern prefetching can improve prediction accuracy, its effectiveness may depend on whether the required pattern is available when the prediction is made.

This experiment investigates the effect of approximate pattern-prefetch access delay on prediction accuracy.

### Experimental Setup

The timing-sensitivity experiment uses:

- 14 workloads.
- 3 TAGE-SC-L capacity configurations.
- 5 access-delay values.
- 100 million warmup instructions.
- 200 million measured instructions.
- BTB enabled.

The evaluated access delays are:

\[
0,\ 2,\ 4,\ 8,\ 16
\]

For each capacity configuration, a corresponding non-timing LLBP-X configuration serves as the reference.

The experiment consists of:

| Experiment Type | Number of Runs |
|---|---:|
| Timing-enabled configurations | 210 |
| Non-timing reference configurations | 42 |
| **Total** | **252** |

The configurations use the same relevant predictor settings within each capacity comparison. The timing-enabled configurations activate the approximate timing model, while the reference configurations do not.

**Important:** A delay-zero timing-enabled run is not equivalent to a non-timing reference run. The timing-enabled path still uses the timing-model queue and associated bookkeeping, even when the configured access delay is zero.

### Timing Model

The access delay is specified in simulator ticks.

The simulator increments the predictor's internal tick counter when a branch is taken or when more than eight instructions are skipped. In timing-enabled LLBP-X, each tick also advances the pattern-prefetch queue.

This is a rough timing approximation. The simulator does not model the full processor pipeline or determine the exact number of clock cycles between predictions. Therefore, simulator ticks should not be interpreted as CPU clock cycles.

The experiment studies the effect of varying this simulator-level access-delay parameter. It does not establish a direct mapping between the evaluated delays and a specific physical hardware latency.

### Evaluation Metrics

The primary metric is MPKI.

For each timing-enabled configuration, its MPKI is compared against the corresponding non-timing reference with the same capacity configuration.

The percentage change is calculated as:

\[
\Delta MPKI(\%) =
\frac{MPKI_{\text{timing}}-MPKI_{\text{reference}}}
{MPKI_{\text{reference}}}\times 100
\]

A positive value indicates an increase in MPKI and therefore worse prediction accuracy.

A negative value indicates an improvement in prediction accuracy.

The analysis also considers:

- Geometric-mean MPKI-ratio change.
- Pooled MPKI change.
- Number of workloads with increased or decreased MPKI.
- LLBP-X provider rate.
- LLBP-X provider accuracy.
- Pattern-prefetch availability and related statistics.

### Aggregate Results

The following table compares each timing-enabled configuration against its corresponding non-timing reference.

Positive values indicate worse MPKI.

| Capacity | Delay (ticks) | Geometric-Mean MPKI Change | Pooled MPKI Change | Workloads Worse | Workloads Better |
|---|---:|---:|---:|---:|---:|
| LogG10 | 0 | +0.18% | +0.17% | 10 | 4 |
| LogG10 | 2 | +0.60% | +0.52% | 12 | 2 |
| LogG10 | 4 | +1.66% | +1.55% | 14 | 0 |
| LogG10 | 8 | +4.34% | +4.48% | 14 | 0 |
| LogG10 | 16 | +12.74% | +10.50% | 14 | 0 |
| LogG9 | 0 | +0.14% | +0.00% | 9 | 5 |
| LogG9 | 2 | +0.42% | +0.35% | 12 | 2 |
| LogG9 | 4 | +1.54% | +1.42% | 14 | 0 |
| LogG9 | 8 | +4.88% | +4.79% | 14 | 0 |
| LogG9 | 16 | +14.16% | +11.24% | 14 | 0 |
| LogG8 | 0 | +0.10% | +0.03% | 9 | 5 |
| LogG8 | 2 | +0.47% | +0.35% | 10 | 4 |
| LogG8 | 4 | +1.81% | +1.48% | 14 | 0 |
| LogG8 | 8 | +4.41% | +4.51% | 14 | 0 |
| LogG8 | 16 | +13.94% | +11.01% | 14 | 0 |

### Key Observations

1. **Increasing access delay generally reduces prediction accuracy.** The increase in MPKI becomes more pronounced as access delay increases.

2. **The effect is consistent at higher delays.** At delays of 4, 8, and 16 ticks, all 14 workloads exhibit higher MPKI than their corresponding non-timing reference across all three capacity configurations.

3. **The largest aggregate degradation occurs at 16 ticks.** The geometric-mean MPKI increase ranges from 12.74% to 14.16%, depending on capacity.

4. **Small delays have a relatively limited effect.** At delays of 0 and 2 ticks, some workloads show improvements relative to their non-timing references.

5. **The effect varies across workloads.** Not every workload exhibits a perfectly monotonic increase in MPKI across all delay values.

### Pattern-Prefetch Diagnostics

The following table reports aggregated pattern-prefetch statistics.

| Capacity | Delay (ticks) | Providers per Pattern Hit (%) | Provider Accuracy (%) | No-Prefetch per Pattern Hit (%) |
|---|---:|---:|---:|---:|
| LogG10 | 0 | 83.57% | 97.98% | 0.05% |
| LogG10 | 2 | 83.07% | 97.99% | 0.89% |
| LogG10 | 4 | 82.53% | 98.03% | 2.82% |
| LogG10 | 8 | 74.36% | 98.20% | 13.64% |
| LogG10 | 16 | 60.57% | 98.51% | 28.17% |
| LogG9 | 0 | 85.71% | 98.05% | 0.09% |
| LogG9 | 2 | 84.55% | 98.05% | 0.66% |
| LogG9 | 4 | 83.22% | 98.09% | 2.43% |
| LogG9 | 8 | 76.99% | 98.26% | 10.98% |
| LogG9 | 16 | 67.48% | 98.56% | 24.33% |
| LogG8 | 0 | 86.54% | 98.07% | 0.03% |
| LogG8 | 2 | 87.01% | 98.08% | 0.57% |
| LogG8 | 4 | 86.50% | 98.09% | 2.02% |
| LogG8 | 8 | 80.16% | 98.27% | 9.17% |
| LogG8 | 16 | 72.00% | 98.56% | 20.26% |

The results show that increasing access delay is associated with a reduction in the proportion of pattern hits that can be used by LLBP-X as a provider.

At the same time, the no-prefetch-per-pattern-hit rate increases substantially.

Provider accuracy increases slightly at higher delays. This should not be interpreted as an improvement in overall prediction accuracy. Provider accuracy measures only predictions made using LLBP-X providers; it does not capture the loss of provider coverage.

The observed increase in provider accuracy may be associated with changes in which predictions remain provider-eligible. The aggregate data alone does not establish the precise cause.

The `Shorter` and `NoPrefetch` counters track separate conditions associated with pattern hits that are not used as providers. Both conditions can apply to the same pattern hit, so the counters are not mutually exclusive and should not be interpreted as a complete partition of all pattern hits.

### Workload-Level Analysis

At an access delay of 16 ticks, all 14 workloads exhibit higher MPKI than their corresponding non-timing references across all three capacity configurations.

The largest relative MPKI increases occur for the Chirper workload:

| Capacity | Reference MPKI | Timing MPKI | Absolute Increase | Relative Increase |
|---|---:|---:|---:|---:|
| LogG10 | 0.4173 | 0.6438 | 0.2265 | 54.29% |
| LogG9 | 0.4415 | 0.7620 | 0.3205 | 72.59% |
| LogG8 | 0.4883 | 0.8504 | 0.3621 | 74.17% |

The large relative increase should be interpreted in the context of Chirper's relatively low starting MPKI.

The largest absolute increases occur for the following workloads:

| Workload | LogG10 Increase | LogG9 Increase | LogG8 Increase |
|---|---:|---:|---:|
| mwnginxfpm-wiki | +0.7191 | +0.9324 | +1.1023 |
| nodeapp-nodeapp | +0.6280 | +0.5395 | +0.5414 |
| dacapo-spring | +0.5120 | +0.5334 | +0.4704 |

These results indicate that the impact of pattern-prefetch access delay depends on workload characteristics and the underlying predictor capacity.

### Discussion

The timing experiment demonstrates that LLBP-X's prediction-accuracy benefit depends not only on pattern availability but also on whether the pattern can be accessed in time for the prediction.

As access delay increases, fewer matching patterns are available for use as LLBP-X providers. This is accompanied by a reduction in provider coverage and an increase in MPKI.

The effect is visible across all three capacity configurations. Although the exact degradation differs between LogG10, LogG9, and LogG8, all configurations show substantial deterioration at the largest evaluated delay.

These results highlight the importance of considering access latency when evaluating the practical effectiveness of pattern-based branch prediction.

---

## Limitations

The experiments have the following limitations:

- The timing model uses simulator ticks, not physical CPU cycles.
- The evaluated access delays are approximate simulator parameters and are not mapped to measured hardware latency.
- No cycle-accurate performance, IPC, energy, or physical silicon-area measurements are claimed.
- The storage values are estimates rather than synthesized hardware measurements.
- The workload set contains 14 benchmarks, and the results may not generalize to all applications.
- Each workload and configuration is evaluated once in the reported experiment matrix. The results do not establish statistical significance across repeated independent trials.
- The timing experiment evaluates the behavior of the existing approximate timing model and does not constitute a complete hardware implementation of the pattern-prefetch mechanism.

---

## Conclusion

The capacity-sensitivity study shows that LLBP-X can recover a portion of the prediction-accuracy loss associated with reducing TAGE-SC-L capacity. The degree of recovery varies with capacity configuration and workload.

Metric A shows that LLBP-X improves over the corresponding same-capacity standalone predictor in aggregate. Metric B shows that the advantage over the full-size standalone baseline becomes smaller as capacity is reduced.

The timing-sensitivity study shows that increasing approximate pattern-prefetch access delay generally degrades prediction accuracy. At 4 ticks and above, all 14 workloads show higher MPKI than their corresponding non-timing references across all three capacity configurations.

Together, the two studies demonstrate that both predictor capacity and pattern-prefetch access delay influence the effectiveness of LLBP-X.

---

## References

David Schall, Mária Ďuráčková, and Boris Grot, “The Last-Level Branch Predictor Revisited,” *Proceedings of the IEEE International Symposium on High-Performance Computer Architecture (HPCA)*, 2026.

DOI: [10.1109/HPCA68181.2026.11408567](https://doi.org/10.1109/HPCA68181.2026.11408567)

Upstream implementation: [LLBP-X repository](https://github.com/dhschall/LLBP-X)

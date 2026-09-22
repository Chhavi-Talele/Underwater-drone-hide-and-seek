# Underwater Drone Hide & Seek — MATLAB Simulation

**Author:** Chhavi Talele ([@Chhavi-Talele](https://github.com/Chhavi-Talele))  
**Project:** MathWorks Excellence in Innovation — Autonomous Underwater Vehicle (AUV) Hide & Seek  
**Official Reference:** [MathWorks AUV Modeling & Simulation Challenge](https://www.mathworks.com/videos/design-modeling-and-simulation-of-autonomous-underwater-vehicles-1619636864529.html)  
**Platform:** MATLAB (R2020b or newer / MATLAB Online)  

A multi-agent autonomous underwater vehicle (AUV) simulation where two drones play hide-and-seek in a 3D underwater terrain, built on the [MathWorks AUV Demo](../reference_auv/).

---

## Quick Start

1. Open MATLAB (R2020b or later)
2. Navigate to this directory: `src/matlab/`
3. Run:

```matlab
runHideAndSeek              % standard 300 s game with dashboard
runHideAndSeek('quick')     % 60 s game, no visualisation (fast test)
runHideAndSeek('challenge') % hard mode, 600 s game
runHideAndSeek('mc', 10)    % 10 Monte Carlo trials, win-rate statistics
```

---

## Requirements

| Toolbox | Used for |
|---|---|
| Navigation Toolbox | `occupancyMap3D`, `plannerRRT`, `stateSpaceSE3` |
| UAV Toolbox | `uavScenario`, `uavPlatform`, `uavSensor` |
| Robotics System Toolbox | State spaces, validators |

> The reference project's occupancy maps and path-planning files in `../reference_auv/Source/Planning/` are loaded automatically.

---

## Game Rules

| Condition | Winner |
|---|---|
| Seeker gets within **8 m** of Hider | 🔵 Seeker |
| 300 seconds elapse without capture | 🔴 Hider |

**Default game parameters** (all configurable):

| Parameter | Default |
|---|---|
| Game duration | 300 s |
| Capture radius | 8 m |
| Seeker speed | 1.5 m/s |
| Hider speed | 1.0 m/s (2.5 m/s evasion) |
| Sonar range | 125 m |
| Ping interval | 10 s |
| Particles (belief filter) | 50 |

---

## Project Structure

```
src/matlab/
├── runHideAndSeek.m          ← ENTRY POINT — run this
│
├── HideAndSeekGame.m         ← Game loop orchestrator
├── AUVAgent.m                ← Abstract base class (shared movement)
├── SeekerAUV.m               ← Seeker AI (search → track → pursue)
├── HiderAUV.m                ← Hider AI (hide → silent → evade)
├── UnderwaterEnvironment.m   ← World model (map, currents, LOS)
├── AcousticSonarModel.m      ← Sonar physics (LOS, noise, multipath)
├── ParticleFilter.m          ← Bayesian Hider position estimator
├── GameVisualizer.m          ← 4-panel live MATLAB dashboard
│
├── utils/
│   ├── initOccupancyMap.m    ← Load & prepare 3D map
│   ├── computeLOS.m          ← Line-of-sight check
│   ├── oceanCurrent.m        ← Spatially-varying current field
│   └── selectHidingSpot.m    ← Score candidate hiding positions
│
└── tests/
    ├── test_sonar.m           ← AcousticSonarModel unit tests
    ├── test_particle_filter.m ← ParticleFilter unit tests
    └── test_pathplanner.m     ← LOS, current, hiding spot tests
```

---

## AI Agent Descriptions

### 🔵 Seeker AUV

| State | Behaviour |
|---|---|
| **SEARCH** | Lawnmower sweep across 3 depth layers (−15, −40, −75 m) |
| **TRACK** | Particle filter updated on each acoustic ping; replans path every 5 s |
| **PURSUE** | Aggressive pursuit when belief uncertainty drops below 25 m |

### 🔴 Hider AUV

| State | Behaviour |
|---|---|
| **HIDE** | Navigate to best terrain-occluded, far, mid-depth position |
| **SILENT** | Suppress acoustic pings; slow drift when Seeker within 60 m |
| **EVADE** | Emergency dash at 2.5× normal speed when Seeker within 25 m |

---

## Sonar Physics

The `AcousticSonarModel` extends the reference `blackBox.m` + `phasedArraySonar.m`:

- **LOS occlusion** — terrain blocks acoustic propagation
- **Range** — 125 m (quadratic signal decay)
- **Bearing noise** — σ = 7.5° azimuth, 3° elevation (Gaussian)
- **Depth attenuation** — 20% faster signal decay at depth
- **Multipath** — 30% probability of spurious ghost bearing

---

## Running Tests

```matlab
cd tests
addpath('..')
addpath('../utils')

test_sonar            % 6 sonar model tests
test_particle_filter  % 6 particle filter tests
test_pathplanner      % 7 utility tests
```

---

## Architecture Diagram

```
HideAndSeekGame (game loop)
├── UnderwaterEnvironment  ──▶  3D occupancy map (reference .mat files)
│                           ──▶  Ocean current field
│                           ──▶  Free-cell candidates for Hider
│
├── AcousticSonarModel  ──▶  Ping detection (LOS + range + noise)
│
├── SeekerAUV  ──▶  ParticleFilter (belief over Hider pose)
│              ──▶  auvPathPlanner (RRT from reference, if available)
│
├── HiderAUV   ──▶  selectHidingSpot (terrain scoring)
│              ──▶  Acoustic silence management
│
└── GameVisualizer  ──▶  4-panel MATLAB figure (real-time)
```

---

## Reference

This project builds on the **MathWorks AUV Demo** (2021):
- [`reference_auv/Source/Planning/auvPathPlanner.m`](../reference_auv/Source/Planning/auvPathPlanner.m) — RRT path planner
- [`reference_auv/Source/Planning/phasedArraySonar.m`](../reference_auv/Source/Planning/phasedArraySonar.m) — sonar bearing model
- [`reference_auv/Source/Planning/blackBox.m`](../reference_auv/Source/Planning/blackBox.m) — acoustic ping model

Webinar: https://www.mathworks.com/videos/design-modeling-and-simulation-of-autonomous-underwater-vehicles-1619636864529.html

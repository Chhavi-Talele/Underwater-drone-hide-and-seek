# Underwater Drone Hide & Seek — 3D Autonomous Tactical Simulation

[![MATLAB](https://img.shields.io/badge/MATLAB-R2020b%2B-blue.svg)](https://www.mathworks.com/products/matlab.html)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/Platform-MATLAB%20%7C%20MATLAB%20Online-orange.svg)](https://matlab.mathworks.com/)

An advanced, self-contained **3D Underwater Autonomous Vehicle (AUV) Hide & Seek Simulation** built in MATLAB. The simulation models a tactical game between an active searching drone (**Seeker**) and a stealthy evading drone (**Hider**) in a complex ocean environment filled with bathymetric seabed terrain, procedural rock obstacles, swaying kelp thickets, ray-cast acoustic shadows, and dynamic sonar exposure heatmaps.

---

## 🌊 Overview & Highlights

* **100% Standalone**: Runs out-of-the-box in **MATLAB Desktop** and **MATLAB Online** with zero external toolbox dependencies.
* **Dual Autonomous AI Engines**:
  * **Seeker AUV**: Features a $38^\circ$ conical active sonar scanning beam, 3D obstacle repulsion, and a **3D Particle Filter** target belief tracking engine.
  * **Hider AUV**: Features a **$110\text{m}$ Long-Range Passive Acoustic Array**, **4-step Predictive Sonar Beam Avoidance**, multi-criterion candidate hiding spot evaluation (boulder shadows + kelp attenuation), and 4 tactical AI behavioral modes.
* **Interactive UI & Camera Controls**: Integrated toolbar with **Pause/Resume**, **Restart**, **3D Isometric View**, **2D Top-Down Map View**, **Side Elevation View**, **Zoom (+/-)**, **Mouse Scroll Wheel Zoom**, and **3D Orbit Rotate** (`rotate3d`).
* **Crisp Ocean Visuals**: Light ocean aesthetic with semi-transparent water surface, textured bathymetric floor, 14 shaded 3D boulders, swaying multi-leaf kelp fronds, and live floor sonar exposure heatmap overlay.

---

## 🎯 Key Features

### 1. Advanced Hider AI Senses
* **Passive Acoustic Array Hearing ($110\text{m}$ Range)**: Hider listens for Seeker sonar pings from long distances, detecting the Seeker well before entering its direct line of sight.
* **Predictive Sonar Sweep Avoidance**: Projects the Seeker's rotational sonar sweep $4$ steps into the future. If projected to enter the beam, the Hider triggers a **`PRE-EMPTIVE DUCK`** maneuver to hide behind cover before the sonar ping arrives.
* **Multi-Factor Shadow Evaluator**: Evaluates candidate hiding vectors behind 14 boulders and kelp thickets using a composite safety score:
  $$\text{Score} = 1.8 \cdot d_{\text{seeker}} - 0.35 \cdot d_{\text{hider}} - 18.0 \cdot \cos(\theta_{\text{shadow}}) + \text{KelpBonus}$$
* **4 Tactical AI Modes**:
  1. `HIDE (STALK)`: Cruising toward optimal occluded hiding spot ($1.5\text{ m/step}$).
  2. `SILENT SHADOW`: Silent crawl ($0.45\text{ m/step}$) when clinging to rock shadow cover to minimize target strength.
  3. `SPRINT EVADE`: Max speed burst ($2.7\text{ m/step}$) when spotted or within close range.
  4. `PRE-EMPTIVE DUCK`: Pre-emptive evasion ($2.2\text{ m/step}$) into acoustic dark zones upon sweep warning.

### 2. Seeker AUV & Active Sonar Engine
* **Conical Scanning Beam**: $38^\circ$ azimuth and $24^\circ$ elevation active sonar cone with max range of $65\text{m}$.
* **Ray-Cast Occlusion**: Computes exact ray-sphere intersections against all 14 boulders to determine acoustic line-of-sight shadow zones.
* **3D Particle Filter Tracking**: Maintains a 40-particle belief distribution estimating Hider position under noisy measurements or loss of signal.

### 3. Seabed Sonar Exposure Heatmap
Live floor overlay using MATLAB's `parula` colormap to track acoustic energy exposure levels over time:
* 🟦 **Dark Blue / Purple ($0 - 5$)**: **Dark Zone** — Unscanned areas or boulder acoustic shadows (Safest Hiding Spot).
* 🩵 **Cyan / Teal ($5 - 15$)**: Low exposure areas swept 1–2 times.
* 🟩 **Green ($15 - 30$)**: Frequently scanned ocean floor zones.
* 🟨 **Bright Yellow ($30 - 40+$)**: **Hotspots** — Heavily scanned or target-locked areas (High Detection Risk).

---

## 🎮 Interactive Toolbar & Controls

| Button | Action |
| :--- | :--- |
| **`⏸ Pause` / `▶ Resume`** | Toggles simulation pause state with on-screen banner overlay. |
| **`↺ Restart`** | Re-initializes simulation positions and parameters instantly. |
| **`📷 3D Iso`** | Switches to 3D isometric perspective (`view([38, 28])`). |
| **`🗺 2D Top`** | Switches to top-down 2D map view (`view([0, 90])`) with North up. |
| **`⚓ Side View`** | Switches to side elevation view (`view([0, 0])`) displaying depth profiles. |
| **`🔍 Zoom +`** | Zooms camera in ($1.25\times$). |
| **`🔎 Zoom -`** | Zooms camera out ($0.80\times$). |
| **`🎯 Reset Cam`** | Resets camera angle and bounds to default. |
| **`🔄 Orbit 3D`** | Toggles interactive mouse drag-rotation (`rotate3d`). |
| **Mouse Scroll Wheel** | Scroll up to zoom in, scroll down to zoom out smoothly. |

---

## 🚀 Quick Start Guide

### Running in MATLAB Online
1. Open [MATLAB Online](https://matlab.mathworks.com/).
2. Open [`src/matlab/StandaloneSimulation.m`](src/matlab/StandaloneSimulation.m) and copy the entire file.
3. Paste into a new script in MATLAB Online and click **Run** (or press `F5`).

### Running in Desktop MATLAB
1. Clone this repository:
   ```bash
   git clone https://github.com/Chhavi-Talele/Underwater-drone-hide-and-seek.git
   cd Underwater-drone-hide-and-seek
   ```
2. Open MATLAB and run:
   ```matlab
   cd('src/matlab');
   StandaloneSimulation;
   ```

---

## 📁 Repository Structure

```
Underwater-drone-hide-and-seek/
├── README.md                           # Documentation & user guide
├── src/
│   └── matlab/
│       └── StandaloneSimulation.m      # Complete standalone MATLAB simulation script
└── web/                                # HTML/Web demo files
```

---

## 📜 License

Distributed under the MIT License. See `LICENSE` for more information.

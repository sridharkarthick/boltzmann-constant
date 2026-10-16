# Boltzmann's Constant: Shockley Diode Equation Method

## 1. Apparatus

| # | Component | Part / Spec | Role |
|:---:|:---|:---|:---|
| 1 | **Keithley 2450 SourceMeter SMU** | 200 V / 1 A / 10 fA resolution | Sources precise voltage; measures diode current simultaneously |
| 2 | **Raspberry Pi 3B+** | 1 GB RAM, 40-pin GPIO, full-size HDMI | Runs measurement script; displays results on monitor |
| 3 | **ADS1115 ADC module** | 16-bit, I²C (addr `0x48`), ±4.096 V | Reads thermistor voltage → temperature |
| 4 | **NTC thermistor** | NTC50805E, 10 kΩ at 25°C, β = 3950 K | Temperature sensing (mounted on diode body) |
| 5 | **Fixed resistor** | 10 kΩ, 1% tolerance | Voltage divider partner for thermistor |
| 6 | **Test diode** | 1N4148, small-signal silicon | Device under test (DUT) |
| 7 | **DPDT switch** | Momentary or latching | Trigger to start automated sweep |
| 8 | **Breadboard + jumper wires** | Standard 0.1″ pitch | Assembly |
| 9 | **USB-A to USB-B cable** | Standard printer cable | RPi ↔ Keithley 2450 |
| 10 | **HDMI cable** | Standard full-size HDMI | RPi → monitor (live plot display) |
| 11 | **Micro-SD card** | ≥ 16 GB, Class 10 | RPi OS and scripts |
| 12 | **Micro-USB power supply** | 5 V / 2.5 A | Powers RPi 3B+ |

> [!NOTE]
> **Why 1N4148?** Provides a clean Shockley characteristic in the 10 nA to 1 mA range, an ideality factor η ≈ 1.00, and significantly lower junction capacitance than standard rectifier diodes like the 1N4007.

---

## 2. Principle

### 2.1 Shockley Diode Equation

The current-voltage characteristic of an ideal p–n junction diode is governed by the **Shockley diode equation** (refer to [Shockley, 1949](./literature/Shockley_1949_BSTJ_Theory_of_pn_Junctions.pdf)):

> **_I_<sub>D</sub> = _I_<sub>S</sub> · [ exp( _V_<sub>D</sub> / (_n_ · _V_<sub>T</sub>) ) − 1 ]**

| Symbol | Meaning | Value / Source |
|:---:|:---|:---|
| **_I_<sub>D</sub>** | Diode current | Measured by Keithley 2450 |
| **_I_<sub>S</sub>** | Reverse-bias saturation current (scale current) | Constant pre-factor (cancels in linear fit) |
| **_V_<sub>D</sub>** | Voltage across the diode | Sourced and measured by Keithley 2450 |
| **_V_<sub>T</sub>** | Thermal voltage = (_k_<sub>B</sub> · _T_) / _q_ | Evaluated from junction temperature |
| **_n_** | Ideality factor (quality factor / emission coefficient) | ≈ 1.00 for 1N4148 (_n_ = 1 for the ideal Shockley diode) |
| **_k_<sub>B</sub>** | **Boltzmann constant** | **Target parameter** |
| **_T_** | Absolute temperature of the p–n junction | Measured by NTC thermistor via ADS1115 |
| **_q_** | Elementary charge | 1.602176634 × 10⁻¹⁹ C (exact) |

---

### Thermal Voltage Definition

The thermal voltage **_V_<sub>T</sub>** represents the characteristic energy scale per unit charge:

> **_V_<sub>T</sub> = (_k_<sub>B</sub> · _T_) / _q_**

---

### 2.2 Moderate Forward-Bias Approximation & Linearisation

For moderate forward-bias voltages (_V_<sub>D</sub> > 0.3 V), the exponential term becomes several orders of magnitude larger than 1 because the thermal voltage is comparatively small (_V_<sub>T</sub> ≈ 25.7 mV at room temperature).

The "− 1" term in the Shockley equation becomes negligible, allowing the forward diode current to approximate:

> **_I_<sub>D</sub> ≈ _I_<sub>S</sub> · exp[ _V_<sub>D</sub> / (_n_ · _V_<sub>T</sub>) ] = _I_<sub>S</sub> · exp[ (_q_ · _V_<sub>D</sub>) / (_n_ · _k_<sub>B</sub> · _T_) ]**

Taking the natural logarithm of both sides in the forward-bias region where _I_<sub>D</sub> ≫ _I_<sub>S</sub>:

> **ln(_I_<sub>D</sub>) = ln(_I_<sub>S</sub>) + [ _q_ / (_n_ · _k_<sub>B</sub> · _T_) ] · _V_<sub>D</sub>**

This matches the standard straight-line equation **_y_ = _c_ + _m_ · _x_**, where:

- **_y_** = ln(_I_<sub>D</sub>)
- **_x_** = _V_<sub>D</sub>
- **_c_** = ln(_I_<sub>S</sub>) (y-intercept)
- **_m_** = _q_ / (_n_ · _k_<sub>B</sub> · _T_) (slope)

---

### 2.3 Extracting _k_<sub>B</sub>

Solving the slope relation for Boltzmann's constant:

> **_k_<sub>B</sub> = _q_ / (_n_ · _T_ · _m_)**

The slope **_m_** is obtained from ordinary least-squares linear regression of **ln(_I_<sub>D</sub>)** versus **_V_<sub>D</sub>**. Because **_q_** is an exact constant and **_T_** is measured independently by the thermistor, **_k_<sub>B</sub>** follows directly.

## 3. How This Method Estimates k_B

The 1N4148 diode acts as a thermodynamic voltmeter. At a given temperature *T*, the steepness of the exponential current rise with voltage is governed by the ratio *q* / (*k_B T*)—the thermal energy scale that underpins Maxwell-Boltzmann statistics. By measuring how steeply ln(*I*) rises per volt (the slope *m*) and knowing *T* independently from the NTC thermistor, the software inverts the Shockley equation to compute:

> **_k_<sub>B</sub> = _q_ / (η · _T_ · _m_)**

The Keithley 2450 SMU provides the precision needed for this measurement: it sources voltage within ±500 µV and resolves current down to 10 fA. Integrating each sample point over multiple power line cycles (NPLC) suppresses 50/60 Hz mains interference. Three independent sweeps are executed and statistically pooled, typically yielding a result within 0.5%–2% of the standard value (1.380649 × 10⁻²³ J·K⁻¹).

---

## 4. Uncertainty Analysis & Propagation

The measurement model for Boltzmann’s constant is:

> **_k_<sub>B</sub> = _f_(_m_, _T_, _n_) = _q_ / (_n_ · _T_ · _m_)**

Because elementary charge _q_ is an exact defining constant (_q_ ≡ 1.602 176 634 × 10⁻¹⁹ C under the SI definition, σ_q = 0), the variance in _k_<sub>B</sub> originates from the uncertainty in the regression slope _m_, the absolute temperature _T_, and the ideality factor _n_.

---

### 4.1 First-Order Taylor Propagation (Covariance Law)

The combined standard variance _u_<sub>c</sub>²(_k_<sub>B</sub>) is given by the multivariate partial-derivative expansion:

> **_u_<sub>c</sub>²(_k_<sub>B</sub>) = (∂_f_ / ∂_m_)² · _u_²(_m_) + (∂_f_ / ∂_T_)² · _u_²(_T_) + (∂_f_ / ∂_n_)² · _u_²(_n_) + 2 · ∑ (∂_f_ / ∂_x_<sub>i</sub>)(∂_f_ / ∂_x_<sub>j</sub>) · _u_(_x_<sub>i</sub>, _x_<sub>j</sub>)**

The partial derivatives (sensitivity coefficients) evaluate to:

- **∂_f_ / ∂_m** = −_q_ / (_n_ · _T_ · _m_²) = −_k_<sub>B</sub> / _m_
- **∂_f_ / ∂_T** = −_q_ / (_n_ · _T_² · _m_) = −_k_<sub>B</sub> / _T_
- **∂_f_ / ∂_n** = −_q_ / (_n_² · _T_ · _m_) = −_k_<sub>B</sub> / _n_

Because temperature _T_ is acquired via the NTC/ADS1115 front-end while the slope _m_ is extracted from the Keithley 2450 SMU _I_–_V_ sweep, their cross-correlation is zero (_u_(_m_, _T_) = 0). For an ideal small-signal silicon junction operating strictly in the low-level diffusion regime where _n_ is fixed (_u_(_n_) → 0):

> **_u_<sub>c</sub>(_k_<sub>B</sub>) / _k_<sub>B</sub> = √[ (_u_(_m_) / _m_)² + (_u_(_T_) / _T_)² ]**

Where:

- **_u_(_m_)** is the standard error of the regression slope estimated from the residual sum of squares:

  > **_u_(_m_) = √[ ∑ ( ln _I_<sub>k</sub> − (_ĉ_ + _m_ · _V_<sub>k</sub>) )² / ( (_K_ − 2) · ∑ (_V_<sub>k</sub> − _V̄_)² ) ]**

  *(for _K_ voltage-current sample pairs per sweep)*

- **_u_(_T_)** is the combined temperature uncertainty incorporating sensor calibration, ADC quantization, and Steinhart-Hart / β-parameter tolerance:

  > **_u_(_T_) = √[ _u_<sub>cal</sub>² + _u_<sub>ADC</sub>² + _u_<sub>drift</sub>² ]**

---

### 4.2 Inverse-Variance Weighted Pooling of Independent Runs

For an ensemble of _N_ sweeps executed at steady state, each run yields an estimate _k_<sub>B,_i_</sub> with associated variance σ<sub>_i_</sub>² ≡ _u_<sub>c,_i_</sub>²(_k_<sub>B</sub>). The maximum-likelihood estimator under a Gaussian error model is the weighted mean:

> **_k_<sub>B, comb</sub> = ( ∑ _w_<sub>_i_</sub> · _k_<sub>B,_i_</sub> ) / ( ∑ _w_<sub>_i_</sub> ), &nbsp;&nbsp;&nbsp;&nbsp; where _w_<sub>_i_</sub> = 1 / σ<sub>_i_</sub>²**

The internal standard error of the combined estimate is:

> **σ<sub>int</sub> = 1 / √( ∑ _w_<sub>_i_</sub> )**

---

### 4.3 Goodness-of-Fit and Birge Ratio (χ²<sub>red</sub>)

To test whether the dispersion among sweeps agrees with the estimated single-sweep measurement uncertainties, we calculate the reduced chi-squared statistic (Birge ratio _R_<sub>B</sub>²):

> **χ²<sub>red</sub> = [ 1 / (_N_ − 1) ] · ∑ [ (_k_<sub>B,_i_</sub> − _k_<sub>B, comb</sub>)² / σ<sub>_i_</sub>² ]**

- **χ²<sub>red</sub> ≈ 1:** The residuals conform to the expected stochastic distribution; σ<sub>int</sub> fully characterizes the measurement uncertainty.
- **χ²<sub>red</sub> ≫ 1:** Indicates non-negligible systematic drift between sweeps (e.g., localized self-heating or junction contact drift). In accordance with standard metrological practice, the combined uncertainty is inflated by the Birge scale factor:

> **_u_<sub>total</sub>(_k_<sub>B</sub>) = σ<sub>int</sub> · max( 1, √(χ²<sub>red</sub>) )**

Expanded uncertainty is reported at the 95% confidence level (_k_ = 2 coverage factor):

> **_k_<sub>B, final</sub> = _k_<sub>B, comb</sub> ± 2 · _u_<sub>total</sub>(_k_<sub>B</sub>)**

---

## 5. Assembly — Pin-by-Pin Wiring

### 5.1 RPi 3B+ GPIO Header Reference

The 40-pin header is located along the top edge of the Raspberry Pi 3B+ board. Pin 1 is the inner pin in the top row (closest to the board edge / marked with a small square/triangle silkscreen).

```text
         Pin 1   Pin 2
         3.3V    5V
          SDA    5V
          SCL    GND   ← Pin 6
        GPIO4    TX
          GND    RX
       GPIO17    ...   ← Pin 11 = GPIO 17 (trigger)
          ...
```

- Odd-numbered pins (1, 3, 5, 7, …) form the inside column.
- Even-numbered pins (2, 4, 6, 8, …) form the outside column.

### 5.2 ADS1115 Module

| ADS1115 Pin | Suggested Wire Colour | RPi Physical Pin | Signal / Function |
|:---|:---|:---|:---|
| **VDD** | Red | **Pin 1** | 3.3 V Power |
| **GND** | Black | **Pin 6** | Ground |
| **SCL** | Yellow | **Pin 5** | GPIO 3 (I²C Clock) |
| **SDA** | Blue | **Pin 3** | GPIO 2 (I²C Data) |
| **ADDR** | Black | **Pin 6** | Ground (Sets address to `0x48`) |
| **A0** | Green | Breadboard node | Thermistor divider output voltage |
| **A1, A2, A3** | — | Unconnected | Leave floating or ground |

### 5.3 Thermistor Voltage Divider (on Breadboard)

```text
RPi Pin 1 (3.3 V)
       │
    [10 kΩ]  ← 1% Precision fixed resistor
       │
       ├────────────────────────► ADS1115 Pin A0
       │
    [ NTC ]  ← 10 kΩ thermistor, thermally bonded to 1N4148 diode body
       │
RPi Pin 6 (GND)
```

### 5.4 DPDT Switch (Sweep Trigger)

Only one single-throw pole (two terminals) is needed:

| Switch Terminal | RPi Physical Pin | Signal | Notes |
|:---|:---|:---|:---|
| **Terminal A** | **Pin 11** | GPIO 17 | Pulled HIGH internally via software |
| **Terminal B** | **Pin 9** | GND | Pulls GPIO 17 LOW when closed |

### 5.5 Keithley 2450 SMU Connections

Configure the SMU in 2-wire local sensing mode:

| 2450 Terminal | Binding Post Colour | Target Connection |
|:---|:---|:---|
| **FORCE HI** | Red | 1N4148 **Anode** (terminal opposite the cathode band) |
| **FORCE LO** | Black | 1N4148 **Cathode** (terminal with black stripe) |
| **SENSE HI** | Red (inner) | Short directly to FORCE HI |
| **SENSE LO** | Black (inner) | Short directly to FORCE LO |
| **USB Type-B** | Rear chassis | Any open USB-A port on the Raspberry Pi |

### 5.6 Monitor Connection

```text
RPi 3B+ HDMI Port ──► Standard Full-Size HDMI Cable ──► Monitor HDMI Input
```

> [!TIP]
> If connecting to an older lab monitor with only a VGA port, use an **active HDMI-to-VGA converter** with external micro-USB power injection. Passive adapters cannot draw sufficient current from the Raspberry Pi HDMI lines and will cause display dropout.

### 5.7 Complete Wiring Map

| RPi Physical Pin | Signal Name | Connected To |
|:---|:---|:---|
| **Pin 1** | 3.3 V DC | ADS1115 VDD · Top leg of 10 kΩ divider resistor |
| **Pin 3** | GPIO 2 (I²C SDA) | ADS1115 SDA |
| **Pin 5** | GPIO 3 (I²C SCL) | ADS1115 SCL |
| **Pin 6** | GND | ADS1115 GND · ADS1115 ADDR · Bottom leg of NTC thermistor |
| **Pin 9** | GND | Switch Terminal B |
| **Pin 11** | GPIO 17 | Switch Terminal A |
| **USB-A Port** | USB 2.0 Host | Keithley 2450 rear USB-B port (USBTMC interface) |
| **HDMI Port** | Digital Video | Lab HDMI monitor |

---


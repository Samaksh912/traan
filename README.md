# 🛡️ Raksha — Women Safety App

> **Raksha** (Sanskrit: रक्षा, *protection*) is a cross-platform mobile application built with Flutter that empowers women with real-time district-level safety insights powered by machine learning, interactive maps, an AI chatbot, and a community forum.

---

## 📋 Table of Contents

- [Overview](#overview)
- [Features](#features)
- [Tech Stack](#tech-stack)
- [Project Structure](#project-structure)
- [Backend — ML Pipeline](#backend--ml-pipeline)
- [Frontend — Flutter App](#frontend--flutter-app)
- [Getting Started](#getting-started)
- [Dataset](#dataset)
- [Model Performance](#model-performance)

---

## Overview

Raksha combines a Python-based data science backend with a Flutter mobile frontend to deliver district-level women's safety scores across India. Historical crime data (2001–2015) from the National Crime Records Bureau (NCRB) is cleaned, processed, and used to train a **Random Forest classifier** that categorises any district as **Safe**, **Moderate**, or **Unsafe**. The resulting safety scores are bundled into the app and visualised on an interactive map.

---

## ✨ Features

| Feature | Description |
|---|---|
| 🗺️ **Safety Map** | Interactive district-level map with colour-coded safety overlays (Safe / Moderate / Unsafe) |
| 🤖 **AI Chatbot** | Dialogflow-powered safety assistant for real-time guidance |
| 📰 **News Feed** | Curated safety-related news for women |
| 👥 **Community** | Forum for sharing experiences and safety tips |
| 🆘 **Emergency Call** | One-tap direct calling to emergency contacts |
| 🔐 **Authentication** | Firebase Auth with Google Sign-In support |
| 📍 **Geolocation** | Live location awareness for contextual safety information |
| 🏠 **Home Widget** | Quick-access home screen widget |

---

## 🛠️ Tech Stack

### Frontend
| Layer | Technology |
|---|---|
| Framework | Flutter (Dart) — SDK `>=3.0.0 <4.0.0` |
| Maps | `flutter_map` + `latlong2` |
| Authentication | Firebase Auth + Google Sign-In |
| Chatbot | `dialog_flowtter` (Dialogflow) |
| Navigation | `curved_navigation_bar` |
| Fonts | `google_fonts` |
| Storage | `shared_preferences`, `path_provider` |
| Networking | `http`, `url_launcher` |
| Data | CSV parsing via `csv` package |
| Location | `geolocator` |

### Backend (ML Pipeline)
| Layer | Technology |
|---|---|
| Language | Python 3 (Google Colab) |
| Data Processing | `pandas`, `numpy` |
| Visualisation | `matplotlib`, `folium` |
| ML Models | `scikit-learn` (Random Forest, KNN) |
| Serialisation | `joblib` |

---

## 📁 Project Structure

```
raksha/
├── lib/                          # Flutter frontend source
│   ├── main.dart                 # App entry point
│   ├── firebase_options.dart     # Firebase configuration
│   ├── Home/                     # Home screen & dashboard
│   ├── Map/                      # Safety map screen
│   ├── bot/                      # AI chatbot interface
│   ├── community/                # Community forum
│   ├── models/                   # Data models
│   ├── pages/                    # App pages
│   │   ├── authpage.dart         # Auth gate
│   │   ├── loginpage.dart        # Login screen
│   │   ├── registerpage.dart     # Registration screen
│   │   ├── loginorreg.dart       # Login/Register switcher
│   │   ├── profile.dart          # User profile
│   │   ├── raksha.dart           # Main scaffold
│   │   └── newsmodel.dart        # News data model
│   ├── services/
│   │   └── authservice.dart      # Firebase auth service
│   ├── tools/                    # Utility tools
│   ├── utils/                    # Helper utilities
│   └── widgets/                  # Reusable UI widgets
│
├── assets/
│   ├── images/                   # App images & icons
│   └── final_safety_scores.csv   # Pre-processed safety scores (ML output)
│
├── women_crimes (1).ipynb        # 🔬 Backend ML pipeline (Google Colab)
├── pubspec.yaml                  # Flutter dependencies
└── README.md
```

---

## 🔬 Backend — ML Pipeline

The backend is a **Google Colab notebook** (`women_crimes (1).ipynb`) that implements the full data science pipeline.

### Pipeline Stages

```
Raw CSV Data → Cleaning → Feature Engineering → Safety Scoring → ML Model → Export
```

#### 1. Data Ingestion
- Loads 4 NCRB datasets: `dataset_2001_2012.csv`, `dataset_2013.csv`, `dataset_2014.csv`, `dataset_2015.csv`
- Total records: **11,530** rows after merging

#### 2. Data Cleaning
- Standardises column names across datasets
- Removes duplicate columns
- Forward-fills missing `State/UT` values
- Drops irrelevant columns (Dowry Deaths, serial numbers, totals rows, etc.)
- Combines modesty-related crime columns into a single `Modesty-Related Crimes` feature

#### 3. Feature Engineering
The model uses **7 crime features**:

| Feature | Importance |
|---|---|
| Modesty-Related Crimes | **49.8%** |
| Rape | 24.1% |
| Kidnapping and Abduction | 24.0% |
| Attempt to commit Rape | 1.5% |
| Protection of Women from Domestic Violence Act, 2005 | 0.4% |
| Importation of Girls | 0.3% |
| Protection of Children from Sexual Offences Act | ~0% |

#### 4. Safety Scoring
- Computes `Total Crimes against Women` by summing all 7 crime features
- Applies a **non-linear normalised safety score**:
  ```
  Safety Score = 100 − ((crimes^0.8 / max_crimes^0.8) × 100)
  ```
- Classifies districts using **90th/70th percentile thresholds**:
  - **Safe** — below 70th percentile (7,685 districts)
  - **Moderate** — 70th–90th percentile (2,215 districts)
  - **Unsafe** — above 90th percentile (1,103 districts)

#### 5. Machine Learning

**Random Forest Classifier**
```python
RandomForestClassifier(n_estimators=100, random_state=42)
```
- Accuracy: **98.73%**

**K-Nearest Neighbours (KNN)**
```python
KNeighborsClassifier(n_neighbors=5)
```
- Accuracy: **98.91%**

#### 6. Output Artifacts
| File | Description |
|---|---|
| `final_safety_scores.csv` | District-level safety scores — bundled in the Flutter app |
| `safety_model.pkl` | Serialised Random Forest model |
| `label_encoder.pkl` | Serialised label encoder |

---

## 📱 Frontend — Flutter App

### Architecture
The app follows a feature-based folder structure with dedicated directories for pages, services, widgets, and models.

### Key Screens

- **Login / Register** — Firebase email+password and Google Sign-In authentication
- **Home Dashboard** — Safety overview and quick actions
- **Safety Map** — `flutter_map`-based interactive map with district safety colour coding, powered by `final_safety_scores.csv`
- **AI Chatbot** — Dialogflow integration via `dialog_flowtter` for conversational safety guidance
- **Community** — User forum for sharing safety tips and experiences
- **Profile** — User account management
- **Emergency** — Direct calling via `flutter_phone_direct_caller`

### Navigation
Bottom navigation using `curved_navigation_bar` for a smooth, modern UX.

---

## 🚀 Getting Started

### Prerequisites
- Flutter SDK `>=3.0.0`
- Dart SDK
- Android Studio / Xcode
- Firebase project with Auth enabled

### Frontend Setup

```bash
# Clone the repository
git clone https://github.com/Samaksh912/traan.git
cd traan

# Install dependencies
flutter pub get

# Run the app
flutter run
```

### Backend Setup (ML Pipeline)

1. Open `women_crimes (1).ipynb` in **Google Colab**
2. Upload the four NCRB CSV datasets when prompted:
   - `dataset_2001_2012.csv`
   - `dataset_2013.csv`
   - `dataset_2014.csv`
   - `dataset_2015.csv`
3. Run all cells sequentially
4. Download `final_safety_scores.csv` and place it in `assets/`

---

## 📊 Dataset

The project uses **National Crime Records Bureau (NCRB)** district-level crime statistics covering **2001–2015** across all Indian states and union territories.

**Dataset columns used:**
- State/UT, District, Year
- Rape, Attempt to commit Rape
- Kidnapping and Abduction
- Modesty-Related Crimes (Assault + Insult combined)
- Importation of Girls
- Protection of Children from Sexual Offences Act (POCSO)
- Protection of Women from Domestic Violence Act, 2005

---

## 📈 Model Performance

| Model | Accuracy |
|---|---|
| Random Forest (n=100) | **98.73%** |
| K-Nearest Neighbours (k=5) | **98.91%** |

**Random Forest Confusion Matrix:**
```
             Unsafe  Moderate   Safe
Unsafe      [  403        7      6 ]
Moderate    [    6     1561      0 ]
Safe        [    9        0    209 ]
```

---

## 🤝 Contributing

Pull requests are welcome. For major changes, please open an issue first to discuss what you would like to change.

---

## 📄 License

This project is private and not published to pub.dev.

---

<div align="center">
  <b>Built with ❤️ to help keep women safe across India.</b>
</div>

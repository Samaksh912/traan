# 🛡️ Traan — Women Safety & Empowerment App

> **Traan** is a comprehensive cross-platform mobile application built with Flutter that empowers women with real-time district-level safety insights, AI-powered navigation, emergency response features, and community support powered by machine learning and interactive mapping.

---

## 📋 Table of Contents

- [Overview](#overview)
- [Features](#features)
- [Tech Stack](#tech-stack)
- [Project Structure](#project-structure)
- [Backend — ML Pipeline](#backend--ml-pipeline)
- [Frontend — Flutter App](#frontend--flutter-app)
- [Key Features in Detail](#key-features-in-detail)
- [Getting Started](#getting-started)
- [Dataset](#dataset)
- [Model Performance](#model-performance)

---

## Overview

Traan combines a Python-based data science backend with a Flutter mobile frontend to deliver district-level women's safety scores across India, complemented by intelligent navigation features, emergency response capabilities, and community engagement. Historical crime data (2001–2015) from the National Crime Records Bureau (NCRB) is cleaned, processed, and used to train machine learning models that categorise any district as **Safe**, **Moderate**, or **Unsafe**. The resulting safety scores are integrated with real-time location awareness and Google Maps API to provide safety-based route navigation.

---

## ✨ Features

| Feature | Description |
|---|---|
| 🗺️ **Safety Map** | Interactive district-level map with colour-coded safety overlays (Safe / Moderate / Unsafe) |
| 🧭 **Safe Route Navigation** | Google Maps-integrated routing that selects safer paths based on district safety scores |
| 🤖 **AI Chatbot** | Dialogflow-powered safety assistant for real-time guidance and safety advice |
| 📰 **News Feed** | Curated safety-related news and updates for women |
| 👥 **Community Forum** | Collaborative space for sharing experiences, safety tips, and support |
| 🆘 **Emergency SOS** | One-tap emergency contact notifications with location sharing (WhatsApp, Call) |
| 🔐 **Authentication** | Secure Firebase Auth with Google Sign-In and email/password support |
| 📍 **Real-time Geolocation** | Live location tracking for contextual safety information and emergency response |
| 🏠 **Home Widget** | Quick-access home screen widget for instant safety updates |
| 👤 **User Profiles** | Personalized profiles with customizable emergency contacts |

---

## 🛠️ Tech Stack

### Frontend
| Layer | Technology |
|---|---|
| Framework | Flutter (Dart) — SDK `>=3.0.0 <4.0.0` |
| Maps & Navigation | `flutter_map` + `latlong2` + Google Maps API |
| Authentication | Firebase Auth + Google Sign-In |
| Chatbot | `dialog_flowtter` (Dialogflow) |
| Navigation UI | `curved_navigation_bar` |
| Typography | `google_fonts` |
| Storage | `shared_preferences`, `path_provider` |
| Networking | `http`, `url_launcher`, `webview_flutter` |
| Data | CSV parsing via `csv` package |
| Location Services | `geolocator` |
| Phone Integration | `flutter_phone_direct_caller` (calling), direct messaging |
| Home Widget | `home_widget` (home screen widget integration) |
| Icon Library | `boxicons` (icon set) |

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
traan/
├── lib/                          # Flutter frontend source
│   ├── main.dart                 # App entry point
│   ├── firebase_options.dart     # Firebase configuration
│   ├── Home/                     # Home screen & dashboard
│   ├── Map/                      # Safety map screen with Google Maps integration
│   ├── bot/                      # AI chatbot interface
│   ├── community/                # Community forum
│   ├── models/                   # Data models
│   │   └── sos.dart              # Emergency SOS model
│   ├── pages/                    # App pages
│   │   ├── authpage.dart         # Authentication gate
│   │   ├── loginpage.dart        # Login screen
│   │   ├── registerpage.dart     # Registration screen
│   │   ├── loginorreg.dart       # Login/Register switcher
│   │   ├── profile.dart          # User profile and settings
│   │   ├── raksha.dart           # Main app scaffold and routing
│   │   └── newsmodel.dart        # News data model
│   ├── services/
│   │   ├── authservice.dart      # Firebase authentication service
│   │   └── contacts_store.dart   # Emergency contacts management
│   ├── tools/                    # Utility tools
│   ├── utils/                    # Helper utilities
│   │   ├── colors.dart           # App color constants
│   │   ├── routes.dart           # Route definitions
│   │   ├── textfield.dart        # Custom text field widget
│   │   ├── loginbutton.dart      # Custom button widget
│   │   └── squaretile.dart       # Custom tile widget
│   └── widgets/                  # Reusable UI widgets
│       ├── cards.dart            # Card components
│       └── home_widget_helper.dart # Home screen widget integration
│
├── assets/
│   ├── images/                   # App images & icons
│   └── final_safety_scores.csv   # Pre-processed district safety scores (ML output)
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
The app follows a feature-based modular folder structure with dedicated directories for pages, services, widgets, models, and utilities, promoting code reusability and maintainability.

### Key Screens & Functionality

- **Authentication** — Secure Firebase email+password and Google Sign-In authentication with account creation and validation
- **Home Dashboard** — Personalized safety overview with quick-access actions, emergency contacts, and safety summaries
- **Safety Map** — Interactive map powered by `flutter_map` with district-level safety colour coding based on ML-generated scores from `final_safety_scores.csv`
- **Safe Route Navigation** — Google Maps API integration for generating routes that prioritize safer districts based on safety scores
- **AI Chatbot** — Dialogflow-powered conversational assistant providing safety guidance, tips, and emergency advice
- **Community Forum** — Peer-to-peer platform for sharing safety experiences, tips, and providing mutual support
- **User Profile** — Account management with customizable emergency contacts and personal preferences
- **Emergency SOS** — Direct emergency notifications via WhatsApp (with location sharing) and phone calls to pre-configured contacts
- **Home Widget** — iOS/Android home screen widget for instant access to safety information

### Navigation
Bottom navigation using `curved_navigation_bar` for intuitive, modern user experience across all app sections.

---

## 🔄 Key Features in Detail

### Safe Route Navigation
- Integrates Google Maps API to provide real-time routing
- Analyzes district safety scores along potential routes
- Prioritizes safer districts when multiple routes are available
- Displays safety information for selected routes

### Emergency SOS System
- Quick-access emergency contact management
- One-tap emergency notifications via multiple channels (WhatsApp with location, direct calling)
- Real-time location sharing with trusted contacts
- Customizable emergency contact list

### Community Engagement
- User forum for sharing safety experiences and advice
- Crowdsourced safety tips and insights
- Peer support network for women across India

---

## 🚀 Getting Started

### Prerequisites
- Flutter SDK `>=3.0.0`
- Dart SDK
- Android Studio / Xcode (for mobile emulation/deployment)
- Firebase project with Authentication enabled
- Google Maps API key (for navigation features)

### Frontend Setup

```bash
# Clone the repository
git clone https://github.com/Samaksh912/traan.git
cd traan

# Install dependencies
flutter pub get

# Configure Google Maps API
# Add your Google Maps API key to:
# - Android: android/app/src/main/AndroidManifest.xml
# - iOS: ios/Runner/Info.plist

# Configure Firebase
# - Add your Google Services JSON (Android)
# - Add your GoogleService-Info.plist (iOS)

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
5. Rebuild the Flutter app to include the updated scores

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

We welcome contributions! For major changes, please open an issue first to discuss your proposed changes. Our current focus areas include:

- Enhancing the ML model with more recent crime data
- Adding new safety features and notifications
- Improving the community forum with moderation tools
- Expanding language support
- Optimizing performance and reducing app size

To contribute:
1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

---

## 📄 License

This project is **private and proprietary**. It is not published to pub.dev and is developed for educational and social impact purposes.

---

## 🔧 Troubleshooting

### Google Maps API Not Working
- Ensure your Google Maps API key is correctly configured in both Android and iOS projects
- Verify API key has Maps SDK for Android/iOS enabled
- Check that the package name (Android) and bundle ID (iOS) match your configuration

### Firebase Authentication Issues
- Verify Firebase project is properly set up in Firebase Console
- Ensure GoogleService-Info.plist (iOS) and google-services.json (Android) are in place
- Check that authentication methods are enabled in Firebase Console

### App Crashes on Startup
- Run `flutter clean && flutter pub get` to clear build cache
- Check device/emulator has sufficient storage
- Review logs with `flutter logs`

### Maps Not Displaying District Safety Scores
- Verify `final_safety_scores.csv` exists in `assets/` folder
- Rebuild app with `flutter clean && flutter run`
- Check that CSV formatting matches the expected ML pipeline output

---

## 🙏 Acknowledgments

- **National Crime Records Bureau (NCRB)** for providing the crime statistics dataset
- **Flutter & Firebase communities** for the excellent documentation and support
- **Dialogflow** for the conversational AI capabilities
- All contributors and users who help improve Traan

<div align="center">
  <b>Built with ❤️ to help keep women safe across India.</b>
</div>

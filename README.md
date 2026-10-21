# Maji Ndogo Water Access Analytics

**SQL and Python analysis of water access across a country of 27.6 million people, including data cleaning, exploratory analysis, a province map, and a well contamination risk model**

> Interactive dashboard: [dashboard/water_access_dashboard.html](dashboard/water_access_dashboard.html)

## In short

- **What:** I combined four incomplete data exports from a water ministry to find out who has basic water access, where the gaps are worst, and how the improvement budget has been spent.
- **Data:** about 39,650 water sources, 60,146 site visits, and 17,383 well tests across 5 provinces, covering 27.6 million people.
- **Tools:** Python (pandas, scikit-learn), SQL (SQLite), Plotly.
- **Main findings:**
  - Only 46.1% of people have basic water access, and even the best province leaves about half its population underserved.
  - 71.7% of tested wells are contaminated.
  - The cost per project varies by more than 8 times between vendors doing the same type of work.
  - A model to rank wells by contamination risk gave a moderate result (ROC-AUC 0.66, where 0.5 is guessing and 1.0 is perfect) and would need tuning before it could be used.

---

## Problem

Maji Ndogo's water ministry has years of operational data: water source records, site visits, well quality tests, an infrastructure improvement programme, and historical crime records. This data was spread across four exports of the same tracking system, and none of them was complete on its own.

In this project, I combined the four exports into one clean dataset and used it to answer the questions the ministry would care about. Who has basic water access and who does not? Where is the gap worst? How contaminated is the groundwater? And how well has the $154.5M improvement programme been spent?

**Research questions:**
- What share of the population has *basic* water access by the WHO/JMP standard, and where is it worst?
- Which provinces have the longest queues, and does queue time alone explain the access gap?
- How contaminated is well water, and can contamination risk be predicted without lab results?
- How much has the improvement programme invested, and how efficiently, by vendor and type of improvement?

---

## Dataset

Source: four separate Excel exports of the same water services tracking system. Together they cover about 39,650 water sources, 60,146 site visits, 17,383 well quality tests, 25,398 completed infrastructure projects, 95 vendors, and historical crime records across 5 provinces and 31 towns.

**None of the four exports was complete.** Each one was missing different columns or whole tables that another export had. In [`notebooks/01_data_cleaning.ipynb`](notebooks/01_data_cleaning.ipynb), I documented which export supplied each field and why. For example, one export turned out to be an earlier snapshot of the same records rather than a different version of the truth.

| Table | Rows | What it holds |
|---|---|---|
| `water_source` | 39,650 | Source type (tap/well/shared tap/river), people served |
| `location` | 39,650 | Province, town, urban/rural, address |
| `visits` | 60,146 | Site visit records, queue time, timestamp (2021–2023) |
| `well_pollution` | 17,383 | Lab test results for every well (Clean / Chemical / Biological) |
| `project_progress` | 25,398 | Improvement projects, status, cost, vendor, dates |
| `vendors` | 95 | Infrastructure contractors |
| `water_source_related_crime` | 77,226 | Historical incidents near water sources (2010–2020) |

---

## Methods

| Step | What I did | Files |
|---|---|---|
| **Cleaning** | Combined the 4 incomplete exports into one complete, validated dataset | [`notebooks/01_data_cleaning.ipynb`](notebooks/01_data_cleaning.ipynb) |
| **SQL** | Built a SQLite database, ran validation checks, and wrote 10 queries for the business questions (window functions, ranking, CTEs) | [`sql/`](sql/) |
| **Exploratory analysis** | Classified access levels, mapped access by province, analysed queues, contamination rates, and vendor cost efficiency | [`notebooks/02_exploratory_analysis.ipynb`](notebooks/02_exploratory_analysis.ipynb) |
| **Machine learning** | Well contamination risk classification (Logistic Regression and Random Forest) | [`notebooks/03_machine_learning.ipynb`](notebooks/03_machine_learning.ipynb) |
| **Dashboard** | An interactive HTML dashboard | [`dashboard/water_access_dashboard.html`](dashboard/water_access_dashboard.html) |

---

## Results

- **Only 46.1% of the population (27.6M) has basic water access.** 31.6% have an improved source but queue for 30 minutes or more on average, 13.8% rely on broken taps at home, and 8.6% still depend on river water.
- **Sokoto has the lowest basic access (42.1%) and Akatsi the highest (50.2%).** Even in the best province, about half the population is underserved, so this is a problem across the whole country rather than in one province.
- **71.7% of tested wells are contaminated** (40.8% chemically and 30.9% biologically). This is a health issue on top of the queue time problem.
- **The improvement programme has invested $154.5M across 25,398 completed projects**, but the cost per project varies by more than 8 times between vendors doing the same type of work.
- **Women account for 69% of average queue time.** The historical crime data near water sources shows that 64.4% of recorded victims are female. The crime data covers 2010 to 2020 and the visit data covers 2021 to 2023, so I report these two findings separately and do not claim one causes the other.

![Water Access Dashboard](images/dashboard.png)
![Basic Access Choropleth](images/access_choropleth.png)

---

## Machine Learning

**Well contamination risk classification.** Every well in the data has already been lab tested, so the model is not predicting something unknown. Its purpose is to rank risk by location, which could help prioritise where to drill or inspect next.

To avoid giving the model the answer, I left out the lab measurements that produce the contamination label (`pollutant_ppm`, `biological`, `description`). The model only uses information that would be known before a test: province, urban or rural location, number of people served, and how heavily the source is used.

During evaluation, I found and fixed a problem with the cross-validation. The data is sorted by province, so splitting it into folds without shuffling gave very unstable results, with some folds scoring an AUC as low as 0.20. After switching to a shuffled `StratifiedKFold`, **both models scored a stable ROC-AUC of about 0.66** (standard deviation about 0.01 across folds). This is a moderate result. The most important features were the number of people served and the province, while usage (visit count and queue time) added very little. This suggests contamination is more related to *where* a well is than how much it is used.

**The AUC does not tell the whole story.** At the default threshold, the model only identifies 1% of the clean wells correctly, because it predicts "Contaminated" almost every time. It ranks risk reasonably well, but it would need threshold tuning before it could be used as a classifier. More detail is in [`notebooks/03_machine_learning.ipynb`](notebooks/03_machine_learning.ipynb).

![Feature Importance](images/feature_importance.png)

---

## Installation

```bash
git clone https://github.com/Valerie-komen/Maji-Ndogo-Water-Access-Analytics.git
cd Maji-Ndogo-Water-Access-Analytics
pip install -r requirements.txt
```

## Reproducibility

1. **Data cleaning:** [`notebooks/01_data_cleaning.ipynb`](notebooks/01_data_cleaning.ipynb) combines the raw exports (not included in this repository, see the note below) into `data/*.csv` and `data/water_services.db`.
2. **SQL:** [`sql/database_creation.sql`](sql/database_creation.sql) → [`sql/cleaning_queries.sql`](sql/cleaning_queries.sql) → [`sql/analysis_queries.sql`](sql/analysis_queries.sql).
3. **Exploratory analysis:** [`notebooks/02_exploratory_analysis.ipynb`](notebooks/02_exploratory_analysis.ipynb).
4. **Machine learning:** [`notebooks/03_machine_learning.ipynb`](notebooks/03_machine_learning.ipynb).
5. **Dashboard:** open [`dashboard/water_access_dashboard.html`](dashboard/water_access_dashboard.html) in a browser.

**Note on raw data:** the four original Excel exports (about 20MB combined) are ALX coursework materials, so I have not included them here. The `data/` folder contains the cleaned, analysis-ready output instead, and notebook 01 explains how each field was combined.

All notebook outputs in this repository are from real runs of the code.

---

## Repository Structure

```
Maji-Ndogo-Water-Access-Analytics/
├── README.md
├── requirements.txt
├── data/                  # cleaned CSVs, SQLite database, province GeoJSON
├── notebooks/
│   ├── 01_data_cleaning.ipynb
│   ├── 02_exploratory_analysis.ipynb
│   └── 03_machine_learning.ipynb
├── sql/
│   ├── database_creation.sql
│   ├── cleaning_queries.sql
│   └── analysis_queries.sql
├── dashboard/
│   └── water_access_dashboard.html
└── images/
```

---

## Limitations

- The crime data (2010 to 2020) and the visit data (2021 to 2023) cover different periods, so I only report location patterns and make no claims about cause and effect over time.
- The contamination model describes historical risk factors across provinces. It cannot confirm that any individual untested well is safe.
- There is no data linking specific improvement projects to the current water access figures, so the relationship between the $154.5M invested and the 46.1% access figure is descriptive only.

---

*If you have questions or feedback, feel free to open an issue or connect with me on [LinkedIn](https://www.linkedin.com/in/valerie-komen-468a93355/).*

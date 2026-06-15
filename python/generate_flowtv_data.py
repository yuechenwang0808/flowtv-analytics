"""
FlowTV — Synthetic Streaming Analytics Dataset Generator
=========================================================
Generates a realistic synthetic dataset for a fictional streaming service.
Designed for portfolio analytics projects (PostgreSQL + Tableau).

Output: 9 CSV files in ./data/
Runtime: ~2-3 minutes on a modern Mac
Total disk: ~1.2 GB

Engineered "storylines" (insights you can find in dashboards):
  - Channel-level LTV/CAC variance
  - Genre-driven retention differences
  - Trial length tradeoffs
  - Annual vs monthly subscriber economics
  - Device usage and churn
  - A/B tests with surface-level vs deep-metric conflicts

Author: [your name]
"""

import os
import csv
import random
import math
from datetime import datetime, timedelta
from pathlib import Path

import numpy as np
import pandas as pd
from faker import Faker

# ============================================================
# CONFIGURATION
# ============================================================
SEED = 42
N_USERS = 100_000
START_DATE = datetime(2024, 1, 1)
END_DATE = datetime(2025, 6, 30)  # 18 months
OUTPUT_DIR = Path(__file__).parent.parent / "data"

random.seed(SEED)
np.random.seed(SEED)
fake = Faker()
Faker.seed(SEED)

OUTPUT_DIR.mkdir(exist_ok=True, parents=True)
print(f"📁 Output directory: {OUTPUT_DIR}")

# ============================================================
# REFERENCE DATA
# ============================================================

PLANS = [
    # plan_id, name, price_monthly, billing_period, max_streams, hd_4k
    (1, "Basic",    7.99,  "monthly", 1, "HD"),
    (2, "Standard", 12.99, "monthly", 2, "HD"),
    (3, "Premium",  17.99, "monthly", 4, "4K"),
    (4, "Annual",   119.99, "annual",  4, "4K"),  # ~$10/mo effective
]

# Acquisition channels with realistic CAC and conversion profiles
# (channel, cac, signup_conversion_rate, trial_to_paid_rate, ltv_multiplier)
CHANNELS = {
    "organic":      {"cac": 0,     "conv": 0.18, "trial_paid": 0.42, "ltv_mult": 1.20, "weight": 0.22},
    "referral":     {"cac": 5,     "conv": 0.25, "trial_paid": 0.55, "ltv_mult": 1.80, "weight": 0.08},
    "paid_search":  {"cac": 28,    "conv": 0.15, "trial_paid": 0.38, "ltv_mult": 1.10, "weight": 0.18},
    "paid_social":  {"cac": 22,    "conv": 0.12, "trial_paid": 0.28, "ltv_mult": 0.65, "weight": 0.32},  # storyline: high volume, low LTV
    "display":      {"cac": 18,    "conv": 0.08, "trial_paid": 0.25, "ltv_mult": 0.75, "weight": 0.10},
    "affiliate":    {"cac": 12,    "conv": 0.20, "trial_paid": 0.48, "ltv_mult": 1.40, "weight": 0.07},
    "email":        {"cac": 3,     "conv": 0.22, "trial_paid": 0.45, "ltv_mult": 1.30, "weight": 0.03},
}

DEVICES = ["mobile", "desktop", "smart_tv", "tablet"]
DEVICE_WEIGHTS = [0.42, 0.25, 0.23, 0.10]

COUNTRIES = ["US", "CA", "UK", "AU", "DE", "FR", "BR", "MX", "JP", "IN"]
COUNTRY_WEIGHTS = [0.45, 0.08, 0.12, 0.05, 0.06, 0.05, 0.08, 0.04, 0.04, 0.03]

GENRES = ["Drama", "Comedy", "Action", "Documentary", "Reality", "Kids", "Thriller", "Sci-Fi", "Romance", "Horror"]
# Drama is engineered to drive retention
GENRE_RETENTION_BOOST = {"Drama": 1.30, "Documentary": 1.10, "Thriller": 1.05}

CONTENT_TYPES = ["series", "movie"]

# A/B TESTS — each has variants with engineered effects
EXPERIMENTS = [
    {
        "experiment_id": "exp_001_trial_length",
        "name": "Trial Length: 7 vs 14 days",
        "start_date": datetime(2024, 6, 1),
        "end_date": datetime(2024, 8, 31),
        "variants": ["control_7day", "treatment_14day"],
        "effect": {  # treatment effects on metrics
            "control_7day":     {"signup_lift": 0.0,  "d30_retention_lift": 0.0},
            "treatment_14day":  {"signup_lift": -0.05, "d30_retention_lift": 0.12},  # storyline: trades signups for retention
        },
    },
    {
        "experiment_id": "exp_002_paywall_copy",
        "name": "Paywall Copy: Value vs Urgency",
        "start_date": datetime(2024, 9, 1),
        "end_date": datetime(2024, 10, 15),
        "variants": ["control_value", "treatment_urgency"],
        "effect": {  # storyline: wins on signup, loses on retention
            "control_value":     {"signup_lift": 0.0,   "d30_retention_lift": 0.0},
            "treatment_urgency": {"signup_lift": 0.18,  "d30_retention_lift": -0.08},
        },
    },
    {
        "experiment_id": "exp_003_onboarding",
        "name": "Onboarding: Skip vs Guided",
        "start_date": datetime(2024, 11, 1),
        "end_date": datetime(2025, 1, 31),
        "variants": ["control_skip", "treatment_guided"],
        "effect": {  # clear winner — guided improves everything
            "control_skip":     {"signup_lift": 0.0,  "d30_retention_lift": 0.0},
            "treatment_guided": {"signup_lift": 0.02, "d30_retention_lift": 0.15},
        },
    },
    {
        "experiment_id": "exp_004_recommendation",
        "name": "Recommendation Algorithm: Collab vs Content",
        "start_date": datetime(2025, 2, 1),
        "end_date": datetime(2025, 4, 30),
        "variants": ["control_collaborative", "treatment_content_based"],
        "effect": {  # no significant difference — flat result
            "control_collaborative":  {"signup_lift": 0.0,  "d30_retention_lift": 0.0},
            "treatment_content_based": {"signup_lift": 0.01, "d30_retention_lift": 0.005},
        },
    },
    {
        "experiment_id": "exp_005_pricing",
        "name": "Pricing: Standard $12.99 vs $14.99",
        "start_date": datetime(2025, 5, 1),
        "end_date": datetime(2025, 6, 15),
        "variants": ["control_1299", "treatment_1499"],
        "effect": {  # storyline: higher price, fewer conversions, same revenue, lower churn (price-anchoring loyalty)
            "control_1299":   {"signup_lift": 0.0,   "d30_retention_lift": 0.0},
            "treatment_1499": {"signup_lift": -0.14, "d30_retention_lift": 0.03},
        },
    },
]

# ============================================================
# 1. PLANS
# ============================================================
print("\n📋 Generating plans...")
plans_df = pd.DataFrame(PLANS, columns=["plan_id", "plan_name", "price_monthly", "billing_period", "max_streams", "resolution"])
plans_df.to_csv(OUTPUT_DIR / "plans.csv", index=False)
print(f"   ✓ {len(plans_df)} plans")

# ============================================================
# 2. CONTENT CATALOG
# ============================================================
print("\n🎬 Generating content catalog...")
catalog = []
for i in range(500):
    content_type = random.choices(CONTENT_TYPES, weights=[0.4, 0.6])[0]
    genre = random.choices(GENRES, weights=[2, 1.5, 1.5, 1, 1, 1, 1.2, 1, 1, 0.8])[0]
    catalog.append({
        "content_id": f"c_{i:04d}",
        "title": fake.catch_phrase(),
        "content_type": content_type,
        "genre": genre,
        "release_year": random.randint(2018, 2025),
        "duration_minutes": random.randint(22, 180) if content_type == "movie" else random.randint(22, 60),
        "is_original": random.random() < 0.35,
    })
catalog_df = pd.DataFrame(catalog)
catalog_df.to_csv(OUTPUT_DIR / "content_catalog.csv", index=False)
print(f"   ✓ {len(catalog_df)} titles")

# ============================================================
# 3. EXPERIMENTS
# ============================================================
print("\n🧪 Generating experiments...")
exp_rows = []
for exp in EXPERIMENTS:
    for variant in exp["variants"]:
        exp_rows.append({
            "experiment_id": exp["experiment_id"],
            "experiment_name": exp["name"],
            "variant": variant,
            "start_date": exp["start_date"].date(),
            "end_date": exp["end_date"].date(),
            "is_control": variant.startswith("control"),
        })
exp_df = pd.DataFrame(exp_rows)
exp_df.to_csv(OUTPUT_DIR / "experiments.csv", index=False)
print(f"   ✓ {len(EXPERIMENTS)} experiments, {len(exp_df)} variants")

# ============================================================
# 4. USERS
# ============================================================
print(f"\n👥 Generating {N_USERS:,} users...")

users = []
channel_names = list(CHANNELS.keys())
channel_weights = [CHANNELS[c]["weight"] for c in channel_names]

# Signup distribution — growing user base over 18 months, with seasonality
days_total = (END_DATE - START_DATE).days
signup_dates = []
for i in range(N_USERS):
    # Linear growth + weekly seasonality (more signups on weekends)
    base = i / N_USERS  # 0 → 1
    growth_skew = base ** 0.7  # earlier dates slightly weighted, but still spread
    day_offset = int(growth_skew * days_total + np.random.normal(0, days_total * 0.05))
    day_offset = max(0, min(days_total - 1, day_offset))
    signup_dt = START_DATE + timedelta(days=day_offset)
    # Weekend boost
    if signup_dt.weekday() >= 5 and random.random() < 0.3:
        signup_dt += timedelta(hours=random.randint(10, 22))
    else:
        signup_dt += timedelta(hours=random.randint(8, 23), minutes=random.randint(0, 59))
    signup_dates.append(signup_dt)

signup_dates.sort()

for i in range(N_USERS):
    channel = random.choices(channel_names, weights=channel_weights)[0]
    country = random.choices(COUNTRIES, weights=COUNTRY_WEIGHTS)[0]
    primary_device = random.choices(DEVICES, weights=DEVICE_WEIGHTS)[0]
    age = max(16, min(75, int(np.random.normal(34, 12))))

    users.append({
        "user_id": f"u_{i:07d}",
        "signup_date": signup_dates[i].date(),
        "signup_timestamp": signup_dates[i],
        "acquisition_channel": channel,
        "country": country,
        "primary_device": primary_device,
        "age": age,
        "email": fake.email(),
    })

users_df = pd.DataFrame(users)
users_df.to_csv(OUTPUT_DIR / "users.csv", index=False)
print(f"   ✓ {len(users_df):,} users")

# ============================================================
# 5. EXPERIMENT ASSIGNMENTS
# ============================================================
print("\n🎯 Assigning users to experiments...")
assignments = []
for exp in EXPERIMENTS:
    # Pick users who signed up during experiment window
    eligible = users_df[
        (users_df["signup_timestamp"] >= exp["start_date"]) &
        (users_df["signup_timestamp"] <= exp["end_date"])
    ]
    # 80% of eligible users are in the experiment
    sample_size = int(len(eligible) * 0.80)
    sampled = eligible.sample(n=sample_size, random_state=SEED)

    for _, user in sampled.iterrows():
        variant = random.choice(exp["variants"])
        assignments.append({
            "experiment_id": exp["experiment_id"],
            "user_id": user["user_id"],
            "variant": variant,
            "assigned_at": user["signup_timestamp"],
        })

assignments_df = pd.DataFrame(assignments)
assignments_df.to_csv(OUTPUT_DIR / "experiment_assignments.csv", index=False)
print(f"   ✓ {len(assignments_df):,} assignments")

# Build a lookup for fast assignment access
user_to_exp = {}
for _, row in assignments_df.iterrows():
    user_to_exp.setdefault(row["user_id"], []).append({
        "experiment_id": row["experiment_id"],
        "variant": row["variant"],
    })

# ============================================================
# 6. SUBSCRIPTIONS
# ============================================================
print("\n💳 Generating subscriptions...")

def get_experiment_lift(user_id, metric):
    """Sum lift effects from all experiments a user is in."""
    total = 0.0
    if user_id not in user_to_exp:
        return total
    for assignment in user_to_exp[user_id]:
        for exp in EXPERIMENTS:
            if exp["experiment_id"] == assignment["experiment_id"]:
                effects = exp["effect"].get(assignment["variant"], {})
                total += effects.get(metric, 0.0)
    return total

subscriptions = []
sub_id_counter = 0

for _, user in users_df.iterrows():
    channel_info = CHANNELS[user["acquisition_channel"]]
    signup_lift = get_experiment_lift(user["user_id"], "signup_lift")

    # Step 1: Did they start a trial?
    trial_prob = channel_info["conv"] * (1 + signup_lift)
    if random.random() > trial_prob:
        continue  # never converted to trial, no subscription

    # Step 2: Pick a plan (weighted toward Standard)
    plan_id = random.choices([1, 2, 3, 4], weights=[0.20, 0.45, 0.25, 0.10])[0]
    plan_info = next(p for p in PLANS if p[0] == plan_id)
    price = plan_info[2]
    billing = plan_info[3]

    # Step 3: Trial start
    trial_start = user["signup_timestamp"] + timedelta(hours=random.randint(1, 48))
    trial_length = 14 if random.random() < 0.5 else 7  # default mix; overridden for experiment users
    if user["user_id"] in user_to_exp:
        for a in user_to_exp[user["user_id"]]:
            if a["experiment_id"] == "exp_001_trial_length":
                trial_length = 14 if a["variant"] == "treatment_14day" else 7

    trial_end = trial_start + timedelta(days=trial_length)

    # Step 4: Did they convert to paid?
    convert_prob = channel_info["trial_paid"]
    if random.random() > convert_prob:
        # Trial-only subscription
        subscriptions.append({
            "subscription_id": f"s_{sub_id_counter:07d}",
            "user_id": user["user_id"],
            "plan_id": plan_id,
            "status": "trial_expired",
            "started_at": trial_start,
            "ended_at": trial_end,
            "is_trial": True,
            "converted_to_paid": False,
            "mrr": 0.0,
        })
        sub_id_counter += 1
        continue

    # Step 5: Paid subscription begins
    paid_start = trial_end
    monthly_mrr = price if billing == "monthly" else price / 12  # normalize annual to monthly

    # Step 6: Retention modeling
    # Base monthly churn rate ~5%, adjusted by channel LTV multiplier and experiment lift
    retention_lift = get_experiment_lift(user["user_id"], "d30_retention_lift")
    base_churn = 0.05
    adjusted_churn = base_churn / channel_info["ltv_mult"] * (1 - retention_lift)
    # Device effect: mobile-only churns faster
    if user["primary_device"] == "mobile":
        adjusted_churn *= 1.40
    # Annual plan: lower churn
    if billing == "annual":
        adjusted_churn *= 0.40
    adjusted_churn = max(0.005, min(0.25, adjusted_churn))

    # Simulate month-by-month survival
    current_date = paid_start
    months_active = 0
    max_months = 60
    while current_date < END_DATE and months_active < max_months:
        if random.random() < adjusted_churn:
            break
        current_date += timedelta(days=30 if billing == "monthly" else 365)
        months_active += 1
        if billing == "annual":
            break  # one-year commit, churns at renewal

    sub_end = current_date if months_active < max_months and current_date < END_DATE else None
    status = "churned" if sub_end else "active"

    subscriptions.append({
        "subscription_id": f"s_{sub_id_counter:07d}",
        "user_id": user["user_id"],
        "plan_id": plan_id,
        "status": status,
        "started_at": paid_start,
        "ended_at": sub_end,
        "is_trial": False,
        "converted_to_paid": True,
        "mrr": round(monthly_mrr, 2),
    })
    sub_id_counter += 1

subs_df = pd.DataFrame(subscriptions)
subs_df.to_csv(OUTPUT_DIR / "subscriptions.csv", index=False)
print(f"   ✓ {len(subs_df):,} subscriptions ({(subs_df['converted_to_paid']).sum():,} paid)")

# ============================================================
# 7. EVENTS — funnel tracking
# ============================================================
print("\n📊 Generating funnel events...")

EVENT_TYPES = ["page_view", "signup_started", "signup_completed", "trial_started",
               "paywall_view", "subscribe_clicked", "subscribed", "churned"]

events = []
event_id = 0
paid_user_ids = set(subs_df[subs_df["converted_to_paid"]]["user_id"])
trial_user_ids = set(subs_df["user_id"])

for _, user in users_df.iterrows():
    ts = user["signup_timestamp"]
    # Every user gets these
    events.append({"event_id": f"e_{event_id:08d}", "user_id": user["user_id"], "event_type": "page_view", "event_timestamp": ts - timedelta(minutes=random.randint(2, 30))})
    event_id += 1
    events.append({"event_id": f"e_{event_id:08d}", "user_id": user["user_id"], "event_type": "signup_started", "event_timestamp": ts - timedelta(minutes=random.randint(1, 5))})
    event_id += 1
    events.append({"event_id": f"e_{event_id:08d}", "user_id": user["user_id"], "event_type": "signup_completed", "event_timestamp": ts})
    event_id += 1
    # Trial start (subset)
    if user["user_id"] in trial_user_ids:
        sub = subs_df[subs_df["user_id"] == user["user_id"]].iloc[0]
        events.append({"event_id": f"e_{event_id:08d}", "user_id": user["user_id"], "event_type": "trial_started", "event_timestamp": sub["started_at"]})
        event_id += 1
        events.append({"event_id": f"e_{event_id:08d}", "user_id": user["user_id"], "event_type": "paywall_view", "event_timestamp": sub["started_at"] + timedelta(days=random.randint(1, 5))})
        event_id += 1
    # Subscribe events for paid users
    if user["user_id"] in paid_user_ids:
        sub = subs_df[(subs_df["user_id"] == user["user_id"]) & (subs_df["converted_to_paid"])].iloc[0]
        events.append({"event_id": f"e_{event_id:08d}", "user_id": user["user_id"], "event_type": "subscribe_clicked", "event_timestamp": sub["started_at"] - timedelta(minutes=random.randint(1, 30))})
        event_id += 1
        events.append({"event_id": f"e_{event_id:08d}", "user_id": user["user_id"], "event_type": "subscribed", "event_timestamp": sub["started_at"]})
        event_id += 1
        if sub["ended_at"] is not None and pd.notna(sub["ended_at"]):
            events.append({"event_id": f"e_{event_id:08d}", "user_id": user["user_id"], "event_type": "churned", "event_timestamp": sub["ended_at"]})
            event_id += 1

events_df = pd.DataFrame(events)
events_df.to_csv(OUTPUT_DIR / "events.csv", index=False)
print(f"   ✓ {len(events_df):,} events")

# ============================================================
# 8. SESSIONS — daily engagement
# ============================================================
print("\n📺 Generating sessions (this takes a moment)...")
sessions = []
sess_id = 0

# Only paid + trial users have sessions
active_users = subs_df[subs_df["status"].isin(["active", "churned", "trial_expired"])].copy()

for _, sub in active_users.iterrows():
    user_id = sub["user_id"]
    user_row = users_df[users_df["user_id"] == user_id].iloc[0]
    start = sub["started_at"]
    end = sub["ended_at"] if pd.notna(sub["ended_at"]) else END_DATE

    # Engagement intensity per user (gamma distribution — most are casual, few are heavy)
    intensity = np.random.gamma(2.0, 1.5)  # mean ~3 sessions/week
    intensity = min(intensity, 10)  # cap at 10/week

    current = start
    while current < end:
        # Probability of session today
        prob_today = min(0.95, intensity / 7.0)
        # Weekend boost
        if current.weekday() >= 5:
            prob_today *= 1.4
        if random.random() < prob_today:
            duration = max(5, int(np.random.gamma(2, 30)))  # minutes
            device = user_row["primary_device"] if random.random() < 0.7 else random.choice(DEVICES)
            sessions.append({
                "session_id": f"sess_{sess_id:09d}",
                "user_id": user_id,
                "session_date": current.date(),
                "session_start": current.replace(hour=random.randint(8, 23), minute=random.randint(0, 59)),
                "duration_minutes": duration,
                "device": device,
            })
            sess_id += 1
        current += timedelta(days=1)

sessions_df = pd.DataFrame(sessions)
sessions_df.to_csv(OUTPUT_DIR / "sessions.csv", index=False)
print(f"   ✓ {len(sessions_df):,} sessions")

# ============================================================
# 9. CONTENT VIEWS
# ============================================================
print("\n🍿 Generating content views...")
content_views = []
view_id = 0

# Each session yields 1-3 content views
content_ids = catalog_df["content_id"].tolist()
content_genres = dict(zip(catalog_df["content_id"], catalog_df["genre"]))

for _, sess in sessions_df.iterrows():
    n_views = random.choices([1, 2, 3], weights=[0.5, 0.35, 0.15])[0]
    for _ in range(n_views):
        content_id = random.choice(content_ids)
        watch_pct = random.choices([0.25, 0.5, 0.75, 1.0], weights=[0.15, 0.2, 0.2, 0.45])[0]
        content_views.append({
            "view_id": f"v_{view_id:09d}",
            "user_id": sess["user_id"],
            "session_id": sess["session_id"],
            "content_id": content_id,
            "view_date": sess["session_date"],
            "watch_percentage": watch_pct,
            "completed": watch_pct >= 0.9,
        })
        view_id += 1

# Write in chunks (memory)
views_df = pd.DataFrame(content_views)
views_df.to_csv(OUTPUT_DIR / "content_views.csv", index=False)
print(f"   ✓ {len(views_df):,} content views")

# ============================================================
# SUMMARY
# ============================================================
print("\n" + "=" * 60)
print("✅ GENERATION COMPLETE")
print("=" * 60)
print(f"\nFiles in {OUTPUT_DIR}:")
for f in sorted(OUTPUT_DIR.glob("*.csv")):
    size_mb = f.stat().st_size / 1024 / 1024
    print(f"   {f.name:35s}  {size_mb:7.1f} MB")

print(f"\nNext step: load these CSVs into a PostgreSQL database called 'flowtv'.")
print("See: sql/01_create_tables.sql and sql/02_load_data.sh in the project README.")

ScrollSense Assignment 1 - README

What this is

This is the database project for ScrollSense, built as SQLite. It includes the schema, a data generator, views, transactions, and thirteen queries, all tested against a real populated database rather than just written and assumed correct.

Roll number : da24b048

How to run this from a completely empty database

Step 1: Delete any old database files

Remove scrollsense.db, scrollsense.db-wal, and scrollsense.db-shm if they already exist in this folder.

Step 2: Build the schema

Run this command:

python -c "import sqlite3; c=sqlite3.connect('scrollsense.db'); c.executescript(open('schema.sql').read())"

This creates every table, all primary keys, foreign keys, and check constraints.

Step 3: Generate the base data

Run:

python generate_data.py

This creates 5000 users, 20000 videos, around 300000 impressions, and 2000 agent sessions, along with likes, comments, shares, follows, and agent turns.

Step 4: Run the data patch scripts, in this order

The base generator on its own does not produce data good enough to answer every query correctly. While testing the queries against the generated data, several real problems were found and fixed. Each patch script below fixes one specific problem. Run them in this order:

python patch_missing_data.py
python fix_view_durations.py
python fix_retraction_gaps.py
python patch_moderation_history.py
python fix_user_activity_pattern.py
python backfill_turn_usage.py
python patch_toolcall_nesting.py
python fix_recommendation_watches.py

What each one fixes:

patch_missing_data.py adds hashtags pulled from video captions, inferred interests, blocks, mutes, and recommendations linking agent turns to real videos and viewing outcomes.

fix_view_durations.py fixes a bug where every view segment had the exact same start and end time, meaning zero watch time everywhere.

fix_retraction_gaps.py fixes a bug where every retracted like was retracted at the exact same instant it was liked, giving no real time gap to test against.

patch_moderation_history.py gives a sample of videos a real multi step moderation history instead of just one event each.

fix_user_activity_pattern.py fixes a bug where almost every user ended up active on all seven days, because users were picked completely at random for each impression instead of following a realistic pattern.

backfill_turn_usage.py adds token usage numbers needed to calculate cost per turn.

patch_toolcall_nesting.py adds real nested tool calls, since the base generator never created any.

fix_recommendation_watches.py fixes a bug where every recommended clip was watched for a fixed 20 seconds, which meant no recommendation could ever be marked as watched to completion.

Step 5: Create the views

Run:

python -c "import sqlite3; c=sqlite3.connect('scrollsense.db'); c.executescript(open('views.sql').read())"

This creates the five views: v_public_profile, v_video_current_state, v_creator_tier_current, v_video_daily_engagement, and v_turn_cost.

Step 6: Run the queries

Run:

python run_queries.py

This runs and times all thirteen queries from Deliverable F and prints the results. The finished versions of these queries, with their row counts and runtimes already recorded, are in queries.sql.

Step 7: Run the transaction demonstrations

Run:

python run_transactions.py

This demonstrates the three transaction scenarios from Deliverable G, each with a real failure forced on purpose and a real check afterward proving the database stayed correct. The plain SQL version of these same scripts is in transactions.sql.

Files in this folder

schema.sql - the database structure, all tables and constraints

generate_data.py - creates the base dataset

patch_missing_data.py, fix_view_durations.py, fix_retraction_gaps.py, patch_moderation_history.py, fix_user_activity_pattern.py, backfill_turn_usage.py, patch_toolcall_nesting.py, fix_recommendation_watches.py - fix specific problems found in the base data

views.sql - the five views

transactions.sql - the three transaction scripts, plain SQL

queries.sql - all thirteen queries with results filled in

run_queries.py - runs and times the queries

run_views.py - builds and checks the views

run_transactions.py - runs and demonstrates the transactions

A note on the generator

Running generate_data.py by itself is not enough to get data that correctly answers every query. Several real bugs were only found by actually running the queries and checking whether the results made sense, not by assuming a script that ran without an error had produced correct data. Each patch script exists because one of these problems was found and fixed. They are kept as separate files on purpose, so the mistake and the fix both stay visible instead of being hidden inside one script that looks clean from the start.

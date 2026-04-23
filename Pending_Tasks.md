# Pending Works

Based on the Second Review Report for the **Civic AI System**, here is the clear list of pending works that remain to be actively implemented.

### 1. SLA Monitoring & Escalation (Chapter 5, Section 5.3)
- **Current State:** The system currently only tallies SLA breaches (issues taking > 3 days) for the dashboard (`views.py` stats).
- **Pending Work:** 
  - Define separate SLA timers based on Priority (e.g., Critical = 24h, High = 48h, Low = 72h).
  - Implement an automated job (e.g., a Django management command using Celery/cron) that routinely checks for expired SLAs.
  - Create the Escalation Workflow: automatically notify higher-level administrators and re-assign tasks if lower-level crew fail to act within the boundary.

### 2. Predictive Analytics (Prophet / LSTM) (Chapter 4, Section 4.3)
- **Current State:** The system currently generates hot-spot heatmaps using a lightweight 7-day rolling mean approximation in `generate_heatmap.py`.
- **Pending Work:** Implement actual time-series forecasting to match the report.
  - Integrate **Facebook Prophet** to forecast short-term and seasonal spikes in complaints.
  - Integrate **LSTM (Long Short-Term Memory)** neural networks to model non-linear temporal dependencies, factoring in location, issue type, and historical frequencies.
  - Link these models so that the Admin Dashboard predictions are driven by real predictive machine learning rather than simple statistical averages.

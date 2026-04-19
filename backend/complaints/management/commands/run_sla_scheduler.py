"""
Management command: run_sla_scheduler
======================================
Starts an APScheduler background scheduler that runs the SLA check every
15 minutes.  Also fires once immediately on startup so there is no cold-start
delay.

Usage
-----
    # Terminal 1 – Django API
    python manage.py runserver

    # Terminal 2 – SLA scheduler (runs alongside the API)
    python manage.py run_sla_scheduler

Stop with Ctrl+C.
"""

import logging
import time

from django.core.management.base import BaseCommand

logger = logging.getLogger(__name__)


class Command(BaseCommand):
    help = "Run the SLA monitoring scheduler (fires every 15 minutes)"

    def add_arguments(self, parser):
        parser.add_argument(
            "--interval",
            type=int,
            default=15,
            help="Check interval in minutes (default: 15)",
        )
        parser.add_argument(
            "--once",
            action="store_true",
            help="Run the SLA check once and exit (useful for cron jobs)",
        )

    def handle(self, *args, **options):
        from services.sla_service import run_sla_check

        interval_minutes: int = options["interval"]
        run_once: bool = options["once"]

        if run_once:
            self.stdout.write(self.style.NOTICE("Running SLA check once..."))
            summary = run_sla_check()
            self.stdout.write(
                self.style.SUCCESS(f"SLA check complete: {summary}")
            )
            return

        # ---- APScheduler continuous mode ------------------------------------
        try:
            from apscheduler.schedulers.background import BackgroundScheduler
            from apscheduler.triggers.interval import IntervalTrigger
        except ImportError:
            self.stderr.write(
                self.style.ERROR(
                    "APScheduler is not installed. "
                    "Run: pip install apscheduler>=3.10"
                )
            )
            raise SystemExit(1)

        scheduler = BackgroundScheduler(timezone="UTC")
        scheduler.add_job(
            func=_run_check_wrapper,
            trigger=IntervalTrigger(minutes=interval_minutes),
            id="sla_check",
            name="SLA Monitoring Check",
            replace_existing=True,
            max_instances=1,  # Prevent overlapping runs
        )
        scheduler.start()

        self.stdout.write(
            self.style.SUCCESS(
                f"SLA scheduler started – running every {interval_minutes} minute(s). "
                f"Press Ctrl+C to stop."
            )
        )

        # Fire immediately on startup (no waiting for the first interval)
        self.stdout.write(self.style.NOTICE("Running initial SLA check..."))
        summary = run_sla_check()
        self.stdout.write(self.style.SUCCESS(f"Initial SLA check: {summary}"))

        try:
            while True:
                time.sleep(30)  # heartbeat – keep main thread alive
        except (KeyboardInterrupt, SystemExit):
            scheduler.shutdown()
            self.stdout.write(self.style.WARNING("SLA scheduler stopped."))


def _run_check_wrapper():
    """Thin wrapper so APScheduler can call run_sla_check and log exceptions."""
    try:
        from services.sla_service import run_sla_check
        summary = run_sla_check()
        logger.info("Scheduled SLA check: %s", summary)
    except Exception as exc:  # pylint: disable=broad-except
        logger.exception("Scheduled SLA check failed: %s", exc)

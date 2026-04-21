"""
run_demo.py — thin wrapper to execute demo_complaints.py via manage.py shell -c
Run: .\venv\Scripts\python.exe manage.py shell -c "exec(open('run_demo.py', encoding='utf-8').read())"
"""
exec(open('demo_complaints.py', encoding='utf-8').read())

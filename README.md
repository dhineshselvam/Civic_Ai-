# Project

This repository contains a full-stack application with a Django backend and a Flutter frontend.

## Backend (Django)

- Located in the `backend/` directory.
- Uses SQLite database by default (`db.sqlite3`).
- Core app: `complaints`

### Setup

```bash
cd backend
python -m venv venv
# activate the environment
# Windows
venv\Scripts\activate
# Install requirements
pip install -r requirements.txt
# Apply migrations
django-admin migrate
# Run development server
python manage.py runserver
```

### Useful commands

- Create superuser: `python manage.py createsuperuser`
- Run tests: `python manage.py test`

## Frontend (Flutter)

- Located in the `frontend/` directory.
- Mobile/web app for reporting issues.

### Setup

```bash
cd frontend
flutter pub get
flutter run     # choose a device or emulator
```

### Notes

- The frontend uses `api_service.dart` to communicate with the backend.
- Web version: `flutter run -d chrome`

## Environment

- Backend: Python 3.x, Django
- Frontend: Flutter (stable channel)

## Deployment

- Configure environment variables as needed in `backend/config/settings.py`.
- Build Flutter app for release using `flutter build`.

## License

Specify your license here.

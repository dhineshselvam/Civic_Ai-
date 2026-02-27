# AI-Enhanced Civic Reporting System

Flutter (Web + Mobile) frontend and Django REST backend with CLIP-based issue classification.

## Folder structure

```
Project/
├── lib/                          # Flutter app
│   ├── main.dart
│   ├── screens/
│   │   └── report_issue_screen.dart
│   ├── services/
│   │   ├── api_service.dart
│   │   ├── api_service_io.dart    # Mobile: File
│   │   └── api_service_web.dart   # Web: bytes
│   └── widgets/
│       └── map_picker.dart
├── web/
│   ├── index.html
│   └── manifest.json
├── pubspec.yaml
├── backend/                       # Django project
│   ├── manage.py
│   ├── config/
│   │   ├── settings.py
│   │   ├── urls.py
│   │   ├── wsgi.py
│   │   └── asgi.py
│   ├── complaints/
│   │   ├── models.py
│   │   ├── serializers.py
│   │   ├── views.py
│   │   ├── urls.py
│   │   ├── clip_service.py
│   │   └── admin.py
│   ├── requirements.txt
│   └── .env.example
└── README.md
```

---

## Setup instructions

### 1. Backend (Django + PostgreSQL)

1. **Create and activate a virtual environment** (recommended):

   ```bash
   cd backend
   python -m venv venv
   # Windows:
   venv\Scripts\activate
   # macOS/Linux:
   source venv/bin/activate
   ```

2. **Install dependencies:**

   ```bash
   pip install -r requirements.txt
   ```

3. **PostgreSQL:**

   - Install PostgreSQL and create a database, e.g. `civic_reporting`.
   - Copy `.env.example` to `.env` and set:

   ```env
   PGDATABASE=civic_reporting
   PGUSER=postgres
   PGPASSWORD=your_password
   PGHOST=localhost
   PGPORT=5432
   ```

   Load them (e.g. with `python-dotenv` in a small script or export in shell). Alternatively set the same variables in the environment before running Django.

4. **CLIP model (local only):**

   The app expects **openai/clip-vit-base-patch32** to be available **locally** (no download in code). Set the path in `.env`:

   ```env
   CLIP_MODEL_PATH=C:\path\to\clip-vit-base-patch32
   ```

   Typical locations:

   - A folder you copied the model into, e.g. `backend/clip_model`.
   - Hugging Face cache:  
     `~/.cache/huggingface/hub/models--openai--clip-vit-base-patch32/snapshots/<snapshot_id>`

   Use that snapshot folder as `CLIP_MODEL_PATH`.

5. **Run migrations and server:**

   ```bash
   python manage.py migrate
   python manage.py runserver
   ```

   API base: `http://localhost:8000`  
   Endpoint: `POST /api/report-issue/`

6. **Optional:** Create a superuser for admin:

   ```bash
   python manage.py createsuperuser
   ```

   Then open `http://localhost:8000/admin/`.

---

### 2. Frontend (Flutter)

1. **Install Flutter SDK** and ensure `flutter doctor` passes.

2. **Install dependencies:**

   ```bash
   flutter pub get
   ```

3. **Run:**

   - **Web:** `flutter run -d chrome` (or another browser).
   - **Mobile:** `flutter run` with a device/emulator.

4. **Backend URL:**  
   The app uses `http://localhost:8000` by default. To change it, pass a base URL into `ApiService(baseUrl: 'https://your-api.com')` where the service is created (e.g. in `report_issue_screen.dart`).

---

## API

- **POST /api/report-issue/**  
  - Content-Type: `multipart/form-data`  
  - Fields: `image` (file), `description`, `latitude`, `longitude`, `timestamp` (ISO 8601).  
  - Response: `{ "message": "Complaint submitted successfully", "predicted_category": "Pothole" }`

---

## Tech stack

- **Frontend:** Flutter (Web + Mobile), flutter_map (OSM), latlong2, image_picker, file_picker (web), http.
- **Backend:** Django REST Framework, PostgreSQL (psycopg2), CORS (django-cors-headers).
- **AI:** Local CLIP (`openai/clip-vit-base-patch32`) via `transformers` + `torch`; categories: Garbage, Pothole, Water Leakage, Streetlight Issue, Road Damage.

---

## Error handling

- **Backend:** Validation errors (400), missing CLIP model (503), classification/server errors (500). Logs in Django.
- **Frontend:** Loading state, success message with predicted category, form clear on success, and display of API error message on failure.

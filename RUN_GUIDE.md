# AuraMind local run guide (MySQL + FastAPI + Flutter Edge)

This project uses **MySQL** as its central database. The old `.db` files in the repository are not used by the current FastAPI backend.

## Fastest local setup: Docker Desktop + MySQL

### 1. Install prerequisites
- Flutter SDK and Microsoft Edge.
- Python 3.10+ (Python 3.13 also works with this project if the packages install correctly).
- Docker Desktop for Windows, running.

### 2. Start MySQL
From the repository root:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\START_MYSQL.ps1
```

Or without the helper script:

```powershell
docker compose up -d db
```

Check the database container:

```powershell
docker compose ps
```

The `db` service should eventually be `running`/healthy. It listens on `127.0.0.1:3306`.

### 3. Start FastAPI
Open a **second VS Code terminal** at the repository root:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\START_BACKEND.ps1
```

Or manually:

```powershell
cd FastAPI
python -m venv .venv
.\.venv\Scripts\python.exe -m pip install -r requirements.txt
.\.venv\Scripts\python.exe -m uvicorn app:app --reload --host 127.0.0.1 --port 8000
```

When successful, open:

`http://127.0.0.1:8000/docs`

On first successful MySQL connection, FastAPI automatically creates the required tables and seeds the local demo administrator.

### 4. Start Flutter in Edge
Open a **third VS Code terminal** at the repository root:

```powershell
flutter pub get
flutter run -d edge
```

The web frontend uses `http://127.0.0.1:8000` from `lib/config/api_config.dart`.

## Local demo administrator

- Email: `admin@auramind.local`
- Password: `Admin@1234`

These can be changed in `FastAPI/.env`. For a fresh MySQL database, the backend seeds this local demo administrator during database initialization.

## If login says the database/server cannot be reached

1. Confirm MySQL:
   ```powershell
   docker compose ps
   ```
2. Confirm FastAPI Swagger opens at `http://127.0.0.1:8000/docs`.
3. In Swagger, test `POST /auth/login`.
4. If the response says MySQL is unavailable, MySQL is not running or the credentials in `FastAPI/.env` do not match the database service.

Do **not** switch the backend to SQLite for this version. The current backend is configured for MySQL.

## Module 3 checks

### Kindness Wheel
1. Sign up or sign in as a normal user.
2. Open **Deliberate Acts of Kindness**.
3. Wait for the progress summary to load.
4. Spin the wheel and complete the selected act.
5. The points, completion count, streak and last-seven-days history should update.

The database table is `KINDNESS_COMPLETIONS`. Older records are pruned when the kindness summary/completion endpoint runs, so only the rolling seven-day history is retained.

### Anonymous community moderation
1. As a normal user, create a comment.
2. Report that comment from another normal user.
3. Sign in to the protected Admin Panel.
4. Open **Reported comments — safety review**.
5. The report reason, comment content, and the reported comment author's account details are visible to the administrator for safety review.
6. The administrator can delete the reported comment.

Regular community users still only see anonymous aliases. Identity disclosure is limited to the protected administrator safety-review endpoint.

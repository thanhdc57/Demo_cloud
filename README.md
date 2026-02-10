# DemoCloud - ASP.NET Core + React + Postgres

A full-stack CRUD application built with:
- **Backend**: ASP.NET Core 8 Web API
- **Frontend**: React 18 (Vite)
- **Database**: PostgreSQL 15
- **Infrastructure**: Docker & Docker Compose

## Project Structure
- `DemoCloud.Backend/`: ASP.NET Core Web API source code
- `DemoCloud.Frontend/`: React source code
- `docker-compose.yml`: Orchestration for local and cloud deployment
- `deploy.sh`: Helper script for Google Cloud Shell deployment

## How to Run Locally
1. Ensure Docker Desktop is running.
2. Run `docker-compose up --build`.
3. Access Frontend: `http://localhost:5173`
4. Access Backend API: `http://localhost:5000/api/products` (or via frontend proxy)

## How to Deploy to Google Cloud Shell
1. Zip this content or clone this repository to Google Cloud Shell.
2. Run `chmod +x deploy.sh`
3. Run `./deploy.sh`
4. Use "Web Preview" on port **5173**.

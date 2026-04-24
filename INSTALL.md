# Banana — Installation & Usage

## Requirements

- Linux (Ubuntu, Debian, Fedora, etc.)
- An internet connection for the initial setup

---

## 1. Install Docker

Open a terminal and run:

```bash
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker $USER
```

Then **log out and log back in** (or restart your computer). This lets you run Docker without typing `sudo` every time.

---

## 2. Start the app

Navigate to the Banana folder and run:

```bash
./start.sh
```

The first time you run this it will take **5–10 minutes** — it's downloading and building everything it needs. A browser window will open automatically when it's ready.

Subsequent starts take only a few seconds.

---

## 3. Create your account

On the first run, the app opens to a sign-up page. Create your account — you only need to do this once.

---

## Day-to-day use

**Start:**
```bash
./start.sh
```

**Stop** (when you're done):
```bash
./stop.sh
```

The app does not need to be running all the time — start it when you want to use it, stop it when you're done.

---

## Your data

- **GPS files and uploads** are stored in the `storage/` folder inside the Banana directory.
- **Your activity database** is stored in a Docker volume on your machine.

Both survive stops, restarts, and upgrades. Do not delete the `storage/` folder or the `.env` file.

---

## Upgrading

When you receive a new version of Banana:

```bash
./stop.sh
```

Replace the app files with the new ones, keeping your existing `storage/` folder and `.env` file. Then:

```bash
docker compose build
./start.sh
```

---

## Troubleshooting

**"Docker is not running"**
Start Docker with:
```bash
sudo systemctl start docker
```
Or add it to startup so it runs automatically:
```bash
sudo systemctl enable docker
```

**The browser doesn't open automatically**
Open it manually: [http://localhost:3000](http://localhost:3000)

**Something else is broken**
View the app logs:
```bash
docker compose logs app
```

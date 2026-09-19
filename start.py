import subprocess
import time
import sys
import os

def main():
    root = os.path.dirname(os.path.abspath(__file__))
    backend_dir = os.path.join(root, "backend")
    frontend_dir = os.path.join(root, "frontend")

    print("==================================================")
    print("      RWJO v4 — Reputation-Weighted Jury Oracle   ")
    print("==================================================")
    print("[1/2] Starting Flask Backend on http://127.0.0.1:5000...")
    backend_proc = subprocess.Popen([sys.executable, "app.py"], cwd=backend_dir)
    time.sleep(2)

    print("[2/2] Starting Vite Vue Frontend on http://localhost:5173...")
    try:
        frontend_proc = subprocess.Popen(["npm", "run", "dev"], cwd=frontend_dir, shell=True)
        print("\n>>> RWJO v4 System is LIVE! <<<")
        print("Dashboard URL: http://localhost:5173")
        print("Backend API:   http://127.0.0.1:5000/api/health")
        print("Press Ctrl+C to terminate both servers.\n")
        frontend_proc.wait()
    except KeyboardInterrupt:
        print("\nStopping services...")
    finally:
        backend_proc.terminate()
        try:
            frontend_proc.terminate()
        except Exception:
            pass
        print("Done.")

if __name__ == "__main__":
    main()

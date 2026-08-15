from backend.app.startup_tasks import run_startup_tasks


if __name__ == "__main__":
    result = run_startup_tasks()
    print("startup_tasks result:", result)

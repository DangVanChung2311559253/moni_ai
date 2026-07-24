from fastapi import FastAPI

app = FastAPI(title="Moni AI Backend")


@app.get("/")
def root():
    return {
        "app": "Moni AI Backend",
        "status": "running",
    }


@app.get("/health")
def health():
    return {
        "status": "ok",
    }

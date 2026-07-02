import os
import shutil
import subprocess
import time
import uuid
import zipfile
from pathlib import Path
from threading import Lock, Thread
from typing import Any, Literal

from fastapi import BackgroundTasks, FastAPI, File, HTTPException, UploadFile
from fastapi.responses import JSONResponse


JobStatus = Literal["queued", "running", "succeeded", "failed"]

app = FastAPI(title="MIDI Music OMR Service")

AUDIVERIS_BIN = os.getenv("AUDIVERIS_BIN", "audiveris")
WORK_DIR = Path(os.getenv("OMR_WORK_DIR", "/tmp/midi_music_omr"))
JOB_TIMEOUT_SECONDS = int(os.getenv("OMR_JOB_TIMEOUT_SECONDS", "600"))
MAX_UPLOAD_BYTES = int(os.getenv("OMR_MAX_UPLOAD_MB", "30")) * 1024 * 1024
JOB_TTL_SECONDS = int(os.getenv("OMR_JOB_TTL_SECONDS", str(24 * 60 * 60)))
CLEANUP_INTERVAL_SECONDS = int(os.getenv("OMR_CLEANUP_INTERVAL_SECONDS", "1800"))

_jobs: dict[str, dict[str, Any]] = {}
_jobs_lock = Lock()
_cleanup_started = False


@app.get("/healthz")
async def healthz():
    return {"ok": True}


@app.on_event("startup")
def start_cleanup_worker() -> None:
    global _cleanup_started
    if _cleanup_started:
        return
    _cleanup_started = True
    WORK_DIR.mkdir(parents=True, exist_ok=True)
    worker = Thread(target=_cleanup_loop, daemon=True)
    worker.start()


@app.post("/v1/omr/jobs")
async def create_omr_job(
    background_tasks: BackgroundTasks,
    file: UploadFile = File(...),
):
    if file.content_type not in {"application/pdf", "application/octet-stream"}:
        raise HTTPException(status_code=415, detail="Only PDF files are supported")

    job_id = uuid.uuid4().hex
    job_dir = WORK_DIR / job_id
    job_dir.mkdir(parents=True, exist_ok=False)
    input_pdf = job_dir / "input.pdf"

    try:
        _save_upload(file, input_pdf)
    except ValueError as error:
        shutil.rmtree(job_dir, ignore_errors=True)
        raise HTTPException(status_code=413, detail=str(error)) from error

    with _jobs_lock:
        _jobs[job_id] = {
            "status": "queued",
            "createdAt": time.time(),
            "updatedAt": time.time(),
            "jobDir": str(job_dir),
        }

    background_tasks.add_task(_run_omr_job, job_id, input_pdf, job_dir)
    return {"jobId": job_id}


@app.get("/v1/omr/jobs/{job_id}")
async def get_omr_job(job_id: str):
    with _jobs_lock:
        job = dict(_jobs.get(job_id) or {})

    if not job:
        raise HTTPException(status_code=404, detail="OMR job not found")

    status = job["status"]
    if status == "succeeded":
        musicxml_path = job.get("musicXmlPath")
        if not musicxml_path:
            return JSONResponse({"status": "failed", "message": "MusicXML missing"})
        return {
            "status": "succeeded",
            "musicXml": Path(musicxml_path).read_text(),
        }

    if status == "failed":
        return {"status": "failed", "message": job.get("message", "OMR failed")}

    return {"status": status}


def _run_omr_job(job_id: str, input_pdf: Path, job_dir: Path) -> None:
    _set_job(job_id, status="running")
    output_dir = job_dir / "out"
    output_dir.mkdir(exist_ok=True)

    command = [
        AUDIVERIS_BIN,
        "-batch",
        "-transcribe",
        "-export",
        "-output",
        str(output_dir),
        str(input_pdf),
    ]

    try:
        result = subprocess.run(
            command,
            cwd=job_dir,
            capture_output=True,
            text=True,
            timeout=JOB_TIMEOUT_SECONDS,
            check=False,
        )
        (job_dir / "audiveris.stdout.log").write_text(result.stdout)
        (job_dir / "audiveris.stderr.log").write_text(result.stderr)

        if result.returncode != 0:
            _set_job(
                job_id,
                status="failed",
                message=f"Audiveris exited with code {result.returncode}",
            )
            return

        exported = _find_musicxml(output_dir)
        if exported is None:
            _set_job(job_id, status="failed", message="No MusicXML exported")
            return

        normalized = job_dir / "score.musicxml"
        normalized.write_text(_read_musicxml(exported))
        _set_job(job_id, status="succeeded", musicXmlPath=str(normalized))
    except subprocess.TimeoutExpired:
        _set_job(job_id, status="failed", message="OMR job timed out")
    except Exception as error:  # noqa: BLE001 - API should expose safe failure text.
        _set_job(job_id, status="failed", message=str(error))


def _find_musicxml(output_dir: Path) -> Path | None:
    candidates = [
        *output_dir.rglob("*.musicxml"),
        *output_dir.rglob("*.xml"),
        *output_dir.rglob("*.mxl"),
    ]
    return candidates[0] if candidates else None


def _read_musicxml(path: Path) -> str:
    if path.suffix.lower() != ".mxl":
        return path.read_text()

    with zipfile.ZipFile(path) as archive:
        names = [
            name
            for name in archive.namelist()
            if name.lower().endswith((".musicxml", ".xml"))
            and not name.startswith("META-INF/")
        ]
        if not names:
            raise ValueError("MXL archive does not contain MusicXML")
        return archive.read(names[0]).decode("utf-8")


def _save_upload(file: UploadFile, target: Path) -> None:
    total = 0
    with target.open("wb") as output:
        while True:
            chunk = file.file.read(1024 * 1024)
            if not chunk:
                break
            total += len(chunk)
            if total > MAX_UPLOAD_BYTES:
                raise ValueError(
                    f"PDF 文件过大，当前限制为 {MAX_UPLOAD_BYTES // 1024 // 1024}MB"
                )
            output.write(chunk)


def _cleanup_loop() -> None:
    while True:
        time.sleep(CLEANUP_INTERVAL_SECONDS)
        _cleanup_expired_jobs()


def _cleanup_expired_jobs() -> None:
    now = time.time()
    expired_job_ids: list[str] = []
    expired_dirs: list[Path] = []

    with _jobs_lock:
        for job_id, job in _jobs.items():
            updated_at = float(job.get("updatedAt", job.get("createdAt", now)))
            if now - updated_at <= JOB_TTL_SECONDS:
                continue
            expired_job_ids.append(job_id)
            job_dir = job.get("jobDir")
            if isinstance(job_dir, str):
                expired_dirs.append(Path(job_dir))

        for job_id in expired_job_ids:
            _jobs.pop(job_id, None)

    for job_dir in expired_dirs:
        shutil.rmtree(job_dir, ignore_errors=True)


def _set_job(job_id: str, **updates: Any) -> None:
    with _jobs_lock:
        job = _jobs.setdefault(job_id, {})
        updates["updatedAt"] = time.time()
        job.update(updates)

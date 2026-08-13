from flask import Flask, Response
from pathlib import Path

app = Flask(__name__)
METRICS_PATH = Path("/shared/backup_metrics.prom")

@app.route("/metrics")
def metrics():
    if METRICS_PATH.exists():
        return Response(METRICS_PATH.read_text(), mimetype="text/plain")
    return Response(
        "backup_last_success_timestamp_seconds 0\n"
        "backup_last_size_bytes 0\n",
        mimetype="text/plain"
    )

@app.route("/health")
def health():
    return "ok", 200

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8000)
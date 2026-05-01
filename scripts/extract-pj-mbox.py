#!/usr/bin/env python3
"""NAS-logo — extraction PJ mbox Gmail → /Volumes/NAS-LOGO-DATA/PJgmail{Doc,Photos}/YYYY/MM/

Lecture streaming (pas de mailbox.mbox) : évite le pre-scan de 9 Go.
"""

import email
import email.header
import hashlib
import io
import sys
from datetime import datetime
from email.utils import parsedate_to_datetime
from pathlib import Path

MBOX_PATH    = Path("/Volumes/NAS-LOGO-DATA/MAIL/gmail-archive.mbox")
DIR_DOCS     = Path("/Volumes/NAS-LOGO-DATA/PJgmailDoc")
DIR_PHOTOS   = Path("/Volumes/NAS-LOGO-DATA/PJgmail-Photos")
JOURNAUX_DIR = Path("/Volumes/NAS-LOGO-DATA/journaux")
_RUN_TS      = datetime.now().strftime("%Y%m%d-%H%M%S")
LOG_FILE     = JOURNAUX_DIR / f"extract-pj-mbox-{_RUN_TS}.log"
STATE_FILE   = JOURNAUX_DIR / "extract-pj-mbox-hashes.txt"  # cumulatif, non horodaté

DRY_RUN = "--dry-run" in sys.argv

SKIP_EXT = {
    ".p7s", ".p7m",   # signatures S/MIME
    ".ics",            # invitations calendrier
    ".vcf",            # contacts
    ".html", ".htm",   # corps HTML inline
    ".wav", ".mp3", ".ogg", ".m4a", ".aac", ".flac", ".wma",  # audio → ignoré
}

DOC_EXT = {
    ".pdf", ".doc", ".docx", ".odt", ".txt", ".rtf", ".eml",
    ".xls", ".xlsx", ".ods", ".csv",
}

PHOTO_EXT = {
    ".jpg", ".jpeg", ".png", ".heic", ".heif", ".gif",
    ".bmp", ".webp", ".tiff", ".tif",
    ".mp4", ".mov", ".avi", ".mkv", ".m4v", ".3gp",
}


def dest_dir_for(ext, year, month):
    if ext in DOC_EXT:
        return DIR_DOCS / year / month
    if ext in PHOTO_EXT:
        return DIR_PHOTOS / year / month
    return None


def decode_hdr(value):
    if not value:
        return ""
    parts = email.header.decode_header(value)
    result = []
    for part, charset in parts:
        if isinstance(part, bytes):
            result.append(part.decode(charset or "utf-8", errors="replace"))
        else:
            result.append(part)
    return "".join(result).strip()


def safe_filename(name):
    name = name.strip().replace("/", "-").replace("\x00", "")
    return name[:200] or "pj_sans_nom"


def parse_date(msg):
    try:
        return parsedate_to_datetime(msg.get("Date", ""))
    except Exception:
        return datetime.now()


def file_hash(data):
    return hashlib.sha1(data).hexdigest()


def log(msg):
    line = f"{datetime.now():%H:%M:%S}  {msg}"
    try:
        print(line, flush=True)
    except BrokenPipeError:
        pass
    with open(LOG_FILE, "a") as f:
        f.write(line + "\n")


def iter_messages(path):
    """Lecture streaming ligne par ligne — pas de pre-scan."""
    buf = []
    with open(path, "rb") as f:
        for raw_line in f:
            if raw_line.startswith(b"From ") and buf:
                yield email.message_from_bytes(b"".join(buf))
                buf = []
            buf.append(raw_line)
    if buf:
        yield email.message_from_bytes(b"".join(buf))


def process_attachment(part, year, month, seen_hashes, stats, new_hashes):
    raw_name = part.get_filename()
    if not raw_name:
        return

    filename = safe_filename(decode_hdr(raw_name))
    ext = Path(filename).suffix.lower()

    if ext in SKIP_EXT:
        stats["skipped"] += 1
        return

    dest_base = dest_dir_for(ext, year, month)
    if dest_base is None:
        stats["skipped"] += 1
        return

    try:
        data = part.get_payload(decode=True)
    except Exception as e:
        log(f"  ERREUR décodage {filename} : {e}")
        stats["errors"] += 1
        return

    if not data:
        stats["skipped"] += 1
        return

    h = file_hash(data)
    if h in seen_hashes:
        stats["dupes"] += 1
        return

    if not DRY_RUN:
        dest_base.mkdir(parents=True, exist_ok=True)

    dest = dest_base / filename
    if not DRY_RUN and dest.exists():
        dest = dest_base / f"{dest.stem}_{h[:6]}{ext}"

    if not DRY_RUN:
        dest.write_bytes(data)

    seen_hashes.add(h)
    new_hashes.append(h)
    category = "docs" if ext in DOC_EXT else "photos"
    stats[category] += 1

    total = stats["docs"] + stats["photos"]
    if DRY_RUN or total <= 20:
        label = "Doc" if ext in DOC_EXT else "Photo"
        log(f"  {'[DRY] ' if DRY_RUN else ''}[{label}] → {year}/{month}/{filename}  ({len(data)//1024} Ko)")


def main():
    JOURNAUX_DIR.mkdir(parents=True, exist_ok=True)
    if not DRY_RUN:
        DIR_DOCS.mkdir(parents=True, exist_ok=True)
        DIR_PHOTOS.mkdir(parents=True, exist_ok=True)

    seen_hashes = set()
    if STATE_FILE.exists():
        seen_hashes = set(STATE_FILE.read_text().splitlines())

    log(f"=== extract-pj {'DRY-RUN ' if DRY_RUN else ''}démarré ===")
    log(f"Source : {MBOX_PATH}  ({MBOX_PATH.stat().st_size / 1e9:.1f} Go)")
    log(f"Docs   : {DIR_DOCS}")
    log(f"Photos : {DIR_PHOTOS}")
    log(f"Hashes déjà vus : {len(seen_hashes)}")

    stats = {"emails": 0, "docs": 0, "photos": 0, "dupes": 0, "skipped": 0, "errors": 0}
    new_hashes = []

    for i, msg in enumerate(iter_messages(MBOX_PATH)):
        stats["emails"] += 1
        if i % 1000 == 0 and i > 0:
            log(f"  {i} emails — {stats['docs']} docs, {stats['photos']} photos, {stats['dupes']} dupes")

        try:
            date = parse_date(msg)
        except Exception:
            date = datetime.now()
        year  = date.strftime("%Y")
        month = date.strftime("%m")

        try:
            parts = list(msg.walk())
        except Exception as e:
            log(f"  ERREUR walk email {i} : {e}")
            continue

        for part in parts:
            disposition = decode_hdr(part.get("Content-Disposition") or "")
            if "attachment" not in disposition.lower():
                continue
            process_attachment(part, year, month, seen_hashes, stats, new_hashes)

    if not DRY_RUN and new_hashes:
        with open(STATE_FILE, "a") as f:
            f.write("\n".join(new_hashes) + "\n")

    log("=== Terminé ===")
    log(f"  Emails parcourus : {stats['emails']}")
    log(f"  Docs extraits    : {stats['docs']}  → {DIR_DOCS}")
    log(f"  Photos extraites : {stats['photos']}  → {DIR_PHOTOS}")
    log(f"  Doublons ignorés : {stats['dupes']}")
    log(f"  Types ignorés    : {stats['skipped']}")
    log(f"  Erreurs          : {stats['errors']}")


if __name__ == "__main__":
    main()

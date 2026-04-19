import { Controller } from "@hotwired/stimulus";
import { DirectUpload } from "@rails/activestorage";

export default class extends Controller {
  static targets = ["input", "list", "dropZone"];

  upload(event) {
    const files = Array.from(this.inputTarget.files);
    files.forEach((file) => this.uploadFile(file));
    this.inputTarget.value = "";
  }

  dragover(event) {
    event.preventDefault();
    this.dropZoneTarget.classList.add("drop-zone--over");
  }

  dragleave() {
    this.dropZoneTarget.classList.remove("drop-zone--over");
  }

  drop(event) {
    event.preventDefault();
    this.dropZoneTarget.classList.remove("drop-zone--over");
    const files = Array.from(event.dataTransfer.files).filter((f) =>
      f.name.endsWith(".gpx"),
    );
    if (files.length === 0) {
      this.showDropError("Only .gpx files are supported.");
      return;
    }
    files.forEach((file) => this.uploadFile(file));
  }

  uploadFile(file) {
    const item = this.createItem(file.name);
    this.listTarget.appendChild(item);

    const upload = new DirectUpload(
      file,
      "/rails/active_storage/direct_uploads",
      {
        directUploadWillStoreFileWithXHR: (request) => {
          request.upload.addEventListener("progress", (event) => {
            const pct = Math.round((event.loaded / event.total) * 100);
            item.querySelector(".upload-progress").value = pct;
          });
        },
      },
    );

    upload.create((error, blob) => {
      if (error) {
        this.setStatus(item, "error", "Upload failed — " + error);
      } else {
        this.setStatus(item, "processing", "Processing…");
        this.createActivity(blob, item);
      }
    });
  }

  createActivity(blob, item) {
    fetch("/activities", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]').content,
      },
      body: JSON.stringify({ activity: { file: blob.signed_id, name: blob.filename } }),
    })
      .then((r) => {
        if (!r.ok) throw new Error("Server error " + r.status);
        return r.json();
      })
      .then((data) => {
        item.querySelector(".upload-filename").textContent = data.name || blob.filename;
        let status = `<a href="/activities/${data.id}">View</a>`;
        if (data.duplicate_of) {
          status += ` &middot; <span class="upload-warning">⚠ possible duplicate of <a href="/activities/${data.duplicate_of.id}">${data.duplicate_of.name}</a></span>`;
        }
        this.setStatus(item, "done", status);
      })
      .catch((err) => {
        this.setStatus(item, "error", "Failed — " + err.message);
      });
  }

  createItem(filename) {
    const li = document.createElement("li");
    li.className = "upload-item";
    li.innerHTML = `
      <span class="upload-filename">${filename}</span>
      <progress class="upload-progress" max="100" value="0"></progress>
      <span class="upload-status">Uploading…</span>
    `;
    return li;
  }

  setStatus(item, state, html) {
    const status = item.querySelector(".upload-status");
    status.innerHTML = html;
    status.dataset.state = state;
    if (state !== "processing") item.querySelector(".upload-progress").remove();
  }

  showDropError(message) {
    const p = document.createElement("p");
    p.className = "drop-error";
    p.textContent = message;
    this.dropZoneTarget.appendChild(p);
    setTimeout(() => p.remove(), 3000);
  }
}

import { Controller } from "@hotwired/stimulus";
import { DirectUpload } from "@rails/activestorage";

export default class extends Controller {
  static targets = ["input", "list"];

  upload(event) {
    const files = Array.from(this.inputTarget.files);
    files.forEach((file) => this.uploadFile(file));
    // Clear the input so user can drop more
    this.inputTarget.value = "";
  }

  uploadFile(file) {
    // 1. Create a UI element for this file
    const item = this.createProgressElement(file);
    this.listTarget.appendChild(item);

    // 2. Start Direct Upload
    const upload = new DirectUpload(
      file,
      "/rails/active_storage/direct_uploads",
      {
        directUploadWillStoreFileWithXHR: (request) => {
          request.upload.addEventListener("progress", (event) => {
            this.updateProgress(item, event);
          });
        },
      },
    );

    upload.create((error, blob) => {
      if (error) {
        item.querySelector(".status").innerText = "Upload Failed";
      } else {
        // 3. Tell Rails to create the Activity record with the blob signed_id
        this.createActivity(blob, item);
      }
    });
  }

  createActivity(blob, item) {
    fetch("/activities", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]')
          .content,
      },
      body: JSON.stringify({
        activity: {
          file: blob.signed_id,
          name: blob.filename,
        },
      }),
    })
      .then((response) => response.json())
      .then((data) => {
        item.querySelector(".status").innerHTML =
          `<a href="/activities/${data.id}/edit">Edit Details</a>`;
      });
  }

  createProgressElement(file) {
    const template = document.createElement("div");
    template.className = "upload-item border p-2 mb-2 flex justify-between";
    template.innerHTML = `
      <span>${file.name}</span>
      <progress max="100"></progress>
      <span class="status">Uploading...</span>
    `;
    return template;
  }

  updateProgress(item, event) {
    const percent = (event.loaded / event.total) * 100;
    item.querySelector("progress").value = `${percent}`;
  }
}

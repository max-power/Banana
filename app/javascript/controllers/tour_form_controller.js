import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["startDate", "endDate", "preview"]
  static values = { previewUrl: String }

  refresh() {
    const start = this.startDateTarget.value
    const end = this.endDateTarget.value

    if (!start || !end) {
      this.previewTarget.innerHTML = '<p class="tour-preview-hint">Select a date range to preview matching activities</p>'
      return
    }

    const url = new URL(this.previewUrlValue, window.location.origin)
    url.searchParams.set("start_date", start)
    url.searchParams.set("end_date", end)

    fetch(url, { headers: { "Accept": "text/html", "X-Requested-With": "XMLHttpRequest" } })
      .then(r => r.text())
      .then(html => { this.previewTarget.innerHTML = html })
  }
}

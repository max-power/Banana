import { Controller } from "@hotwired/stimulus"

const SCHEMES = ["auto", "light", "dark"]
const KEY     = "color-scheme"

const ICONS = {
  auto: `<svg width="16" height="16" viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round">
    <rect x="1" y="2" width="14" height="10" rx="1.5"/>
    <path d="M6 12l-.5 2h5l-.5-2"/>
    <line x1="3.5" y1="14.5" x2="12.5" y2="14.5"/>
  </svg>`,

  light: `<svg width="16" height="16" viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round">
    <circle cx="8" cy="8" r="2.5"/>
    <line x1="8" y1="1.5" x2="8" y2="3"/>
    <line x1="8" y1="13" x2="8" y2="14.5"/>
    <line x1="1.5" y1="8" x2="3" y2="8"/>
    <line x1="13" y1="8" x2="14.5" y2="8"/>
    <line x1="3.4" y1="3.4" x2="4.5" y2="4.5"/>
    <line x1="11.5" y1="11.5" x2="12.6" y2="12.6"/>
    <line x1="12.6" y1="3.4" x2="11.5" y2="4.5"/>
    <line x1="4.5" y1="11.5" x2="3.4" y2="12.6"/>
  </svg>`,

  dark: `<svg width="16" height="16" viewBox="0 0 16 16" fill="currentColor">
    <path d="M6.5 2.5a5.5 5.5 0 1 0 7 7 4 4 0 0 1-7-7z"/>
  </svg>`
}

export default class extends Controller {
  connect() {
    this.apply(this.current)
  }

  toggle() {
    const next = SCHEMES[(SCHEMES.indexOf(this.current) + 1) % SCHEMES.length]
    localStorage.setItem(KEY, next)
    this.apply(next)
  }

  get current() {
    return localStorage.getItem(KEY) || "auto"
  }

  apply(scheme) {
    if (scheme === "auto") {
      document.documentElement.style.removeProperty("color-scheme")
    } else {
      document.documentElement.style.colorScheme = scheme
    }
    this.element.innerHTML = ICONS[scheme]
    this.element.title = `Color scheme: ${scheme} — click to cycle`
  }
}

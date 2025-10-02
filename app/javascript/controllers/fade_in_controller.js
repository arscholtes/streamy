import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    // Set initial opacity to 0
    this.element.style.opacity = "0"
    this.element.style.transition = "opacity 1s ease-in-out"

    // Use requestAnimationFrame to ensure the initial style is applied
    requestAnimationFrame(() => {
      requestAnimationFrame(() => {
        this.element.style.opacity = "1"
      })
    })
  }
}

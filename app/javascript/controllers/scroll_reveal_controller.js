// app/javascript/controllers/scroll_reveal_controller.js
// Stimulus controller for scroll-triggered animations
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["animate"]

  connect() {
    this.observer = new IntersectionObserver(
      (entries) => this.handleIntersection(entries),
      {
        threshold: 0.1,
        rootMargin: '0px 0px -100px 0px'
      }
    )

    this.animateTargets.forEach(target => {
      this.observer.observe(target)
    })
  }

  disconnect() {
    if (this.observer) {
      this.observer.disconnect()
    }
  }

  handleIntersection(entries) {
    entries.forEach(entry => {
      if (entry.isIntersecting) {
        entry.target.classList.add('is-visible')
        // Optionally unobserve after animation
        // this.observer.unobserve(entry.target)
      }
    })
  }
}

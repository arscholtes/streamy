import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["card"]

  connect() {
    this.currentIndex = 0
    this.startAutoScroll()
  }

  disconnect() {
    this.stopAutoScroll()
  }

  next() {
    this.stopAutoScroll()
    this.currentIndex = (this.currentIndex + 1) % this.cardTargets.length
    this.updateActiveCard()
    this.startAutoScroll()
  }

  prev() {
    this.stopAutoScroll()
    this.currentIndex = (this.currentIndex - 1 + this.cardTargets.length) % this.cardTargets.length
    this.updateActiveCard()
    this.startAutoScroll()
  }

  updateActiveCard() {
    this.cardTargets.forEach((card, index) => {
      if (index === this.currentIndex) {
        card.classList.add('active')
      } else {
        card.classList.remove('active')
      }
    })
  }

  startAutoScroll() {
    this.autoScrollInterval = setInterval(() => {
      this.next()
    }, 5000)
  }

  stopAutoScroll() {
    if (this.autoScrollInterval) {
      clearInterval(this.autoScrollInterval)
    }
  }
}

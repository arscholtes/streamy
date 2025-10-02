import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    // Add hover event listeners
    this.element.addEventListener('mouseenter', this.handleMouseEnter.bind(this))
    this.element.addEventListener('mouseleave', this.handleMouseLeave.bind(this))
  }

  disconnect() {
    this.element.removeEventListener('mouseenter', this.handleMouseEnter.bind(this))
    this.element.removeEventListener('mouseleave', this.handleMouseLeave.bind(this))
  }

  handleMouseEnter() {
    this.element.style.transform = 'translateY(-8px) scale(1.02)'
    this.element.style.boxShadow = '0 8px 30px rgba(139, 92, 246, 0.5)'
  }

  handleMouseLeave() {
    this.element.style.transform = 'translateY(0) scale(1)'
    this.element.style.boxShadow = ''
  }
}

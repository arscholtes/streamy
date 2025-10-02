import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="chat"
export default class extends Controller {
  static targets = ["messages", "input", "form"]
  static values = { streamId: Number }

  connect() {
    // Scroll to bottom on load
    this.scrollToBottom()

    // Set up mutation observer to auto-scroll when new messages arrive
    this.observer = new MutationObserver(() => {
      this.scrollToBottom()
    })

    if (this.hasMessagesTarget) {
      this.observer.observe(this.messagesTarget, {
        childList: true,
        subtree: true
      })
    }
  }

  disconnect() {
    if (this.observer) {
      this.observer.disconnect()
    }
  }

  scrollToBottom() {
    if (this.hasMessagesTarget) {
      this.messagesTarget.scrollTop = this.messagesTarget.scrollHeight
    }
  }

  submit(event) {
    event.preventDefault()

    const content = this.inputTarget.value.trim()
    if (!content) return

    // Send message to server
    fetch(`/streams/${this.streamIdValue}/chat_messages`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content
      },
      body: JSON.stringify({ content: content })
    })
    .then(response => {
      if (response.ok) {
        // Clear input on success
        this.inputTarget.value = ''
        this.inputTarget.focus()
      }
    })
    .catch(error => {
      console.error('Error sending message:', error)
    })
  }

  // Handle Enter key to submit (Shift+Enter for new line)
  handleKeydown(event) {
    if (event.key === 'Enter' && !event.shiftKey) {
      event.preventDefault()
      this.submit(event)
    }
  }
}

import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["panel", "messages", "input", "form", "sendButton", "history"]

  connect() {
    console.log("Chat controller connected")
    this.scrollToBottom()
  }

  toggle() {
    const panel = this.panelTarget
    panel.classList.toggle("translate-x-full")
    
    // Focus the input when opening
    if (!panel.classList.contains("translate-x-full")) {
      setTimeout(() => this.inputTarget.focus(), 300)
    }
  }

  close() {
    this.panelTarget.classList.add("translate-x-full")
  }

  toggleHistory() {
    if (this.hasHistoryTarget) {
      this.historyTarget.classList.toggle("hidden")
      this.scrollToBottom()
    }
  }

  async submitMessage(event) {
    event.preventDefault()

    const message = this.inputTarget.value.trim()
    if (!message) return

    // Disable form while processing
    this.disableForm()

    // Add user message to chat immediately
    this.addMessage(message, "user")

    // Clear input
    this.inputTarget.value = ""

    // Show loading indicator
    const loadingId = this.addLoadingMessage()

    try {
      const response = await this.sendMessageToServer(message)
      
      // Remove loading indicator
      this.removeLoadingMessage(loadingId)

      if (response.error) {
        this.addMessage(response.error, "error")
      } else {
        this.addMessage(response.ai_response, "ai", response.created_at)
      }
    } catch (error) {
      console.error("Error sending message:", error)
      this.removeLoadingMessage(loadingId)
      this.addMessage("Sorry, there was an error processing your message. Please try again.", "error")
    } finally {
      this.enableForm()
    }
  }

  async sendMessageToServer(message) {
    const csrfToken = document.querySelector('meta[name="csrf-token"]').content
    
    const response = await fetch("/dashboard/messages", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "X-CSRF-Token": csrfToken
      },
      body: JSON.stringify({ message })
    })

    if (!response.ok) {
      const errorData = await response.json()
      throw new Error(errorData.error || "Failed to send message")
    }

    return await response.json()
  }

  addMessage(text, type, timestamp = null) {
    const messageDiv = document.createElement("div")
    messageDiv.classList.add("mb-4", "animate-fade-in")

    if (type === "user") {
      messageDiv.innerHTML = `
        <div class="flex justify-end">
          <div class="bg-blue-500 text-white rounded-lg px-4 py-2 max-w-xs lg:max-w-md">
            <p class="text-sm">${this.escapeHtml(text)}</p>
            <p class="text-xs opacity-75 mt-1">${this.formatTime(new Date())}</p>
          </div>
        </div>
      `
    } else if (type === "ai") {
      messageDiv.innerHTML = `
        <div class="flex justify-start">
          <div class="bg-green-500 text-white rounded-lg px-4 py-2 max-w-xs lg:max-w-md">
            <p class="text-sm">${this.escapeHtml(text)}</p>
            <p class="text-xs opacity-75 mt-1">${this.formatTime(timestamp ? new Date(timestamp) : new Date())}</p>
          </div>
        </div>
      `
    } else if (type === "error") {
      messageDiv.innerHTML = `
        <div class="flex justify-center">
          <div class="bg-red-100 text-red-800 rounded-lg px-4 py-2 max-w-xs lg:max-w-md">
            <p class="text-sm">${this.escapeHtml(text)}</p>
          </div>
        </div>
      `
    }

    this.messagesTarget.appendChild(messageDiv)
    this.scrollToBottom()
  }

  addLoadingMessage() {
    const loadingId = `loading-${Date.now()}`
    const messageDiv = document.createElement("div")
    messageDiv.id = loadingId
    messageDiv.classList.add("mb-4", "flex", "justify-start")
    messageDiv.innerHTML = `
      <div class="bg-gray-200 rounded-lg px-4 py-2">
        <div class="flex space-x-2">
          <div class="w-2 h-2 bg-gray-500 rounded-full animate-bounce"></div>
          <div class="w-2 h-2 bg-gray-500 rounded-full animate-bounce" style="animation-delay: 0.1s"></div>
          <div class="w-2 h-2 bg-gray-500 rounded-full animate-bounce" style="animation-delay: 0.2s"></div>
        </div>
      </div>
    `

    this.messagesTarget.appendChild(messageDiv)
    this.scrollToBottom()
    return loadingId
  }

  removeLoadingMessage(loadingId) {
    const loadingElement = document.getElementById(loadingId)
    if (loadingElement) {
      loadingElement.remove()
    }
  }

  disableForm() {
    this.inputTarget.disabled = true
    this.sendButtonTarget.disabled = true
  }

  enableForm() {
    this.inputTarget.disabled = false
    this.sendButtonTarget.disabled = false
    this.inputTarget.focus()
  }

  scrollToBottom() {
    const container = this.messagesTarget
    container.scrollTop = container.scrollHeight
  }

  escapeHtml(text) {
    const div = document.createElement("div")
    div.textContent = text
    return div.innerHTML
  }

  formatTime(date) {
    return date.toLocaleTimeString("en-US", { 
      hour: "numeric", 
      minute: "2-digit",
      hour12: true 
    })
  }
}


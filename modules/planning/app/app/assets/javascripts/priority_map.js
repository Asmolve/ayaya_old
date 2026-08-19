class PriorityMap {
  constructor(root) {
    this.root = root
    this.inspector = root.querySelector("[data-item-inspector]")
    this.status = root.querySelector("[data-priority-status]")
    this.reducedMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches
    this.connect()
  }

  connect() {
    this.root.querySelectorAll("[data-planning-select]").forEach((button) => {
      button.addEventListener("click", () => this.select(button.closest("[data-priority-item]")))
    })
    this.root.querySelectorAll("[data-priority-move]").forEach((form) => {
      form.addEventListener("submit", (event) => this.moveFromForm(event, form))
    })
    this.root.querySelectorAll("[data-priority-lane-select]").forEach((select) => {
      select.addEventListener("change", () => select.closest("form")?.requestSubmit())
    })
    this.root.querySelectorAll("[data-priority-item]").forEach((item) => this.connectDrag(item))
    this.root.querySelectorAll("[data-priority-items]").forEach((list) => this.connectDropZone(list))
  }

  select(item) {
    if (!item || !this.inspector) return

    this.root.querySelectorAll("[data-priority-item]").forEach((candidate) => {
      const selected = candidate === item
      candidate.classList.toggle("is-selected", selected)
      candidate.querySelector("[data-planning-select]")?.setAttribute("aria-pressed", selected)
    })

    const form = this.inspector.querySelector("[data-inspector-form]")
    if (!form) return

    this.inspector.querySelector("[data-inspector-heading]").textContent = item.dataset.itemTitle
    form.action = `/m/planning/plan_items/${item.dataset.itemId}`
    form.querySelector("[data-inspector-title]").value = item.dataset.itemTitle
    form.querySelector("[data-inspector-notes]").value = item.dataset.itemNotes || ""
    form.querySelector("[data-inspector-priority]").value = item.dataset.itemPriority
    form.querySelector("[data-inspector-completed]").checked = item.dataset.itemCompleted === "true"
    if (!this.reducedMotion) this.inspector.animate([{ opacity: .55 }, { opacity: 1 }], { duration: 150 })
  }

  moveFromForm(event, form) {
    event.preventDefault()
    const item = form.closest("[data-priority-item]")
    const data = new FormData(form)
    this.optimisticMove(item, data.get("plan_item[priority]"), data.get("plan_item[position]"))
  }

  connectDrag(item) {
    item.addEventListener("dragstart", (event) => {
      event.dataTransfer.effectAllowed = "move"
      event.dataTransfer.setData("text/plain", item.dataset.itemId)
      item.classList.add("is-moving")
    })
    item.addEventListener("dragend", () => item.classList.remove("is-moving"))
  }

  connectDropZone(list) {
    list.addEventListener("dragover", (event) => {
      event.preventDefault()
      list.classList.add("is-insertion-target")
    })
    list.addEventListener("dragleave", () => list.classList.remove("is-insertion-target"))
    list.addEventListener("drop", (event) => {
      event.preventDefault()
      list.classList.remove("is-insertion-target")
      const item = this.root.querySelector(`[data-item-id="${event.dataTransfer.getData("text/plain")}"]`)
      const lane = list.closest("[data-priority-lane]")
      this.optimisticMove(item, lane.dataset.priorityLane, list.children.length)
    })
  }

  async optimisticMove(item, priority, position) {
    if (!item || !priority || position === null) return

    const snapshot = { parent: item.parentElement, next: item.nextElementSibling, priority: item.dataset.itemPriority, position: item.dataset.itemPosition }
    const destination = this.root.querySelector(`[data-priority-lane="${priority}"] [data-priority-items]`)
    destination?.append(item)
    item.dataset.itemPriority = priority
    item.dataset.itemPosition = position
    this.select(item)

    try {
      const response = await fetch(`/m/planning/plan_items/${item.dataset.itemId}/position`, {
        method: "PATCH",
        headers: { "Content-Type": "application/json", "Accept": "application/json", "X-CSRF-Token": document.querySelector("meta[name='csrf-token']")?.content },
        body: JSON.stringify({ priority, position: Number(position) })
      })
      if (!response.ok) throw new Error("Priority map update failed")
      const movedItem = await response.json()
      item.dataset.itemPriority = movedItem.priority
      item.dataset.itemPosition = movedItem.position
      this.announce(`Moved ${item.dataset.itemTitle} to ${this.laneName(movedItem.priority)}.`)
    } catch (_) {
      snapshot.parent.insertBefore(item, snapshot.next)
      item.dataset.itemPriority = snapshot.priority
      item.dataset.itemPosition = snapshot.position
      this.select(item)
      this.announce(`Could not move ${item.dataset.itemTitle}. Changes were reverted.`)
    }
  }

  announce(message) {
    if (this.status) this.status.textContent = message
  }

  laneName(priority) {
    return priority.charAt(0).toUpperCase() + priority.slice(1)
  }
}

document.addEventListener("DOMContentLoaded", () => {
  document.querySelectorAll("[data-priority-map]").forEach((root) => new PriorityMap(root))
})

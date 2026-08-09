const DRAFT_TTL = 24 * 60 * 60 * 1000
const DRAFT_WRITE_DELAY = 250

const normalizeRange = (left, right) => left <= right ? [ left, right ] : [ right, left ]
const draftKey = (userId, start, end) => `diary-draft-v1:${userId}:${start}:${end}`
const expiresAt = () => Date.now() + DRAFT_TTL

class DiaryCalendar {
  constructor(calendar) {
    this.calendar = calendar
    this.modal = document.querySelector("#diary-modal")
    this.form = document.querySelector("#diary-form")
    this.startInput = document.querySelector("#note_start_date")
    this.endInput = document.querySelector("#note_end_date")
    this.titleInput = document.querySelector("#note_title")
    this.editor = document.querySelector("trix-editor")
    this.deleteButton = document.querySelector("[data-diary-delete]")
    this.errors = document.querySelector("[data-diary-errors]")
    this.lookupUrl = calendar.dataset.entryLookupUrl
    this.userId = calendar.dataset.localUserId
    this.createAction = this.form.action
    this.dragStart = null
    this.dragEnd = null
    this.skipNextDayClick = false
    this.draftTimer = null

    this.connect()
  }

  connect() {
    this.calendar.querySelectorAll("[data-date]").forEach((day) => {
      day.addEventListener("pointerdown", (event) => this.startDrag(event))
      day.addEventListener("pointerenter", (event) => this.extendDrag(event))
      day.addEventListener("click", (event) => this.selectDay(event))
    })
    this.calendar.querySelectorAll("[data-range-start][data-range-end]").forEach((button) => {
      button.addEventListener("click", () => this.openRange(button.dataset.rangeStart, button.dataset.rangeEnd))
    })
    this.calendar.addEventListener("pointermove", (event) => this.extendDrag(event))
    this.calendar.addEventListener("pointerup", (event) => this.finishDrag(event))
    this.calendar.addEventListener("pointercancel", () => this.cancelDrag())

    this.modal.querySelector("[data-diary-close]").addEventListener("click", () => this.close())
    this.modal.addEventListener("click", (event) => {
      if (event.target === this.modal) this.close()
    })
    document.addEventListener("keydown", (event) => {
      if (event.key === "Escape" && this.isOpen()) this.close()
    })
    this.form.addEventListener("submit", (event) => this.save(event))
    this.deleteButton.addEventListener("click", () => this.deleteEntry())
    ;[ this.startInput, this.endInput, this.titleInput ].forEach((input) => {
      input.addEventListener("input", () => this.queueDraft())
      input.addEventListener("change", () => this.queueDraft())
    })
    this.editor.addEventListener("trix-change", () => this.queueDraft())
  }

  startDrag(event) {
    this.dragStart = event.currentTarget.dataset.date
    this.dragEnd = this.dragStart
    this.skipNextDayClick = true
    event.currentTarget.setPointerCapture?.(event.pointerId)
    this.updateSelectionPreview()
  }

  extendDrag(event) {
    if (!this.dragStart) return

    const date = this.dateAt(event)
    if (!date) return

    this.dragEnd = date
    this.updateSelectionPreview()
  }

  finishDrag(event) {
    if (!this.dragStart) return

    const [ start, end ] = normalizeRange(this.dragStart, this.dateAt(event) || this.dragEnd || this.dragStart)
    this.cancelDrag()
    this.openRange(start, end)
  }

  cancelDrag() {
    this.dragStart = null
    this.dragEnd = null
    this.calendar.querySelectorAll(".is-selecting").forEach((day) => day.classList.remove("is-selecting"))
  }

  selectDay(event) {
    if (this.skipNextDayClick) {
      this.skipNextDayClick = false
      return
    }

    const date = event.currentTarget.dataset.date
    this.openRange(date, date)
  }

  dateAt(event) {
    const target = document.elementFromPoint(event.clientX, event.clientY)
    return target?.closest("[data-date]")?.dataset.date
  }

  updateSelectionPreview() {
    const [ start, end ] = normalizeRange(this.dragStart, this.dragEnd)
    this.calendar.querySelectorAll("[data-date]").forEach((day) => {
      day.classList.toggle("is-selecting", day.dataset.date >= start && day.dataset.date <= end)
    })
  }

  async openRange(start, end) {
    ;[ start, end ] = normalizeRange(start, end)
    this.resetForm(start, end)
    this.show()

    try {
      const entry = await this.fetchEntry(start, end)
      if (entry) this.populateForm(entry)
      this.restoreDraft(start, end)
    } catch (_) {
      this.showErrors([ "Unable to load this diary entry." ])
    }
  }

  async fetchEntry(start, end) {
    const url = new URL(this.lookupUrl, window.location.origin)
    url.searchParams.set("start_date", start)
    url.searchParams.set("end_date", end)
    const response = await fetch(url, { headers: { Accept: "application/json" } })

    if (response.status === 404) return null
    if (!response.ok) throw new Error("Diary entry lookup failed")

    return response.json()
  }

  resetForm(start, end) {
    this.form.reset()
    this.form.action = this.createAction
    this.form.querySelector("[data-diary-method]")?.remove()
    delete this.form.dataset.entryId
    this.deleteButton.hidden = true
    this.clearErrors()
    this.startInput.value = start
    this.endInput.value = end
    this.setEditorHTML("")
  }

  populateForm(entry) {
    this.form.dataset.entryId = entry.id
    this.form.action = `${this.createAction}/${entry.id}`
    const method = document.createElement("input")
    method.type = "hidden"
    method.name = "_method"
    method.value = "patch"
    method.dataset.diaryMethod = "true"
    this.form.append(method)
    this.titleInput.value = entry.title
    this.startInput.value = entry.start_date
    this.endInput.value = entry.end_date
    this.setEditorHTML(entry.content)
    this.deleteButton.hidden = false
  }

  restoreDraft(start, end) {
    const draft = this.readDraft(start, end)
    if (!draft) return

    this.titleInput.value = draft.title || ""
    this.startInput.value = draft.start_date
    this.endInput.value = draft.end_date
    this.setEditorHTML(draft.content || "")
  }

  readDraft(start, end) {
    const key = draftKey(this.userId, start, end)

    try {
      const draft = JSON.parse(localStorage.getItem(key))
      if (!draft) return null
      if (draft.expires_at <= Date.now() || draft.start_date !== start || draft.end_date !== end) {
        localStorage.removeItem(key)
        return null
      }

      return draft
    } catch (_) {
      localStorage.removeItem(key)
      return null
    }
  }

  queueDraft() {
    window.clearTimeout(this.draftTimer)
    this.draftTimer = window.setTimeout(() => this.persistDraft(), DRAFT_WRITE_DELAY)
  }

  persistDraft() {
    const start = this.startInput.value
    const end = this.endInput.value
    if (!start || !end) return

    const draft = {
      title: this.titleInput.value,
      content: this.editor.innerHTML,
      start_date: start,
      end_date: end,
      expires_at: expiresAt()
    }

    try {
      localStorage.setItem(draftKey(this.userId, start, end), JSON.stringify(draft))
    } catch (_) {
      // A full or disabled localStorage must not prevent editing or saving.
    }
  }

  async save(event) {
    event.preventDefault()
    this.clearErrors()

    try {
      const response = await fetch(this.form.action, { method: "POST", body: new FormData(this.form) })
      if (!response.ok) return this.showResponseErrors(response)

      this.clearCurrentDraft()
      this.close()
      window.location.reload()
    } catch (_) {
      this.showErrors([ "Unable to save this diary entry." ])
    }
  }

  async deleteEntry() {
    if (!this.form.dataset.entryId) return

    this.clearErrors()
    try {
      const response = await fetch(this.form.action, {
        method: "DELETE",
        headers: this.csrfHeaders(),
        redirect: "manual"
      })
      if (!response.ok && response.type !== "opaqueredirect") return this.showResponseErrors(response)

      this.clearCurrentDraft()
      this.close()
      window.location.reload()
    } catch (_) {
      this.showErrors([ "Unable to delete this diary entry." ])
    }
  }

  async showResponseErrors(response) {
    const document = new DOMParser().parseFromString(await response.text(), "text/html")
    const messages = [ ...document.querySelectorAll("li") ].map((item) => item.textContent.trim()).filter(Boolean)
    this.showErrors(messages.length ? messages : [ "Unable to save this diary entry." ])
  }

  csrfHeaders() {
    const token = document.querySelector("meta[name='csrf-token']")?.content
    return token ? { "X-CSRF-Token": token } : {}
  }

  clearCurrentDraft() {
    localStorage.removeItem(draftKey(this.userId, this.startInput.value, this.endInput.value))
  }

  setEditorHTML(html) {
    if (this.editor.editor) {
      this.editor.editor.loadHTML(html)
    } else {
      this.editor.innerHTML = html
    }
  }

  clearErrors() {
    this.errors.replaceChildren()
    this.errors.hidden = true
  }

  showErrors(messages) {
    const list = document.createElement("ul")
    messages.forEach((message) => {
      const item = document.createElement("li")
      item.textContent = message
      list.append(item)
    })
    this.errors.replaceChildren(list)
    this.errors.hidden = false
  }

  show() {
    this.modal.classList.add("is-open")
    this.modal.setAttribute("aria-hidden", "false")
  }

  close() {
    this.modal.classList.remove("is-open")
    this.modal.setAttribute("aria-hidden", "true")
  }

  isOpen() {
    return this.modal.classList.contains("is-open")
  }
}

const connectDiaryCalendars = () => {
  document.querySelectorAll("[data-diary-calendar]").forEach((calendar) => new DiaryCalendar(calendar))
}

if (document.readyState === "loading") {
  document.addEventListener("DOMContentLoaded", connectDiaryCalendars, { once: true })
} else {
  connectDiaryCalendars()
}

export { DiaryCalendar, draftKey, expiresAt, normalizeRange }

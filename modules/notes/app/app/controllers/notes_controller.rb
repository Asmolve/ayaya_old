class NotesController < ApplicationController
  include AyayaIdentity

  before_action :set_note, only: %i[show edit update destroy]

  def index
    @notes = current_local_user.notes.order(updated_at: :desc)
  end

  def show
  end

  def new
    @note = current_local_user.notes.build
  end

  def create
    @note = current_local_user.notes.build(note_params)

    if @note.save
      redirect_to note_path(@note)
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @note.update(note_params)
      redirect_to note_path(@note)
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @note.destroy!
    redirect_to notes_root_path
  end

  private

  def set_note
    @note = current_local_user.notes.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    head :not_found
  end

  def note_params
    params.require(:note).permit(:title, :body)
  end
end

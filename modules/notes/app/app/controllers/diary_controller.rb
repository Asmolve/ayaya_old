class DiaryController < ApplicationController
  include AyayaIdentity
  include DiaryHelper

  def index
    @quarter_start = quarter_start(parse_iso_date(params[:quarter]) || Date.current)
    @months = 3.times.map { |offset| @quarter_start + offset.months }
    @visible_diary_entries = current_local_user.notes.diary.where(
      "start_date <= ? AND end_date >= ?", @quarter_start.advance(months: 3) - 1.day, @quarter_start
    )
  rescue Date::Error
    render plain: "quarter must be an ISO date", status: :unprocessable_entity
  end

  def entry
    entry = current_local_user.notes.diary.find_by!(
      start_date: parse_required_iso_date(:start_date),
      end_date: parse_required_iso_date(:end_date)
    )
    render json: { id: entry.id, title: entry.title, start_date: entry.start_date,
                   end_date: entry.end_date, content: entry.diary_content.to_s }
  rescue Date::Error
    render json: { error: "dates must be ISO dates" }, status: :unprocessable_entity
  rescue ActiveRecord::RecordNotFound
    render json: { id: nil }, status: :not_found
  end

  private

  def parse_iso_date(value)
    return if value.nil? || value == ""

    raise Date::Error unless value.is_a?(String)

    Date.iso8601(value)
  end

  def parse_required_iso_date(name)
    value = params[name]
    raise ActionController::ParameterMissing, name if value.nil? || value == ""

    parse_iso_date(value)
  end
end

module DiaryHelper
  def quarter_start(date)
    date.beginning_of_quarter
  end

  def range_for_iso_week(date)
    (date - date.cwday + 1)..(date - date.cwday + 7)
  end

  def range_for_month(date)
    date.beginning_of_month..date.end_of_month
  end
end

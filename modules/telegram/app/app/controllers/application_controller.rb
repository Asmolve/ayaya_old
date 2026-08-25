class ApplicationController < ActionController::Base
  protect_from_forgery with: :exception
  allow_browser versions: :modern

  private

  def reject_cross_site_mutation
    return unless request.post? || request.patch? || request.put? || request.delete?
    return head :forbidden if request.headers["Sec-Fetch-Site"] == "cross-site"

    origin = request.headers["Origin"]
    return if origin.blank? || origin == request.base_url

    head :forbidden
  end
end

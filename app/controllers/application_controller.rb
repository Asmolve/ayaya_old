class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  def authenticate_admin_user!
    authenticate_user!
    raise ActionController::RoutingError, "Not Found" unless current_user.admin?
  end
end

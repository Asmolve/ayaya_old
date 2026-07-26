class HomeController < ApplicationController
  before_action :authenticate_user!

  def index
    @modules = RegisteredModule.order(:name).select { |mod| mod.accessible_by?(current_user) }
  end
end

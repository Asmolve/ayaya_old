class FolderProposalsController < ApplicationController
  include AyayaIdentity

  def accept
    proposal = current_module_user.telegram_account.folder_proposals.find(params[:id])
    proposal.accept!
    redirect_to telegram_root_path, notice: "#{proposal.title} is ready to be included in the next dry-run."
  rescue ActiveRecord::RecordNotFound
    head :not_found
  end
end

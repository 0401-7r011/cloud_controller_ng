require 'messages/deployments_list_message'
require 'messages/deployment_create_message'
require 'fetchers/deployment_list_fetcher'
require 'presenters/v3/deployment_presenter'
require 'actions/deployment_create'
require 'actions/deployment_cancel'

class DeploymentsController < ApplicationController
  def index
    message = DeploymentsListMessage.from_params(query_params)
    invalid_param!(message.errors.full_messages) unless message.valid?
    deployment_list_fetcher = DeploymentListFetcher.new(message: message)
    dataset = if permission_queryer.can_read_globally?
                deployment_list_fetcher.fetch_all
              else
                deployment_list_fetcher.fetch_for_spaces(space_guids: permission_queryer.readable_space_guids)
              end

    render status: :ok, json: Presenters::V3::PaginatedListPresenter.new(
      presenter: Presenters::V3::DeploymentPresenter,
      paginated_result: SequelPaginator.new.get_page(dataset, message.try(:pagination_options)),
      path: '/v3/deployments',
      message: message
    )
  end

  def create
    deployments_not_enabled! if Config.config.get(:temporary_disable_deployments)

    message = DeploymentCreateMessage.new(hashed_params[:body])

    app = AppModel.find(guid: message.app_guid)
    unprocessable!('Unable to use app. Ensure that the app exists and you have access to it.') unless app && permission_queryer.can_write_to_space?(app.space.guid)
    unprocessable!('Cannot create a deployment for a STOPPED app.') if app.stopped?
    unprocessable!('Cannot create deployment from a revision for an app without revisions enabled') if message.revision_guid && !app.revisions_enabled

    # push into message
    unprocessable!("Cannot set both fields 'droplet' and 'revision'") if message.revision_guid && message.droplet_guid

    droplet = choose_droplet(app, message.droplet_guid, message.revision_guid) # push into action

    begin
      deployment = DeploymentCreate.create(app: app, droplet: droplet, user_audit_info: user_audit_info, message: message)
      logger.info("Created deployment #{deployment.guid} for app #{app.guid}")
    rescue DeploymentCreate::SetCurrentDropletError => e
      unprocessable!(e.message)
    end

    render status: :created, json: Presenters::V3::DeploymentPresenter.new(deployment)
  end

  def show
    deployment = DeploymentModel.find(guid: hashed_params[:guid])

    resource_not_found!(:deployment) unless deployment &&
      permission_queryer.can_read_from_space?(deployment.app.space.guid, deployment.app.space.organization.guid)

    render status: :ok, json: Presenters::V3::DeploymentPresenter.new(deployment)
  end

  def cancel
    deployment = DeploymentModel.find(guid: hashed_params[:guid])

    resource_not_found!(:deployment) unless deployment && permission_queryer.can_write_to_space?(deployment.app.space_guid)

    begin
      DeploymentCancel.cancel(deployment: deployment, user_audit_info: user_audit_info)
      logger.info("Canceled deployment #{deployment.guid} for app #{deployment.app_guid}")
    rescue DeploymentCancel::Error => e
      unprocessable!(e.message)
    end

    head :ok
  end

  private

  def choose_droplet(app, droplet_guid, revision_guid)
    if droplet_guid
      droplet = DropletModel.find(guid: droplet_guid)
    elsif revision_guid
      revision = RevisionModel.find(guid: revision_guid)
      unprocessable!('The revision does not exist') unless revision
      droplet = DropletModel.find(guid: revision.droplet_guid)
      unprocessable!('Invalid revision. Please specify a revision with a valid droplet in the request.') unless droplet
    else
      droplet = app.droplet
      unprocessable!('Invalid droplet. Please specify a droplet in the request or set a current droplet for the app.') unless droplet
    end
    droplet
  end

  def deployments_not_enabled!
    raise CloudController::Errors::ApiError.new_from_details('DeploymentsDisabled')
  end
end

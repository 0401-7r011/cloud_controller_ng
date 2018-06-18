require 'fetchers/app_fetcher'
require 'fetchers/task_list_fetcher'
require 'fetchers/task_create_fetcher'
require 'fetchers/task_fetcher'
require 'actions/task_create'
require 'actions/task_cancel'
require 'messages/task_create_message'
require 'messages/tasks_list_message'
require 'presenters/v3/task_presenter'
require 'controllers/v3/mixins/app_sub_resource'

class TasksController < ApplicationController
  include AppSubResource

  def index
    message = TasksListMessage.from_params(subresource_query_params)
    invalid_param!(message.errors.full_messages) unless message.valid?

    show_secrets = false

    if app_nested?
      app, dataset = TaskListFetcher.new.fetch_for_app(message: message)
      app_not_found! unless app && permission_queryer.can_read_from_space?(app.space.guid, app.organization.guid)
      show_secrets = permission_queryer.can_read_secrets_in_space?(app.space.guid, app.organization.guid)
    else
      dataset = if permission_queryer.can_read_globally?
                  TaskListFetcher.new.fetch_all(message: message)
                else
                  TaskListFetcher.new.fetch_for_spaces(message: message, space_guids: readable_space_guids)
                end
    end

    render :ok, json: Presenters::V3::PaginatedListPresenter.new(
      presenter: Presenters::V3::TaskPresenter,
      paginated_result: SequelPaginator.new.get_page(dataset, message.try(:pagination_options)),
      path: base_url(resource: 'tasks'),
      message: message,
      show_secrets: show_secrets
    )
  end

  def create
    FeatureFlag.raise_unless_enabled!(:task_creation)

    message = TaskCreateMessage.new(params[:body])
    unprocessable!(message.errors.full_messages) unless message.valid?

    app, space, org, droplet = TaskCreateFetcher.new.fetch(app_guid: params[:app_guid], droplet_guid: message.droplet_guid)

    app_not_found! unless app && permission_queryer.can_read_from_space?(space.guid, org.guid)
    unauthorized! unless can_write?(space.guid)
    droplet_not_found! if message.requested?(:droplet_guid) && droplet.nil?

    task = TaskCreate.new(configuration).create(app, message, user_audit_info, droplet: droplet)

    render status: :accepted, json: Presenters::V3::TaskPresenter.new(task)
  rescue TaskCreate::InvalidTask, TaskCreate::TaskCreateError => e
    unprocessable!(e)
  end

  def cancel
    task, space, org = TaskFetcher.new.fetch(task_guid: params[:task_guid])
    task_not_found! unless task && permission_queryer.can_read_from_space?(space.guid, org.guid)

    unauthorized! unless can_write?(space.guid)
    TaskCancel.new(configuration).cancel(task: task, user_audit_info: user_audit_info)

    render status: :accepted, json: Presenters::V3::TaskPresenter.new(task.reload)
  rescue TaskCancel::InvalidCancel => e
    unprocessable!(e)
  end

  def show
    task, space, org = TaskFetcher.new.fetch(task_guid: params[:task_guid])
    task_not_found! unless task && permission_queryer.can_read_from_space?(space.guid, org.guid)

    render status: :ok, json: Presenters::V3::TaskPresenter.new(task, show_secrets: permission_queryer.can_read_secrets_in_space?(space.guid, org.guid))
  end

  private

  def task_not_found!
    resource_not_found!(:task)
  end

  def droplet_not_found!
    resource_not_found!(:droplet)
  end
end

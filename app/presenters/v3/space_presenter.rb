require 'presenters/v3/base_presenter'

module CloudController::Presenters::V3
  class SpacePresenter < BasePresenter
    def to_hash
      {
        guid: space.guid,
        created_at: space.created_at,
        updated_at: space.updated_at,
        name: space.name,
        relationships: {
          organization: {
            data: {
              guid: space.organization_guid
            }
          }
        },
        links: build_links,
      }
    end

    private

    def space
      @resource
    end

    def build_links
      url_builder = CloudController::Presenters::ApiUrlBuilder.new

      {
        self: {
          href: url_builder.build_url(path: "/v3/spaces/#{space.guid}")
        },
        organization: {
          href: url_builder.build_url(path: "/v3/organizations/#{space.organization_guid}")
        },
      }
    end
  end
end

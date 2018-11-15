require 'spec_helper'

RSpec.describe 'App Features' do
  describe 'GET /v3' do
    it 'returns a list of links to resources available on the v3 API' do
      get '/v3'
      expect(last_response.status).to eq(200)
      expect(parsed_response).to be_a_response_like({
        'links' => {
          'self' => {
            'href' => "#{link_prefix}/v3"
          },
          'apps' => {
            'href' => "#{link_prefix}/v3/apps"
          },
          'builds' => {
            'href' => "#{link_prefix}/v3/builds"
          },
          'deployments' => {
            'href' => "#{link_prefix}/v3/deployments",
            'experimental' => true
          },
          'droplets' => {
            'href' => "#{link_prefix}/v3/droplets"
          },
          'isolation_segments' => {
            'href' => "#{link_prefix}/v3/isolation_segments"
          },
          'organizations' => {
            'href' => "#{link_prefix}/v3/organizations"
          },
          'packages' => {
            'href' => "#{link_prefix}/v3/packages"
          },
          'processes' => {
            'href' => "#{link_prefix}/v3/processes"
          },
          'service_instances' => {
            'href' => "#{link_prefix}/v3/service_instances"
          },
          'spaces' => {
            'href' => "#{link_prefix}/v3/spaces"
          },
          'stacks' => {
            'href' => "#{link_prefix}/v3/stacks",
            'experimental' => true
          },
          'tasks' => {
            'href' => "#{link_prefix}/v3/tasks"
          }
        }
      })
    end
  end
end

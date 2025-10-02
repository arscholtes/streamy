# config/initializers/integration_routes.rb
# Route macro for generating standard integration routes
# Usage in routes.rb: integration_routes :steam

module IntegrationRoutes
  # Generate standard integration routes
  # @param name [Symbol] Integration name (e.g., :steam, :discord)
  # @param options [Hash] Additional options
  def integration_routes(name, options = {})
    controller_name = options[:controller] || name.to_s

    scope name do
      # OAuth flow
      get 'connect', to: "#{controller_name}#connect", as: :"#{name}_connect"
      get 'callback', to: "#{controller_name}#callback", as: :"#{name}_callback"

      # Management
      delete 'disconnect', to: "#{controller_name}#disconnect", as: :"#{name}_disconnect"
      post 'sync', to: "#{controller_name}#sync", as: :"#{name}_sync"

      # Privacy settings
      get 'privacy-settings', to: "#{controller_name}#privacy_settings", as: :"#{name}_privacy_settings"
      post 'privacy-settings', to: "#{controller_name}#update_privacy_settings"

      # Additional routes if specified
      if options[:additional_routes].respond_to?(:call)
        instance_eval(&options[:additional_routes])
      end
    end
  end
end

# Extend ActionDispatch::Routing::Mapper with our macro
ActionDispatch::Routing::Mapper.include IntegrationRoutes

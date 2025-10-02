# app/components/integration_privacy_form_component.rb
# ViewComponent for rendering privacy settings forms
# Generates checkboxes based on a schema definition

class IntegrationPrivacyFormComponent < ViewComponent::Base
  attr_reader :integration, :privacy_setting, :settings_schema

  # @param integration [IntegrationAccount] Integration account (SteamAccount, DiscordAccount, etc.)
  # @param settings_schema [Hash] Schema defining available privacy settings
  def initialize(integration:, settings_schema:)
    @integration = integration
    @privacy_setting = integration.integration_privacy_setting
    @settings_schema = settings_schema
  end

  # Render the privacy form
  def call
    content_tag :div, class: 'integration-privacy-form' do
      form_with(
        model: privacy_setting,
        url: update_path,
        method: :post,
        local: true
      ) do |f|
        safe_join([
          render_header,
          render_setting_groups(f),
          render_submit_button(f)
        ])
      end
    end
  end

  private

  def render_header
    content_tag :div, class: 'mb-4' do
      safe_join([
        content_tag(:h3, "#{integration_name} Privacy Settings", class: 'mb-2'),
        content_tag(:p, 'Choose what information to display on your profile:', class: 'text-muted')
      ])
    end
  end

  def render_setting_groups(form)
    settings_schema.map do |group_name, settings|
      content_tag :div, class: 'mb-4' do
        safe_join([
          render_group_header(group_name),
          render_settings(form, settings)
        ])
      end
    end.reduce(:+)
  end

  def render_group_header(group_name)
    content_tag :h5, group_name.to_s.titleize, class: 'mb-3'
  end

  def render_settings(form, settings)
    content_tag :div, class: 'ms-3' do
      settings.map do |setting|
        render_checkbox(form, setting)
      end.reduce(:+)
    end
  end

  def render_checkbox(form, setting)
    key = setting[:key]
    label = setting[:label]
    checked = privacy_setting.show?(key) || setting[:default]

    content_tag :div, class: 'form-check mb-2' do
      safe_join([
        check_box_tag(
          "privacy_settings[#{key}]",
          true,
          checked,
          class: 'form-check-input',
          id: "privacy_#{key}"
        ),
        label_tag(
          "privacy_#{key}",
          label,
          class: 'form-check-label'
        )
      ])
    end
  end

  def render_submit_button(form)
    content_tag :div, class: 'mt-4' do
      safe_join([
        form.submit('Save Privacy Settings', class: 'btn btn-primary'),
        ' ',
        link_to('Cancel', settings_path, class: 'btn btn-secondary')
      ])
    end
  end

  def integration_name
    integration.class.name.demodulize.gsub('Account', '')
  end

  def update_path
    # Try to use named route, fallback to settings
    send("integrations_#{integration_name.underscore}_privacy_settings_path")
  rescue
    settings_path
  end

  def settings_path
    helpers.settings_path
  end
end

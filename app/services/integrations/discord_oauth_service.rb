# app/services/integrations/discord_oauth_service.rb
# Discord OAuth 2.0 authentication service
module Integrations
  class DiscordOauthService < BaseOauthService
    def initialize
      super('discord')
      @client_id = ENV['DISCORD_CLIENT_ID']
      @client_secret = ENV['DISCORD_CLIENT_SECRET']
      @redirect_uri = ENV['DISCORD_REDIRECT_URI'] || "#{ENV['APP_URL']}/integrations/discord/callback"
    end

    def authorize_url(scopes: ['identify', 'email', 'guilds'], state: nil)
      params = {
        client_id: @client_id,
        redirect_uri: @redirect_uri,
        response_type: 'code',
        scope: scopes.join(' ')
      }
      params[:state] = state if state.present?
      "#{authorize_endpoint}?#{URI.encode_www_form(params)}"
    end

    def exchange_code(code)
      response = HTTParty.post(token_endpoint, body: {
        client_id: @client_id,
        client_secret: @client_secret,
        grant_type: 'authorization_code',
        code: code,
        redirect_uri: @redirect_uri
      }, headers: { 'Content-Type' => 'application/x-www-form-urlencoded' })

      handle_token_response(response)
    end

    def refresh_token(refresh_token)
      response = HTTParty.post(token_endpoint, body: {
        client_id: @client_id,
        client_secret: @client_secret,
        grant_type: 'refresh_token',
        refresh_token: refresh_token
      }, headers: { 'Content-Type' => 'application/x-www-form-urlencoded' })

      handle_token_response(response)
    end

    def fetch_user_data(access_token)
      response = HTTParty.get('https://discord.com/api/v10/users/@me', headers: {
        'Authorization' => "Bearer #{access_token}"
      })

      if response.code == 200
        user = response.parsed_response
        {
          discord_id: user['id'],
          username: user['username'],
          discriminator: user['discriminator'],
          avatar_url: user['avatar'] ? "https://cdn.discordapp.com/avatars/#{user['id']}/#{user['avatar']}.png" : nil,
          email: user['email'],
          verified: user['verified'],
          locale: user['locale']
        }
      else
        raise Integrations::APIError, 'Failed to fetch Discord user data'
      end
    end

    private

    def authorize_endpoint
      'https://discord.com/api/oauth2/authorize'
    end

    def token_endpoint
      'https://discord.com/api/v10/oauth2/token'
    end

    def handle_token_response(response)
      if response.code == 200
        data = response.parsed_response
        {
          access_token: data['access_token'],
          refresh_token: data['refresh_token'],
          expires_at: Time.current + data['expires_in'].seconds
        }
      else
        raise Integrations::AuthenticationError, "Discord OAuth failed: #{response.body}"
      end
    end
  end
end

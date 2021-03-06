#!/usr/bin/env ruby

#
# Forked from https://github.com/sensu/sensu-community-plugins/
#
# Copyright 2014 Dan Shultz and contributors.
#
# Released under the same terms as Sensu (the MIT license); see LICENSE
# for details.
#
# In order to use this plugin, you must first configure an incoming webhook
# integration in slack. You can create the required webhook by visiting
# https://{your team}.slack.com/services/new/incoming-webhook
#
# After you configure your webhook, you'll need the webhook URL from the integration.

require 'sensu-handler'
require 'json'
require 'time'

class Slack < Sensu::Handler
  option :json_config,
         description: 'Configuration name',
         short: '-j JSONCONFIG',
         long: '--json JSONCONFIG',
         default: 'slack'

  def admin_url
    get_setting('admin_url') || 'http://localhost:8080/#/events'
  end

  def admin_text
    get_setting('admin_text') || 'Uchiwa'
  end

  def show_command
    get_setting('show_command')
  end

  def show_address
    get_setting('show_address')
  end

  def show_admin_link
    get_setting('show_admin_link')
  end

  def convert_time(time)
    format = get_setting('time_format') || "%a %b %e @ %I:%M%P"
    time = Time.parse(time)
    time.strftime(format)
  end

  def show_occurrences
    get_setting('show_occurrences')
  end

  def show_subscriptions
    get_setting('show_subscriptions')
  end

  def show_timestamp
    get_setting('show_timestamp')
  end

  def icon_url
    get_setting('icon_url') || 'http://sensuapp.org/img/sensu_logo_large-c92d73db.png'
  end

  def custom_values
    get_setting('custom_values') || false
  end

  def slack_webhook_url
    get_setting('webhook_url')
  end

  def slack_channel
    @event['client']['slack_channel'] || @event['check']['slack_channel'] || get_setting('channel')
  end

  def slack_proxy_addr
    get_setting('proxy_addr')
  end

  def slack_proxy_port
    get_setting('proxy_port')
  end

  def slack_bot_name
    get_setting('bot_name')
  end

  def markdown_enabled
    get_setting('markdown_enabled') || true
  end

  def incident_key
    @event['client']['name'] + '/' + @event['check']['name']
  end

  def get_setting(name)
    settings[config[:json_config]][name]
  end

  def tick(string)
    '```' + string + '```'
  end

  def check_status
    @event['check']['status']
  end

  def action_to_string
    @event['action'].eql?('resolve') ? 'RESOLVED' : 'ALERT'
  end

  def status
    status = {
      0 => 'OK',
      1 => 'WARNING',
      2 => 'CRITICAL',
      3 => 'UNKNOWN'
    }
    status.fetch(check_status.to_i)
  end

  def color
    color = {
      0 => '#36a64f',
      1 => '#FFCC00',
      2 => '#FF0000',
      3 => '#6600CC'
    }
    color.fetch(check_status.to_i)
  end

  def get_custom_val(key)
    key.to_s.split('.').inject(@event['check']) { |h, k| h[k] }
  end

  def message
    message = {
      icon_url: icon_url,
      parse: 'none',
      attachments: [
        color: color,
        fallback: incident_key + ' is ' + status,
        fields: [
          {
            title: action_to_string,
            value: incident_key + ' is ' + status
          },
          {
            title: 'Details',
            value: tick(@event['check']['output'])
          }
        ]
      ]
    }

    if show_command
      message[:attachments][0][:fields].concat [
        {
          title: 'Command',
          value: tick(@event['check']['command'])
        }
      ]
    end

    if show_address
      message[:attachments][0][:fields].concat [
        {
          title: 'Address',
          value: @event['client']['address'],
          short: true
        }
      ]
    end

    message
  end

  def payload(channel)
    message.tap do |payload|
      payload[:channel] = channel
      payload[:username] = slack_bot_name if slack_bot_name
      payload[:attachments][0][:mrkdwn_in] = %w(fields text) if markdown_enabled

      if show_timestamp
        payload[:attachments][0][:fields].concat [
          {
            title: 'Timestamp',
            value: convert_time(Time.at(@event['check']['issued']).to_s),
            short: true
          }
        ]
      end

      if show_occurrences
        payload[:attachments][0][:fields].concat [
          {
            title: 'Occurrences',
            value: @event['occurrences'],
            short: true
          }
        ]
      end

      if show_subscriptions
        payload[:attachments][0][:fields].concat [
          {
            title: 'Subscriptions',
            value: @event['client']['subscriptions'].join(', '),
            short: true
          }
        ]
      end

      if custom_values
        custom_values.each do |params|
          payload[:attachments][0][:fields].concat [
            {
              title: params['title'] || params['key'],
              value: get_custom_val(params['key']),
              short: params['short'] || false
            }
          ]
        end
      end

      if show_admin_link
        payload[:attachments][0][:fields].concat [
          {
            title: '',
            value: "[ <#{admin_url}}|#{admin_text}> ]"
          }
        ]
      end
    end
  end

  def handle
    uri = URI(slack_webhook_url)

    if (defined?(slack_proxy_addr)).nil?
      http = Net::HTTP.new(uri.host, uri.port)
    else
      http = Net::HTTP::Proxy(slack_proxy_addr, slack_proxy_port).new(uri.host, uri.port)
    end

    http.use_ssl = true

    req = Net::HTTP::Post.new("#{uri.path}?#{uri.query}")

    channels = Array(slack_channel)
    channels.each do |channel|
      puts "slack notification to #{channel}"
      req.body = payload(channel).to_json
      response = http.request(req)
      verify_response(response)
    end
  end

  def verify_response(response)
    case response
    when Net::HTTPSuccess
      true
    else
      fail response.error!
    end
  end
end

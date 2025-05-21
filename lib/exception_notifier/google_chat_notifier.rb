# frozen_string_literal: true

require 'httparty'

module ExceptionNotifier
  class GoogleChatNotifier < BaseNotifier
    def call(exception, opts = {})
      options = base_options.merge(opts)
      formatter = Formatter.new(exception, options)

      HTTParty.post(
        options[:webhook_url],
        body: { text: body(exception, formatter, opts) }.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )
    end

    private

    def body(exception, formatter, options)
      text = [
        "\nApplication: *#{formatter.app_name}*",
        formatter.subtitle,
        '',
        formatter.title,
        "*#{exception.message.tr('`', "'")}*"
      ]

      if (request = formatter.request_message.presence)
        text << ''
        text << '*Request:*'
        text << request
      end

      if (backtrace = formatter.backtrace_message.presence)
        text << ''
        text << '*Backtrace:*'
        text << backtrace
      end

      _text, data = information_from_options(exception.class, options)
      text << ''
      text << '*Data:*'
      text << '```'
      text << data
      text << '```'
      text.compact.join("\n")
    end

    def information_from_options(exception_class, options)
      errors_count = options[:accumulated_errors_count].to_i

      measure_word = if errors_count > 1
                       errors_count
                     else
                       exception_class.to_s =~ /^[aeiou]/i ? 'An' : 'A'
                     end

      exception_name = "*#{measure_word}* `#{exception_class}`"
      env = options[:env]

      if env.nil?
        data = options[:data] || {}
        text = "#{exception_name} *occured in background*\n"
      else
        data = (env['exception_notifier.exception_data'] || {}).merge(options[:data] || {})

        kontroller = env['action_controller.instance']
        request = "#{env['REQUEST_METHOD']} <#{env['REQUEST_URI']}>"
        text = "#{exception_name} *occurred while* `#{request}`"
        text += " *was processed by* `#{kontroller.controller_name}##{kontroller.action_name}`" if kontroller
        text += "\n"
      end

      [text, data]
    end

  end
end

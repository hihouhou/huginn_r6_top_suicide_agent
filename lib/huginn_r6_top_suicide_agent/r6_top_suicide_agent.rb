module Agents
  class R6TopSuicideAgent < Agent
    include FormConfigurable
    can_dry_run!
    default_schedule 'every_1d'
    description do
      <<-MD

      This agent fetch stats about user's suicides and creates a top score for R6 Games

      `debug` is used for verbose mode.
      MD
    end

    event_description <<-MD
      Events look like this:

          {
            "type": "suicide",
            "game": "r6",
            "classement": {
              "XXXXXXXXXX": "41",
              "XXXXXX": "36",
              "XXXXXXX": "20",
              "XXXXXXXX": "18",
              "XXXXXXXXXXXXXX": "18",
              "XXXXXXXX": "17",
              "XXXXXXXX": "16",
              "XXXXXXXXXX": "12",
              "XXXXXXX": "9",
              "XXXXXXXX": "7"
            }
          }
    MD

    def default_options
      {
        'users' => 'user1 user2 user3 user4',
        'debug' => 'false',
        'changes_only' => 'true'
      }
    end
    form_configurable :users, type: :string
    form_configurable :debug, type: :boolean
    form_configurable :changes_only, type: :boolean

    def validate_options
      unless options['users'].present?
        errors.add(:base, "users is a required field")
      end

      if options.has_key?('changes_only') && boolify(options['changes_only']).nil?
        errors.add(:base, "if provided, changes_only must be true or false")
      end

      if options.has_key?('debug') && boolify(options['debug']).nil?
        errors.add(:base, "if provided, debug must be true or false")
      end
    end

    def working?
      event_created_within?(options['expected_receive_period_in_days']) && !recent_error_logs?
    end

    def check
      top_suicide interpolated['users']
    end

    private

    def top_suicide(users)
      top = []
      payload = { "type" => "suicide", "game" => "r6", "classement" => {} }
      log "top_suicide launched"
      users_array = users.split(" ")
      users_array.each do |item, index|
          json = fetch(item)
          username  = json['data']['username']
          nbr_suicide = json['data']['stats'][0]['general']['suicides']
          if interpolated['debug'] == 'true'
            log "#{username} #{nbr_suicide}"
          end
          top << { :username => username, :nbr => nbr_suicide }
      end
      top = top.sort_by { |hsh| hsh[:nbr] }.reverse
      top.each do |top|
        if interpolated['debug'] == 'true'
          log "#{top[:username]}: #{top[:nbr]}"
        end
        payload.deep_merge!({"classement" => { "#{top[:username]}" => "#{top[:nbr]}" }})
      end
      log "conversion done"
      if interpolated['changes_only'] == 'true'
        if payload.to_s != memory['top_suicide']
          memory['top_suicide'] = payload.to_s
          create_event payload: payload.to_json
        end
      else
        create_event payload: payload
        if payload.to_s != memory['top_suicide']
          memory['top_suicide'] = payload
        end
      end
    end

    def fetch(user)
        url = 'https://r6stats.com/api/stats/' + user
        uri = URI(url)
        response = Net::HTTP.get(uri)
        if interpolated['debug'] == 'true'
          log "request status for #{user} : #{response}"
        end
        obj = JSON.parse(response)
    end
  end
end

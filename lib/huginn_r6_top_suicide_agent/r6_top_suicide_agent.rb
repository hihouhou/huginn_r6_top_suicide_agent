module Agents
  class R6TopSuicideAgent < Agent
    can_dry_run!
    default_schedule '1d'

    description <<-MD
      This agent fetch stats about user's suicides and creates a top score for R6 Games
    MD

    def default_options
      {
        'users' => ["a", "b", "c"],
        'changes_only' => 'true'
      }
    end

    def validate_options
      unless options['users'].present?
        errors.add(:base, "users is a required field")
      end

      if options.has_key?('changes_only') && boolify(options['changes_only']).nil?
        errors.add(:base, "if provided, changes_only must be true or false")
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
      payload = { "type" => "suicide", "classement" => {} }
      log "top_suicide launched"

      users.each do |item, index|
          json = fetch(item)
          username  = json['data']['username']
          nbr_suicide = json['data']['stats'][0]['general']['suicides']
#          log "#{username} #{nbr_suicide}"
          top << { :username => username, :nbr => nbr_suicide }
      end
      top = top.sort_by { |hsh| hsh[:nbr] }.reverse
      top.each do |top|
        log "#{top[:username]}: #{top[:nbr]}"
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
        obj = JSON.parse(response)
#        log "request status for #{user} : #{response.code}"
    end
  end
end

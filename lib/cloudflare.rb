require 'net/http'
require 'json'

# All public functions return (Hash) result: success or error with message and error code
#
# For more information please visit:
# - http://www.cloudflare.com/wiki/Client_Interface_API
# - http://www.cloudflare.com/docs/host-api.html

class CloudFlare

  # URL for Client and Host API

  URL_API = {
    client: 'https://www.cloudflare.com/api_json.html',
    host: 'https://api.cloudflare.com/host-gw.html'
  }

  TIMEOUT = 5 # Default is 5 seconds

  # @param api_key User or Host API key.
  # @param email It is for a Client API.
  def initialize(api_key, email = nil)

    @params = Hash.new

    if email.nil?
      @params[:api_key] = api_key
    else
      @params[:api_key] = api_key
      @params[:email] = email
    end

  end

  # CLIENT

  # This function can be used to get currently settings of values such as the security level. 
  #
  # More: https://www.cloudflare.com/wiki/Client_Interface_API#FUNCTION:_Current_Stats_and_Settings
  #
  # @param zone The zone you'd like to run CNAMES through CloudFlare for, e.g. +example.com+.
  # @param interval The interval parameter defines what period you want to look at. Default is 30 days, but 1 day delayed. Pro only intervals are 100, 110, and 120.
  #
  # @return (Hash) the current stats and settings for a particular website 

  def stats(zone, interval = 20)
    send_req({a: :stats, z: zone, interval: interval})
  end

  # This function sets the Basic Security Level to HELP I'M UNDER ATTACK / HIGH / MEDIUM / LOW / ESSENTIALLY OFF.
  #
  # @param zone The zone you'd like to run CNAMES through CloudFlare for, e.g. +example.com+.
  # @param value Must be one of low|med|high|help|eoff.

  def set_security_lvl(zone, value)
    send_req({a: :sec_lvl, z: zone, v: value})
  end

  # This function sets the Caching Level to Aggressive or Basic.
  #
  # @param zone The zone you'd like to run CNAMES through CloudFlare for, e.g. +example.com+.
  # @param value Must be one of agg|basic.

  def set_cache_lvl(zone, value)
    send_req({a: :cache_lvl, z: zone, v: value})   
  end

  # This function allows you to toggle Development Mode on or off for a particular domain. When Development Mode is on the cache is bypassed. Development mode remains on for 3 hours or until when it is toggled back off.
  #
  # @note Development mode will expire on "expires_on" (3 hours from when it is toggled on). Development mode can be toggled off immediately by setting +value+ to 0.
  #
  # @param zone The zone you'd like to run CNAMES through CloudFlare for, e.g. +example.com+
  # @param value May be set to true (on) or false (off).
  # @return (Hash) expires_on

  def devmode(zone, value)
    send_req({a: :devmode, z: zone, v: value == true ? 1 : 0})
  end

  # This function will purge CloudFlare of any cached files. It may take up to 48 hours for the cache to rebuild and optimum performance to be achieved so this function should be used sparingly. 
  #
  # @param zone The zone you'd like to run CNAMES through CloudFlare for, e.g. +example.com+.
  # @return (Hash) fpurge_ts, cooldown
  # @return *fpurge_ts* - Time at which cache was purged.
  # @return *cooldown* - Number of seconds before the next time this call is allowed again.

  def purge_cache(zone)
    send_req({a: :fpurge_ts, z: zone, v: 1})    
  end

  # This function will purge a single file from CloudFlare's cache.
  #
  # @param zone The zone you'd like to run CNAMES through CloudFlare for, e.g. +example.com+.
  # @param file_url The full URL of the file that needs to be purged from Cloudflare's cache. Keep in mind, that if an HTTP and an HTTPS version of the file exists, then both versions will need to be purged independently.
  # @return *result* - string containing "success" if purge is successful

  def purge_zone_file(zone, file_url)
    send_req({a: :zone_file_purge, z: zone, url: file_url})
  end

  # This function checks whether one or more websites/domains are active under an account and return the zone ids (zids) for these.
  #
  # @param zones Zones, eg. +example.com+, +exampletwo.com+
  # @return (Hash) Map of passed in zones. If a zone if hosted on CloudFlare and the email + tkn combination is correct for the given zone, the value for the zone will be its zone id (use this for other API calls). Otherwise 0.

  def zone_check(*zones)
    send_req({a: :zone_check, zones: zones.kind_of?(Array) ? zones.join(',') : zones})
  end

  # This function pulls recent IPs hitting your site.
  #
  # @param zoneid Id of the zone you would like to check.
  # @param hours Number of hours to go back. Default is 24, max is 48.
  # @param class Restrict the result set to a given class. Currently r|s|t, for regular, crawler, threat resp.
  # @param geo Add to add longitude and latitude information to the response. 0,0 means no data.
  # @return (Hash) A list of IP addresses which hit your site classified by type.

  def zone_ips(domain, classification, hours = 24, geo = true)
    send_req({a: :zone_ips, z: domain, hours: hours, class: classification, geo: geo == true ? 1 : 0})  
  end

  # This functions updates the snapshot of your site for CloudFlare's challenge page.
  #
  # @note Yhis call is rate limited to once per zone per day. Also the new image may take up to 1 hour to appear.
  # 
  # @param zoneid Id of the zone you would like to check.

  def update_image(zoneid)
    send_req({a: :zone_grab, zid: zoneid})
  end

  # This function adds an IP address to your white lists.
  #
  # @param address The address you wish to set a rule for.

  def whitelist(address)
    send_req({a: :wl, key: address})
  end

  # This function adds an IP address to your black lists.
  #
  # @param address The address you wish to set a rule for.

  def blacklist(address)  
    send_req({a: :ban, key: address})
  end

  # This function creates a new DNS record for your site. This can be either a CNAME or A record.
  #
  # @param zone The zone you'd like to run CNAMES through CloudFlare for, e.g. +example.com+.
  # @param type Type of record - CNAME or A.
  # @param content The value of the cname or IP address (the destination).
  # @param name The name of the record you wish to create.
  # @param mode False or true. false means CloudFlare is off (grey cloud) for the new zone, while true means a happy orange cloud.
  # @param ttl 1 or int. 1 means 'automatic', otherwise, value must be in between 120 and 4,294,967,295 seconds.

  def add_rec(zone, type, content, name, mode, ttl)
    send_req({a: :rec_new, z: zone, type: type, content: content, name: name, ttl: ttl, service_mode: mode == true ? 1 : 0})
  end

  # This function deletes a DNS record.
  #
  # @note All records of the given name will be deleted. For this reason, you must pass in the full DNS name of the record you wish to remove. For +example+, +sub.foo.com+, as opposed to just sub.
  #
  # @param zone The target domain
  # @param id DNS Record ID.

  def del_rec(zone, id)
    send_req({a: :rec_delete, z: zone, id: id})
  end

  # This function purges the preloader's cache.
  #
  # @note Can take up to an hour for this to take effect.
  #
  # @param ip The value of the IP address.

  def pre_purge(ip)
    send_req({a: :pre_purge, zone_name: ip})
  end

  # This function updates a DNS record for your site. This needs to be an A record.
  #
  # @param zone The zone you'd like to run CNAMES through CloudFlare for, e.g. +example.com+.
  # @param type Type of record - CNAME or A.
  # @param id DNS Record ID.
  # @param content The value of the cname or IP address (the destination).
  # @param name The name of the record you wish to create.
  # @param mode False or true. false means CloudFlare is off (grey cloud) for the new zone, while true means a happy orange cloud.
  # @param ttl 1 or int. 1 means 'automatic', otherwise, value must be in between 120 and 4,294,967,295 seconds.

  def update_rec(zone, type, id, content, name, mode, ttl)
    send_req({a: :rec_edit, z: zone, type: type, id: id, content: content, name: name, ttl: ttl, service_mode: mode == true ? 1 : 0})
  end

  # This function checks the threat score for a given IP.
  #
  # @note scores are logarithmically increasing, like the Richter scale.
  #
  # @param ip IP address to check.
  # @return The current threat score for a given IP.

  def threat_score(ip)
    send_req({a: :ip_lkup, ip: ip})
  end

  # This function toggles ipv6 support for a site.
  #
  # @param zone
  # @param value False disables, true enables support.

  def toggle_ipv6(zone, value)
    send_req({a: :ipv46, z: zone, v: value == true ? 1 : 0})
  end

  # HOST
  
  # This function creates a CloudFlare account mapped to your user.
  #
  # @param email The user's e-mail address for the new CloudFlare account.
  # @param pass The user's password for the new CloudFlare account. CloudFlare will never store this password in clear text.
  # @param login (optional) The user's username for the new CloudFlare account. CloudFlare will auto-generate one if it is not specified.
  # @param id Set a unique string identifying the User. This identifier will serve as an alias to the user's CloudFlare account. Typically you would set this value to the unique ID in your system (e.g., the internal customer number or username stored in your own system). This parameter can be used to retrieve a user_key when it is required. The unique_id must be an ASCII string with a maximum length of 100 characters.
  # @return (String) cloudflare_email
  # @return (String) user_key
  # @return (String) unique_id
  # @return (String) cloudflare_username

  def create_user(email, pass, login = nil, id = nil)
    send_req({act: :user_create, cloudflare_email: email, cloudflare_pass: pass, cloudflare_username: login, unique_id: id})
  end

  # This function setups a User's zone for CNAME hosting.
  #
  # @note This function replaces any previous setup for the particular zone_name. If are adding an additional subdomain to an account that already has some subdomains setup, you should specify all the subdomains not only the new subdomains.
  #
  # @param user_key The unique 32 hex character auth string, identifying the user's CloudFlare Account. Generated from a +create_user+ or +user_auth+.
  # @param zone The zone you'd like to run CNAMES through CloudFlare for, e.g. +example.com+.
  # @param resolve_to The CNAME that CloudFlare should ultimately resolve web connections to after they have been filtered, e.g. +resolve-to-cloudflare.example.com+. This record should ultimately resolve to the one or more IP addresses of the hosts for the particular website for all the specified subdomains.
  # @param subdomains A comma-separated string of subdomain(s) that CloudFlare should host, e.g. +www,blog,forums+ or +www.example.com,blog.example.com,forums.example.com+.
  # @return (String) zone_name
  # @return (String) resolving_to
  # @return (Hash) hosted_cnames
  # @return (Hash) forward_tos

  def add_zone(user_key, zone, resolve_to, subdomains)
    send_req({act: :zone_set, user_key: user_key, zone_name: zone, resolve_to: resolve_to, subdomains: subdomains.kind_of?(Array) ? zones.join(',') : subdomains})
  end

  # This function lookups a user's CloudFlare account information.
  #
  # @note If you use +unique_id+, +id+ must be +true+.
  #
  # *Example:*
  #
  #   cf = CloudFlare('your_host_key')
  #   cf.user_lookup('unique_id', true)
  #
  # @param email Lookup a user's account information or status by either +email+ or +unique_id+.
  # @return (String) user_key
  # @return (Boolean) user_exists
  # @return (Boolean) user_authed
  # @return (String) cloudflare_email
  # @return (String) unique_id
  # @return (Array) hosted_zones 

  def user_lookup(email, id = false)
    if id
      send_req({act: :user_lookup, unique_id: email})
    else
      send_req({act: :user_lookup, cloudflare_email: email})
    end
  end

  # This function authorizes access to a user's existing CloudFlare account.
  #
  # @param email the user's e-mail address for the new CloudFlare account.
  # @param pass the user's password for the new CloudFlare account. CloudFlare will never store this password in clear text.
  # @param unique_id (optional) set a unique string identifying the user. This identifier will serve as an alias to the user's CloudFlare account. Typically you would set this value to the unique ID in your system. This parameter can be used as an alias for other actions (e.g., it can substitute for the +email+ and +pass+ if you choose not to store those fields in your system).
  # @return (Hash) User's e-mail, key and unique id.

  def user_auth(email, pass, id = nil)
    send_req({act: :user_auth, cloudflare_email: email, cloudflare_pass: pass, unique_id: id})
  end

  # This function lookups a specific user's zone.
  #
  # @param user_key API user key
  # @param zone the zone you'd like to lookup, e.g. "example.com"
  # @return (String) zone_name
  # @return (Boolean) zones_exists
  # @return (Boolean) zone_hosted
  # @return (Hash) hosted_cnames
  # @return (Hash) hosted_cnames
  # @return (Hash) forward_tos

  def zone_lookup(user_key, zone)
    send_req({act: :zone_lookup, user_key: user_key, zone_name: zone}) 
  end

  # This function deletes a specific zone on behalf of a user.
  #
  # @param user_key API user key
  # @param zone The zone you'd like to lookup, e.g. +example.com+
  # @return (String) zone_name, 
  # @return (Boolean) zone_deleted

  def del_zone(user_key, zone)
    send_req({act: :zone_delee, user_key: user_key, zone_name: zone}) 
  end

  private 

  def send_req(params)

    if @params[:email]
      params[:tkn] = @params[:api_key]
      params[:u] = @params[:email]
      uri = URI(URL_API[:client])
    else
      params[:host_key] = @params[:api_key]
      uri = URI(URL_API[:host])
    end

    req = Net::HTTP::Post.new(uri.path)
    req.set_form_data(params)

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.read_timeout = TIMEOUT

    begin
      res = http.request(req)
      JSON.parse(res.body)
    rescue => e
      puts "#{e.class} #{e.message}"
    end

  end

end

require 'net/http'
require 'tmpdir'
require 'yaml'
require 'json'

module Puppet::Parser::Functions
  newfunction(:cloudfront_ips, :type => :rvalue, :doc => <<-'ENDHEREDOC') do |args|
    
    Returns a hash containing both IPv4 and IPv6 IP ranges used by Amazon
    CloudFront CDN. This is useful for crafting ACLs on webservers to block
    any requests attempting to bypass the CDN.

    For performance and reliability this function caches the results and only
    refreshes every 24 hours. If a refresh fails (eg network issue) it falls
    back to serving stale cache so there's no sudden change of configuration
    as long as the cache files remain on disk (generally in /tmp)

    ENDHEREDOC

    
    # URL for the IP range source code
    url_range_json = 'https://ip-ranges.amazonaws.com/ip-ranges.json'

    data_cached      = nil
    data_downloaded  = nil
    data_expired     = true

    # Do we have a processed copy of the data cached on disk?
    # TODO: Is there some better "puppet way" of caching this? Couldn't find
    # any clear advice when researching and can't see an obvious home for
    # function caches. :-/ PRs welcome if you have a better idea.

    cachefile = Dir.tmpdir() + "/.puppet_cloudfront_ip_ranges.yaml"

    if File.exists?(cachefile)
      debug("CloudFront: Loading data from cachefile "+ cachefile +"...")

      # Load the data
      begin
        data_cached = YAML::load(File.open(cachefile))
      rescue StandardError => e
        raise Puppet::ParseError, "Unexpected error attempting to load cache file "+ cachefile +" exception "+ e.class.to_s
      end

      # Check if file has expired?
      if (Time.now - File.stat(cachefile).mtime).to_i <= 86400
        # Anything less than a day old is still fresh. Not sure exactly how
        # often AWS changes their IP ranges, but it seems unlikely they're
        # launching more than one POP every day. ;-)
        data_expired = false
      end
    end


    # Do we need to download and parse new data?
    if data_expired or data_cached.nil?
      # Either of two conditions is true:

      begin
        tries ||= 3

        # Download the file from AWS into memory.
        uri = URI(url_range_json)
        debug("CloudFront: Downloading latest data... " + uri.to_s)
        response = Net::HTTP.get_response(uri)

       if response.code.to_i == 200

         # Parse the JSON blob downloaded from AWS and extract the Cloudfront
         # IP ranges (v4 and v6).
    
         data_downloaded_raw = JSON.parse(response.body)

         data_downloaded         = Hash.new
         data_downloaded["ipv4"] = Array.new
         data_downloaded["ipv6"] = Array.new
         
         data_downloaded_raw['prefixes'].each do |prefix|
           if prefix['service'] == 'CLOUDFRONT'
             data_downloaded['ipv4'].push(prefix['ip_prefix'])
           end
         end

         data_downloaded_raw['ipv6_prefixes'].each do |prefix|
           # Note that at time of authoring, AWS don't do IPv6 connectivity
           # back to origin, however the code here is ready to support it for
           # future proofing.
           if prefix['service'] == 'CLOUDFRONT'
             data_downloaded['ipv6'].push(prefix['ipv6_prefix'])
           end
         end


          # Write the new cache file
          begin
            debug("CloudFront: Writing to cache file at "+ cachefile)

            # Make sure the file isn't writable by anyone else
            FileUtils.touch cachefile
            File.chmod(0600, cachefile)

            # Write out the processed data in YAML format
            File.open(cachefile, 'w' ) do |file|
              YAML.dump(data_downloaded, file)
            end

          rescue StandardError => e
            raise Puppet::ParseError, "Unexpected error attempting to write cache file "+ cachefile +" exception "+ e.class.to_s
          end

       else
         raise Puppet::ParseError, "Unexpected response code: "+ response.code
       end

      rescue StandardError => e
        retry unless (tries -= 1).zero?

        # We've been unable to download a new file. If there's no cached data available, we should return an error.
        if data_cached.nil?
          raise Puppet::ParseError, "Unexpected error fetching AWS CloudFront IP ranges unexpected exception "+ e.class.to_s
          return nil
        end

      end
    end

    # If we have downloaded data use that, otherwise we use the cached data.
    unless data_downloaded.nil?
      data = data_downloaded
    else
      data = data_cached
    end

    # Catch the developer being a muppet, this should never be possible to execute.
    if data.to_s.empty?
      raise Puppet::ParseError, "Something went very wrong with cloudfront_ips function"
      return nil
    end

    # Complete!
    debug("CloudFront: Data successfully processed, returning results")

    return data

  end

end


# vim: ai ts=2 sts=2 et sw=2 ft=ruby

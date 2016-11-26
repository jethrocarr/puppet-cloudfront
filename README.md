# puppet-cloudfront

Provides a helper function that returns IP ranges being used by Amazon Web
Services CloudFront.


# cloudfront_ips

Returns a hash containing both IPv4 and IPv6 IP ranges used by Amazon CloudFront
CDN. This is useful for crafting ACLs on webservers to block any requests
attempting to bypass the CDN.

For performance and reliability this function caches the results and only
refreshes every 24 hours. If a refresh fails (eg network issue) it falls back to
serving stale cache so there's no sudden change of configuration as long as the
cache files remain on disk (generally in /tmp)

## Parameters & Output

Returns a hash with both IPv4 and IPv6 ranges.


## Usage Examples

You can call the cloudfront_ips function from inside your Puppet manifests and
even iterate through them inside Puppet's DSL, or you can use it directly from
ERB templates.


### Usage in Puppet Resources

TODO: re-write example.

This is an example of setting iptables rules that restrict traffic to SSH to
New Zealand (APNIC/NZ) IPv6 addresses using the puppetlabs/firewall module
with ip6tables provider for Linux:

    # Use jethrocarr-rirs rir_allocations function to get an array of all IP
    # addresses belonging to NZ IPv6 allocations and then create iptables
    # rules for each of them accordingly.
    #
    # Note we use a old style interation (pre future parser) to ensure
    # compatibility with Puppet 3 systems. In future when 4.x+ is standard we
    # could rewite with a newer loop approach as per:
    # https://docs.puppetlabs.com/puppet/latest/reference/lang_iteration.html

    define s_firewall::ssh_ipv6 ($address = $title) {
      firewall { "004 V6 Permit SSH ${address}":
        provider => 'ip6tables',
        proto    => 'tcp',
        port     => '22',
        source   => $address,
        action   => 'accept',
      }  
    }

    $ipv6_allocations = rir_allocations('apnic', 'ipv6', 'nz')
    s_firewall::pre::ssh_ipv6 { $ipv6_allocations: }

Note that due to the use of Puppet 3 compatible iterator, you'll need to rename
`s_firewall::ssh_ipv6` to `yourmodule::yourclass::ssh_ipv6` as the
definition has to be a child of the module/class that it's inside of - in the
above example, it lives in `s_firewall/manifests/init.pp`.




### Usage in Puppet ERB Templates

TODO: re-write example

If you want to provide the list of addresses to configuration files or scripts
rather than using it to create Puppet resources, it's entirely possible to call
the function directly from inside ERB templates. The following is an example of
generating Apache `mod_access_compat` rules to restrict visitors from
New Zealand (APNIC/NZ) IPv4 and IPv6 addresses only.

    <Location "/admin">
      Order deny,allow
      Deny from all

      # Use the jethrocarr-rirs Puppet module functions to lookup the IP
      # allocations from APNIC for New Zealand. This works better than the
      # buggy mod_geoip module since it supports both IPv4 and IPv6 concurrently.

      <% scope.function_rir_allocations(['apnic', 'ipv4', 'nz']).each do |ipv4| -%>
        Allow from <%= ipv4 %>
      <% end -%>
      <% scope.function_rir_allocations(['apnic', 'ipv6', 'nz']).each do |ipv6| -%>
        Allow from <%= ipv6 %>
      <% end -%>
    </Location>



# Requirements

The minimum requirements are met by most systems:
* Standard Ruby environment.
* Ability to connect to remote HTTP webservers to download latest data.


# Contributions

Contributions via the form of Pull Requests is always welcome!


## Debugging

Remember that custom Puppet functions execute on the master/server, not the
local server. This means that:

1. If the master is behind a restrictive network it may be unable to access the
   AWS JSON download file from their public endpoint.

2. Errors and debug log messages might only appear on the master.

If Puppet is run with --debug it exposes additional debug messages from the RIR
functions, useful if debugging timeout issues, etc.

    TODO: Put example here.


# License

This module is licensed under the Apache License, Version 2.0 (the "License").
See the `LICENSE` or http://www.apache.org/licenses/LICENSE-2.0

    Unless required by applicable law or agreed to in writing, software
    distributed under the License is distributed on an "AS IS" BASIS,
    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
    See the License for the specific language governing permissions and
    limitations under the License.

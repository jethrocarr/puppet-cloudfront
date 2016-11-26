# puppet-cloudfront

Provides a helper function that returns IP ranges being used by Amazon Web
Services CloudFront.


# Function cloudfront_ips

Returns a hash containing both IPv4 and IPv6 IP ranges used by Amazon CloudFront
CDN. This is useful for crafting ACLs on webservers to block any requests
attempting to bypass the CDN.

For performance and reliability this function caches the results and only
refreshes every 24 hours. If a refresh fails (eg network issue) it falls back to
serving stale cache so there's no sudden change of configuration as long as the
cache files remain on disk (generally in /tmp)


## Parameters & Output

Returns a hash with both IPv4 and IPv6 ranges, consisting of a set of strings in
CIDR notation.

Note that as of 2016-11-25, AWS does not yet use IPv6 for connectivity from
CloudFront to origin, so the array of IPv6 addresses returned is empty. This may
change at any time in future so if you have an IPv6 enabled server, recommend
that you enable the functionality now.


## Usage Examples

You can call the cloudfront_ips function from inside your Puppet manifests and
even iterate through them inside Puppet's DSL, or you can use it directly from
ERB templates.


### Usage in Puppet Resources

This is an example of setting up an iptables/ip6tables firewall on a GNU/Linux
server to only permit access to HTTPS (TCP 443) from CloudFront IP ranges. This
makes it possible to have a locked down webserver that forces all requests
through the CDN and blocking attacks directed at origin.

    # Use jethrocarr-cloudfront cloudfront_ips function to get an array of all
    # IP addresses used by CloudFront and craft iptables rules to permit access
    # from those IP ranges only. With a corresponding default block rule, this
    # restricts access to this webserver to the CloudFront CDN only to prevent
    # any users/attackers bypassing the CDN and hitting origin directly.
    #
    # Note we use a old style interation (pre future parser) to ensure
    # compatibility with Puppet 3 systems. In future when 4.x+ is standard we
    # could rewite with a newer loop approach as per:
    # https://docs.puppetlabs.com/puppet/latest/reference/lang_iteration.html

    define https_ipv4 ($address = $title) {
      firewall { "100 V4 Permit HTTPS CloudFront ${address}":
        provider => 'iptables',
        proto    => 'tcp',
        dport    => '443',
        source   => $address,
        action   => 'accept',
      }
    }

    define https_ipv6 ($address = $title) {
      firewall { "100 V6 Permit HTTPS CloudFront ${address}":
        provider => 'ip6tables',
        proto    => 'tcp',
        dport    => '443',
        source   => $address,
        action   => 'accept',
      }
    }

    $cloudfront_allocations = cloudfront_ips()

    https_ipv4 { $cloudfront_allocations['ipv4']: }
    https_ipv6 { $cloudfront_allocations['ipv6']: }


### Usage with Apache

When using Apache behind a CDN, generally you will want to use the
`X-Forwarded-For` header in logs and also ACLs. However it can't be trusted if
you aren't firewalling the server to the CDN only.

The following example uses the Apache `remoteip` module and the
`puppetlabs-apache` Puppet module to configure Apache to trust the headers from
any CloudFront IP range.

    # Trust X-Forwarded-For header from CloudFront. We use the
    # jethrocarr-cloudfront Puppet module to download a list of all the IP
    # addresses allocated to CloudFront regularly.
    $cloudfront_allocations = cloudfront_ips()

    class { 'apache::mod::remoteip':
      header            => 'X-Forwarded-For',
      proxy_ips         => ['127.0.0.1', '::1'],
      trusted_proxy_ips => concat($cloudfront_allocations['ipv4'], $cloudfront_allocations['ipv6']),
    }



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

    Debug: Scope(Class[main]): CloudFront: Downloading latest data... https://ip-ranges.amazonaws.com/ip-ranges.json
    Debug: Scope(Class[main]): CloudFront: Writing to cache file at /tmp/.puppet_cloudfront_ip_ranges.yaml
    Debug: Scope(Class[main]): CloudFront: Data successfully processed, returning results

    Debug: Scope(Class[main]): CloudFront: Loading data from cachefile /tmp/.puppet_cloudfront_ip_ranges.yaml...
    Debug: Scope(Class[main]): CloudFront: Data successfully processed, returning results


# License

This module is licensed under the Apache License, Version 2.0 (the "License").
See the `LICENSE` or http://www.apache.org/licenses/LICENSE-2.0

    Unless required by applicable law or agreed to in writing, software
    distributed under the License is distributed on an "AS IS" BASIS,
    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
    See the License for the specific language governing permissions and
    limitations under the License.

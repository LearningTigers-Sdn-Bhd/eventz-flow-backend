# frozen_string_literal: true

require 'ipaddr'
require 'resolv'

module AiIntegrations
  # Keeps requests to a configured AI provider from reaching private or local
  # networks (SSRF). Shared by every outbound provider call.
  module NetworkGuard
    class Blocked < StandardError; end

    BLOCKED_NETWORKS = %w[
      0.0.0.0/8
      10.0.0.0/8
      100.64.0.0/10
      127.0.0.0/8
      169.254.0.0/16
      172.16.0.0/12
      192.0.0.0/24
      192.0.2.0/24
      192.168.0.0/16
      198.18.0.0/15
      198.51.100.0/24
      203.0.113.0/24
      224.0.0.0/4
      240.0.0.0/4
      ::/128
      ::1/128
      ::ffff:0:0/96
      fc00::/7
      fe80::/10
      ff00::/8
    ].map { |network| IPAddr.new(network) }.freeze

    # Returns an address that is safe to connect to. Pin the socket to it
    # (Net::HTTP#ipaddr=) so DNS can't change between this check and the connect.
    def self.pick_safe_address(host)
      addresses = Resolv.getaddresses(host)
      raise Blocked, 'Provider URL could not be resolved' if addresses.empty?
      if addresses.any? { |address| blocked_address?(address) }
        raise Blocked, 'Provider URL must not target a private or local network'
      end

      addresses.first
    rescue Resolv::ResolvError
      raise Blocked, 'Provider URL could not be resolved'
    end

    def self.blocked_address?(address)
      ip_address = IPAddr.new(address)
      BLOCKED_NETWORKS.any? { |network| network.include?(ip_address) }
    rescue IPAddr::InvalidAddressError
      true
    end
  end
end

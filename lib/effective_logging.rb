require "effective_logging/engine"
require "effective_logging/version"

module EffectiveLogging
  # The following are all valid config keys
  mattr_accessor :logs_table_name
  mattr_accessor :authorization_method
  mattr_accessor :layout
  mattr_accessor :statuses

  def self.setup
    yield self
  end

  def self.authorized?(controller, action, resource)
    raise Effective::AccessDenied.new() unless (controller || self).instance_exec(controller, action, resource, &EffectiveLogging.authorization_method)
    true
  end

  def self.statuses
    @statuses ||= Array(@@statuses).map { |status| status.to_s.downcase } | ['info', 'success', 'error']
  end

end

module EffectiveLogging
  class ActiveRecordLogger
    attr_accessor :object, :resource, :logger, :depth, :options

    BLANK = "''"

    def initialize(object, options = {})
      raise ArgumentError.new('options must be a Hash') unless options.kind_of?(Hash)

      @object = object
      @resource = Effective::Resource.new(object)

      @logger = options.delete(:logger) || object
      @depth = options.delete(:depth) || 0
      @options = options

      raise ArgumentError.new('logger must respond to logged_changes') unless @logger.respond_to?(:logged_changes)
    end

    # execute! is called when we recurse, otherwise the following methods are best called individually
    def execute!
      if object.new_record?
        created!
      elsif object.marked_for_destruction?
        destroyed!
      else
        changed!
      end
    end

    # before_destroy
    def destroyed!
      log('Deleted', details: applicable(resource.instance_attributes))
    end

    # after_commit
    def created!
      log('Created', details: applicable(resource.instance_attributes))
    end

    # after_commit
    def updated!
      log('Updated', details: applicable(resource.instance_attributes))
    end

    # before_save
    def changed!
      applicable(resource.instance_changes).each do |attribute, (before, after)|
        if object.respond_to?(:log_changes_formatted_value)
          before = object.log_changes_formatted_value(attribute, before) || before
          after = object.log_changes_formatted_value(attribute, after) || after
        end

        attribute = if object.respond_to?(:log_changes_formatted_attribute)
          object.log_changes_formatted_attribute(attribute)
        end || attribute.titleize

        log("#{attribute}: #{before.presence || BLANK} &rarr; #{after.presence || BLANK}", details: { attribute: attribute, before: before, after: after })
      end

      # Log changes on all accepts_as_nested_parameters has_many associations
      resource.nested_resources.each do |association|
        title = association.name.to_s.singularize.titleize

        Array(object.send(association.name)).each_with_index do |child, index|
          ActiveRecordLogger.new(child, options.merge(logger: logger, depth: (depth + 1), prefix: "#{title} ##{index+1}: ")).execute!
        end
      end
    end

    private

    def log(message, details: {})
      logger.logged_changes.build(
        user: EffectiveLogging.current_user,
        status: EffectiveLogging.log_changes_status,
        message: "#{"\t" * depth}#{options[:prefix]}#{message}",
        associated: object,
        associated_to_s: (object.to_s rescue nil),
        details: details
      ).tap { |log| log.save }
    end

    # TODO: Make this work better with nested objects
    def applicable(attributes)
      atts = if options[:only].present?
        attributes.slice(*options[:only])
      elsif options[:except].present?
        attributes.except(*options[:except])
      else
        attributes.except(:updated_at, :created_at)
      end

      (options[:additionally] || []).each do |attribute|
        value = (object.send(attribute) rescue :effective_logging_nope)
        next if attributes[attribute].present? || value == :effective_logging_nope

        atts[attribute] = value
      end

      atts
    end

  end
end

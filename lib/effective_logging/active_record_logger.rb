module EffectiveLogging
  class ActiveRecordLogger
    attr_accessor :object, :resource, :logger, :depth, :include_associated, :options

    BLANK = "''"

    def initialize(object, options = {})
      raise ArgumentError.new('options must be a Hash') unless options.kind_of?(Hash)

      @object = object
      @resource = Effective::Resource.new(object)
      @logged = false # If work was done

      @logger = options.delete(:logger) || object
      @depth = options.delete(:depth) || 0
      @include_associated = options.fetch(:include_associated, true)
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

      log_nested_resources! if include_associated

      @logged
    end

    # before_destroy
    def destroyed!
      log('Deleted')
    end

    # after_commit
    def created!
      log('Created', details: applicable(resource.instance_attributes(include_associated: include_associated)))
    end

    # after_commit
    def updated!
      log('Updated', details: applicable(resource.instance_attributes(include_associated: include_associated)))
    end

    private

    def changed!
      applicable(resource.instance_changes).each do |attribute, (before, after)|
        if object.respond_to?(:log_changes_formatted_value)
          before = object.log_changes_formatted_value(attribute, before) || before
          after = object.log_changes_formatted_value(attribute, after) || after
        end

        before = before.to_s if before.kind_of?(ActiveRecord::Base) || before.kind_of?(FalseClass)
        after = after.to_s if after.kind_of?(ActiveRecord::Base) || after.kind_of?(FalseClass)

        attribute = if object.respond_to?(:log_changes_formatted_attribute)
          object.log_changes_formatted_attribute(attribute)
        end || attribute.titleize

        log("#{attribute}: #{before.presence || BLANK} &rarr; #{after.presence || BLANK}", details: { attribute: attribute, before: before, after: after })
      end
    end

    def log_nested_resources!
      # Log changes on all accepts_as_nested_parameters has_many associations
      resource.nested_resources.each do |association|
        title = association.name.to_s.singularize.titleize

        Array(object.send(association.name)).each_with_index do |child, index|
          child_options = options.merge(logger: logger, depth: depth+1, include_associated: include_associated, prefix: "#{title} #{index} - #{child} - ")
          @logged = true if ::EffectiveLogging::ActiveRecordLogger.new(child, child_options).execute!
        end
      end
    end

    def log(message, details: {})
      @logged = true

      log = logger.logged_changes.build(
        user: EffectiveLogging.current_user,
        status: EffectiveLogging.log_changes_status,
        message: "#{"\t" * depth}#{options[:prefix]}#{message}",
        associated_to_s: (logger.to_s rescue nil),
        details: details
      )

      log.save
      log
    end

    # TODO: Make this work better with nested objects
    def applicable(attributes)

      atts = if options[:only].present?
        attributes.stringify_keys.slice(*options[:only])
      elsif options[:except].present?
        attributes.stringify_keys.except(*options[:except])
      else
        attributes.except(:updated_at, :created_at, 'updated_at', 'created_at')
      end

      (options[:additionally] || []).each do |attribute|
        value = (object.send(attribute) rescue :effective_logging_nope)
        next if attributes[attribute].present? || value == :effective_logging_nope

        atts[attribute] = value
      end

      # Blacklist
      atts.except(:logged_changes, :trash, 'logged_changes', 'trash')
    end
  end
end

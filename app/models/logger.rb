module Intrigue
  module Model
    class Logger < Sequel::Model
      plugin :serialization, :json
      plugin :validation_helpers

      one_to_one :task_result
      one_to_one :scan_result
      many_to_one :project

      #set_allowed_columns :full_log, :project_id

      def self.scope_by_project(name)
        named_project_id = Intrigue::Model::Project.first(:name => name).id
        where(:project_id => named_project_id)
      end

      def validate
        super
      end

      def log(message)
        _log "[#{id}][ ] " << message
      end

      def log_debug(message)
        _log "[#{id}][D] " << message
      end

      def log_good(message)
        _log "[#{id}][+] " << message
      end

      def log_error(message)
        _log "[#{id}][E] " << message
      end

      def log_warning(message)
        _log "[#{id}][W] " << message
      end

      def log_fatal(message)
        _log "[#{id}][F] " << message
      end

    private

      def _log(message)
        encoded_message = _encode_string(message)
        full_log = "#{full_log}\n#{encoded_message}"
        return true if save
      false
      end

      def _encode_string(string)
        string.encode("UTF-8", :undef => :replace, :invalid => :replace, :replace => "?")
      end

    end
end
end

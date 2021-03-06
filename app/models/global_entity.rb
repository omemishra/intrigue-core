module Intrigue
  module Model
    class GlobalEntity < Sequel::Model
      plugin :validation_helpers
      plugin :timestamps

      self.raise_on_save_failure = false

      def validate
        super
        validates_unique([:namespace, :type, :name])
      end

      def self.parse_domain_name(record)
        split_tld = parse_tld(record).split(".")
        if (split_tld.last == "com" || split_tld.last == "net") && split_tld.count > 1 # handle cases like amazonaws.com, netlify.com
          length = split_tld.count
        else
          length = split_tld.count + 1
        end
        
      record.split(".").last(length).join(".")
      end
    
      # assumes we get a dns name of arbitrary length
      def self.parse_tld(record)
    
        # first check if we're not long enough to split, just returning the domain
        return record if record && record.split(".").length < 2
    
        # Make sure we're comparing bananas to bananas
        record = record.downcase
    
        # now one at a time, check all known TLDs and match
        begin
          raw_suffix_list = File.open("#{$intrigue_basedir}/data/public_suffix_list.clean.txt").read.split("\n")
          suffix_list = raw_suffix_list.map{|l| "#{l.downcase}".strip }
    
          # first find all matches
          matches = []
          suffix_list.each do |s|
            if record =~ /.*#{Regexp.escape(s.strip)}$/i # we have a match ..
              matches << s.strip
            end
          end
    
          # then find the longest match
          if matches.count > 0
            longest_match = matches.sort_by{|x| x.split(".").length }.last
            return longest_match
          end
    
        rescue Errno::ENOENT => e
          _log_error "Unable to locate public suffix list, failing to check / create domain for #{lookup_name}"
          return nil
        end
    
      # unknown tld
      record
      end


      #TODO .. this method should only be called if we don't already have the entity in our project
      def self.traversable?(entity_type, entity_name, project)
         
        # by default things are not traversable
        out = false 

        # first check to see if we know about this exact entity (type matters too)
        puts "Looking for global entity: #{entity_type} #{entity_name}"
        global_entity = Intrigue::Model::GlobalEntity.first(:name => entity_name, :type => entity_type)

        # If we know it exists, is it in our project (cool) or someone else (no traverse!)
        if global_entity
          puts "Global entity found: #{entity_type} #{entity_name}!"
          
          # we need to have a namespace to validate against
          if project.allowed_namespaces
            project.allowed_namespaces.each do |namespace|
              # if the entity's' namespace matches one of ours, we're good!
              if global_entity.namespace.downcase == namespace.downcase 
                puts "Matches our namespace!"
                return true # we can immediately return 
              end
            end
          else
            puts "No Allowed Namespaces, but this is a claimed entity!"
            return false
          end

        else 
          puts "No Global entity found!"
        end

        # okay so if we made it this far, we may or may not have a matching entiy, so now 
        # we need to find if it matches based on regex... since entities can have a couple
        # different forms (uri, dns_record, domain, etc)

        # TODAY this only works on domains... and things that have a domain (like a uri)

        # then check each for a match 
        found_entity = nil

        ## Okay let's get smart by getting down to the smallest searchable unit first
        searchable_name = nil
        
        #include Intrigue::Task::Dns # useful for parsing domain names
        
        if entity_type == "Domain"
          # this should have gotten caught above... 
          searchable_name = parse_domain_name(entity_name)
        elsif entity_type == "DnsRecord"  
          searchable_name = parse_domain_name(entity_name)
        elsif entity_type == "EmailAddress"  
          searchable_name = parse_domain_name(entity_name.split("@").last)
        elsif entity_type == "Nameserver"  
          searchable_name = parse_domain_name(entity_name)
        elsif entity_type == "Uri"
          searchable_name = parse_domain_name(URI.parse(entity_name).host)
        end

        # now form the query, taking into acount the filter if we can
        if searchable_name
          found_entity = Intrigue::Model::GlobalEntity.first(:type => "Domain", :name => searchable_name)
        else
          global_entities = Intrigue::Model::GlobalEntity.all

          global_entities.each do |ge|
            # this needs a couple (3) cases:
            # 1) case where we're an EXACT match (ey.com)
            # 2) case where we're a subdomain of an exception domain (x.ey.com)
            # 3) case where we're a uri and should match an exception domain (https://ey.com)
            # none of these cases should match the case: jcpenney.com
            if (entity_name.downcase =~ /^#{Regexp.escape(ge.name.downcase)}(:[0-9]*)?$/ ||
              entity_name.downcase =~ /^.*\.#{Regexp.escape(ge.name.downcase)}(:[0-9]*)?$/ ||
              entity_name.downcase =~ /^https?:\/\/#{Regexp.escape(ge.name.downcase)}(:[0-9]*)?$/)
              
              #okay we found it... now we need to check if it's an allowed project
              found_entity = ge
            end
          end
        end

      if found_entity && !project.allowed_namespaces.empty? # now lets check if we have an allowance for it

         (project.allowed_namespaces || []).each do |namespace|
          if found_entity.namespace.downcase == namespace.downcase # Good! 
            return true 
          end
        end

        out = false
      else # we never found it or we don't care (no namespaces)! 
        out = true 
      end

      #puts "Result for: #{entity_type} #{entity_name} in project #{project.name}: #{out}" 

      out 
      end

      def self.load_global_namespace(data)
        (data["entities"] || []).each do |x|
          Intrigue::Model::GlobalEntity.update_or_create(:name => x["name"], :type => x["type"], :namespace => x["namespace"])
        end
      end

    end
  end
end

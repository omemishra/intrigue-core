module Intrigue
module Entity
class PhoneNumber < Intrigue::Model::Entity

  def self.metadata
    {
      :name => "PhoneNumber",
      :description => "A Phone Number",
      :user_creatable => true,
      :example => "555-555-5555"
    }
  end

  def validate_entity
    name =~ /^\D*([2-9]\d{2})(\D*)([2-9]\d{2})(\D*)(\d{4})\D*$/
  end

  def detail_string
    "#{details["origin"]}"
  end
  
  def scoped?
    return true if self.seed
    return false if self.hidden
  true # otherwise just default to true
  end

end
end
end

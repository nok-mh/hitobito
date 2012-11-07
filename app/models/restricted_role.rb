# Usage: restricted_role :advisor, Role::Advisor
# Adds an accessors for a restricted role to the current group.
# So it is possible to change the assigned Person like a regular group attribute.
module RestrictedRole
  extend ActiveSupport::Concern
  
  included do
    class_attribute :restricted_roles
    self.restricted_roles = {}
  end

  private

  # after the group was saved, create or destroy the restricted roles.
  def create_restricted_roles
    restricted_roles.each do |attr, type|
      role = restricted_role(attr, type)
      if role.try(:person_id) != send("#{attr}_id")
        if role 
          # be on the save side with destroy_all
          restricted_role_scope(type).destroy_all
          @restricted_role[attr] = nil # clear cache
        end
        if id = restricted_role_id(attr, type).presence
          build_restricted_role(type.new, id).save!
        end
      end
    end
  end
  
  def build_restricted_role(role, id)
    role.person_id = id
    role.group = self
    role
  end
  
  def restricted_role_scope(type)
    roles.where(type: type.sti_name)
  end
  
  def restricted_role(attr, type)
    @restricted_role ||= {}
    @restricted_role[attr] ||= restricted_role_scope(type).first
  end
  
  def restricted_role_id(attr, type)
    @restricted_role_id ||= {}
    @restricted_role_id[attr] ||= restricted_role(attr, type).try(:person_id)
  end
  
  def set_restricted_role_id(attr, value)
    @restricted_role_id ||= {}
    @restricted_role_id[attr] = value
  end
  
  module ClassMethods
    def restricted_role(attr, type)
      after_save :create_restricted_roles
      restricted_roles[attr] = type
      self.role_types += [type]
      
      # getter for the person
      define_method attr do        
        if new_record?
          id = restricted_role_id(attr, type)
          Person.find(id) if id
        else
          restricted_role(attr, type).try(:person)
        end
      end
      
      # getter for the person id
      define_method "#{attr}_id" do
        restricted_role_id(attr, type)
      end
      
      # setter for the person id
      define_method "#{attr}_id=" do |value|
        set_restricted_role_id(attr, value)
      end
    end
  end

end

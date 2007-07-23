# Copyright (c) 2007 Flinn Mueller
# Released under the MIT License.  See the MIT-LICENSE file for more details.

module ActiveRecord #:nodoc:
  module Acts #:nodoc:
    module Scoped #:nodoc:
      # This plugin does is similar to {Scoped Access plugin}[http://agilewebdevelopment.com/plugins/scoped_access]
      # In light of Rails Core's {comments on depracating public with_scope}[http://groups.google.com/group/rubyonrails-core/msg/91ecfff96ae35de1],
      # this plugin attempts to retain the Tao of Rails while still enabling
      # the {many of us}[http://groups.google.com/group/rubyonrails-core/browse_frm/thread/a8e60f340a682977/] who need this functionality to use with_scope to restrict access.

      def self.append_features(base)
        super
        base.extend(ClassMethods)
      end
    
      module ClassMethods
        # acts_as_scoped(scope_association = :user, options = {})
        #
        # Options are:
        # * <tt>:id</tt>: scoped foreign key, defaults to association.foreign_key
        # * <tt>:class_name</tt>: class name of the current scope class, defaults to association.classify
        # * <tt>:class_id</tt>: identifier method for current scope class, defaults to primary_key
        # * <tt>:current</tt>: method to call the current scope object, defaults to :current
        # * <tt>:find_with_nil_scope</tt>: allow find when no current scope is set (good for authentication on a scoped object)
        # * <tt>:find_global_nils</tt>: allows you to mix scoped and global objects together

        def acts_as_scoped(scope_association = :user, options = {})
          scope_id = (options.delete(:id) || scope_association).to_s.foreign_key
          scope_class_name = (options.delete(:class_name) || scope_association).to_s.classify
          scope_class_id = options.delete(:class_id) || scope_class_name.constantize.primary_key
          scope_current = options.delete(:current) || :current
          find_with_nil_scope = options.delete(:find_with_nil_scope) || false
          find_global_nils = options.delete(:find_global_nils) || false

          self.class_eval <<-EOV
            @@scope_id = "#{scope_id}".to_sym
            cattr_accessor :scope_id

            @@find_with_nil_scope = #{find_with_nil_scope}
            cattr_accessor :find_with_nil_scope

            @@find_global_nils = #{find_global_nils}
            cattr_accessor :find_global_nils

            include ActiveRecord::Acts::Scoped::InstanceMethods
            belongs_to "#{scope_association}".to_sym

            # Ensure scoping
            attr_protected "#{scope_id}".to_sym
            validates_presence_of "#{scope_id}".to_sym
            before_validation_on_create :create_with_current_scope

            def self.current_scope
              #{scope_class_name}.#{scope_current}
            end

            def self.current_scope_value
              (self.current_scope.class == #{scope_class_name} ? self.current_scope.#{scope_class_id} : nil)
            end

            def readonly_with_current_scope?
              #if self.class.current_scope.nil? || self.class.current_scope_value != send(scope_id)
              if send(scope_id).nil?
                true
              else
                readonly_without_current_scope?
              end
            end
            alias_method_chain :readonly?, :current_scope

            def destroy_with_current_scope
              if !self.class.current_scope.nil? && self.class.current_scope_value == send(scope_id)
                destroy_without_current_scope
              end
            end
            alias_method_chain :destroy, :current_scope

          EOV

          class << self
            alias_method_chain :calculate, :current_scope
            alias_method_chain :find, :current_scope
            alias_method_chain :construct_finder_sql, :current_scope
            alias_method_chain :delete_all, :current_scope
          end
        end

        def construct_finder_sql_with_current_scope(options) #:nodoc:
          if find_with_nil_scope && self.current_scope.nil?
            construct_finder_sql_without_current_scope(options)
          else
            with_current_scope do
              construct_finder_sql_without_current_scope(options)
            end
          end
        end

        # Scoped version of +calculate+
        def calculate_with_current_scope(*args) #:nodoc:
          if find_with_nil_scope && self.current_scope.nil?
            calculate_without_current_scope(*args)
          else
            with_current_scope do
              calculate_without_current_scope(*args)
            end
          end
        end

        # Scoped version of +find+
        def find_with_current_scope(*args) #:nodoc:
          if find_with_nil_scope && self.current_scope.nil?
            find_without_current_scope(*args)
          else
            with_current_scope do
              find_without_current_scope(*args)
            end
          end
        end

        # Scoped version of +delete_all+
        # "EX-TER-MI-NATE!" ( In the voice of a Dalek[http://en.wikipedia.org/wiki/Dalek] )
        def delete_all_with_current_scope(conditions = nil) #:nodoc:
          delete_with_current_scope do
            delete_all_without_current_scope(conditions)
          end
        end

        protected

          # scoping for find
          def with_current_scope(&proc) #:nodoc:
            if self.current_scope
              # is IS NULL proper for all adapters?
              conditions = (find_global_nils ? [ "#{scope_id} = ? OR #{scope_id} IS NULL", self.current_scope_value ] : { scope_id => self.current_scope_value })
              self.with_exclusive_scope(:find => { :conditions => conditions }) do
                yield
              end
            else
              [] # this shouldn't happen, throw an error instead maybe?
            end          
          end

          # scoping for delete_all
          def delete_with_current_scope(&proc) #:nodoc:
            if self.current_scope
              self.with_exclusive_scope(:find => { :conditions => { scope_id => self.current_scope_value } }) do
                yield
              end
            else
              [] # this shouldn't happen, throw an error instead maybe?
            end          
          end
      end

      module InstanceMethods #:nodoc:
        # Create doesn't respect scoping because scoping isn't made for this type of thing.
        # So instead of asking create to go against the Tao,
        # we'll enforce a protected attribute and set attribute on create
        def create_with_current_scope #:nodoc:
          if self.class.current_scope
            send("#{self.scope_id}=", self.class.current_scope_value)
          end # else - validation ensure this bombs out
        end
      end
    end
  end
end
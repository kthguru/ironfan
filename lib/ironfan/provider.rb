# Providers present a lightweight wrapper for various third-party services,
#   such as Chef's node and client APIs, and Amazon's EC2 APIs. This allows
#   Ironfan ask specialized questions (such as whether a given resource 
#   matches
module Ironfan
  class Provider < Builder

    def self.receive(obj,&block)
      obj[:_type] = case obj[:name]
        when    :chef;          Chef
        when    :ec2;           Ec2
        when    :virtualbox;    VirtualBox
        else;   raise "Unsupported provider #{obj[:name]}"
      end unless native?(obj)
      super
    end

    def resources()     self.class.resources;   end
    def self.resources
      raise "missing #{self.class}.resources declaration"
    end

    #
    # Discovery
    #
    def self.load(cluster)
      Ironfan.delegate_to(resources) { load! cluster }
    end

    def self.validate(computers)
      Ironfan.delegate_to(resources) { validate_resources! computers }
    end


    class Resource < Builder
      @@known = {}
      field             :adaptee,       Whatever
      field             :bogus,         Array,          :default => []
      attr_accessor     :owner
      attr_accessor     :users
      def users()       @users ||= [];  end;

      def bogus?()                      !bogus.empty?;          end

      #
      # Flags
      # 
      # Non-shared resources live and die with the computer
      def self.shared?()                true;                   end
      # Can multiple instances of this resource be associated with the computer?
      def self.multiple?()              false;                  end

      #
      # Discovery
      #
      def self.load!(*p)                Ironfan.noop(self,__method__,*p);   end
      def self.correlate!(*p)           Ironfan.noop(self,__method__,*p);   end
      def self.validate_computer!(*p)   Ironfan.noop(self,__method__,*p);   end
      def self.validate_resources!(*p)  Ironfan.noop(self,__method__,*p);   end

      def on_correlate(*p)              Ironfan.noop(self,__method__,*p);   end

      #
      # Manipulation
      #
      def self.create!(*p)              Ironfan.noop(self,__method__,*p);   end
      def self.save!(*p)                Ironfan.noop(self,__method__,*p);   end
      def self.destroy!(*p)             Ironfan.noop(self,__method__,*p);   end

      #
      # Utilities
      #
      [:shared?, :multiple?, :load!,:correlate!,:validate_computer!,
       :validate_resources!,:create!,:save!,:destroy!].each do |method_name|
        define_method(method_name) {|*p| self.class.send(method_name,*p) }
      end

      def self.remember(resource,options={})
        index = options[:id] || resource.name
        index += options[:append_id] if options[:append_id]
        self.known[index] = resource
      end

      # Register and return the (adapted) object with the collection
      def self.register(native)
        result = new(:adaptee => native)
        remember result unless result.nil?
      end

      def self.recall?(id)
        self.known.include? id
      end

      def self.recall(id=nil)
        return self.known if id.nil?
        self.known[id]
      end

      def self.forget(id)
        self.known.delete(id)
      end

      # Provide a separate namespace in @@known for each subclass
      def self.known
        @@known[self.name] ||= {}
      end
    end

  end

  class IaasProvider < Provider
    def self.machine_class
      self.const_get(:Machine)
    end

    #
    # Manipulation
    #
    def ensure_prerequisites!(computers)
      # Create all things that aren't machines
      targets = resources.reject {|type| type < IaasProvider::Machine}
      computers.each do |computer|
        delegate_to(targets) { create! computer }
      end
    end

    def save!(computers)
      computers.each do |computer|
        delegate_to(resources) { save! computer }
      end
    end

    class Machine < Resource
      # A Machine lives and dies with its Computer
      def self.shared?()        false;                   end
    end
  end

end
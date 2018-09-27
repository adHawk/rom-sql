module ROM::Factory
  module Attributes
    # @api private
    module Association
      def self.new(assoc, builder, *traits, **options)
        const_get(assoc.definition.type).new(assoc, builder, *traits, **options)
      end

      # @api private
      class Core
        attr_reader :assoc, :options, :traits

        # @api private
        def initialize(assoc, builder, *traits, **options)
          @assoc = assoc
          @builder_proc = builder
          @traits = traits
          @options = options
        end

        # @api private
        def builder
          @__builder__ ||= @builder_proc.call
        end

        # @api private
        def name
          assoc.key
        end

        # @api private
        def dependency?(*)
          false
        end

        # @api private
        def value?
          false
        end
      end

      # @api private
      class ManyToOne < Core
        # @api private
        def call(persist: true, **attrs)
          if attrs.key?(name) && !attrs[foreign_key]
            assoc.associate(attrs, attrs[name])
          elsif !attrs[foreign_key]
            struct = builder.persistable.create(*traits)
            tuple = { name => struct }
            assoc.associate(tuple, struct)
          end
        end

        # @api private
        def foreign_key
          assoc.foreign_key
        end
      end

      # @api private
      class OneToMany < Core
        # @api private
        def call(attrs = EMPTY_HASH, parent, persist: true)
          return if attrs.key?(name)

          structs = Array.new(count).map do
            # hash which contains the foreign key info, i.e: { user_id: 1 }
            association_hash = assoc.associate(attrs, parent)

            if persist
              builder.persistable.create(*traits, association_hash)
            else
              builder.struct(*traits, attrs.merge(association_hash))
            end
          end

          { name => structs }
        end

        # @api private
        def dependency?(rel)
          assoc.source == rel
        end

        # @api private
        def count
          options.fetch(:count)
        end
      end

      # @api private
      class OneToOne < OneToMany
        # @api private
        def call(attrs = EMPTY_HASH, parent, persist: true)
          return if attrs.key?(name)

          association_hash = assoc.associate(attrs, parent)

          struct = if persist
                     builder.persistable.create(*traits, association_hash)
                   else
                     belongs_to_name = Dry::Core::Inflector.singularize(assoc.source_alias)
                     belongs_to_associations = { belongs_to_name.to_sym => parent }
                     final_attrs = attrs.merge(association_hash).merge(belongs_to_associations)
                     builder.struct(*traits, final_attrs)
                   end

          { name => struct }
        end
      end
    end
  end
end

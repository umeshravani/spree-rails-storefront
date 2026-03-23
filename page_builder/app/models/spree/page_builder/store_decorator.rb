module Spree
  module PageBuilder
    module StoreDecorator
      def self.prepended(base)
        base.include Spree::HasPageLinks
        base.include Spree::Stores::Socials

        # Page Builder associations
        base.has_many :themes, -> { without_previews }, class_name: 'Spree::Theme', dependent: :destroy, inverse_of: :store
        base.has_many :theme_previews,
                      -> { only_previews },
                      class_name: 'Spree::Theme',
                      through: :themes,
                      source: :previews,
                      inverse_of: :store,
                      dependent: :destroy
        base.has_one :default_theme, -> { without_previews.where(default: true) }, class_name: 'Spree::Theme', inverse_of: :store
        base.alias_method :theme, :default_theme
        base.has_many :theme_pages, class_name: 'Spree::Page', through: :themes, source: :pages
        base.has_many :theme_page_previews, class_name: 'Spree::Page', through: :theme_pages, source: :previews
        base.has_many :pages, -> { without_previews.custom }, class_name: 'Spree::Pages::Custom', dependent: :destroy, as: :pageable
        base.has_many :page_previews, class_name: 'Spree::Pages::Custom', through: :pages, as: :pageable, source: :previews

        base.after_create :create_default_theme

        base.has_rich_text :checkout_message

        # Storefront-specific attachments
        base.has_one_attached :favicon_image, service: Spree.public_storage_service_name
        base.has_one_attached :social_image, service: Spree.public_storage_service_name

        base.validates :favicon_image, :social_image, content_type: Rails.application.config.active_storage.web_image_content_types

        base.preference :index_in_search_engines, :boolean, default: false
        base.preference :password_protected, :boolean, default: false
        base.store_accessor :private_metadata, :storefront_password

        base.translates(:facebook, :twitter, :instagram, column_fallback: !Spree.always_use_translations?)
      end

      def favicon
        return unless favicon_image.attached? && favicon_image.variable?

        favicon_image.variant(resize_to_limit: [32, 32])
      end

      private

      def create_default_theme
        ensure_default_taxonomies
        ensure_default_automatic_taxons

        themes.find_or_initialize_by(default: true) do |theme|
          theme.name = Spree.t(:default_theme_name)
          theme.save!
        end
      end

      def ensure_default_taxonomies
        [
          Spree.t(:taxonomy_categories_name),
          Spree.t(:taxonomy_brands_name),
          Spree.t(:taxonomy_collections_name)
        ].each do |taxonomy_name|
          next if taxonomies.with_matching_name(taxonomy_name).exists?

          taxonomies.create(name: taxonomy_name)
        end
      end

      def ensure_default_automatic_taxons
        collections_taxonomy = taxonomies.with_matching_name(Spree.t(:taxonomy_collections_name)).first
        return unless collections_taxonomy.present?

        [
          { name: Spree.t('automatic_taxon_names.on_sale'), rule_type: 'Spree::TaxonRules::Sale', rule_value: 'true' },
          { name: Spree.t('automatic_taxon_names.new_arrivals'), rule_type: 'Spree::TaxonRules::AvailableOn', rule_value: 30 }
        ].each do |config|
          next if collections_taxonomy.taxons.automatic.with_matching_name(config[:name]).exists?

          collections_taxonomy.taxons.create!(
            name: config[:name],
            automatic: true,
            parent: collections_taxonomy.root,
            taxon_rules: [Spree::TaxonRule.new(type: config[:rule_type], value: config[:rule_value])]
          )
        end
      end

      def create_default_policies
        super

        policies.each do |policy|
          links.find_or_create_by(linkable: policy)
        end
      end
    end
  end
end

Spree::Store.prepend(Spree::PageBuilder::StoreDecorator)

class Organisation < ActiveRecord::Base
  has_many :child_organisational_relationships,
           foreign_key: :parent_organisation_id,
           class_name: "OrganisationalRelationship"
  has_many :parent_organisational_relationships,
           foreign_key: :child_organisation_id,
           class_name: "OrganisationalRelationship",
           dependent: :destroy
  has_many :child_organisations,
           through: :child_organisational_relationships
  has_many :parent_organisations,
           through: :parent_organisational_relationships

  has_and_belongs_to_many :extra_sites,
                          join_table: 'organisations_sites',
                          class_name: 'Site'

  has_many :sites
  has_many :hosts, through: :sites
  has_many :mappings, through: :sites

  validates_presence_of :whitehall_slug
  validates_uniqueness_of :whitehall_slug
  validates_presence_of :title
  validates_presence_of :content_id

  # Returns organisations ordered by descending error count across
  # all their sites.
  scope :leaderboard, -> {
    select(
      <<-POSTGRESQL
        organisations.title,
        organisations.whitehall_slug,
        COUNT(*)                                     AS site_count,
        SUM(site_mapping_counts.mapping_count)       AS mappings_across_sites,
        SUM(unresolved_mapping_counts.mapping_count) AS unresolved_mapping_count,
        SUM(error_counts.error_count)                AS error_count
      POSTGRESQL
    ).
    joins(
      <<-POSTGRESQL
        INNER JOIN sites
               ON sites.organisation_id = organisations.id
        LEFT JOIN (SELECT sites.id AS site_id,
                          COUNT(*)::integer AS mapping_count
                   FROM   mappings
                          INNER JOIN sites
                                  ON sites.id = mappings.site_id
                   GROUP  BY sites.id) site_mapping_counts ON site_mapping_counts.site_id = sites.id
        LEFT JOIN (SELECT sites.id AS site_id,
                          COUNT(*)::integer AS mapping_count
                   FROM   mappings
                          INNER JOIN sites
                                  ON sites.id = mappings.site_id
                   WHERE  mappings.type = 'unresolved'
                   GROUP  BY sites.id) unresolved_mapping_counts ON unresolved_mapping_counts.site_id = sites.id
        LEFT JOIN (SELECT hosts.site_id AS site_id,
                          SUM(count)::integer AS error_count
                   FROM   daily_hit_totals
                          INNER JOIN hosts
                                  ON hosts.id = daily_hit_totals.host_id
                   WHERE  daily_hit_totals.http_status = '404'
                   AND daily_hit_totals.total_on >= (current_date - 30)
                   GROUP BY site_id) AS error_counts ON error_counts.site_id = sites.id
      POSTGRESQL
    ).
    group('organisations.id').
    order('error_count DESC NULLS LAST')
  }

  def to_param
    whitehall_slug
  end
end

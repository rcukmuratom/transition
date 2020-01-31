FactoryBot.define do
  factory :organisation do
    title { "Orgtastic" }

    ga_profile_id { "46600000" }
    whitehall_type { "Executive non-departmental public body" }
    sequence(:whitehall_slug) { |n| "org-#{n}" }
    content_id { SecureRandom.uuid }

    trait :with_site do
      after(:create) do |site, _|
        create_list(:site, 1, organisation: site)
      end
    end
  end
end

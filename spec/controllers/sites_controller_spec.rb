require "rails_helper"

describe SitesController do
  let(:site)    { create :site, abbr: "moj" }
  let(:gds_bob) { create(:gds_editor, name: "Bob Terwhilliger") }

  describe "#edit" do
    context "when the user does have permission" do
      before do
        login_as gds_bob
      end

      it "displays the form" do
        get :edit, params: { id: site.abbr }
        expect(response.status).to eql(200)
      end
    end

    context "when the user does not have permission" do
      def make_request
        get :edit, params: { id: site.abbr }
      end

      it_behaves_like "disallows editing by non-GDS Editors"
    end
  end

  context 'logged in' do
    before do
      login_as gds_bob
    end

    describe '#show' do
      it 'loads the site' do
        site = create :site
        get :show, params: { id: site.abbr }
        expect(assigns(:site)).to eq(site)
      end

      context 'when the site has no hosts' do
        render_views

        it 'renders a sensible placeholder name for the site' do
          site = create :site_without_host
          get :show, params: { id: site.abbr }
          expect(response.body).to include("#{site.abbr} (no hosts configured)")
        end
      end
    end

    describe '#new' do
      let(:organisation) { create :organisation }

      before do
        get :new, params: { organisation: organisation.whitehall_slug }
      end

      it 'assigns a new organisation' do
        expect(assigns(:site)).not_to be_nil
      end

      it 'new site has the correct organisation id' do
        expect(assigns(:site).organisation_id).to eq(organisation.id)
      end
    end

    describe '#create' do
      let(:organisation) { create :organisation }
      it 'creates a new site' do
        params = {
          organisation_id: organisation.id,
          launch_date: Time.zone.today + 10.days,
          abbr: 'MOJ',
          query_params: 'search=q',
          homepage: 'http://department.gov.uk',
          global_new_url: 'http://gov.uk/department',
          global_redirect_append_path: true,
          homepage_title: 'Deparment of M'
        }

        expect do
          post :create, params: { site: params, host_names: 'example.com, example.net' }
        end.to change { Site.all.count }.by(1)

        site = Site.find_by(abbr: 'MOJ')
        expect(site.launch_date).to eq(params[:launch_date])
        expect(site.abbr).to eq(params[:abbr])
        expect(site.query_params).to eq(params[:query_params])
        expect(site.homepage).to eq(params[:homepage])
        expect(site.global_new_url).to eq(params[:global_new_url])
        expect(site.global_redirect_append_path)
          .to eq(params[:global_redirect_append_path])
        expect(site.homepage_title).to eq(params[:homepage_title])
        expect(site.organisation).to eq(organisation)
        # Check hosts
        expect(site.hosts.length).to eq(2)
        host = site.hosts.where(hostname: "example.com").first
        expect(host).to be_present
        expect(host.cname).to eq("example.com")
        host = site.hosts.where(hostname: "example.net").first
        expect(host).to be_present
        expect(host.cname).to eq("example.net")
      end
    end

    describe '#update' do
      let(:site) { create :site }

      it 'updates a site' do
        # To start with, we should have one host created by the factory
        expect(site.hosts.length).to eq(1)

        params = {
          launch_date: Time.zone.today + 10.days,
          abbr: 'MOJ',
          query_params: 'search=q',
          homepage: 'http://department.gov.uk',
          global_new_url: 'http://gov.uk/department',
          global_redirect_append_path: true,
          homepage_title: 'Deparment of M'
        }
        # Include the default host as well as a new one
        host_names = "#{site.hosts.first.hostname}, example.org"

        patch :update, params: { id: site.abbr, site: params, host_names: host_names }
        site.reload
        expect(site.launch_date).to eq(params[:launch_date])
        expect(site.abbr).to eq(params[:abbr])
        expect(site.query_params).to eq(params[:query_params])
        expect(site.homepage).to eq(params[:homepage])
        expect(site.global_new_url).to eq(params[:global_new_url])
        expect(site.global_redirect_append_path)
          .to eq(params[:global_redirect_append_path])
        expect(site.homepage_title).to eq(params[:homepage_title])
        # Check new host was added
        expect(site.hosts.length).to eq(2)
        host = site.hosts.where(hostname: "example.org").first
        expect(host).to be_present
        expect(host.cname).to eq("example.org")
      end
    end
  end
end

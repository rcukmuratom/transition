require 'spec_helper'
require 'transition/import/whitehall/mappings_csv'

def csv_for(old_path, govuk_path, whitehall_state = 'published')
  StringIO.new(<<-END)
Old URL,New URL,Admin URL,State
http://dft.gov.uk#{old_path},https://www.gov.uk#{govuk_path},http://whitehall-admin/#{rand(1000)},#{whitehall_state}
END
end

describe Transition::Import::Whitehall::MappingsCSV do
  describe 'from_csv' do
    let(:as_user) { create(:user, name: 'C-3PO', is_robot: true) }

    context 'site and host exists' do
      let!(:site) { create(:site, abbr: 'dft', query_params: 'significant') }

      before do
        Transition::Import::Whitehall::MappingsCSV.new(as_user).from_csv(csv)
      end

      context 'rosy case' do
        let(:csv) { csv_for('/oldurl', '/new') }

        subject(:mapping) { Mapping.first }

        specify { Mapping.count.should == 1 }

        its(:site)        { should == site }
        its(:path)        { should == '/oldurl' }
        its(:new_url)     { should == 'https://www.gov.uk/new' }
        its(:type)        { should == 'redirect' }
      end

      context 'Old URL is not canonical, no mapping' do
        let(:csv) { csv_for('/oldurl?significant=aha&ignored=ohyes', '/new') }

        subject(:mapping) { Mapping.first }

        specify { Mapping.count.should == 1 }

        its(:site)    { should == site }
        its(:path)    { should == '/oldurl?significant=aha' }
        its(:new_url) { should == 'https://www.gov.uk/new' }
        its(:type)    { should == 'redirect' }
      end

      context 'existing mapping and the Old URL is not canonical' do
        let(:mapping) { create(:mapping, site: site, path: '/oldurl?significant=aha', new_url: 'https://www.gov.uk/mediocre') }
        let(:csv) { csv_for('/oldurl?significant=aha&ignored=ohyes', '/amazing') }

        subject(:mapping) { Mapping.first }

        specify { Mapping.count.should == 1 }

        its(:site)    { should == site }
        its(:path)    { should == '/oldurl?significant=aha' }
        its(:new_url) { should == 'https://www.gov.uk/amazing' }
        its(:type)    { should == 'redirect' }
      end

      context 'existing redirect mapping edited by a human' do
        let(:csv) {
          create(:redirect, from_redirector: true, site: site, path: '/oldurl', new_url: 'https://www.gov.uk/curated')
          csv_for('/oldurl', '/automated')
        }

        subject(:mapping) { Mapping.first }

        specify { Mapping.count.should == 1 }

        its(:new_url)     { should == 'https://www.gov.uk/curated' }
      end

      context 'existing archive mapping edited by a human' do
        let(:csv) {
          create(:archived, from_redirector: true, site: site, path: '/oldurl')
          csv_for('/oldurl', '/automated')
        }

        subject(:mapping) { Mapping.first }

        specify { Mapping.count.should == 1 }

        its(:type)    { should == 'redirect' }
        its(:new_url) { should == 'https://www.gov.uk/automated' }
      end

      context 'existing unresolved mapping edited by a human' do
        let(:csv) {
          create(:unresolved, from_redirector: true, site: site, path: '/oldurl')
          csv_for('/oldurl', '/automated')
        }

        subject(:mapping) { Mapping.first }

        specify { Mapping.count.should == 1 }

        its(:type)    { should == 'redirect' }
        its(:new_url) { should == 'https://www.gov.uk/automated' }
      end

      context 'CSV row without an Old URL' do
        let(:csv) { StringIO.new(<<-END)
Old URL,New URL,Admin URL,State
,https://www.gov.uk/a-document,http://whitehall-admin/#{rand(1000)},published
END
}

        specify { Mapping.count.should == 0 }
      end

      context 'row has a State which isn\'t "published"' do
        let(:csv) { csv_for('/oldurl', '/new', 'draft') }

        specify { Mapping.all.count.should == 0 }
      end

      context 'Old URL is unparseable' do
        let(:csv) { StringIO.new(<<-END)
Old URL,New URL,Admin URL,State
http://_____/old,https://www.gov.uk/a-document,http://whitehall-admin/#{rand(1000)},published
END
}

        specify { Mapping.all.count.should == 0 }
      end
    end

    context 'testing version recording', versioning: true do
      let!(:site) { create(:site, abbr: 'dft', query_params: 'significant') }
      let(:csv) { csv_for('/oldurl', '/new') }

      before do
        Transition::Import::Whitehall::MappingsCSV.new(as_user).from_csv(csv)
      end

      subject(:mapping) { Mapping.first }

      specify 'records the changes being made by a robot user' do
        mapping.versions.size.should == 1
        mapping.versions.first.whodunnit.should == as_user.name
        mapping.versions.first.user_id.should == as_user.id
      end

      specify 'reverts the whodunnit user' do
        ::PaperTrail.whodunnit.should be_nil
      end
    end

    context 'no site/host for Old URL' do
      let(:csv) { csv_for('/oldurl', '/amazing') }

      it 'logs an unknown host' do
        Rails.logger.should_receive(:warn).with("Skipping mapping for unknown host in Whitehall URL CSV: 'dft.gov.uk'")
        Transition::Import::Whitehall::MappingsCSV.new(as_user).from_csv(csv)
      end
    end
  end
end

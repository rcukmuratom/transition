require 'spec_helper'
require 'transition/import/dns_details'

describe Transition::Import::DnsDetails do
  describe '#from_nameserver!' do
    let(:a_host) { create :host, hostname: 'www.direct.gov.uk' }

    describe 'a host that has a CNAME' do
      before do
        cname_record = double(name: 'redirector-cdn.production.govuk.service.gov.uk', ttl: 100)
        Resolv::DNS.any_instance
            .stub(:getresource).with('www.direct.gov.uk', Resolv::DNS::Resource::IN::CNAME)
            .and_return(cname_record)

        Transition::Import::DnsDetails.from_nameserver!([a_host])
      end

      subject { a_host }

      its(:cname)      { should =~ /gov.uk$/ }
      its(:ip_address) { should be_nil }
      its(:ttl)        { should be_between(1, 999999) }
    end

    describe 'a host that does not have a CNAME' do
      before do
        Resolv::DNS.any_instance
            .stub(:getresource).with('www.direct.gov.uk', Resolv::DNS::Resource::IN::CNAME)
            .and_raise(Resolv::ResolvError)

        a_record = double(address: '1.1.1.1', ttl: 100)
        Resolv::DNS.any_instance
            .stub(:getresource).with('www.direct.gov.uk', Resolv::DNS::Resource::IN::A)
            .and_return(a_record)

        Transition::Import::DnsDetails.from_nameserver!([a_host])
      end

      subject { a_host }

      its(:cname)      { should be_nil }
      its(:ip_address) { should eql('1.1.1.1') }
      its(:ttl)        { should eql(100) }
    end
  end
end

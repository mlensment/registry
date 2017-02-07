require 'rails_helper'

RSpec.describe 'admin/disputes/edit' do
  let(:dispute) { build_stubbed(:dispute) }
  let(:dispute_presenter) { instance_spy(DisputePresenter) }

  before :example do
    assign(:dispute, dispute)
    allow(DisputePresenter).to receive(:new).and_return(dispute_presenter)
    stub_template '_form.html.erb' => ''
  end

  describe 'breadcrumbs section' do
    it 'has link to disputes' do
      render
      expect(rendered).to have_link('Disputes', href: admin_disputes_path)
    end

    it 'has current dispute name' do
      expect(dispute_presenter).to receive(:name).and_return('test name')
      render
      expect(rendered).to have_text('test name')
    end
  end

  it 'has header' do
    render
    expect(rendered).to have_text('Edit dispute')
  end
end
require 'rails_helper'
require_relative 'registrar_shared'

RSpec.describe 'mailers/shared/registrar/_registrar.ru.text.erb' do
  include_examples 'domain mailer registrar info'
end

require 'open3'

class Certificate < ActiveRecord::Base
  include Versions

  belongs_to :api_user

  SIGNED = 'signed'
  UNSIGNED = 'unsigned'
  EXPIRED = 'expired'
  REVOKED = 'revoked'
  VALID = 'valid'

  validates :csr, presence: true

  def parsed_crt
    @p_crt ||= OpenSSL::X509::Certificate.new(crt) if crt
  end

  def parsed_csr
    @p_csr ||= OpenSSL::X509::Request.new(csr) if csr
  end

  def revoked?
    status == REVOKED
  end

  def status
    return UNSIGNED if crt.blank?
    return @cached_status if @cached_status

    @cached_status = SIGNED

    if parsed_crt.not_before > Time.zone.now.utc && parsed_crt.not_after < Time.zone.now.utc
      @cached_status = EXPIRED
    end

    crl = OpenSSL::X509::CRL.new(File.open("#{ENV['crl_dir']}/crl.pem").read)
    return @cached_status unless crl.revoked.map(&:serial).include?(parsed_crt.serial)

    @cached_status = REVOKED
  end

  def sign!
    csr_file = Tempfile.new('client_csr')
    csr_file.write(csr)
    csr_file.rewind

    crt_file = Tempfile.new('client_crt')
    _out, err, _st = Open3.capture3("openssl ca -config #{ENV['openssl_config_path']} -keyfile #{ENV['ca_key_path']} \
    -cert #{ENV['ca_cert_path']} \
    -extensions usr_cert -notext -md sha256 \
    -in #{csr_file.path} -out #{crt_file.path} -key '#{ENV['ca_key_password']}' -batch")

    if err.match(/Data Base Updated/)
      crt_file.rewind
      self.crt = crt_file.read
      save!
    else
      logger.error('FAILED TO CREATE CLIENT CERTIFICATE')
      if err.match(/TXT_DB error number 2/)
        errors.add(:base, I18n.t('failed_to_create_crt_csr_already_signed'))
        logger.error('CSR ALREADY SIGNED')
      else
        errors.add(:base, I18n.t('failed_to_create_certificate'))
      end
      logger.error(err)
      # rubocop:disable Rails/Output
      puts "Certificate sign issue: #{err.inspect}" if Rails.env.test?
      # rubocop:enable Rails/Output
      return false
    end
  end

  def revoke!
    crt_file = Tempfile.new('client_crt')
    crt_file.write(crt)
    crt_file.rewind

    _out, err, _st = Open3.capture3("openssl ca -config #{ENV['openssl_config_path']} -keyfile #{ENV['ca_key_path']} \
      -cert #{ENV['ca_cert_path']} \
      -revoke #{crt_file.path} -key '#{ENV['ca_key_password']}' -batch")

    if err.match(/Data Base Updated/) || err.match(/ERROR:Already revoked/)
      save!
      @cached_status = REVOKED
    else
      errors.add(:base, I18n.t('failed_to_revoke_certificate'))
      logger.error('FAILED TO REVOKE CLIENT CERTIFICATE')
      logger.error(err)
      return false
    end

    self.class.update_registry_crl
    self.class.reload_apache
  end

  class << self
    def update_crl
      update_id_crl
      update_registry_crl
      reload_apache
    end

    def update_id_crl
      %x(
        mkdir -p #{ENV['crl_dir']}/crl-id-temp
        cd #{ENV['crl_dir']}/crl-id-temp

        wget https://sk.ee/crls/esteid/esteid2007.crl
        wget https://sk.ee/crls/juur/crl.crl
        wget https://sk.ee/crls/eeccrca/eeccrca.crl
        wget https://sk.ee/repository/crls/esteid2011.crl


        # convert to PEM
        openssl crl -in esteid2007.crl -out esteid2007.crl -inform DER
        openssl crl -in crl.crl -out crl.crl -inform DER
        openssl crl -in eeccrca.crl -out eeccrca.crl -inform DER
        openssl crl -in esteid2011.crl -out esteid2011.crl -inform DER

        ln -s crl.crl `openssl crl -hash -noout -in crl.crl`.r0
        ln -s esteid2007.crl `openssl crl -hash -noout -in esteid2007.crl`.r0
        ln -s eeccrca.crl `openssl crl -hash -noout -in eeccrca.crl`.r0
        ln -s esteid2011.crl `openssl crl -hash -noout -in esteid2011.crl`.r0

        rm -rf #{ENV['crl_dir']}/*.crl #{ENV['crl_dir']}/*.r0

        mv #{ENV['crl_dir']}/crl-id-temp/* #{ENV['crl_dir']}

        rm -rf #{ENV['crl_dir']}/crl-id-temp
      )
    end

    def update_registry_crl
      %x(
        mkdir -p #{ENV['crl_dir']}/crl-temp
        cd #{ENV['crl_dir']}/crl-temp

        openssl ca -config #{ENV['openssl_config_path']} -keyfile #{ENV['ca_key_path']} -cert \
        #{ENV['ca_cert_path']} -gencrl -out #{ENV['crl_dir']}/crl-temp/crl.pem -key \
        '#{ENV['ca_key_password']}' -batch

        ln -s crl.pem `openssl crl -hash -noout -in crl.pem`.r1

        rm -rf #{ENV['crl_dir']}/*.pem #{ENV['crl_dir']}/*.r1

        mv #{ENV['crl_dir']}/crl-temp/* #{ENV['crl_dir']}

        rm -rf #{ENV['crl_dir']}/crl-temp
      )
    end

    def reload_apache
      `sudo /etc/init.d/apache2 reload`
    end
  end
end
